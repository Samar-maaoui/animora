-- Base de demonstration fictive Animora, schema version 2.
PRAGMA foreign_keys=ON;

CREATE TABLE adoption_contracts (
id INTEGER PRIMARY KEY CHECK(id>0),adoptionId INTEGER NOT NULL UNIQUE REFERENCES adoptions(id) ON DELETE CASCADE,
signatureDate TEXT,conditions TEXT NOT NULL,signed INTEGER NOT NULL CHECK(signed IN (0,1)),
CHECK((signed=0 AND signatureDate IS NULL) OR (signed=1 AND signatureDate IS NOT NULL)));

CREATE TABLE adoption_followups (
id INTEGER PRIMARY KEY CHECK(id>0),adoptionId INTEGER NOT NULL REFERENCES adoptions(id) ON DELETE CASCADE,
date TEXT NOT NULL,news TEXT NOT NULL,photo TEXT,visitType TEXT NOT NULL);

CREATE TABLE adoption_questionnaires (
id INTEGER PRIMARY KEY CHECK(id>0),adoptionId INTEGER NOT NULL UNIQUE REFERENCES adoptions(id) ON DELETE CASCADE,
housingType TEXT NOT NULL,hasChildren INTEGER NOT NULL CHECK(hasChildren IN (0,1)),
hasOtherAnimals INTEGER NOT NULL CHECK(hasOtherAnimals IN (0,1)),experience TEXT NOT NULL,availableTime TEXT NOT NULL);

CREATE TABLE adoptions (
id INTEGER PRIMARY KEY CHECK(id>0),
userId TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
animalId INTEGER NOT NULL REFERENCES animals(id) ON DELETE RESTRICT,
applicationDate TEXT NOT NULL,motivation TEXT NOT NULL,
compatibilityScore REAL NOT NULL CHECK(compatibilityScore BETWEEN 0 AND 100),
status TEXT NOT NULL CHECK(status IN ('PENDING','ACCEPTED','REJECTED','CANCELLED')),
decisionDate TEXT,adoptionDate TEXT,
applicantSnapshot TEXT NOT NULL);

CREATE TABLE animals (
id INTEGER PRIMARY KEY CHECK(id>0),name TEXT NOT NULL CHECK(length(trim(name))>0),
species TEXT NOT NULL,breed TEXT NOT NULL,sex TEXT NOT NULL,
age INTEGER NOT NULL CHECK(typeof(age)='integer' AND age BETWEEN 0 AND 200),
weight REAL NOT NULL CHECK(weight>0 AND weight<=10000),color TEXT NOT NULL,
sterilized INTEGER NOT NULL CHECK(sterilized IN (0,1)),health TEXT NOT NULL,
character TEXT NOT NULL,microchipNumber TEXT NOT NULL,animalPhoto TEXT NOT NULL,
status TEXT NOT NULL CHECK(status IN ('AVAILABLE','FOSTERED','PENDING_ADOPTION','ADOPTED','LOST','FOUND')),
arrivalDate TEXT NOT NULL,city TEXT NOT NULL);

CREATE TABLE database_metadata (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL);

CREATE TABLE favorites (
userId TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
animalId INTEGER NOT NULL REFERENCES animals(id) ON DELETE CASCADE,
addedAt TEXT NOT NULL,PRIMARY KEY(userId,animalId));

CREATE TABLE foster_placements (
id INTEGER PRIMARY KEY CHECK(id>0),animalId INTEGER NOT NULL REFERENCES animals(id) ON DELETE RESTRICT,
fosterFamilyUserId TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
startDate TEXT NOT NULL,endDate TEXT,status TEXT NOT NULL CHECK(status IN ('ACTIVE','COMPLETED','CANCELLED')),
remarks TEXT NOT NULL,CHECK(endDate IS NULL OR julianday(endDate)>=julianday(startDate)));

CREATE TABLE users (
id TEXT PRIMARY KEY NOT NULL CHECK(length(trim(id))>0),
firstName TEXT NOT NULL,lastName TEXT NOT NULL,
email TEXT NOT NULL COLLATE NOCASE UNIQUE CHECK(length(trim(email))>0),
phone TEXT,photo TEXT,city TEXT NOT NULL,
profile TEXT NOT NULL CHECK(profile IN ('citizen','veterinarian','fosterFamily','petSitter','admin')),
status TEXT NOT NULL CHECK(status IN ('pending','active','blocked')),
createdAt TEXT NOT NULL);

CREATE UNIQUE INDEX idx_accepted_animal ON adoptions(animalId) WHERE status='ACCEPTED';

CREATE UNIQUE INDEX idx_active_placement ON foster_placements(animalId) WHERE status='ACTIVE';

CREATE INDEX idx_adoptions_animal ON adoptions(animalId,status);

CREATE INDEX idx_adoptions_user_date ON adoptions(userId,applicationDate);

CREATE INDEX idx_animals_name ON animals(name COLLATE NOCASE);

CREATE INDEX idx_animals_search ON animals(status,species,city);

CREATE INDEX idx_favorites_animal ON favorites(animalId);

CREATE INDEX idx_followups_adoption_date ON adoption_followups(adoptionId,date);

CREATE UNIQUE INDEX idx_pending_adoption ON adoptions(userId,animalId) WHERE status='PENDING';

CREATE INDEX idx_placements_family ON foster_placements(fosterFamilyUserId,status);
PRAGMA user_version=2;
