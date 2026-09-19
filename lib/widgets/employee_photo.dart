import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmployeePhoto extends StatelessWidget {
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

  String? _storagePath(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return null;
    if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
      return clean;
    }
    final uri = Uri.tryParse(clean);
    if (uri == null) return null;
    const marker = '/storage/v1/object/public/employee-photos/';
    final index = uri.path.indexOf(marker);
    if (index < 0) return null;
    final encoded = uri.path.substring(index + marker.length);
    return Uri.decodeComponent(encoded);
  }

  Future<String?> _resolvedUrl() async {
    final raw = photoUrl?.trim() ?? '';
    final path = _storagePath(raw);
    if (path == null || path.isEmpty) return null;
    try {
      return await Supabase.instance.client.storage
          .from('employee-photos')
          .createSignedUrl(path, 3600);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Text(
        name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
        style: TextStyle(
          color: foregroundColor,
          fontWeight: FontWeight.w800,
          fontSize: radius * .72,
        ),
      ),
    );

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor,
        border: Border.all(
          color: borderColor ?? Colors.white.withValues(alpha: .9),
          width: radius >= 36 ? 3 : 2,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 7, offset: Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: FutureBuilder<String?>(
        future: _resolvedUrl(),
        builder: (context, snapshot) {
          final url = snapshot.data?.trim() ?? '';
          if (url.isEmpty) return fallback;
          return Image.network(
            url,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (_, __, ___) => fallback,
          );
        },
      ),
    );
  }
}
