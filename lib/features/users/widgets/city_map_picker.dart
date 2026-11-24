import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_scope.dart';
import '../../../core/widgets/app_notification.dart';
import '../../reports/services/geocoding_api.dart';
import '../../reports/services/report_location_service.dart';
import '../services/ip_location_api.dart';
import 'locate_city_button.dart' show webGeolocationBlocked;

/// Place found by reverse geocoding (Nominatim), French labels.
class PlaceDetails {
  const PlaceDetails({this.district, this.city, this.region, this.country});
  final String? district, city, region, country;

  bool get isEmpty =>
      [district, city, region, country].every((v) => v == null || v.isEmpty);

  /// Value for the « Ville » field.
  String? get cityName => city ?? district;

  /// Reads Nominatim's `address` object.
  factory PlaceDetails.fromNominatim(Object? json) {
    final address = json is Map ? json['address'] : null;
    if (address is! Map) return const PlaceDetails();
    String? pick(List<String> keys) {
      for (final k in keys) {
        final v = address[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      return null;
    }

    String? strip(String? value, String prefix) {
      if (value == null) return null;
      final v = value.startsWith(prefix)
          ? value.substring(prefix.length)
          : value;
      return v.trim().isEmpty ? null : v.trim();
    }

    final county = pick(['county']);
    // In Tunisia Nominatim often has no city/town (Ariana, Ben Arous, Gabès):
    // fall back to the délégation, then the secteur, then the gouvernorat.
    final city =
        pick(['city', 'town', 'village', 'municipality']) ??
        strip(pick(['state_district']), 'Délégation ') ??
        county ??
        strip(pick(['state']), 'Gouvernorat ');
    var district =
        pick([
          'suburb',
          'neighbourhood',
          'quarter',
          'city_district',
          'hamlet',
        ]) ??
        (address['city'] != null ? pick(['town']) : null) ??
        county;
    if (district == city) district = null;
    return PlaceDetails(
      district: district,
      city: city,
      region: pick(['state', 'state_district', 'county']),
      country: pick(['country']),
    );
  }
}

/// OpenStreetMap card for the « Ville » field.
/// - a tap on the map moves the pin there;
/// - a tap on the pin (and every move) shows the place in a panel
///   (quartier, ville, gouvernorat, pays) via the shared Nominatim service
///   (GeocodingApi: 1 request/second, cached);
/// - « Utiliser ce lieu » fills the city field.
class CityMapPicker extends StatefulWidget {
  const CityMapPicker({
    super.key,
    required this.controller,
    this.enabled = true,
    this.autoLocate = true,
    this.location,
    this.ipLocation,
    this.reverseLookup,
    this.onCity,
  });
  final TextEditingController controller;
  final bool enabled;

  /// Locate as soon as the map is shown (sign-up). The city is filled
  /// automatically only if the field is still empty.
  final bool autoLocate;

  /// Injectable for tests.
  final ReportLocationService? location;
  final IpLocationApi? ipLocation;

  /// Raw Nominatim answer for a point. Defaults to the shared GeocodingApi
  /// (1 request/second + cache); injectable for tests.
  final Future<Object?> Function(double latitude, double longitude)?
  reverseLookup;
  final ValueChanged<String>? onCity;

  /// Tests replace the tile provider (no disk cache / path_provider there).
  @visibleForTesting
  static TileProvider? tileProviderOverride;

  @override
  State<CityMapPicker> createState() => _CityMapPickerState();
}

class _CityMapPickerState extends State<CityMapPicker> {
  static const _tunisia = LatLng(34.2, 9.6);
  final _map = MapController();
  LatLng? _pin;
  PlaceDetails? _place;
  String? _error;
  bool _locating = false, _searching = false, _panel = false;
  bool _approximate = false, _mapReady = false;

  /// Only the answer for the latest pin position is displayed.
  int _request = 0;

  @override
  void initState() {
    super.initState();
    if (widget.autoLocate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _locate(auto: true);
      });
    }
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  void _moveTo(LatLng point, double zoom) {
    if (_mapReady) _map.move(point, zoom);
  }

  /// GPS (unless the browser blocks it), else connection-based position.
  Future<void> _locate({bool auto = false}) async {
    final client = apiClient(context);
    if (client == null || _locating) return;
    setState(() => _locating = true);
    LatLng? point;
    var approximate = false;
    if (!webGeolocationBlocked) {
      try {
        final p = await (widget.location ?? DeviceReportLocationService())
            .locate();
        point = LatLng(p.latitude, p.longitude);
      } catch (_) {}
    }
    if (point == null) {
      try {
        final (p, _) = await (widget.ipLocation ?? IpLocationApi(client))
            .locate();
        point = LatLng(p.latitude, p.longitude);
        approximate = true;
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() => _locating = false);
    if (point == null) {
      if (!auto) {
        AppNotification.warning(
          context,
          'Position introuvable. Touchez la carte à l’endroit voulu.',
          title: 'Localisation',
        );
      }
      return;
    }
    _approximate = approximate;
    await _setPin(point, zoom: 13, autoFill: auto);
  }

  /// Moves the pin, opens the panel and looks the place up.
  Future<void> _setPin(
    LatLng point, {
    double? zoom,
    bool autoFill = false,
  }) async {
    final client = apiClient(context);
    if (client == null) return;
    final id = ++_request;
    setState(() {
      _pin = point;
      _panel = true;
      _place = null;
      _error = null;
      _searching = true;
    });
    // Only « Me localiser » recentres the map; a tap leaves it where it is.
    if (zoom != null) _moveTo(point, zoom);
    try {
      // The user placed the pin: explicit consent for this lookup.
      final json = widget.reverseLookup != null
          ? await widget.reverseLookup!(point.latitude, point.longitude)
          : (await GeocodingApi.forClient(client).reverse(
              point.latitude,
              point.longitude,
              consent: true,
            )).response.json;
      final place = PlaceDetails.fromNominatim(json);
      if (!mounted || id != _request) return;
      setState(() {
        _searching = false;
        _place = place;
        _error = place.isEmpty
            ? 'Aucun lieu nommé ici (mer, zone vide). Déplacez l’épingle.'
            : null;
      });
      if (autoFill && widget.controller.text.trim().isEmpty) _useCity();
    } on ApiFailure catch (failure) {
      if (!mounted || id != _request) return;
      setState(() {
        _searching = false;
        _error = switch (failure.kind) {
          ApiErrorKind.offline => 'Pas de réseau : impossible de trouver le lieu. Vérifiez votre connexion.',
          ApiErrorKind.timeout =>
            'Le service de cartes ne répond pas. Réessayez dans un instant.',
          _ when failure.status == 429 =>
            'Trop de recherches : patientez une seconde puis réessayez.',
          _ => 'Lieu introuvable pour cette position.',
        };
      });
    } catch (_) {
      if (!mounted || id != _request) return;
      setState(() {
        _searching = false;
        _error = 'Lieu introuvable pour cette position.';
      });
    }
  }

  void _useCity() {
    final city = _place?.cityName;
    if (city == null) return;
    widget.controller.value = TextEditingValue(
      text: city,
      selection: TextSelection.collapsed(offset: city.length),
    );
    widget.onCity?.call(city);
    AppNotification.success(
      context,
      _approximate
          ? 'Ville ajoutée : $city (position approximative).'
          : 'Ville ajoutée : $city',
      title: 'Localisation',
    );
  }

  void _onMapTap(LatLng point) {
    if (!widget.enabled) return;
    _approximate = false;
    _setPin(point);
  }

  void _onPinTap() {
    if (_pin == null) return;
    if (_panel) {
      setState(() => _panel = false);
    } else if (_place == null && !_searching) {
      _setPin(_pin!);
    } else {
      setState(() => _panel = true);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 300,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          children: [
            Semantics(
              label: 'Carte OpenStreetMap. Touchez la carte pour déplacer l’épingle.',
              child: FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: _tunisia,
                  initialZoom: 5.6,
                  minZoom: 3,
                  maxZoom: 17,
                  onMapReady: () {
                    _mapReady = true;
                    if (_pin != null) _map.move(_pin!, 13);
                  },
                  onTap: (_, point) => _onMapTap(point),
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.animora',
                    tileProvider: CityMapPicker.tileProviderOverride,
                  ),
                  if (_pin != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _pin!,
                          width: 56,
                          height: 56,
                          alignment: Alignment.topCenter,
                          child: Semantics(
                            button: true,
                            label: 'Épingle : afficher le lieu',
                            child: GestureDetector(
                              key: const ValueKey('city-map-pin'),
                              behavior: HitTestBehavior.opaque,
                              onTap: _onPinTap,
                              child: _Pin(key: ValueKey(_pin)),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Positioned(
              right: 10,
              top: 10,
              child: Material(
                color: AppColors.primary,
                shape: const CircleBorder(),
                elevation: 3,
                shadowColor: const Color(0x407A4A1A),
                child: _locating
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : IconButton(
                        key: const ValueKey('city-map-locate'),
                        tooltip: 'Me localiser sur la carte',
                        color: Colors.white,
                        icon: const Icon(Icons.my_location),
                        onPressed: widget.enabled ? () => _locate() : null,
                      ),
              ),
            ),
            if (_pin == null && !_locating)
              const Positioned(
                left: 10,
                top: 14,
                child: _Hint('Touchez la carte pour placer l’épingle'),
              ),
            if (_panel)
              Positioned(
                left: 8,
                right: 8,
                bottom: 18,
                child: _PlacePanel(
                  searching: _searching,
                  place: _place,
                  error: _error,
                  approximate: _approximate,
                  onUse: widget.enabled && (_place?.cityName != null)
                      ? _useCity
                      : null,
                  onRetry: _pin == null ? null : () => _setPin(_pin!),
                  onClose: () => setState(() => _panel = false),
                ),
              ),
            const Positioned(
              right: 6,
              bottom: 2,
              child: Text(
                '© OpenStreetMap',
                style: TextStyle(fontSize: 9, color: Colors.black54),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    elevation: 2,
    shadowColor: const Color(0x407A4A1A),
    borderRadius: BorderRadius.circular(20),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
  );
}

/// Bottom panel: loading, error, or the place with « Utiliser ce lieu ».
class _PlacePanel extends StatelessWidget {
  const _PlacePanel({
    required this.searching,
    required this.place,
    required this.error,
    required this.approximate,
    required this.onUse,
    required this.onRetry,
    required this.onClose,
  });
  final bool searching, approximate;
  final PlaceDetails? place;
  final String? error;
  final VoidCallback? onUse, onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (searching) {
      body = const Row(
        key: ValueKey('place-loading'),
        children: [
          SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Text('Recherche du lieu…'),
        ],
      );
    } else if (error != null) {
      body = Row(
        key: const ValueKey('place-error'),
        children: [
          const Icon(Icons.wifi_off_rounded, color: Color(0xFFE5484D)),
          const SizedBox(width: 10),
          Expanded(child: Text(error!, style: const TextStyle(fontSize: 13))),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      );
    } else {
      final p = place!;
      Widget line(IconData icon, String label, String? value) => value == null
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  Icon(icon, size: 15, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    '$label : ',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      value,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
      body = Column(
        key: const ValueKey('place-details'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          line(Icons.holiday_village_outlined, 'Quartier', p.district),
          line(Icons.location_city, 'Ville', p.city),
          line(Icons.map_outlined, 'Gouvernorat', p.region),
          line(Icons.public, 'Pays', p.country),
          if (approximate)
            const Text(
              'Position approximative (connexion) : ajustez l’épingle si besoin.',
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          const SizedBox(height: 6),
          FilledButton.icon(
            key: const ValueKey('use-place'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            onPressed: onUse,
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Utiliser ce lieu'),
          ),
        ],
      );
    }
    return Material(
      color: AppColors.surface,
      elevation: 6,
      shadowColor: const Color(0x407A4A1A),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Semantics(liveRegion: true, child: body),
              ),
            ),
            IconButton(
              tooltip: 'Fermer le panneau',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}

/// Orange pin that drops in with a small bounce each time it moves.
class _Pin extends StatelessWidget {
  const _Pin({super.key});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: -24, end: 0),
    duration: const Duration(milliseconds: 450),
    curve: Curves.bounceOut,
    builder: (context, dy, child) =>
        Transform.translate(offset: Offset(0, dy), child: child),
    child: const Icon(
      Icons.location_on,
      size: 52,
      color: AppColors.primary,
      shadows: [
        Shadow(color: Color(0x55000000), blurRadius: 8, offset: Offset(0, 3)),
      ],
    ),
  );
}
