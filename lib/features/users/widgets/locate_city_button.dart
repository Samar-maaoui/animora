import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_scope.dart';
import '../../../core/widgets/app_notification.dart';
import '../../reports/services/geocoding_api.dart';
import '../../reports/services/report_location_service.dart';
import '../services/ip_location_api.dart';

/// Browsers only allow GPS on HTTPS or localhost.
bool get webGeolocationBlocked {
  if (!kIsWeb) return false;
  final base = Uri.base;
  return base.scheme != 'https' &&
      !const {'localhost', '127.0.0.1', '[::1]'}.contains(base.host);
}

/// Suffix icon for a "Ville" field:
/// 1. device GPS + OpenStreetMap Nominatim reverse geocoding (French names);
/// 2. if GPS is unavailable/refused/too slow (emulator, HTTP web page…),
///    an approximate city from the Internet connection (GeoJS, no key).
class LocateCityButton extends StatefulWidget {
  const LocateCityButton({
    super.key,
    required this.controller,
    this.enabled = true,
    this.location,
    this.ipLocation,
  });
  final TextEditingController controller;
  final bool enabled;

  /// Injectable for tests.
  final ReportLocationService? location;
  final IpLocationApi? ipLocation;
  @override
  State<LocateCityButton> createState() => _LocateCityButtonState();
}

class _LocateCityButtonState extends State<LocateCityButton> {
  bool _loading = false;

  Future<String> _cityAt(ApiClient client, ReportPoint point) async {
    // Pressing the button is the user's explicit consent to the request.
    final result = await GeocodingApi.forClient(client)
        .reverse(point.latitude, point.longitude, consent: true);
    return result.value.city.trim();
  }

  Future<void> _locate() async {
    final client = apiClient(context);
    if (client == null) {
      AppNotification.warning(
        context,
        'Service de localisation non configuré. Saisissez la ville.',
      );
      return;
    }
    setState(() => _loading = true);
    String? gpsProblem;
    try {
      // 1. GPS
      if (webGeolocationBlocked) {
        gpsProblem = 'le navigateur bloque le GPS hors HTTPS';
      } else {
        try {
          final point = await (widget.location ?? DeviceReportLocationService())
              .locate();
          final city = await _cityAt(client, point);
          if (city.isNotEmpty) {
            _fill(city);
            return;
          }
          gpsProblem = 'ville introuvable pour cette position';
        } on LocationFailure catch (failure) {
          gpsProblem = failure.message;
        } on ApiFailure catch (failure) {
          gpsProblem = failure.message;
        }
      }
      // 2. Approximate position from the connection.
      final (point, ipCity) = await (widget.ipLocation ?? IpLocationApi(client))
          .locate();
      var city = '';
      try {
        city = await _cityAt(client, point);
      } catch (_) {}
      if (city.isEmpty) city = ipCity;
      if (city.isEmpty) throw const ApiFailure(ApiErrorKind.invalid, '');
      _fill(city, approximate: true, reason: gpsProblem);
    } catch (_) {
      if (mounted) {
        AppNotification.error(
          context,
          gpsProblem == null
              ? 'Localisation impossible. Saisissez la ville manuellement.'
              : 'Localisation impossible ($gpsProblem). Saisissez la ville manuellement.',
          title: 'Ville non détectée',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _fill(String city, {bool approximate = false, String? reason}) {
    widget.controller.value = TextEditingValue(
      text: city,
      selection: TextSelection.collapsed(offset: city.length),
    );
    if (!mounted) return;
    if (approximate) {
      AppNotification.warning(
        context,
        'Ville approximative d’après votre connexion : $city. Corrigez-la si besoin.',
        title: 'GPS indisponible',
      );
    } else {
      AppNotification.success(
        context,
        'Ville détectée : $city',
        title: 'Localisation réussie',
      );
    }
  }

  @override
  Widget build(BuildContext context) => _loading
      ? const Padding(
          padding: EdgeInsets.all(12),
          child: SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        )
      : IconButton(
          tooltip: 'Détecter ma ville',
          icon: const Icon(Icons.my_location),
          onPressed: widget.enabled ? _locate : null,
        );
}
