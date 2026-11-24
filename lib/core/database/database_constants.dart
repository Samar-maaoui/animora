abstract final class DatabaseConstants {
  static const name = 'animora.db';
  static const version = 9;
  static const catalogMigration = 'catalog_preferences_v1';
  static const tables = [
    'users',
    'animals',
    'favorites',
    'adoption_questionnaires',
    'adoptions',
    'adoption_contracts',
    'adoption_followups',
    'foster_placements',
  ];
}
