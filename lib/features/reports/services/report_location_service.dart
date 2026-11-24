import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationFailure implements Exception {
  const LocationFailure(this.message);
  final String message;
}

class ReportPoint {
  const ReportPoint(this.latitude, this.longitude);
  final double latitude, longitude;
}

abstract interface class ReportLocationService {
  Future<ReportPoint> locate();
}

abstract interface class LocationGateway {
  Future<bool> enabled();
  Future<LocationPermission> permission();
  Future<LocationPermission> request();
  Future<ReportPoint> position();
}

class DeviceLocationGateway implements LocationGateway {
  @override
  Future<bool> enabled() => Geolocator.isLocationServiceEnabled();
  @override
  Future<LocationPermission> permission() => Geolocator.checkPermission();
  @override
  Future<LocationPermission> request() => Geolocator.requestPermission();
  @override
  Future<ReportPoint> position() async {
    // A recent cached fix answers instantly (emulators/indoors often have no
    // fresh fix within the time limit). Not supported on Web.
    if (!kIsWeb) {
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null &&
            DateTime.now().difference(last.timestamp) <
                const Duration(minutes: 30)) {
          return ReportPoint(last.latitude, last.longitude);
        }
      } catch (_) {}
    }
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return ReportPoint(p.latitude, p.longitude);
    } catch (_) {
      // Last resort: any older fix is still good enough for a city.
      if (!kIsWeb) {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) return ReportPoint(last.latitude, last.longitude);
      }
      rethrow;
    }
  }
}

class DeviceReportLocationService implements ReportLocationService {
  DeviceReportLocationService({LocationGateway? gateway})
    : gateway = gateway ?? DeviceLocationGateway();
  final LocationGateway gateway;
  @override
  Future<ReportPoint> locate() async {
    try {
      if (!await gateway.enabled()) {
        throw const LocationFailure(
          'GPS indisponible. Vous pouvez continuer sans localisation.',
        );
      }
      var p = await gateway.permission();
      if (p == LocationPermission.denied) p = await gateway.request();
      if (p != LocationPermission.always &&
          p != LocationPermission.whileInUse) {
        throw const LocationFailure(
          'Permission GPS refusée. Saisissez un lieu manuellement ou continuez sans position.',
        );
      }
      return await gateway.position();
    } on LocationFailure {
      rethrow;
    } catch (_) {
      throw const LocationFailure(
        'Position indisponible. Le formulaire reste utilisable sans GPS.',
      );
    }
  }
}
