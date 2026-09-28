import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  Future<String?> _signedUrl() async {
    final raw = widget.photoUrl?.trim() ?? '';
    if (raw.isEmpty) return null;

    var path = raw;
    const marker = '/storage/v1/object/public/employee-photos/';
    final markerIndex = raw.indexOf(marker);
    if (markerIndex >= 0) {
      path = raw.substring(markerIndex + marker.length);
    } else {
      const privateMarker = '/storage/v1/object/authenticated/employee-photos/';
      final privateIndex = raw.indexOf(privateMarker);
      if (privateIndex >= 0) {
        path = raw.substring(privateIndex + privateMarker.length);
      }
    }

    path = path.split('?').first.replaceFirst(RegExp(r'^/+'), '');
    if (path.isEmpty) return null;

    try {
      return await Supabase.instance.client.storage
          .from('employee-photos')
          .createSignedUrl(path, 300);
    } catch (_) {
      return null;
    }
  }

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
      child: FutureBuilder<String?>(
        future: _signedUrl(),
        builder: (context, snapshot) {
          final url = snapshot.data;
          if (url == null || url.isEmpty) return _fallback();
          return Image.network(
            url,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (_, __, ___) => _fallback(),
          );
        },
      ),
    );
  }
}
