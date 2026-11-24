import 'dart:async';

import 'package:animora/features/users/widgets/city_map_picker.dart';
import 'package:flutter_map/flutter_map.dart';

/// Loaded automatically by `flutter test` before every test file.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // No path_provider in tests: the map tiles must not use the disk cache.
  CityMapPicker.tileProviderOverride = NetworkTileProvider(
    cachingProvider: const DisabledMapCachingProvider(),
  );
  await testMain();
}
