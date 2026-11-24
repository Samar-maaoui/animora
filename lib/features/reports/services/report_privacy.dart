import 'report_location_service.dart';

class ReportsFailure implements Exception {
  const ReportsFailure(this.message);
  final String message;
}

String reportsError(Object e) => e is ReportsFailure
    ? e.message
    : e is LocationFailure
    ? e.message
    : 'Une erreur est survenue. Veuillez réessayer.';

abstract final class ReportPrivacy {
  static ReportPoint? publish(
    double? lat,
    double? lon, {
    required bool consent,
  }) {
    if (lat == null && lon == null) return null;
    if (lat == null ||
        lon == null ||
        !lat.isFinite ||
        !lon.isFinite ||
        lat.abs() > 90 ||
        lon.abs() > 180) {
      throw const ReportsFailure(
        'Coordonnées invalides : latitude de −90 à 90 et longitude de −180 à 180.',
      );
    }
    if (!consent) {
      throw const ReportsFailure(
        'Confirmez la publication de la position approximative ou retirez les coordonnées.',
      );
    }
    return ReportPoint((lat * 100).round() / 100, (lon * 100).round() / 100);
  }
}
