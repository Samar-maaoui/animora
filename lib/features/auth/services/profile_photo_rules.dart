/// Shared validation for profile photos stored as data URIs.
abstract final class ProfilePhotoRules {
  /// Max encoded length (~375 KB of image bytes once base64-decoded).
  static const maxLength = 500000;
  static final _pattern = RegExp(
    r'^data:image/(png|jpeg|gif|webp);base64,[A-Za-z0-9+/]+=*$',
  );

  /// Returns an error message, or null when [photo] is acceptable.
  /// A null photo means "remove the photo" and is always valid.
  static String? check(String? photo) {
    if (photo == null) return null;
    if (photo.length > maxLength) {
      return 'La photo est trop lourde. Choisissez une image plus petite.';
    }
    if (!_pattern.hasMatch(photo)) {
      return 'Format de photo non reconnu (PNG, JPEG, GIF ou WebP).';
    }
    return null;
  }
}
