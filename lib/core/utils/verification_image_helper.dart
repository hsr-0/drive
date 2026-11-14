import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Ensures a gallery photo uses an extension accepted by taxi's
/// vehicle-verification API (jpg, jpeg, png). Other image formats,
/// including HEIC/HEIF on iPhone, are converted to JPEG.
class VerificationImageHelper {
  static Future<File> prepare(XFile picked) async {
    final source = File(picked.path);
    if (!await source.exists()) {
      throw const FormatException('Selected image not found');
    }

    final path = picked.path.toLowerCase();
    if (path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png')) {
      return source;
    }

    final temp = await getTemporaryDirectory();
    final target = '${temp.path}/beytei_verify_${DateTime.now().microsecondsSinceEpoch}.jpg';
    final converted = await FlutterImageCompress.compressAndGetFile(
      source.path,
      target,
      format: CompressFormat.jpeg,
      quality: 88,
      keepExif: false,
    );

    if (converted == null) {
      throw const FormatException('Unable to convert image to JPEG');
    }
    final file = File(converted.path);
    if (!await file.exists() || await file.length() == 0) {
      throw const FormatException('Converted image is missing or empty');
    }
    return file;
  }
}
