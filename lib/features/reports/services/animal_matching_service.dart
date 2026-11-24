import 'dart:math';

import '../../../core/enums/announcement_type.dart';
import '../../../core/enums/announcement_status.dart';
import '../models/annonce.dart';

class AnimalMatchingService {
  AnimalMatchingService({Map<String, double>? weights})
    : weights = Map.unmodifiable(weights ?? defaults) {
    if (this.weights.keys
            .toSet()
            .difference(defaults.keys.toSet())
            .isNotEmpty ||
        !this.weights.keys.toSet().containsAll(defaults.keys) ||
        this.weights.values.any((w) => !w.isFinite || w < 0) ||
        (this.weights.values.fold(0.0, (a, b) => a + b) - 100).abs() > 0.001) {
      throw ArgumentError('Pondérations invalides.');
    }
  }
  static const defaults = {
    'species': 30.0,
    'breed': 15.0,
    'color': 20.0,
    'location': 20.0,
    'signs': 15.0,
  };
  final Map<String, double> weights;
  String _normalize(String? s) => (s ?? '')
      .toLowerCase()
      .trim()
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e');
  double _words(String? a, String? b) {
    final x = _normalize(a)
        .split(RegExp(r'\W+'))
        .where((s) => s.isNotEmpty)
        .toSet();
    final y = _normalize(b)
        .split(RegExp(r'\W+'))
        .where((s) => s.isNotEmpty)
        .toSet();
    if (x.isEmpty || y.isEmpty) return 0;
    return x.intersection(y).length / x.union(y).length;
  }

  double distanceKm(double a, double b, double c, double d) {
    double rad(double v) => v * pi / 180;
    final x =
        pow(sin(rad(c - a) / 2), 2) +
        cos(rad(a)) * cos(rad(c)) * pow(sin(rad(d - b) / 2), 2);
    return 6371 * 2 * atan2(sqrt(x.clamp(0, 1)), sqrt((1 - x).clamp(0, 1)));
  }

  double? score(Annonce lost, Annonce found) {
    if (lost.type != AnnouncementType.LOST ||
        found.type != AnnouncementType.FOUND ||
        lost.status != AnnouncementStatus.ACTIVE ||
        found.status != AnnouncementStatus.ACTIVE ||
        lost.hidden ||
        found.hidden) {
      return null;
    }
    final location =
        lost.latitude == null ||
            found.latitude == null ||
            lost.longitude == null ||
            found.longitude == null
        ? 0.0
        : (1 -
                  distanceKm(
                        lost.latitude!,
                        lost.longitude!,
                        found.latitude!,
                        found.longitude!,
                      ) /
                      20)
              .clamp(0.0, 1.0);
    final parts = {
      'species': _normalize(lost.species) == _normalize(found.species)
          ? 1.0
          : 0.0,
      'breed': _words(lost.breed, found.breed),
      'color': _words(lost.color, found.color),
      'location': location,
      'signs': _words(lost.distinguishingSigns, found.distinguishingSigns),
    };
    return (parts.entries.fold(0.0, (s, e) => s + e.value * weights[e.key]!) *
                10)
            .round() /
        10;
  }
}
