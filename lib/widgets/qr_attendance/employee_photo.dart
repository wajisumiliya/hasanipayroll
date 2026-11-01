import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../services/neon_api.dart';

class QrEmployeePhoto extends StatefulWidget {
  const QrEmployeePhoto({super.key, required this.employeeId, this.size = 48});
  final String employeeId;
  final double size;
  @override
  State<QrEmployeePhoto> createState() => _QrEmployeePhotoState();
}

class _QrEmployeePhotoState extends State<QrEmployeePhoto> {
  late Future<Uint8List?> photo = NeonApi.photoRequest(widget.employeeId);
  @override
  void didUpdateWidget(covariant QrEmployeePhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.employeeId != widget.employeeId) {
      photo = NeonApi.photoRequest(widget.employeeId);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
      future: photo,
      builder: (_, snapshot) => CircleAvatar(
          radius: widget.size / 2,
          backgroundImage:
              snapshot.hasData ? MemoryImage(snapshot.data!) : null,
          child: snapshot.hasData
              ? null
              : Icon(Icons.person_outline, size: widget.size * .6)));
}
