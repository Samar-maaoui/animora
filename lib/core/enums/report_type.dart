// ignore_for_file: constant_identifier_names
enum ReportType { STRAY_ANIMAL, INJURED_ANIMAL, ABANDONED_ANIMAL, OTHER }

extension ReportTypeLabel on ReportType {
  String get label => switch (this) {
    ReportType.STRAY_ANIMAL => 'Animal errant',
    ReportType.INJURED_ANIMAL => 'Animal blessé',
    ReportType.ABANDONED_ANIMAL => 'Animal abandonné',
    ReportType.OTHER => 'Autre',
  };
}
