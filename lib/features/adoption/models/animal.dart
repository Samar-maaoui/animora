import '../../../core/enums/animal_status.dart';

/// Numeric identifier (safe JSON integer), age in years, weight in kilograms.
class Animal {
  const Animal({
    required this.id,
    required this.name,
    required this.species,
    required this.breed,
    required this.sex,
    required this.age,
    required this.weight,
    required this.color,
    required this.sterilized,
    required this.health,
    required this.character,
    this.microchipNumber = '',
    this.animalPhoto = '',
    required this.status,
    required this.arrivalDate,
    required this.city,
  });
  final int id, age;
  final String name, species, breed, sex, color, health, character, city;
  final String microchipNumber, animalPhoto;
  final double weight;
  final bool sterilized;
  final AnimalStatus status;
  final DateTime arrivalDate;

  Animal copyWith({
    int? id,
    String? name,
    String? species,
    String? breed,
    String? sex,
    int? age,
    double? weight,
    String? color,
    bool? sterilized,
    String? health,
    String? character,
    String? microchipNumber,
    String? animalPhoto,
    AnimalStatus? status,
    DateTime? arrivalDate,
    String? city,
  }) => Animal(
    id: id ?? this.id,
    name: name ?? this.name,
    species: species ?? this.species,
    breed: breed ?? this.breed,
    sex: sex ?? this.sex,
    age: age ?? this.age,
    weight: weight ?? this.weight,
    color: color ?? this.color,
    sterilized: sterilized ?? this.sterilized,
    health: health ?? this.health,
    character: character ?? this.character,
    microchipNumber: microchipNumber ?? this.microchipNumber,
    animalPhoto: animalPhoto ?? this.animalPhoto,
    status: status ?? this.status,
    arrivalDate: arrivalDate ?? this.arrivalDate,
    city: city ?? this.city,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'species': species,
    'breed': breed,
    'sex': sex,
    'age': age,
    'weight': weight,
    'color': color,
    'sterilized': sterilized,
    'health': health,
    'character': character,
    'microchipNumber': microchipNumber,
    'animalPhoto': animalPhoto,
    'status': status.name,
    'arrivalDate': arrivalDate.toIso8601String(),
    'city': city,
  };
  factory Animal.fromJson(Map<String, dynamic> json) => Animal(
    id: json['id'] as int,
    name: json['name'] as String,
    species: json['species'] as String,
    breed: json['breed'] as String,
    sex: json['sex'] as String,
    age: json['age'] as int,
    weight: (json['weight'] as num).toDouble(),
    color: json['color'] as String,
    sterilized: json['sterilized'] as bool,
    health: json['health'] as String,
    character: json['character'] as String,
    microchipNumber: json['microchipNumber'] as String? ?? '',
    animalPhoto: json['animalPhoto'] as String? ?? '',
    status: AnimalStatus.values.byName(json['status'] as String),
    arrivalDate: DateTime.parse(json['arrivalDate'] as String),
    city: json['city'] as String,
  );
}
