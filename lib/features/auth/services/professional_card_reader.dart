import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/ml/on_device_vision.dart';
import '../../../core/utils/form_validators.dart';
import '../models/auth_requests.dart';

/// Veterinarian sign-up: photographs the professional card and reads its
/// number with Google ML Kit text recognition (offline, Android/iOS).
class ProfessionalCardReader {
  ProfessionalCardReader({ImagePicker? picker, OnDeviceVision? vision})
    : _picker = picker ?? ImagePicker(),
      _vision = vision ?? createOnDeviceVision();
  final ImagePicker _picker;
  final OnDeviceVision _vision;

  /// OCR only runs on Android and iOS.
  static bool get available =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Returns the card number, null if the user cancelled.
  Future<String?> scan(ImageSource source) async {
    final XFile? file;
    try {
      // Higher resolution than profile photos: small print must stay legible.
      file = await _picker.pickImage(
        source: source,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 90,
        requestFullMetadata: false,
      );
    } catch (_) {
      throw const AuthFailure(
        AuthFailureCode.forbidden,
        'Accès à la caméra ou aux photos refusé. Autorisez-le dans les paramètres.',
      );
    }
    if (file == null) return null;
    final text = await _vision.readText(file.path);
    if (text == null) {
      throw const AuthFailure(
        AuthFailureCode.forbidden,
        'Lecture automatique indisponible. Saisissez le numéro manuellement.',
        field: 'professionalCard',
      );
    }
    final number = extractProfessionalCardNumber(text);
    if (number == null) {
      throw const AuthFailure(
        AuthFailureCode.invalidInput,
        'Aucun numéro lisible sur la photo. Recadrez la carte, évitez les reflets, ou saisissez le numéro.',
        field: 'professionalCard',
      );
    }
    return number;
  }
}

final _labelled = RegExp(
  r'(?:n\s*[°ºo]\.?|num[ée]ro|matricule|inscription|ordre|carte|licen[cs]e)'
  r'[^A-Za-z0-9\n]{0,6}([A-Za-z0-9][A-Za-z0-9 /-]{2,24})',
  caseSensitive: false,
);
final _token = RegExp(r'[A-Za-z0-9/-]{3,20}');
final _date = RegExp(r'^\d{1,2}[/-]\d{1,2}[/-]\d{2,4}$');

String _clean(String raw) => raw
    .toUpperCase()
    .replaceAll(RegExp(r'\s+'), '')
    .replaceAll(RegExp(r'^[/-]+|[/-]+$'), '');

int _digits(String s) => RegExp(r'[0-9]').allMatches(s).length;

/// Picks the card number in OCR text: first a value right after a label
/// (« N° », « Numéro », « Matricule », « Inscription à l’Ordre »…), otherwise
/// the token with the most digits that is not a date.
String? extractProfessionalCardNumber(String text) {
  for (final match in _labelled.allMatches(text)) {
    // Stop at the first word without digits (e.g. « 1234 Dr Ali »).
    final words = match.group(1)!.trim().split(RegExp(r'\s+'));
    final kept = <String>[];
    for (final w in words) {
      if (_digits(w) == 0 && kept.isNotEmpty) break;
      if (_digits(w) > 0) kept.add(w);
    }
    final value = _clean(kept.join());
    if (value.isNotEmpty &&
        !_date.hasMatch(value) &&
        FormValidators.professionalCard(value) == null) {
      return value;
    }
  }
  String? best;
  for (final m in _token.allMatches(text)) {
    final value = _clean(m.group(0)!);
    if (_date.hasMatch(value) ||
        FormValidators.professionalCard(value) != null) {
      continue;
    }
    if (best == null || _digits(value) > _digits(best)) best = value;
  }
  return best;
}
