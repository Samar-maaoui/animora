// ignore_for_file: constant_identifier_names
enum ReportStatus { NEW, CONFIRMED, IN_PROGRESS, RESOLVED, REJECTED }

extension ReportStatusLabel on ReportStatus {
  String get label => switch (this) {
    ReportStatus.NEW => 'Nouveau',
    ReportStatus.CONFIRMED => 'Confirmé',
    ReportStatus.IN_PROGRESS => 'En cours',
    ReportStatus.RESOLVED => 'Résolu',
    ReportStatus.REJECTED => 'Rejeté',
  };
}
