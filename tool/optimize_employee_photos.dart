import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

/// One-time employee photo optimizer.
///
/// IMPORTANT:
/// - Run this only from a trusted admin machine.
/// - Pass a Supabase SERVICE_ROLE key at runtime. Never commit that key.
/// - Originals are backed up before replacement.
/// - Dry-run is the default. Add --apply to make changes.
///
/// Example:
/// dart run tool/optimize_employee_photos.dart ///   --url=https://PROJECT.supabase.co ///   --service-role=YOUR_SERVICE_ROLE_KEY
///
/// Apply after reviewing dry-run:
/// dart run tool/optimize_employee_photos.dart ///   --url=https://PROJECT.supabase.co ///   --service-role=YOUR_SERVICE_ROLE_KEY --apply
void main(List<String> args) async {
  final options = _parseArgs(args);
  final baseUrl = options['url'] ?? '';
  final serviceRole = options['service-role'] ?? '';
  final apply = args.contains('--apply');

  if (baseUrl.isEmpty || serviceRole.isEmpty) {
    stderr.writeln(
      'Required: --url=https://PROJECT.supabase.co '
      '--service-role=SERVICE_ROLE_KEY [--apply]',
    );
    exitCode = 64;
    return;
  }

  final client = http.Client();
  try {
    final objects = await _listObjects(client, baseUrl, serviceRole);

    // Some Storage API versions omit object size metadata from list responses.
    // Download only when size is unknown; this endpoint is supported for the
    // same objects we must later optimize, unlike HEAD on some Storage setups.
    final hydrated = <_StorageObject>[];
    final prefetched = <String, Uint8List>{};
    for (final object in objects) {
      if (object.size > 0) {
        hydrated.add(object);
      } else {
        final bytes = await _download(client, baseUrl, serviceRole, object.name);
        prefetched[object.name] = bytes;
        hydrated.add(_StorageObject(
          name: object.name,
          size: bytes.length,
          contentType: object.contentType,
        ));
      }
    }

    final candidates = hydrated.where((o) => o.size > 500 * 1024).toList()
      ..sort((a, b) => b.size.compareTo(a.size));

    stdout.writeln(
      'Found ${objects.length} employee photos; '
      '${candidates.length} are over 500 KB.',
    );
    if (!apply) {
      stdout.writeln('DRY RUN: no Storage objects will be changed.');
    }

    var processed = 0;
    var originalBytes = 0;
    var optimizedBytes = 0;

    for (final object in candidates) {
      final original = prefetched.remove(object.name) ??
          await _download(client, baseUrl, serviceRole, object.name);
      final decoded = img.decodeImage(original);
      if (decoded == null) {
        stderr.writeln('SKIP ${object.name}: unsupported/corrupt image');
        continue;
      }

      final resized = decoded.width > 480 || decoded.height > 480
          ? img.copyResize(
              decoded,
              width: decoded.width >= decoded.height ? 480 : null,
              height: decoded.height > decoded.width ? 480 : null,
              interpolation: img.Interpolation.average,
            )
          : decoded;
      final optimized = Uint8List.fromList(img.encodeJpg(resized, quality: 78));

      stdout.writeln(
        '${object.name}: ${_kb(original.length)} KB -> '
        '${_kb(optimized.length)} KB',
      );

      if (!apply) continue;

      // Preserve the exact original under a separate private-ish backup path
      // in the same bucket before overwriting the live profile object.
      final backupName =
          '_migration_backup/${DateTime.now().millisecondsSinceEpoch}/${object.name}';
      await _upload(
        client,
        baseUrl,
        serviceRole,
        backupName,
        original,
        object.contentType,
        upsert: false,
        cacheControl: '3600',
      );

      await _upload(
        client,
        baseUrl,
        serviceRole,
        object.name,
        optimized,
        'image/jpeg',
        upsert: true,
        cacheControl: '31536000',
      );

      // Verify that the live object can be read and decodes after replacement.
      final verified = await _download(client, baseUrl, serviceRole, object.name);
      if (img.decodeImage(verified) == null || verified.length > 500 * 1024) {
        stderr.writeln('VERIFY FAILED ${object.name}; restoring original.');
        await _upload(
          client,
          baseUrl,
          serviceRole,
          object.name,
          original,
          object.contentType,
          upsert: true,
          cacheControl: '3600',
        );
        continue;
      }

      processed++;
      originalBytes += original.length;
      optimizedBytes += verified.length;
    }

    if (apply) {
      stdout.writeln(
        'Completed: $processed optimized. '
        '${_kb(originalBytes)} KB -> ${_kb(optimizedBytes)} KB.',
      );
      stdout.writeln(
        'Backups were retained under employee-photos/_migration_backup/.',
      );
    }
  } finally {
    client.close();
  }
}

