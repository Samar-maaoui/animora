import 'dart:async';
import 'dart:typed_data';

import 'package:animora/features/reports/repositories/reports_storage.dart';
import 'package:animora/features/reports/services/report_location_service.dart';

class MemoryReportsStorage implements ReportsStorage {
  String? value;
  Completer<void>? photoGate;
  bool fail = false;
  final photos = <String, Uint8List>{};
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String v) async {
    if (fail) throw StateError('disk');
    value = v;
  }

  @override
  Future<String> savePhoto(Uint8List b) async {
    final key = 'media:${photos.length}';
    photos[key] = Uint8List.fromList(b);
    return key;
  }

  @override
  Future<Uint8List?> readPhoto(String key) async {
    await photoGate?.future;
    return photos[key];
  }

  @override
  Future<void> close() async {}
}

class DeniedReportLocation implements ReportLocationService {
  @override
  Future<ReportPoint> locate() async => throw const LocationFailure(
    'Permission GPS refusée. Vous pouvez continuer sans position.',
  );
}
