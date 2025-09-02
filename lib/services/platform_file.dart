import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// Cross-platform file wrapper for web and mobile
class PlatformFile {
  final String name;
  final Uint8List bytes;
  final String? path;
  final int size;

  PlatformFile({
    required this.name,
    required this.bytes,
    this.path,
    required this.size,
  });

  /// Create from XFile (image_picker)
  static Future<PlatformFile> fromXFile(dynamic xFile) async {
    final bytes = await xFile.readAsBytes();
    return PlatformFile(
      name: xFile.name ?? 'image.jpg',
      bytes: bytes,
      path: xFile.path,
      size: bytes.length,
    );
  }

  /// Read bytes (compatible with both web and mobile)
  Future<Uint8List> readAsBytes() async {
    return bytes;
  }
}