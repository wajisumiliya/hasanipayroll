import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<String?> resolveEmployeePhotoUrl(String? photoUrl) async {
  final raw = photoUrl?.trim() ?? '';
  if (raw.isEmpty) return null;

  var path = raw;
  const markers = [
    '/storage/v1/object/public/employee-photos/',
    '/storage/v1/object/authenticated/employee-photos/',
    '/storage/v1/object/sign/employee-photos/',
  ];
  var storagePathFound = false;
  for (final marker in markers) {
    final markerIndex = raw.indexOf(marker);
    if (markerIndex >= 0) {
      path = raw.substring(markerIndex + marker.length);
      storagePathFound = true;
      break;
    }
  }

  // Preserve genuinely external legacy photo URLs. Supabase Storage URLs are
  // always converted back to an object path and freshly signed.
  if (!storagePathFound && Uri.tryParse(raw)?.hasAbsolutePath == true) {
    final uri = Uri.tryParse(raw);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return raw;
    }
  }

  path = Uri.decodeComponent(
    path.split('?').first.replaceFirst(RegExp(r'^/+'), ''),
  );
  if (path.isEmpty) return null;

  try {
    return await Supabase.instance.client.storage
        .from('employee-photos')
        .createSignedUrl(path, 3600);
  } catch (_) {
    return null;
  }
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
  late Future<String?> _resolvedUrl;

  @override
  void initState() {
    super.initState();
    _resolvedUrl = resolveEmployeePhotoUrl(widget.photoUrl);
  }

  @override
  void didUpdateWidget(covariant EmployeePhotoImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoUrl?.trim() != widget.photoUrl?.trim()) {
      _resolvedUrl = resolveEmployeePhotoUrl(widget.photoUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _resolvedUrl,
      builder: (context, snapshot) {
        final url = snapshot.data;
        if (url == null || url.isEmpty) {
          return widget.fallbackBuilder(context);
        }
        return Image.network(
          url,
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
