import 'dart:typed_data';

import '../../../core/enums/report_status.dart';
import '../models/signalement.dart';
import '../models/confirmation_signalement.dart';

abstract interface class ReportRepository {
  Future<List<Signalement>> getReports();
  Future<Signalement> getReport(int id);
  Future<Signalement> createReport(
    Signalement draft, {
    bool locationConsent = false,
  });
  Future<List<ConfirmationSignalement>> getConfirmations(int reportId);
  Future<void> confirmReport(int id, {String? comment});
  Future<void> moderateReport(int id, ReportStatus status);
  Future<String> savePhoto(Uint8List bytes);
  Future<Uint8List?> readPhoto(String reference);
}
