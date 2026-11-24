import '../../features/events/database/events_sql_schema.dart';
import '../../features/donations/database/donations_sql_schema.dart';
import '../../features/animal_services/database/animal_services_sql_schema.dart';
import '../../features/reports/database/reports_sql_schema.dart';

import 'package:sqflite/sqlite_api.dart';

/// Schema v1: relational entities; v2: query and business uniqueness indexes.
abstract final class DatabaseMigrations {
  static Future<void> upgrade(DatabaseExecutor db, int from, int to) async {
    if (from < 1 && to >= 1) {
      for (final sql in schemaV1) {
        await db.execute(sql);
      }
    }
    if (from < 2 && to >= 2) {
      for (final sql in indexesV2) {
        await db.execute(sql);
      }
    }
    if (from < 3 && to >= 3) await _reports(db);
    if (from < 4 && to >= 4) {
      for (final t in ServicesSqlSchema.tables) {
        await db.execute(t.createSql);
      }
      for (final s in ServicesSqlSchema.extra) {
        await db.execute(s);
      }
    }
    if (from < 5 && to >= 5) {
      for (final t in DonationsSqlSchema.tables) {
        await db.execute(t.createSql);
      }
      for (final s in DonationsSqlSchema.extra) {
        await db.execute(s);
      }
    }
    if (from < 6 && to >= 6) {
      for (final t in EventsSqlSchema.tables) {
        await db.execute(t.createSql);
      }
      for (final s in EventsSqlSchema.extra) {
        await db.execute(s);
      }
    }
    if (from < 7 && to >= 7) {
      await db.execute(
        "CREATE UNIQUE INDEX idx_users_email_normalized ON users(lower(trim(email)))",
      );
      await db.execute(
        "CREATE TABLE auth_accounts (userId TEXT PRIMARY KEY NOT NULL REFERENCES users(id) ON DELETE RESTRICT, credentialRef TEXT NOT NULL UNIQUE CHECK(length(credentialRef)>0), revision INTEGER NOT NULL CHECK(revision>0), updatedAt TEXT NOT NULL)",
      );
    }
    if (from < 8 && to >= 8) {
      for (final sql in authEventsV8) {
        await db.execute(sql);
      }
    }
    // v9: professional card number of veterinarians (read by OCR at sign-up).
    if (from < 9 && to >= 9) {
      await db.execute(
        'ALTER TABLE users ADD COLUMN professionalCardNumber TEXT',
      );
    }
  }

  static Future<void> _reports(DatabaseExecutor db) async {
    for (final t in ReportsSqlSchema.tables) {
      await db.execute(t.createSql);
    }
    for (final s in ReportsSqlSchema.extra) {
      await db.execute(s);
    }
  }

  /// v8: security journal of the user module (logins, failures, lockouts,
  /// admin decisions). No password, hash or session id is ever stored here.
  /// No foreign key on userId: failed logins may target unknown e-mails.
  static const authEventsV8 = [
    '''CREATE TABLE auth_events (
id INTEGER PRIMARY KEY AUTOINCREMENT,
type TEXT NOT NULL CHECK(length(type)>0),
email TEXT,userId TEXT,actorId TEXT,details TEXT,
createdAt TEXT NOT NULL)''',
    'CREATE INDEX idx_auth_events_email ON auth_events(email, createdAt)',
    'CREATE INDEX idx_auth_events_date ON auth_events(createdAt)',
  ];

