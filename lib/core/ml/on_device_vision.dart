import 'on_device_vision_stub.dart'
    if (dart.library.io) 'on_device_vision_mlkit.dart'
    as platform;

/// On-device AI (Google ML Kit): runs offline, free, Android and iOS only.
/// Every method returns null when ML Kit is not available (Web, desktop,
/// tests) so callers can fall back to a manual flow.
abstract interface class OnDeviceVision {
  /// Number of faces found in the image file, or null if unavailable.
  Future<int?> countFaces(String imagePath);

  /// Raw text recognised in the image file, or null if unavailable.
  Future<String?> readText(String imagePath);
}

OnDeviceVision createOnDeviceVision() => platform.createOnDeviceVision();
