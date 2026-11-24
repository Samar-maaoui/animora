import '../../../core/database/sql_module.dart';

class EventsSqlSchema {
  static const tables = <SqlTable>[
    SqlTable(
      name: 'events',
      collection: 'events',
      createSql: '''CREATE TABLE events (
"id" INTEGER PRIMARY KEY NOT NULL CHECK(id>0),
"title" TEXT NOT NULL,
"description" TEXT NOT NULL,
"type" TEXT NOT NULL CHECK("type" IN ('ADOPTION_DAY','AWARENESS','COLLECTION','SOLIDARITY_WALK','OTHER')),
"location" TEXT NOT NULL,
"city" TEXT NOT NULL,
"latitude" REAL,
"longitude" REAL,
"startDate" TEXT NOT NULL,
"endDate" TEXT NOT NULL,
"capacity" INTEGER NOT NULL,
"status" TEXT NOT NULL CHECK("status" IN ('DRAFT','PUBLISHED','COMPLETED','CANCELLED')),
"image" TEXT,
"organizerUserId" TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
CHECK((latitude IS NULL AND longitude IS NULL) OR (latitude IS NOT NULL AND longitude IS NOT NULL AND latitude BETWEEN -90 AND 90 AND longitude BETWEEN -180 AND 180)),
CHECK(capacity>0),
CHECK(julianday(endDate)>julianday(startDate))
)''',
      primaryKey: ["id"],
      booleans: [],
      jsonFields: [],
    ),
    SqlTable(
      name: 'event_registrations',
      collection: 'registrations',
      releaseStatuses: ['CONFIRMED', 'ATTENDED'],
      createSql: '''CREATE TABLE event_registrations (
"id" INTEGER PRIMARY KEY NOT NULL CHECK(id>0),
"eventId" INTEGER NOT NULL REFERENCES events(id) ON DELETE RESTRICT,
"userId" TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
"registrationDate" TEXT NOT NULL,
"type" TEXT NOT NULL CHECK("type" IN ('PARTICIPANT','VOLUNTEER')),
"status" TEXT NOT NULL CHECK("status" IN ('CONFIRMED','WAITLISTED','CANCELLED','ATTENDED')),
"userName" TEXT NOT NULL
)''',
      primaryKey: ["id"],
      booleans: [],
      jsonFields: [],
    ),
    SqlTable(
      name: 'event_tickets',
      collection: 'tickets',
      createSql: '''CREATE TABLE event_tickets (
"id" INTEGER PRIMARY KEY NOT NULL CHECK(id>0),
"registrationId" INTEGER NOT NULL REFERENCES event_registrations(id) ON DELETE RESTRICT,
"code" TEXT NOT NULL,
"issueDate" TEXT NOT NULL,
"used" INTEGER NOT NULL CHECK("used" IN (0,1)),
UNIQUE(registrationId),
UNIQUE(code)
)''',
      primaryKey: ["id"],
      booleans: ["used"],
      jsonFields: [],
    ),
    SqlTable(
      name: 'event_activities',
      collection: 'activities',
      createSql: '''CREATE TABLE event_activities (
"id" INTEGER PRIMARY KEY NOT NULL CHECK(id>0),
"eventId" INTEGER NOT NULL REFERENCES events(id) ON DELETE RESTRICT,
"title" TEXT NOT NULL,
"description" TEXT NOT NULL,
"startTime" TEXT NOT NULL,
"endTime" TEXT NOT NULL,
CHECK(julianday(endTime)>julianday(startTime))
)''',
      primaryKey: ["id"],
      booleans: [],
      jsonFields: [],
    ),
    SqlTable(
      name: 'volunteer_tasks',
      collection: 'tasks',
      createSql: '''CREATE TABLE volunteer_tasks (
"id" INTEGER PRIMARY KEY NOT NULL CHECK(id>0),
"eventId" INTEGER NOT NULL REFERENCES events(id) ON DELETE RESTRICT,
"title" TEXT NOT NULL,
"description" TEXT NOT NULL,
"assignedUserId" TEXT REFERENCES users(id) ON DELETE RESTRICT,
"status" TEXT NOT NULL CHECK("status" IN ('AVAILABLE','ASSIGNED','IN_PROGRESS','COMPLETED'))
)''',
      primaryKey: ["id"],
      booleans: [],
      jsonFields: [],
    ),
    SqlTable(
      name: 'event_reports',
      collection: 'reports',
      createSql: '''CREATE TABLE event_reports (
"id" INTEGER PRIMARY KEY NOT NULL CHECK(id>0),
"eventId" INTEGER NOT NULL REFERENCES events(id) ON DELETE RESTRICT,
"participantCount" INTEGER NOT NULL,
"volunteerCount" INTEGER NOT NULL,
"description" TEXT NOT NULL,
"createdAt" TEXT NOT NULL,
"published" INTEGER NOT NULL CHECK("published" IN (0,1)),
"photos" TEXT NOT NULL,
UNIQUE(eventId),
CHECK(participantCount>=0 AND volunteerCount>=0)
)''',
      primaryKey: ["id"],
      booleans: ["published"],
      jsonFields: ["photos"],
    ),
  ];
  static const extra = <String>[
    "CREATE UNIQUE INDEX idx_active_registration ON event_registrations(eventId,userId) WHERE status<>'CANCELLED'",
    "CREATE INDEX idx_event_waitlist ON event_registrations(eventId,status,registrationDate,id)",
    "CREATE INDEX idx_events_search ON events(status,city,startDate)",
    "CREATE TRIGGER capacity_reduce BEFORE UPDATE OF capacity ON events WHEN NEW.capacity<(SELECT COUNT(*) FROM event_registrations r WHERE r.eventId=NEW.id AND r.status IN ('CONFIRMED','ATTENDED')) BEGIN SELECT RAISE(ABORT,'capacity below attendance'); END",
    "CREATE TRIGGER registration_capacity_INSERT BEFORE INSERT ON event_registrations WHEN NEW.status IN ('CONFIRMED','ATTENDED') AND (SELECT COUNT(*) FROM event_registrations r WHERE r.eventId=NEW.eventId AND r.id<>NEW.id AND r.status IN ('CONFIRMED','ATTENDED'))>=(SELECT capacity FROM events WHERE id=NEW.eventId) BEGIN SELECT RAISE(ABORT,'event full'); END",
    "CREATE TRIGGER ticket_registration_INSERT BEFORE INSERT ON event_tickets WHEN NOT EXISTS(SELECT 1 FROM event_registrations r WHERE r.id=NEW.registrationId AND (r.status='CONFIRMED' OR (r.status='ATTENDED' AND NEW.used=1) OR r.status='CANCELLED')) BEGIN SELECT RAISE(ABORT,'ticket registration invalid'); END",
    "CREATE TRIGGER task_volunteer_INSERT BEFORE INSERT ON volunteer_tasks WHEN NEW.assignedUserId IS NOT NULL AND NOT EXISTS(SELECT 1 FROM event_registrations r WHERE r.eventId=NEW.eventId AND r.userId=NEW.assignedUserId AND r.type='VOLUNTEER' AND (r.status IN ('CONFIRMED','ATTENDED') OR NEW.status='COMPLETED')) BEGIN SELECT RAISE(ABORT,'task requires volunteer'); END",
    "CREATE TRIGGER registration_capacity_UPDATE BEFORE UPDATE ON event_registrations WHEN NEW.status IN ('CONFIRMED','ATTENDED') AND (SELECT COUNT(*) FROM event_registrations r WHERE r.eventId=NEW.eventId AND r.id<>NEW.id AND r.status IN ('CONFIRMED','ATTENDED'))>=(SELECT capacity FROM events WHERE id=NEW.eventId) BEGIN SELECT RAISE(ABORT,'event full'); END",
    "CREATE TRIGGER ticket_registration_UPDATE BEFORE UPDATE ON event_tickets WHEN NOT EXISTS(SELECT 1 FROM event_registrations r WHERE r.id=NEW.registrationId AND (r.status='CONFIRMED' OR (r.status='ATTENDED' AND NEW.used=1) OR r.status='CANCELLED')) BEGIN SELECT RAISE(ABORT,'ticket registration invalid'); END",
    "CREATE TRIGGER task_volunteer_UPDATE BEFORE UPDATE ON volunteer_tasks WHEN NEW.assignedUserId IS NOT NULL AND NOT EXISTS(SELECT 1 FROM event_registrations r WHERE r.eventId=NEW.eventId AND r.userId=NEW.assignedUserId AND r.type='VOLUNTEER' AND (r.status IN ('CONFIRMED','ATTENDED') OR NEW.status='COMPLETED')) BEGIN SELECT RAISE(ABORT,'task requires volunteer'); END",
  ];
}
