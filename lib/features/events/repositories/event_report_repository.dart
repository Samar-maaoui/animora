import '../models/event_report.dart';

import 'dart:typed_data';

abstract interface class EventReportRepository {
  Future<EventReport?> getReport(int eventId);
  Future<void> saveReport(
    int eventId,
    String description, {
    List<Uint8List> photos = const [],
    bool publish = false,
  });
  Future<Uint8List?> reportPhoto(int eventId, String reference);
}
