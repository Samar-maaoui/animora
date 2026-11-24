// ignore_for_file: constant_identifier_names
enum MaterialType { FOOD, MEDICINE, EQUIPMENT, OTHER }

extension MaterialTypeLabel on MaterialType {
  String get label => switch (this) {
    MaterialType.FOOD => 'Nourriture',
    MaterialType.MEDICINE => 'Médicaments',
    MaterialType.EQUIPMENT => 'Équipement',
    MaterialType.OTHER => 'Autre',
  };
}