Map<String, String> _parseArgs(List<String> args) {
  final result = <String, String>{};
  for (final arg in args) {
    if (!arg.startsWith('--') || !arg.contains('=')) continue;
    final index = arg.indexOf('=');
    result[arg.substring(2, index)] = arg.substring(index + 1);
  }
  return result;
}

Future<List<_StorageObject>> _listObjects(
  http.Client client,
  String baseUrl,
  String key,
) async {
  // Objects are stored as EMPLOYEE_ID/profile. Supabase Storage list is
  // folder-based, so first list the root folders and then list each folder.
  final roots = await _listPrefix(client, baseUrl, key, '');
  final result = <_StorageObject>[];

  for (final root in roots) {
    final folder = root['name']?.toString() ?? '';
    if (folder.isEmpty || folder == '_migration_backup') continue;
    final children = await _listPrefix(client, baseUrl, key, folder);
    for (final row in children) {
      final child = row['name']?.toString() ?? '';
      if (child.isEmpty) continue;
      final metadata = (row['metadata'] as Map?)?.cast<String, dynamic>() ?? {};
      final size = metadata['size'] ??
          metadata['contentLength'] ??
          metadata['content-length'] ??
          row['size'];
      result.add(_StorageObject(
        name: '$folder/$child',
        size: size is num ? size.toInt() : int.tryParse('$size') ?? 0,
        contentType: metadata['mimetype']?.toString() ??
            metadata['contentType']?.toString() ??
            'application/octet-stream',
      ));
    }
  }
  return result;
}

Future<List<Map<String, dynamic>>> _listPrefix(
  http.Client client,
  String baseUrl,
  String key,
  String prefix,
) async {
  final result = <Map<String, dynamic>>[];
  var offset = 0;
  const limit = 100;

  while (true) {
    final response = await client.post(
      Uri.parse('$baseUrl/storage/v1/object/list/employee-photos'),
      headers: _headers(key, json: true),
      body: jsonEncode({
        'prefix': prefix,
        'limit': limit,
        'offset': offset,
        'sortBy': {'column': 'name', 'order': 'asc'},
      }),
    );
    _ensureSuccess(response, 'list prefix $prefix');
    final value = jsonDecode(response.body) as List<dynamic>;
    final rows =
        value.map((e) => (e as Map).cast<String, dynamic>()).toList();
    result.addAll(rows);
    if (rows.length < limit) break;
    offset += limit;
  }
  return result;
}

Future<Uint8List> _download(
  http.Client client,
  String baseUrl,
  String key,
  String name,
) async {
  final encoded = name.split('/').map(Uri.encodeComponent).join('/');
  final response = await client.get(
    Uri.parse('$baseUrl/storage/v1/object/employee-photos/$encoded'),
    headers: _headers(key),
  );
  _ensureSuccess(response, 'download $name');
  return response.bodyBytes;
}

Future<void> _upload(
  http.Client client,
  String baseUrl,
  String key,
  String name,
  Uint8List bytes,
  String contentType, {
  required bool upsert,
  required String cacheControl,
}) async {
  final encoded = name.split('/').map(Uri.encodeComponent).join('/');
  final response = await client.post(
    Uri.parse('$baseUrl/storage/v1/object/employee-photos/$encoded'),
    headers: {
      ..._headers(key),
      'Content-Type': contentType,
      'cache-control': 'max-age=$cacheControl',
      'x-upsert': upsert ? 'true' : 'false',
    },
    body: bytes,
  );
  _ensureSuccess(response, 'upload $name');
}

Map<String, String> _headers(String key, {bool json = false}) => {
      'Authorization': 'Bearer $key',
      'apikey': key,
      if (json) 'Content-Type': 'application/json',
    };

void _ensureSuccess(http.Response response, String action) {
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw HttpException(
      '$action failed (${response.statusCode}): ${response.body}',
    );
  }
}

String _kb(int bytes) => (bytes / 1024).toStringAsFixed(1);

class _StorageObject {
  const _StorageObject({
    required this.name,
    required this.size,
    required this.contentType,
  });

  final String name;
  final int size;
  final String contentType;
}
