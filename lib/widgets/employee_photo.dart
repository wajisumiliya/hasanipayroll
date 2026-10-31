import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/neon_api.dart';
import '../services/request_limiter.dart';

// Image bytes stay private and are shared only within the current login session.
final Map<String, Future<Uint8List?>> _photoCache = {};
int _photoCacheSession = -1;
int _photoRevision = 0;
final _photoRequests = RequestLimiter(4);

void invalidateEmployeePhoto(String employeeId) {
  _photoRevision++;
  _photoCache.removeWhere((key, _) => key.startsWith('$employeeId:'));
}

Future<Uint8List?> loadEmployeePhoto(
    String employeeId, String? reference) async {
  if (_photoCacheSession != NeonApi.sessionVersion) {
    _photoCache.clear();
    _photoCacheSession = NeonApi.sessionVersion;
  }
  if (reference == null || reference.trim().isEmpty) return null;
  final key = '$employeeId:$reference';
  if (_photoCache.containsKey(key)) return _photoCache[key];
  // Bound memory use for long-running admin sessions.
  if (_photoCache.length >= 100) _photoCache.remove(_photoCache.keys.first);
  final session = NeonApi.sessionVersion;
  final future = _photoRequests.run<Uint8List?>(() async {
    if (session != NeonApi.sessionVersion) return null;
    final bytes = await NeonApi.photoRequest(employeeId);
    return session == NeonApi.sessionVersion ? bytes : null;
  });
  _photoCache[key] = future;
  try {
    final bytes = await future;
    if (bytes == null) _photoCache.remove(key);
    return bytes;
  } catch (_) {
    _photoCache.remove(key);
    return null;
  }
}

String? employeeIdFromPhotoReference(String? reference) {
  var path = reference?.trim() ?? '';
  if (path.isEmpty) return null;
  for (final marker in [
    '/storage/v1/object/public/employee-photos/',
    '/storage/v1/object/authenticated/employee-photos/',
    '/storage/v1/object/sign/employee-photos/',
  ]) {
    if (path.contains(marker)) {
      path = path.split(marker).last;
      break;
    }
  }
  try {
    path = Uri.decodeComponent(path.split('?').first);
  } on FormatException {
    return null;
  }
  for (final prefix in ['neon-photo/', 'employee-photos/']) {
    if (path.startsWith(prefix)) path = path.substring(prefix.length);
  }
  final id = path.split('/').first;
  return RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(id) ? id : null;
}

class EmployeePhotoImage extends StatefulWidget {
  const EmployeePhotoImage({
    super.key,
    required this.photoUrl,
    required this.fallbackBuilder,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.topCenter,
  });

  final String? photoUrl;
  final WidgetBuilder fallbackBuilder;
  final BoxFit fit;
  final AlignmentGeometry alignment;

  @override
  State<EmployeePhotoImage> createState() => _EmployeePhotoImageState();
}

class _EmployeePhotoImageState extends State<EmployeePhotoImage> {
  late Future<Uint8List?> _photoBytes;
  int _sessionVersion = -1;
  int _loadedRevision = -1;

  @override
  void initState() {
    super.initState();
    _loadPhoto();
  }

  @override
  void didUpdateWidget(covariant EmployeePhotoImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoUrl?.trim() != widget.photoUrl?.trim()) {
      _loadPhoto();
    }
  }

  void _loadPhoto() {
    _sessionVersion = NeonApi.sessionVersion;
    _loadedRevision = _photoRevision;
    final id = employeeIdFromPhotoReference(widget.photoUrl);
    _photoBytes = id == null
        ? Future.value(null)
        : loadEmployeePhoto(id, widget.photoUrl);
  }

  @override
  Widget build(BuildContext context) {
    if (_sessionVersion != NeonApi.sessionVersion ||
        _loadedRevision != _photoRevision) {
      _loadPhoto();
    }
    return FutureBuilder<Uint8List?>(
      future: _photoBytes,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done ||
            bytes == null ||
            bytes.isEmpty) {
          return widget.fallbackBuilder(context);
        }
        return Image.memory(
          bytes,
          fit: widget.fit,
          alignment: widget.alignment,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => widget.fallbackBuilder(context),
        );
      },
    );
  }
}

class EmployeePhoto extends StatefulWidget {
  const EmployeePhoto({
    super.key,
    required this.name,
    this.photoUrl,
    this.radius = 24,
    this.backgroundColor = const Color(0xFFEAF0FF),
    this.foregroundColor = const Color(0xFF2D55D8),
    this.borderColor,
  });

  final String name;
  final String? photoUrl;
  final double radius;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;

  @override
  State<EmployeePhoto> createState() => _EmployeePhotoState();
}

class _EmployeePhotoState extends State<EmployeePhoto> {
  Widget _fallback() {
    final trimmed = widget.name.trim();
    return Center(
      child: Text(
        trimmed.isEmpty ? '?' : trimmed[0].toUpperCase(),
        style: TextStyle(
          color: widget.foregroundColor,
          fontWeight: FontWeight.w800,
          fontSize: widget.radius * .72,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.radius * 2,
      height: widget.radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.backgroundColor,
        border: Border.all(
          color: widget.borderColor ?? Colors.white.withValues(alpha: .9),
          width: widget.radius >= 36 ? 3 : 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 7,
            offset: Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: EmployeePhotoImage(
        photoUrl: widget.photoUrl,
        fallbackBuilder: (_) => _fallback(),
      ),
    );
  }
}
