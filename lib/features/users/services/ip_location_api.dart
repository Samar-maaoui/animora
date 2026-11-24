import '../../../core/network/api_client.dart';
import '../../reports/services/report_location_service.dart';

/// Approximate position from the Internet connection (GeoJS: free, no key,
/// CORS enabled). Used only when the device GPS is unavailable.
class IpLocationApi {
  IpLocationApi(this.client);
  final ApiClient client;
  static final endpoint = Uri.https('get.geojs.io', '/v1/ip/geo.json');

  /// Returns the point and the provider's city name (may be empty).
  Future<(ReportPoint, String)> locate() async {
    final response = await client.get(
      endpoint,
      ttl: const Duration(hours: 1),
      stale: Duration.zero,
    );
    final json = response.json;
    if (json is! Map) {
      throw const ApiFailure(ApiErrorKind.invalid, 'Position IP invalide.');
    }
    final lat = double.tryParse('${json['latitude']}');
    final lon = double.tryParse('${json['longitude']}');
    if (lat == null || lon == null) {
      throw const ApiFailure(ApiErrorKind.invalid, 'Position IP absente.');
    }
    validCoordinates(lat, lon);
    return (ReportPoint(lat, lon), (json['city'] as String?)?.trim() ?? '');
  }
}
