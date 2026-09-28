import 'package:flutter/material.dart';
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
  String? _publicUrl() {
    final raw = widget.photoUrl?.trim() ?? '';
    if (raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;

    final encodedPath = raw
        .split('/')
        .where((part) => part.isNotEmpty)
        .map(Uri.encodeComponent)
        .join('/');
    if (encodedPath.isEmpty) return null;

    return 'https://qychfoxygqzmtsqtxihp.supabase.co/storage/v1/object/public/employee-photos/$encodedPath';
  }

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Text(
        widget.name.trim().isEmpty ? '?' : widget.name.trim()[0].toUpperCase(),
        style: TextStyle(
          color: widget.foregroundColor,
          fontWeight: FontWeight.w800,
          fontSize: widget.radius * .72,
        ),
      ),
    );

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
          BoxShadow(color: Colors.black12, blurRadius: 7, offset: Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Builder(
        builder: (context) {
          final url = _publicUrl()?.trim() ?? '';
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