  static const schemaV1 = [
    '''CREATE TABLE database_metadata (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL)''',
    '''CREATE TABLE users (
id TEXT PRIMARY KEY NOT NULL CHECK(length(trim(id))>0),
firstName TEXT NOT NULL,lastName TEXT NOT NULL,
email TEXT NOT NULL COLLATE NOCASE UNIQUE CHECK(length(trim(email))>0),
phone TEXT,photo TEXT,city TEXT NOT NULL,
profile TEXT NOT NULL CHECK(profile IN ('citizen','veterinarian','fosterFamily','petSitter','admin')),
status TEXT NOT NULL CHECK(status IN ('pending','active','blocked')),
createdAt TEXT NOT NULL)''',
    '''CREATE TABLE animals (
id INTEGER PRIMARY KEY CHECK(id>0),name TEXT NOT NULL CHECK(length(trim(name))>0),
species TEXT NOT NULL,breed TEXT NOT NULL,sex TEXT NOT NULL,
age INTEGER NOT NULL CHECK(typeof(age)='integer' AND age BETWEEN 0 AND 200),
weight REAL NOT NULL CHECK(weight>0 AND weight<=10000),color TEXT NOT NULL,
sterilized INTEGER NOT NULL CHECK(sterilized IN (0,1)),health TEXT NOT NULL,
character TEXT NOT NULL,microchipNumber TEXT NOT NULL,animalPhoto TEXT NOT NULL,
status TEXT NOT NULL CHECK(status IN ('AVAILABLE','FOSTERED','PENDING_ADOPTION','ADOPTED','LOST','FOUND')),
arrivalDate TEXT NOT NULL,city TEXT NOT NULL)''',
    '''CREATE TABLE favorites (
userId TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
animalId INTEGER NOT NULL REFERENCES animals(id) ON DELETE CASCADE,
addedAt TEXT NOT NULL,PRIMARY KEY(userId,animalId))''',
    '''CREATE TABLE adoptions (
id INTEGER PRIMARY KEY CHECK(id>0),
userId TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
animalId INTEGER NOT NULL REFERENCES animals(id) ON DELETE RESTRICT,
applicationDate TEXT NOT NULL,motivation TEXT NOT NULL,
compatibilityScore REAL NOT NULL CHECK(compatibilityScore BETWEEN 0 AND 100),
status TEXT NOT NULL CHECK(status IN ('PENDING','ACCEPTED','REJECTED','CANCELLED')),
decisionDate TEXT,adoptionDate TEXT,
applicantSnapshot TEXT NOT NULL)''',
    '''CREATE TABLE adoption_questionnaires (
id INTEGER PRIMARY KEY CHECK(id>0),adoptionId INTEGER NOT NULL UNIQUE REFERENCES adoptions(id) ON DELETE CASCADE,
housingType TEXT NOT NULL,hasChildren INTEGER NOT NULL CHECK(hasChildren IN (0,1)),
hasOtherAnimals INTEGER NOT NULL CHECK(hasOtherAnimals IN (0,1)),experience TEXT NOT NULL,availableTime TEXT NOT NULL)''',
    '''CREATE TABLE adoption_contracts (
id INTEGER PRIMARY KEY CHECK(id>0),adoptionId INTEGER NOT NULL UNIQUE REFERENCES adoptions(id) ON DELETE CASCADE,
signatureDate TEXT,conditions TEXT NOT NULL,signed INTEGER NOT NULL CHECK(signed IN (0,1)),
CHECK((signed=0 AND signatureDate IS NULL) OR (signed=1 AND signatureDate IS NOT NULL)))''',
    '''CREATE TABLE adoption_followups (
id INTEGER PRIMARY KEY CHECK(id>0),adoptionId INTEGER NOT NULL REFERENCES adoptions(id) ON DELETE CASCADE,
date TEXT NOT NULL,news TEXT NOT NULL,photo TEXT,visitType TEXT NOT NULL)''',
    '''CREATE TABLE foster_placements (
id INTEGER PRIMARY KEY CHECK(id>0),animalId INTEGER NOT NULL REFERENCES animals(id) ON DELETE RESTRICT,
fosterFamilyUserId TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
startDate TEXT NOT NULL,endDate TEXT,status TEXT NOT NULL CHECK(status IN ('ACTIVE','COMPLETED','CANCELLED')),
remarks TEXT NOT NULL,CHECK(endDate IS NULL OR julianday(endDate)>=julianday(startDate)))''',
  ];
  static const indexesV2 = [
    'CREATE INDEX idx_animals_search ON animals(status,species,city)',
    'CREATE INDEX idx_animals_name ON animals(name COLLATE NOCASE)',
    'CREATE INDEX idx_favorites_animal ON favorites(animalId)',
    'CREATE INDEX idx_adoptions_user_date ON adoptions(userId,applicationDate)',
    'CREATE INDEX idx_adoptions_animal ON adoptions(animalId,status)',
    "CREATE UNIQUE INDEX idx_pending_adoption ON adoptions(userId,animalId) WHERE status='PENDING'",
    "CREATE UNIQUE INDEX idx_accepted_animal ON adoptions(animalId) WHERE status='ACCEPTED'",
    'CREATE INDEX idx_followups_adoption_date ON adoption_followups(adoptionId,date)',
    'CREATE INDEX idx_placements_family ON foster_placements(fosterFamilyUserId,status)',
    "CREATE UNIQUE INDEX idx_active_placement ON foster_placements(animalId) WHERE status='ACTIVE'",
  ];
}
