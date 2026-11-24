import 'dart:convert';
import 'dart:ui' as ui;

import 'package:image_picker/image_picker.dart';

import '../repositories/animal_repository.dart';

/// Embeds validated image bytes; never persists XFile.path or a browser blob URL.
class AnimalImagePicker {
  final ImagePicker _picker = ImagePicker();
  Future<String?> pick() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    if (await file.length() > 1000000) {
      throw const CatalogFailure('Choisissez une image de 1 Mo maximum.');
    }
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      try {
        if (frame.image.width > 4096 || frame.image.height > 4096) {
          throw const CatalogFailure(
            'L’image doit mesurer au maximum 4096 × 4096 pixels.',
          );
        }
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
    final type = bytes.length >= 4 && bytes[0] == 0x89 && bytes[1] == 0x50
        ? 'png'
        : bytes.length >= 3 && bytes[0] == 0xff && bytes[1] == 0xd8
        ? 'jpeg'
        : bytes.length >= 6 && bytes[0] == 0x47 && bytes[1] == 0x49
        ? 'gif'
        : bytes.length >= 12 && bytes[0] == 0x52 && bytes[8] == 0x57
        ? 'webp'
        : null;
    if (type == null) {
      throw const CatalogFailure(
        'Choisissez une image PNG, JPEG, GIF ou WebP.',
      );
    }
    return 'data:image/$type;base64,${base64Encode(bytes)}';
  }
}
