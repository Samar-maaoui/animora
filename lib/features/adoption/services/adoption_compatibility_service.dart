import '../models/animal.dart';
import '../models/questionnaire_adoptant.dart';
import '../repositories/animal_repository.dart';

class CompatibilityResult {
  const CompatibilityResult(this.score, this.explanations);
  final double score;
  final List<String> explanations;
}

class AdoptionCompatibilityService {
  AdoptionCompatibilityService({Map<String, double>? weights})
    : weights = Map.unmodifiable(weights ?? defaultWeights) {
    if (this.weights.keys
            .toSet()
            .difference(defaultWeights.keys.toSet())
            .isNotEmpty ||
        !this.weights.keys.toSet().containsAll(defaultWeights.keys) ||
        this.weights.values.any((v) => !v.isFinite || v < 0) ||
        (this.weights.values.fold(0.0, (a, b) => a + b) - 100).abs() > 0.001) {
      throw ArgumentError(
        'Les pondérations doivent être positives et totaliser 100.',
      );
    }
  }
  static const defaultWeights = {
    'housing': 20.0,
    'children': 15.0,
    'animals': 20.0,
    'experience': 20.0,
    'time': 25.0,
  };
  static const housingTypes = [
    'Appartement',
    'Maison avec jardin',
    'Autre logement adapté',
  ];
  static const experiences = [
    'Première adoption',
    'Déjà eu un animal',
    'Expérience régulière',
  ];
  static const availableTimes = [
    'Moins d’une heure',
    'Une à deux heures',
    'Plus de deux heures',
  ];
  final Map<String, double> weights;
  void validate(QuestionnaireAdoptant? q) {
    if (q == null ||
        !housingTypes.contains(q.housingType) ||
        !experiences.contains(q.experience) ||
        !availableTimes.contains(q.availableTime)) {
      throw const CatalogFailure(
        'Répondez à toutes les questions du questionnaire.',
      );
    }
  }

  CompatibilityResult calculate(Animal animal, QuestionnaireAdoptant q) {
    validate(q);
    final dog = animal.species.toLowerCase() == 'chien';
    final nature = animal.character.toLowerCase();
    final housing = q.housingType == housingTypes[1]
        ? 1.0
        : q.housingType == housingTypes[0]
        ? (dog && animal.weight > 15 ? 0.5 : 1.0)
        : 0.7;
    final children =
        !q.hasChildren ||
            nature.contains('calme') ||
            nature.contains('doux') ||
            nature.contains('douce')
        ? 1.0
        : 0.6;
    final others =
        !q.hasOtherAnimals ||
            nature.contains('sociable') ||
            nature.contains('social')
        ? 1.0
        : 0.6;
    final experience = [0.4, 0.75, 1.0][experiences.indexOf(q.experience)];
    final time = q.availableTime == availableTimes[2]
        ? 1.0
        : q.availableTime == availableTimes[1]
        ? (dog ? 0.65 : 1.0)
        : (dog ? 0.2 : 0.4);
    final points = {
      'housing': housing,
      'children': children,
      'animals': others,
      'experience': experience,
      'time': time,
    };
    final labels = {
      'housing': 'Logement',
      'children': 'Enfants',
      'animals': 'Autres animaux',
      'experience': 'Expérience',
      'time': 'Temps disponible',
    };
    final score = points.entries.fold(
      0.0,
      (sum, e) => sum + e.value * weights[e.key]!,
    );
    return CompatibilityResult((score * 10).round() / 10, [
      for (final e in points.entries)
        '${labels[e.key]} : ${(e.value * weights[e.key]!).toStringAsFixed(1)} / ${weights[e.key]!.toStringAsFixed(0)} points.',
      'Ces règles de démonstration ne constituent pas une évaluation scientifique ou vétérinaire. Seul un administrateur prend la décision.',
    ]);
  }
}
