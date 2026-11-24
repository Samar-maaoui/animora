import 'on_device_vision.dart';

/// Web: ML Kit has no browser implementation.
OnDeviceVision createOnDeviceVision() => const _UnavailableVision();

class _UnavailableVision implements OnDeviceVision {
  const _UnavailableVision();
  @override
  Future<int?> countFaces(String imagePath) async => null;
  @override
  Future<String?> readText(String imagePath) async => null;
}
