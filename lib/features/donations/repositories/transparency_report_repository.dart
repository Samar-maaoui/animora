import '../models/transparency_report.dart';

abstract interface class TransparencyReportRepository {
  Future<List<TransparencyReport>> getTransparencyReports(int campaignId);
  Future<void> publishTransparencyReport(
    int campaignId,
    String description,
    String content,
  );
}
