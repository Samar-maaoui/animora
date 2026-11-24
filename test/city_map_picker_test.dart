import 'package:animora/core/network/api_client.dart';
import 'package:animora/core/network/api_scope.dart';
import 'package:animora/features/reports/services/report_location_service.dart';
import 'package:animora/features/users/widgets/city_map_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FixedLocation implements ReportLocationService {
  @override
  Future<ReportPoint> locate() async => const ReportPoint(35.83, 10.64);
}

/// Simulated Nominatim: north of 35.83 → Sousse, otherwise → Msaken.
Future<Object?> Function(double, double) _nominatim({bool offline = false}) =>
    (lat, lon) async {
      // Simulated network latency (shows the loading indicator).
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (offline) {
        throw const ApiFailure(ApiErrorKind.offline, 'hors ligne');
      }
      final north = lat >= 35.83;
      return {
        'address': {
          'suburb': north ? 'Sahloul' : 'Msaken Nord',
          'city': north ? 'Sousse' : 'Msaken',
          'state': 'Gouvernorat Sousse',
          'country': 'Tunisie',
        },
      };
    };

Future<TextEditingController> _mount(
  WidgetTester t,
  Future<Object?> Function(double, double) lookup, {
  bool autoLocate = false,
  String initialCity = '',
}) async {
  final city = TextEditingController(text: initialCity);
  addTearDown(city.dispose);
  await t.pumpWidget(
    ApiScope(
      client: ApiClient(
        cache: MemoryApiCache(),
        client: MockClient((_) async => http.Response('{}', 500)),
      ),
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CityMapPicker(
              controller: city,
              autoLocate: autoLocate,
              location: _FixedLocation(),
              reverseLookup: lookup,
            ),
          ),
        ),
      ),
    ),
  );
  return city;
}

/// Map tiles keep loading, so pump step by step (Nominatim limiter: 1.1 s).
Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 28; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _finish(WidgetTester t) async {
  await t.pump(const Duration(seconds: 5)); // notifications close
  await t.pumpWidget(const SizedBox.shrink());
}

void main() {
  testWidgets('Auto-locate drops the pin and fills an EMPTY city field', (
    t,
  ) async {
    final city = await _mount(t, _nominatim(), autoLocate: true);
    await _settle(t);
    expect(find.byKey(const ValueKey('city-map-pin')), findsOneWidget);
    expect(city.text, 'Sousse');
    expect(find.text('Gouvernorat Sousse'), findsOneWidget);
    await _finish(t);
  });

  testWidgets(
    'Tap moves the pin, shows the place, « Utiliser ce lieu » fills the city',
    (t) async {
      final city = await _mount(t, _nominatim(), initialCity: 'Tunis');
      final map = find.byType(FlutterMap);
      expect(find.byKey(const ValueKey('city-map-pin')), findsNothing);

      // 1. Tap → pin + loading → place details.
      await t.tapAt(t.getCenter(map));
      // flutter_map confirms a single tap after the double-tap delay.
      await t.pump(const Duration(milliseconds: 350));
      expect(find.byKey(const ValueKey('city-map-pin')), findsOneWidget);
      expect(find.byKey(const ValueKey('place-loading')), findsOneWidget);
      await _settle(t);
      final pin = find.byKey(const ValueKey('city-map-pin'));
      expect(pin, findsOneWidget);
      final first = t.getCenter(pin);
      expect(find.text('Gouvernorat Sousse'), findsOneWidget);
      expect(find.text('Tunisie'), findsOneWidget);
      // The field is not changed until the user confirms.
      expect(city.text, 'Tunis');

      // 2. Tap elsewhere → pin moved, new lookup.
      await t.tapAt(t.getCenter(map) + const Offset(-150, -60));
      await _settle(t);
      expect(t.getCenter(pin), isNot(equals(first)));
      expect(find.byKey(const ValueKey('place-details')), findsOneWidget);

      // 3. « Utiliser ce lieu » fills the field with the displayed city.
      final shown = find.descendant(
        of: find.byKey(const ValueKey('place-details')),
        matching: find.text('Msaken'),
      );
      final expected = shown.evaluate().isNotEmpty ? 'Msaken' : 'Sousse';
      await t.tap(find.byKey(const ValueKey('use-place')));
      await t.pump();
      expect(city.text, expected);

      // 4. Tap on the pin hides / shows the panel.
      await t.tap(pin);
      await t.pump();
      expect(find.byKey(const ValueKey('place-details')), findsNothing);
      await t.tap(pin);
      await t.pump();
      expect(find.byKey(const ValueKey('place-details')), findsOneWidget);
      await _finish(t);
    },
  );

  testWidgets('No network: clear message and retry button', (t) async {
    final city = await _mount(t, _nominatim(offline: true), initialCity: 'X');
    await t.tapAt(t.getCenter(find.byType(FlutterMap)));
    await _settle(t);
    expect(find.byKey(const ValueKey('place-error')), findsOneWidget);
    expect(find.textContaining('Pas de réseau'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
    expect(city.text, 'X');
    await _finish(t);
  });

  test(
    'Nominatim address is split into quartier / ville / gouvernorat / pays',
    () {
      final p = PlaceDetails.fromNominatim({
        'address': {
          'neighbourhood': 'Cité Erriadh',
          'town': 'Msaken',
          'state': 'Gouvernorat Sousse',
          'country': 'Tunisie',
        },
      });
      expect(p.district, 'Cité Erriadh');
      expect(p.cityName, 'Msaken');
      expect(p.region, 'Gouvernorat Sousse');
      expect(PlaceDetails.fromNominatim(null).isEmpty, isTrue);
    },
  );

  test('Tunisian addresses without city/town still give a city', () {
    // Real Nominatim answers (zoom 12) for Ariana, Gabès and rural Kairouan.
    final ariana = PlaceDetails.fromNominatim({
      'address': {
        'county': 'Ariana Ville',
        'state_district': 'Délégation Ariana Ville',
        'state': 'Gouvernorat Ariana',
        'country': 'Tunisie',
      },
    });
    expect(ariana.cityName, 'Ariana Ville');
    expect(ariana.region, 'Gouvernorat Ariana');
    final gabes = PlaceDetails.fromNominatim({
      'address': {
        'county': 'Secteur 3',
        'state_district': 'Délégation Gabès Ville',
        'state': 'Gouvernorat Gabès',
        'country': 'Tunisie',
      },
    });
    expect(gabes.cityName, 'Gabès Ville');
    expect(gabes.district, 'Secteur 3');
    final tunis = PlaceDetails.fromNominatim({
      'address': {
        'town': 'Bab Laassal',
        'city': 'Tunis',
        'state': 'Gouvernorat Tunis',
      },
    });
    expect(tunis.cityName, 'Tunis');
    expect(tunis.district, 'Bab Laassal');
    final onlyState = PlaceDetails.fromNominatim({
      'address': {'state': 'Gouvernorat Kairouan', 'country': 'Tunisie'},
    });
    expect(onlyState.cityName, 'Kairouan');
  });
}
