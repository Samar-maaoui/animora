import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image_picker/image_picker.dart';

import '../../../core/ml/on_device_vision.dart';
import '../../auth/models/auth_requests.dart';
import '../../auth/services/profile_photo_rules.dart';

/// Camera or gallery photo, resized and returned as a data URI.
/// Never stores XFile.path (temporary on Android, a blob URL on Web).
/// On Android/iOS, Google ML Kit (offline) checks that the photo shows
/// exactly one face before it is accepted.
class ProfilePhotoPicker {
  ProfilePhotoPicker({ImagePicker? picker, OnDeviceVision? vision})
    : _picker = picker ?? ImagePicker(),
      _vision = vision ?? createOnDeviceVision();
  final ImagePicker _picker;
  final OnDeviceVision _vision;

  Future<String?> pick(ImageSource source) async {
    final XFile? file;
    try {
      file = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
        preferredCameraDevice: CameraDevice.front,
        requestFullMetadata: false,
      );
    } catch (_) {
      throw const AuthFailure(
        AuthFailureCode.forbidden,
        'Accès à la caméra ou aux photos refusé. Autorisez-le dans les paramètres.',
      );
    }
    if (file == null) return null; // cancelled
    final bytes = await file.readAsBytes();
    await _checkDecodable(bytes);
    final type = _imageType(bytes);
    if (type == null) {
      throw const AuthFailure(
        AuthFailureCode.invalidInput,
        'Choisissez une image PNG, JPEG, GIF ou WebP.',
      );
    }
    await checkSingleFace(file.path);
    final uri = 'data:image/$type;base64,${base64Encode(bytes)}';
    final error = ProfilePhotoRules.check(uri);
    if (error != null) {
      throw AuthFailure(AuthFailureCode.invalidInput, error);
    }
    return uri;
  }

  /// Throws unless exactly one face is visible. Skipped (accepted) when
  /// ML Kit is unavailable on this platform.
  Future<void> checkSingleFace(String path) async {
    final faces = await _vision.countFaces(path);
    if (faces == null || faces == 1) return;
    throw AuthFailure(
      AuthFailureCode.invalidInput,
      faces == 0
          ? 'Aucun visage détecté. Choisissez une photo où votre visage est bien visible.'
          : 'Plusieurs visages détectés ($faces). La photo de profil doit montrer une seule personne.',
      diagnostic: 'MLKIT_FACES_$faces',
    );
  }

  Future<void> _checkDecodable(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      frame.image.dispose();
      codec.dispose();
    } catch (_) {
      throw const AuthFailure(
        AuthFailureCode.invalidInput,
        'Ce fichier n’est pas une image lisible.',
      );
    }
  }

  String? _imageType(Uint8List b) =>
      b.length >= 4 && b[0] == 0x89 && b[1] == 0x50
      ? 'png'
      : b.length >= 3 && b[0] == 0xff && b[1] == 0xd8
      ? 'jpeg'
      : b.length >= 6 && b[0] == 0x47 && b[1] == 0x49
      ? 'gif'
      : b.length >= 12 && b[0] == 0x52 && b[8] == 0x57
      ? 'webp'
      : null;
}
