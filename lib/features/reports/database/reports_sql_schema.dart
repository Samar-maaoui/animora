import '../../../core/database/sql_module.dart';

class ReportsSqlSchema {
  static const tables = <SqlTable>[
    SqlTable(
      name: 'reports',
      collection: 'reports',
      createSql: '''CREATE TABLE reports (
"id" INTEGER PRIMARY KEY NOT NULL CHECK(id>0),
"userId" TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
"type" TEXT NOT NULL CHECK("type" IN ('STRAY_ANIMAL','INJURED_ANIMAL','ABANDONED_ANIMAL','OTHER')),
"description" TEXT NOT NULL,
"photo" TEXT,
"latitude" REAL,
"longitude" REAL,
"urgencyLevel" INTEGER NOT NULL,
"status" TEXT NOT NULL CHECK("status" IN ('NEW','CONFIRMED','IN_PROGRESS','RESOLVED','REJECTED')),
"createdAt" TEXT NOT NULL,
CHECK((latitude IS NULL AND longitude IS NULL) OR (latitude IS NOT NULL AND longitude IS NOT NULL AND latitude BETWEEN -90 AND 90 AND longitude BETWEEN -180 AND 180)),
CHECK(urgencyLevel BETWEEN 1 AND 3)
)''',
      primaryKey: ["id"],
      booleans: [],
      jsonFields: [],
    ),
    SqlTable(
      name: 'report_confirmations',
      collection: 'confirmations',
      createSql: '''CREATE TABLE report_confirmations (
"id" INTEGER PRIMARY KEY NOT NULL CHECK(id>0),
"reportId" INTEGER NOT NULL REFERENCES reports(id) ON DELETE RESTRICT,
"userId" TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
"date" TEXT NOT NULL,
"comment" TEXT,
UNIQUE(reportId,userId)
)''',
      primaryKey: ["id"],
      booleans: [],
      jsonFields: [],
    ),
    SqlTable(
      name: 'announcements',
      collection: 'announcements',
      createSql: '''CREATE TABLE announcements (
"id" INTEGER PRIMARY KEY NOT NULL CHECK(id>0),
"userId" TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
"type" TEXT NOT NULL CHECK("type" IN ('LOST','FOUND')),
"species" TEXT NOT NULL,
"breed" TEXT,
"color" TEXT NOT NULL,
"description" TEXT NOT NULL,
"distinguishingSigns" TEXT,
"photo" TEXT,
"latitude" REAL,
"longitude" REAL,
"date" TEXT NOT NULL,
"status" TEXT NOT NULL CHECK("status" IN ('ACTIVE','CLOSED')),
"hidden" INTEGER NOT NULL CHECK("hidden" IN (0,1)),
CHECK((latitude IS NULL AND longitude IS NULL) OR (latitude IS NOT NULL AND longitude IS NOT NULL AND latitude BETWEEN -90 AND 90 AND longitude BETWEEN -180 AND 180))
)''',
      primaryKey: ["id"],
      booleans: ["hidden"],
      jsonFields: [],
    ),
    SqlTable(
      name: 'testimonies',
      collection: 'testimonies',
      createSql: '''CREATE TABLE testimonies (
"id" INTEGER PRIMARY KEY NOT NULL CHECK(id>0),
"announcementId" INTEGER NOT NULL REFERENCES announcements(id) ON DELETE RESTRICT,
"userId" TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
"latitude" REAL,
"longitude" REAL,
"date" TEXT NOT NULL,
"photo" TEXT,
"comment" TEXT NOT NULL,
CHECK((latitude IS NULL AND longitude IS NULL) OR (latitude IS NOT NULL AND longitude IS NOT NULL AND latitude BETWEEN -90 AND 90 AND longitude BETWEEN -180 AND 180))
)''',
      primaryKey: ["id"],
      booleans: [],
      jsonFields: [],
    ),
    SqlTable(
      name: 'search_zones',
      collection: 'zones',
      createSql: '''CREATE TABLE search_zones (
"id" INTEGER PRIMARY KEY NOT NULL CHECK(id>0),
"announcementId" INTEGER NOT NULL REFERENCES announcements(id) ON DELETE RESTRICT,
"latitude" REAL NOT NULL,
"longitude" REAL NOT NULL,
"radius" REAL NOT NULL,
"createdAt" TEXT NOT NULL,
CHECK((latitude IS NULL AND longitude IS NULL) OR (latitude IS NOT NULL AND longitude IS NOT NULL AND latitude BETWEEN -90 AND 90 AND longitude BETWEEN -180 AND 180)),
UNIQUE(announcementId),
CHECK(radius>0)
)''',
      primaryKey: ["id"],
      booleans: [],
      jsonFields: [],
    ),
    SqlTable(
      name: 'matches',
      collection: 'matches',
      createSql: '''CREATE TABLE matches (
"id" INTEGER PRIMARY KEY NOT NULL CHECK(id>0),
"lostAnnouncementId" INTEGER NOT NULL REFERENCES announcements(id) ON DELETE RESTRICT,
"foundAnnouncementId" INTEGER NOT NULL REFERENCES announcements(id) ON DELETE RESTRICT,
"score" REAL NOT NULL,
"status" TEXT NOT NULL CHECK("status" IN ('DETECTED','CONFIRMED','REJECTED')),
"detectedAt" TEXT NOT NULL,
UNIQUE(lostAnnouncementId,foundAnnouncementId),
CHECK(lostAnnouncementId!=foundAnnouncementId),
CHECK(score BETWEEN 0 AND 100)
)''',
      primaryKey: ["id"],
      booleans: [],
      jsonFields: [],
    ),
    SqlTable(
      name: 'claims',
      collection: 'claims',
      createSql: '''CREATE TABLE claims (
"id" INTEGER PRIMARY KEY NOT NULL CHECK(id>0),
"announcementId" INTEGER NOT NULL REFERENCES announcements(id) ON DELETE RESTRICT,
"claimantUserId" TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
"verificationCode" TEXT,
"evidence" TEXT NOT NULL,
"status" TEXT NOT NULL CHECK("status" IN ('PENDING','VERIFIED','REJECTED')),
"createdAt" TEXT NOT NULL
)''',
      primaryKey: ["id"],
      booleans: [],
      jsonFields: [],
    ),
    SqlTable(
      name: 'reunion_stories',
      collection: 'stories',
      createSql: '''CREATE TABLE reunion_stories (
"id" INTEGER PRIMARY KEY NOT NULL CHECK(id>0),
"announcementId" INTEGER NOT NULL REFERENCES announcements(id) ON DELETE RESTRICT,
"title" TEXT NOT NULL,
"photo" TEXT,
"publicationDate" TEXT NOT NULL,
"authorUserId" TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
UNIQUE(announcementId)
)''',
      primaryKey: ["id"],
      booleans: [],
      jsonFields: [],
    ),
  ];
  static const extra = <String>[
    "CREATE INDEX idx_reports_user ON reports(userId,status)",
    "CREATE INDEX idx_announcements_user ON announcements(userId,status)",
    "CREATE INDEX idx_testimonies_announcement ON testimonies(announcementId,date)",
    "CREATE UNIQUE INDEX idx_active_claim ON claims(announcementId,claimantUserId) WHERE status IN ('PENDING','VERIFIED')",
    "CREATE UNIQUE INDEX idx_verified_claim ON claims(announcementId) WHERE status='VERIFIED'",
    "CREATE TRIGGER check_match_insert BEFORE INSERT ON matches WHEN (SELECT type FROM announcements WHERE id=NEW.lostAnnouncementId)!='LOST' OR (SELECT type FROM announcements WHERE id=NEW.foundAnnouncementId)!='FOUND' BEGIN SELECT RAISE(ABORT,'LOST/FOUND mismatch'); END",
    "CREATE TRIGGER check_match_update BEFORE UPDATE ON matches WHEN (SELECT type FROM announcements WHERE id=NEW.lostAnnouncementId)!='LOST' OR (SELECT type FROM announcements WHERE id=NEW.foundAnnouncementId)!='FOUND' BEGIN SELECT RAISE(ABORT,'LOST/FOUND mismatch'); END",
  ];
}
