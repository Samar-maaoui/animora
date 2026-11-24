-- Demonstration fictive, schéma v6. SQLite est ouvert en lecture seule pour cette vérification.
PRAGMA foreign_keys=ON;
CREATE UNIQUE INDEX idx_accepted_animal ON adoptions(animalId) WHERE status='ACCEPTED';

CREATE UNIQUE INDEX idx_active_claim ON claims(announcementId,claimantUserId) WHERE status IN ('PENDING','VERIFIED');

CREATE UNIQUE INDEX idx_active_placement ON foster_placements(animalId) WHERE status='ACTIVE';

CREATE UNIQUE INDEX idx_active_registration ON event_registrations(eventId,userId) WHERE status<>'CANCELLED';

CREATE INDEX idx_adoptions_animal ON adoptions(animalId,status);

CREATE INDEX idx_adoptions_user_date ON adoptions(userId,applicationDate);

CREATE INDEX idx_animals_name ON animals(name COLLATE NOCASE);

CREATE INDEX idx_animals_search ON animals(status,species,city);

CREATE INDEX idx_announcements_user ON announcements(userId,status);

CREATE INDEX idx_appointments_client ON veterinary_appointments(clientUserId,appointmentDate);

CREATE UNIQUE INDEX idx_donation_key ON donations(donorUserId,requestKey) WHERE requestKey IS NOT NULL;

CREATE INDEX idx_donations_campaign ON donations(campaignId,status);

CREATE INDEX idx_event_waitlist ON event_registrations(eventId,status,registrationDate,id);

CREATE INDEX idx_events_search ON events(status,city,startDate);

CREATE INDEX idx_favorites_animal ON favorites(animalId);

CREATE INDEX idx_followups_adoption_date ON adoption_followups(adoptionId,date);

CREATE INDEX idx_health_animal ON vaccinations(animalId,vaccinationDate);

CREATE UNIQUE INDEX idx_held_appointment ON veterinary_appointments(availabilityId) WHERE status IN ('PENDING','CONFIRMED','COMPLETED');

CREATE UNIQUE INDEX idx_occurrence ON donations(recurringDonationId,scheduledFor) WHERE recurringDonationId IS NOT NULL;

CREATE UNIQUE INDEX idx_pending_adoption ON adoptions(userId,animalId) WHERE status='PENDING';

CREATE INDEX idx_placements_family ON foster_placements(fosterFamilyUserId,status);

CREATE UNIQUE INDEX idx_recurring_key ON recurring_donations(donorUserId,requestKey) WHERE requestKey IS NOT NULL;

CREATE INDEX idx_reports_user ON reports(userId,status);

CREATE INDEX idx_requests_owner ON pet_sitting_requests(ownerUserId,status);

CREATE INDEX idx_testimonies_announcement ON testimonies(announcementId,date);

CREATE UNIQUE INDEX idx_verified_claim ON claims(announcementId) WHERE status='VERIFIED';

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

CREATE TABLE animal_care (
"id" INTEGER PRIMARY KEY NOT NULL CHECK(id>0),
"animalId" INTEGER NOT NULL REFERENCES animals(id) ON DELETE RESTRICT,
"veterinarianUserId" TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
"type" TEXT NOT NULL,
"date" TEXT NOT NULL,
"description" TEXT NOT NULL,
"cost" REAL,
"veterinarianName" TEXT NOT NULL,
CHECK(cost IS NULL OR cost>=0)
);

CREATE TABLE animals (
id INTEGER PRIMARY KEY CHECK(id>0),name TEXT NOT NULL CHECK(length(trim(name))>0),
species TEXT NOT NULL,breed TEXT NOT NULL,sex TEXT NOT NULL,
age INTEGER NOT NULL CHECK(typeof(age)='integer' AND age BETWEEN 0 AND 200),
weight REAL NOT NULL CHECK(weight>0 AND weight<=10000),color TEXT NOT NULL,
sterilized INTEGER NOT NULL CHECK(sterilized IN (0,1)),health TEXT NOT NULL,
character TEXT NOT NULL,microchipNumber TEXT NOT NULL,animalPhoto TEXT NOT NULL,
status TEXT NOT NULL CHECK(status IN ('AVAILABLE','FOSTERED','PENDING_ADOPTION','ADOPTED','LOST','FOUND')),
arrivalDate TEXT NOT NULL,city TEXT NOT NULL);

CREATE TABLE announcements (
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
);

CREATE TABLE claims (
"id" INTEGER PRIMARY KEY NOT NULL CHECK(id>0),
"announcementId" INTEGER NOT NULL REFERENCES announcements(id) ON DELETE RESTRICT,
"claimantUserId" TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
"verificationCode" TEXT,
"evidence" TEXT NOT NULL,
"status" TEXT NOT NULL CHECK("status" IN ('PENDING','VERIFIED','REJECTED')),
"createdAt" TEXT NOT NULL
);

CREATE TABLE database_metadata (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL);

CREATE TABLE donation_campaigns (
"id" INTEGER PRIMARY KEY NOT NULL CHECK(id>0),
"title" TEXT NOT NULL,
"description" TEXT NOT NULL,
"targetAmount" INTEGER NOT NULL,
"collectedAmount" INTEGER NOT NULL,
"startDate" TEXT NOT NULL,
"endDate" TEXT NOT NULL,
"status" TEXT NOT NULL CHECK("status" IN ('DRAFT','ACTIVE','COMPLETED','CANCELLED')),
"image" TEXT,
CHECK(targetAmount>0 AND collectedAmount>=0),
CHECK(julianday(endDate)>julianday(startDate)),
CHECK(targetAmount IS NULL OR (typeof(targetAmount)='integer' AND targetAmount>=0)),
CHECK(collectedAmount IS NULL OR (typeof(collectedAmount)='integer' AND collectedAmount>=0))
);

CREATE TABLE donation_receipts (
"id" INTEGER PRIMARY KEY NOT NULL CHECK(id>0),
"donationId" INTEGER NOT NULL REFERENCES donations(id) ON DELETE RESTRICT,
"issueDate" TEXT NOT NULL,
"reference" TEXT NOT NULL,
"filePath" TEXT,
"donationReference" TEXT NOT NULL,
"donorName" TEXT NOT NULL,
"campaignTitle" TEXT NOT NULL,
"type" TEXT NOT NULL CHECK("type" IN ('FINANCIAL','MATERIAL')),
"amount" INTEGER,
"materialDescription" TEXT,
UNIQUE(donationId),
UNIQUE(reference),
CHECK(amount IS NULL OR (typeof(amount)='integer' AND amount>=0))
);

CREATE TABLE donations (
"id" INTEGER PRIMARY KEY NOT NULL CHECK(id>0),
"donorUserId" TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
"campaignId" INTEGER NOT NULL REFERENCES donation_campaigns(id) ON DELETE RESTRICT,
"type" TEXT NOT NULL CHECK("type" IN ('FINANCIAL','MATERIAL')),
"amount" INTEGER,
"donationDate" TEXT NOT NULL,
"status" TEXT NOT NULL CHECK("status" IN ('PENDING','CONFIRMED','CANCELLED')),
"donorName" TEXT NOT NULL,
"campaignTitle" TEXT NOT NULL,
"requestKey" TEXT,
"recurringDonationId" INTEGER REFERENCES recurring_donations(id) ON DELETE RESTRICT,
"scheduledFor" TEXT,
CHECK((type='FINANCIAL' AND amount IS NOT NULL AND amount>0) OR (type='MATERIAL' AND amount IS NULL)),
CHECK((recurringDonationId IS NULL AND scheduledFor IS NULL) OR (recurringDonationId IS NOT NULL AND scheduledFor IS NOT NULL)),
CHECK(amount IS NULL OR (typeof(amount)='integer' AND amount>=0))
);

CREATE TABLE event_activities (
"id" INTEGER PRIMARY KEY NOT NULL CHECK(id>0),
"eventId" INTEGER NOT NULL REFERENCES events(id) ON DELETE RESTRICT,
"title" TEXT NOT NULL,
"description" TEXT NOT NULL,
"startTime" TEXT NOT NULL,
"endTime" TEXT NOT NULL,
CHECK(julianday(endTime)>julianday(startTime))
);

CREATE TABLE event_registrations (
"id" INTEGER PRIMARY KEY NOT NULL CHECK(id>0),
"eventId" INTEGER NOT NULL REFERENCES events(id) ON DELETE RESTRICT,
"userId" TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
"registrationDate" TEXT NOT NULL,
"type" TEXT NOT NULL CHECK("type" IN ('PARTICIPANT','VOLUNTEER')),
"status" TEXT NOT NULL CHECK("status" IN ('CONFIRMED','WAITLISTED','CANCELLED','ATTENDED')),
"userName" TEXT NOT NULL
);

CREATE TABLE event_reports (
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
);

CREATE TABLE event_tickets (
"id" INTEGER PRIMARY KEY NOT NULL CHECK(id>0),
"registrationId" INTEGER NOT NULL REFERENCES event_registrations(id) ON DELETE RESTRICT,
"code" TEXT NOT NULL,
"issueDate" TEXT NOT NULL,
"used" INTEGER NOT NULL CHECK("used" IN (0,1)),
UNIQUE(registrationId),
UNIQUE(code)
);

CREATE TABLE events (
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
);

CREATE TABLE favorites (
userId TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
animalId INTEGER NOT NULL REFERENCES animals(id) ON DELETE CASCADE,
addedAt TEXT NOT NULL,PRIMARY KEY(userId,animalId));

CREATE TABLE foster_placements (
id INTEGER PRIMARY KEY CHECK(id>0),animalId INTEGER NOT NULL REFERENCES animals(id) ON DELETE RESTRICT,
fosterFamilyUserId TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
startDate TEXT NOT NULL,endDate TEXT,status TEXT NOT NULL CHECK(status IN ('ACTIVE','COMPLETED','CANCELLED')),
remarks TEXT NOT NULL,CHECK(endDate IS NULL OR julianday(endDate)>=julianday(startDate)));

CREATE TABLE health_reminders (
"id" INTEGER PRIMARY KEY NOT NULL CHECK(id>0),
"animalId" INTEGER NOT NULL REFERENCES animals(id) ON DELETE RESTRICT,
"type" TEXT NOT NULL,
"scheduledDate" TEXT NOT NULL,
"isSent" INTEGER NOT NULL CHECK("isSent" IN (0,1)),
"vaccinationId" INTEGER REFERENCES vaccinations(id) ON DELETE RESTRICT,
"authorUserId" TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT
);

CREATE TABLE matches (
"id" INTEGER PRIMARY KEY NOT NULL CHECK(id>0),
"lostAnnouncementId" INTEGER NOT NULL REFERENCES announcements(id) ON DELETE RESTRICT,
"foundAnnouncementId" INTEGER NOT NULL REFERENCES announcements(id) ON DELETE RESTRICT,
"score" REAL NOT NULL,
"status" TEXT NOT NULL CHECK("status" IN ('DETECTED','CONFIRMED','REJECTED')),
"detectedAt" TEXT NOT NULL,
UNIQUE(lostAnnouncementId,foundAnnouncementId),
CHECK(lostAnnouncementId!=foundAnnouncementId),
CHECK(score BETWEEN 0 AND 100)
);

CREATE TABLE material_donations (
"id" INTEGER PRIMARY KEY NOT NULL CHECK(id>0),
"donationId" INTEGER NOT NULL REFERENCES donations(id) ON DELETE RESTRICT,
"itemType" TEXT NOT NULL CHECK("itemType" IN ('FOOD','MEDICINE','EQUIPMENT','OTHER')),
"quantity" INTEGER NOT NULL,
"description" TEXT NOT NULL,
"status" TEXT NOT NULL CHECK("status" IN ('PENDING','RECEIVED','REJECTED')),
"materialNeedId" INTEGER REFERENCES material_needs(id) ON DELETE RESTRICT,
UNIQUE(donationId),
CHECK(quantity>0)
);

CREATE TABLE material_needs (
"id" INTEGER PRIMARY KEY NOT NULL CHECK(id>0),
"campaignId" INTEGER NOT NULL REFERENCES donation_campaigns(id) ON DELETE RESTRICT,
"description" TEXT NOT NULL,
"requestedQuantity" INTEGER NOT NULL,
"receivedQuantity" INTEGER NOT NULL,
"status" TEXT NOT NULL CHECK("status" IN ('OPEN','PARTIALLY_FULFILLED','FULFILLED')),
"itemType" TEXT NOT NULL CHECK("itemType" IN ('FOOD','MEDICINE','EQUIPMENT','OTHER')),
CHECK(requestedQuantity>0 AND receivedQuantity>=0)
);

CREATE TABLE pet_sitter_settings (
"userId" TEXT PRIMARY KEY NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
"available" INTEGER NOT NULL CHECK("available" IN (0,1)),
"dailyRate" REAL NOT NULL,
"availableFrom" TEXT NOT NULL,
"availableUntil" TEXT NOT NULL,
CHECK(dailyRate>=0),
CHECK(julianday(availableUntil)>=julianday(availableFrom))
);

CREATE TABLE pet_sitting_requests (
"id" INTEGER PRIMARY KEY NOT NULL CHECK(id>0),
"ownerUserId" TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
"petSitterUserId" TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
"animalId" INTEGER NOT NULL REFERENCES animals(id) ON DELETE RESTRICT,
"startDate" TEXT NOT NULL,
"endDate" TEXT NOT NULL,
"status" TEXT NOT NULL CHECK("status" IN ('PENDING','ACCEPTED','REJECTED','CANCELLED','IN_PROGRESS','COMPLETED')),
"totalPrice" REAL NOT NULL,
"createdAt" TEXT NOT NULL,
"instructions" TEXT NOT NULL,
"ownerName" TEXT NOT NULL,
"petSitterName" TEXT NOT NULL,
"animalName" TEXT NOT NULL,
CHECK(julianday(endDate)>julianday(startDate)),
CHECK(totalPrice>=0)
);

CREATE TABLE pet_sitting_updates (
"id" INTEGER PRIMARY KEY NOT NULL CHECK(id>0),
"petSittingRequestId" INTEGER NOT NULL REFERENCES pet_sitting_requests(id) ON DELETE RESTRICT,
"message" TEXT NOT NULL,
"photo" TEXT,
"createdAt" TEXT NOT NULL
);

CREATE TABLE recurring_donations (
"id" INTEGER PRIMARY KEY NOT NULL CHECK(id>0),
"donorUserId" TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
"campaignId" INTEGER NOT NULL REFERENCES donation_campaigns(id) ON DELETE RESTRICT,
"amount" INTEGER NOT NULL,
"frequency" TEXT NOT NULL CHECK("frequency" IN ('WEEKLY','MONTHLY')),
"nextDonationDate" TEXT NOT NULL,
"status" TEXT NOT NULL CHECK("status" IN ('ACTIVE','PAUSED','CANCELLED')),
"anchorDay" INTEGER NOT NULL,
"donorName" TEXT NOT NULL,
"campaignTitle" TEXT NOT NULL,
"terminationReason" TEXT,
"requestKey" TEXT,
CHECK(amount>0),
CHECK(anchorDay BETWEEN 1 AND 31),
CHECK(amount IS NULL OR (typeof(amount)='integer' AND amount>=0))
);

CREATE TABLE report_confirmations (
"id" INTEGER PRIMARY KEY NOT NULL CHECK(id>0),
"reportId" INTEGER NOT NULL REFERENCES reports(id) ON DELETE RESTRICT,
"userId" TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
"date" TEXT NOT NULL,
"comment" TEXT,
UNIQUE(reportId,userId)
);

CREATE TABLE reports (
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
);

CREATE TABLE reunion_stories (
"id" INTEGER PRIMARY KEY NOT NULL CHECK(id>0),
"announcementId" INTEGER NOT NULL REFERENCES announcements(id) ON DELETE RESTRICT,
"title" TEXT NOT NULL,
"photo" TEXT,
"publicationDate" TEXT NOT NULL,
"authorUserId" TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
UNIQUE(announcementId)
);

CREATE TABLE reviews (
"id" INTEGER PRIMARY KEY NOT NULL CHECK(id>0),
"petSittingRequestId" INTEGER NOT NULL REFERENCES pet_sitting_requests(id) ON DELETE RESTRICT,
"reviewerUserId" TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
"rating" INTEGER NOT NULL,
"comment" TEXT NOT NULL,
"createdAt" TEXT NOT NULL,
UNIQUE(petSittingRequestId),
CHECK(rating BETWEEN 1 AND 5)
);

CREATE TABLE search_zones (
"id" INTEGER PRIMARY KEY NOT NULL CHECK(id>0),
"announcementId" INTEGER NOT NULL REFERENCES announcements(id) ON DELETE RESTRICT,
"latitude" REAL NOT NULL,
"longitude" REAL NOT NULL,
"radius" REAL NOT NULL,
"createdAt" TEXT NOT NULL,
CHECK((latitude IS NULL AND longitude IS NULL) OR (latitude IS NOT NULL AND longitude IS NOT NULL AND latitude BETWEEN -90 AND 90 AND longitude BETWEEN -180 AND 180)),
UNIQUE(announcementId),
CHECK(radius>0)
);

CREATE TABLE testimonies (
"id" INTEGER PRIMARY KEY NOT NULL CHECK(id>0),
"announcementId" INTEGER NOT NULL REFERENCES announcements(id) ON DELETE RESTRICT,
"userId" TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
"latitude" REAL,
"longitude" REAL,
"date" TEXT NOT NULL,
"photo" TEXT,
"comment" TEXT NOT NULL,
CHECK((latitude IS NULL AND longitude IS NULL) OR (latitude IS NOT NULL AND longitude IS NOT NULL AND latitude BETWEEN -90 AND 90 AND longitude BETWEEN -180 AND 180))
);

CREATE TABLE transparency_reports (
"id" INTEGER PRIMARY KEY NOT NULL CHECK(id>0),
"campaignId" INTEGER NOT NULL REFERENCES donation_campaigns(id) ON DELETE RESTRICT,
"description" TEXT NOT NULL,
"content" TEXT NOT NULL,
"createdAt" TEXT NOT NULL,
"documentPath" TEXT,
"financialTotal" INTEGER NOT NULL,
"receivedMaterialCount" INTEGER NOT NULL,
"receivedMaterialSummary" TEXT NOT NULL,
CHECK(financialTotal>=0 AND receivedMaterialCount>=0),
CHECK(financialTotal IS NULL OR (typeof(financialTotal)='integer' AND financialTotal>=0))
);

CREATE TABLE users (
id TEXT PRIMARY KEY NOT NULL CHECK(length(trim(id))>0),
firstName TEXT NOT NULL,lastName TEXT NOT NULL,
email TEXT NOT NULL COLLATE NOCASE UNIQUE CHECK(length(trim(email))>0),
phone TEXT,photo TEXT,city TEXT NOT NULL,
profile TEXT NOT NULL CHECK(profile IN ('citizen','veterinarian','fosterFamily','petSitter','admin')),
status TEXT NOT NULL CHECK(status IN ('pending','active','blocked')),
createdAt TEXT NOT NULL);

CREATE TABLE vaccinations (
"id" INTEGER PRIMARY KEY NOT NULL CHECK(id>0),
"animalId" INTEGER NOT NULL REFERENCES animals(id) ON DELETE RESTRICT,
"veterinarianUserId" TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
"vaccineName" TEXT NOT NULL,
"vaccinationDate" TEXT NOT NULL,
"nextDoseDate" TEXT,
"notes" TEXT,
"veterinarianName" TEXT NOT NULL
);

CREATE TABLE veterinarian_availabilities (
"id" INTEGER PRIMARY KEY NOT NULL CHECK(id>0),
"veterinarianUserId" TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
"date" TEXT NOT NULL,
"startTime" INTEGER NOT NULL,
"endTime" INTEGER NOT NULL,
"isFree" INTEGER NOT NULL CHECK("isFree" IN (0,1)),
CHECK(startTime>=0 AND startTime<endTime AND endTime<=1440)
);

CREATE TABLE veterinary_appointments (
"id" INTEGER PRIMARY KEY NOT NULL CHECK(id>0),
"veterinarianUserId" TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
"clientUserId" TEXT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
"animalId" INTEGER NOT NULL REFERENCES animals(id) ON DELETE RESTRICT,
"availabilityId" INTEGER NOT NULL,
"appointmentDate" TEXT NOT NULL,
"reason" TEXT NOT NULL,
"status" TEXT NOT NULL CHECK("status" IN ('PENDING','CONFIRMED','REJECTED','CANCELLED','COMPLETED')),
"notes" TEXT,
"clientName" TEXT NOT NULL,
"veterinarianName" TEXT NOT NULL,
"animalName" TEXT NOT NULL,
availabilityLinkId INTEGER REFERENCES veterinarian_availabilities(id) ON DELETE SET NULL,
CHECK(availabilityLinkId IS NOT NULL OR status IN ('CANCELLED','REJECTED'))
);

CREATE TABLE volunteer_tasks (
"id" INTEGER PRIMARY KEY NOT NULL CHECK(id>0),
"eventId" INTEGER NOT NULL REFERENCES events(id) ON DELETE RESTRICT,
"title" TEXT NOT NULL,
"description" TEXT NOT NULL,
"assignedUserId" TEXT REFERENCES users(id) ON DELETE RESTRICT,
"status" TEXT NOT NULL CHECK("status" IN ('AVAILABLE','ASSIGNED','IN_PROGRESS','COMPLETED'))
);

CREATE TRIGGER capacity_reduce BEFORE UPDATE OF capacity ON events WHEN NEW.capacity<(SELECT COUNT(*) FROM event_registrations r WHERE r.eventId=NEW.id AND r.status IN ('CONFIRMED','ATTENDED')) BEGIN SELECT RAISE(ABORT,'capacity below attendance'); END;

CREATE TRIGGER check_match_insert BEFORE INSERT ON matches WHEN (SELECT type FROM announcements WHERE id=NEW.lostAnnouncementId)!='LOST' OR (SELECT type FROM announcements WHERE id=NEW.foundAnnouncementId)!='FOUND' BEGIN SELECT RAISE(ABORT,'LOST/FOUND mismatch'); END;

CREATE TRIGGER check_match_update BEFORE UPDATE ON matches WHEN (SELECT type FROM announcements WHERE id=NEW.lostAnnouncementId)!='LOST' OR (SELECT type FROM announcements WHERE id=NEW.foundAnnouncementId)!='FOUND' BEGIN SELECT RAISE(ABORT,'LOST/FOUND mismatch'); END;

CREATE TRIGGER material_link_INSERT BEFORE INSERT ON material_donations WHEN NOT EXISTS(SELECT 1 FROM donations d WHERE d.id=NEW.donationId AND d.type='MATERIAL' AND (NEW.materialNeedId IS NULL OR EXISTS(SELECT 1 FROM material_needs n WHERE n.id=NEW.materialNeedId AND n.campaignId=d.campaignId AND n.itemType=NEW.itemType))) BEGIN SELECT RAISE(ABORT,'material campaign/type mismatch'); END;

CREATE TRIGGER material_link_UPDATE BEFORE UPDATE ON material_donations WHEN NOT EXISTS(SELECT 1 FROM donations d WHERE d.id=NEW.donationId AND d.type='MATERIAL' AND (NEW.materialNeedId IS NULL OR EXISTS(SELECT 1 FROM material_needs n WHERE n.id=NEW.materialNeedId AND n.campaignId=d.campaignId AND n.itemType=NEW.itemType))) BEGIN SELECT RAISE(ABORT,'material campaign/type mismatch'); END;

CREATE TRIGGER receipt_confirmed_INSERT BEFORE INSERT ON donation_receipts WHEN NOT EXISTS(SELECT 1 FROM donations d WHERE d.id=NEW.donationId AND d.status='CONFIRMED') BEGIN SELECT RAISE(ABORT,'receipt requires confirmed donation'); END;

CREATE TRIGGER receipt_confirmed_UPDATE BEFORE UPDATE ON donation_receipts WHEN NOT EXISTS(SELECT 1 FROM donations d WHERE d.id=NEW.donationId AND d.status='CONFIRMED') BEGIN SELECT RAISE(ABORT,'receipt requires confirmed donation'); END;

CREATE TRIGGER registration_capacity_INSERT BEFORE INSERT ON event_registrations WHEN NEW.status IN ('CONFIRMED','ATTENDED') AND (SELECT COUNT(*) FROM event_registrations r WHERE r.eventId=NEW.eventId AND r.id<>NEW.id AND r.status IN ('CONFIRMED','ATTENDED'))>=(SELECT capacity FROM events WHERE id=NEW.eventId) BEGIN SELECT RAISE(ABORT,'event full'); END;

CREATE TRIGGER registration_capacity_UPDATE BEFORE UPDATE ON event_registrations WHEN NEW.status IN ('CONFIRMED','ATTENDED') AND (SELECT COUNT(*) FROM event_registrations r WHERE r.eventId=NEW.eventId AND r.id<>NEW.id AND r.status IN ('CONFIRMED','ATTENDED'))>=(SELECT capacity FROM events WHERE id=NEW.eventId) BEGIN SELECT RAISE(ABORT,'event full'); END;

CREATE TRIGGER review_owner_INSERT BEFORE INSERT ON reviews WHEN NOT EXISTS(SELECT 1 FROM pet_sitting_requests r WHERE r.id=NEW.petSittingRequestId AND r.status='COMPLETED' AND r.ownerUserId=NEW.reviewerUserId) BEGIN SELECT RAISE(ABORT,'review requires completed owned request'); END;

CREATE TRIGGER review_owner_UPDATE BEFORE UPDATE ON reviews WHEN NOT EXISTS(SELECT 1 FROM pet_sitting_requests r WHERE r.id=NEW.petSittingRequestId AND r.status='COMPLETED' AND r.ownerUserId=NEW.reviewerUserId) BEGIN SELECT RAISE(ABORT,'review requires completed owned request'); END;

CREATE TRIGGER sitting_overlap_INSERT BEFORE INSERT ON pet_sitting_requests WHEN NEW.status IN ('ACCEPTED','IN_PROGRESS') AND EXISTS(SELECT 1 FROM pet_sitting_requests r WHERE r.id<>NEW.id AND r.status IN ('ACCEPTED','IN_PROGRESS') AND (r.petSitterUserId=NEW.petSitterUserId OR r.animalId=NEW.animalId) AND julianday(r.startDate)<julianday(NEW.endDate) AND julianday(NEW.startDate)<julianday(r.endDate)) BEGIN SELECT RAISE(ABORT,'sitting overlap'); END;

CREATE TRIGGER sitting_overlap_UPDATE BEFORE UPDATE ON pet_sitting_requests WHEN NEW.status IN ('ACCEPTED','IN_PROGRESS') AND EXISTS(SELECT 1 FROM pet_sitting_requests r WHERE r.id<>NEW.id AND r.status IN ('ACCEPTED','IN_PROGRESS') AND (r.petSitterUserId=NEW.petSitterUserId OR r.animalId=NEW.animalId) AND julianday(r.startDate)<julianday(NEW.endDate) AND julianday(NEW.startDate)<julianday(r.endDate)) BEGIN SELECT RAISE(ABORT,'sitting overlap'); END;

CREATE TRIGGER slots_overlap_INSERT BEFORE INSERT ON veterinarian_availabilities WHEN EXISTS(SELECT 1 FROM veterinarian_availabilities a WHERE a.id<>NEW.id AND a.veterinarianUserId=NEW.veterinarianUserId AND date(a.date)=date(NEW.date) AND a.startTime<NEW.endTime AND NEW.startTime<a.endTime) BEGIN SELECT RAISE(ABORT,'availability overlap'); END;

CREATE TRIGGER slots_overlap_UPDATE BEFORE UPDATE ON veterinarian_availabilities WHEN EXISTS(SELECT 1 FROM veterinarian_availabilities a WHERE a.id<>NEW.id AND a.veterinarianUserId=NEW.veterinarianUserId AND date(a.date)=date(NEW.date) AND a.startTime<NEW.endTime AND NEW.startTime<a.endTime) BEGIN SELECT RAISE(ABORT,'availability overlap'); END;

CREATE TRIGGER task_volunteer_INSERT BEFORE INSERT ON volunteer_tasks WHEN NEW.assignedUserId IS NOT NULL AND NOT EXISTS(SELECT 1 FROM event_registrations r WHERE r.eventId=NEW.eventId AND r.userId=NEW.assignedUserId AND r.type='VOLUNTEER' AND (r.status IN ('CONFIRMED','ATTENDED') OR NEW.status='COMPLETED')) BEGIN SELECT RAISE(ABORT,'task requires volunteer'); END;

CREATE TRIGGER task_volunteer_UPDATE BEFORE UPDATE ON volunteer_tasks WHEN NEW.assignedUserId IS NOT NULL AND NOT EXISTS(SELECT 1 FROM event_registrations r WHERE r.eventId=NEW.eventId AND r.userId=NEW.assignedUserId AND r.type='VOLUNTEER' AND (r.status IN ('CONFIRMED','ATTENDED') OR NEW.status='COMPLETED')) BEGIN SELECT RAISE(ABORT,'task requires volunteer'); END;

CREATE TRIGGER ticket_registration_INSERT BEFORE INSERT ON event_tickets WHEN NOT EXISTS(SELECT 1 FROM event_registrations r WHERE r.id=NEW.registrationId AND (r.status='CONFIRMED' OR (r.status='ATTENDED' AND NEW.used=1) OR r.status='CANCELLED')) BEGIN SELECT RAISE(ABORT,'ticket registration invalid'); END;

CREATE TRIGGER ticket_registration_UPDATE BEFORE UPDATE ON event_tickets WHEN NOT EXISTS(SELECT 1 FROM event_registrations r WHERE r.id=NEW.registrationId AND (r.status='CONFIRMED' OR (r.status='ATTENDED' AND NEW.used=1) OR r.status='CANCELLED')) BEGIN SELECT RAISE(ABORT,'ticket registration invalid'); END;

CREATE TRIGGER totals_donations_DELETE AFTER DELETE ON donations BEGIN UPDATE donation_campaigns SET collectedAmount=COALESCE((SELECT SUM(amount) FROM donations WHERE campaignId=donation_campaigns.id AND type='FINANCIAL' AND status='CONFIRMED'),0); UPDATE material_needs SET receivedQuantity=COALESCE((SELECT SUM(m.quantity) FROM material_donations m JOIN donations d ON d.id=m.donationId WHERE m.materialNeedId=material_needs.id AND m.status='RECEIVED' AND d.status='CONFIRMED'),0); UPDATE material_needs SET status=CASE WHEN receivedQuantity=0 THEN 'OPEN' WHEN receivedQuantity>=requestedQuantity THEN 'FULFILLED' ELSE 'PARTIALLY_FULFILLED' END; END;

CREATE TRIGGER totals_donations_INSERT AFTER INSERT ON donations BEGIN UPDATE donation_campaigns SET collectedAmount=COALESCE((SELECT SUM(amount) FROM donations WHERE campaignId=donation_campaigns.id AND type='FINANCIAL' AND status='CONFIRMED'),0); UPDATE material_needs SET receivedQuantity=COALESCE((SELECT SUM(m.quantity) FROM material_donations m JOIN donations d ON d.id=m.donationId WHERE m.materialNeedId=material_needs.id AND m.status='RECEIVED' AND d.status='CONFIRMED'),0); UPDATE material_needs SET status=CASE WHEN receivedQuantity=0 THEN 'OPEN' WHEN receivedQuantity>=requestedQuantity THEN 'FULFILLED' ELSE 'PARTIALLY_FULFILLED' END; END;

CREATE TRIGGER totals_donations_UPDATE AFTER UPDATE ON donations BEGIN UPDATE donation_campaigns SET collectedAmount=COALESCE((SELECT SUM(amount) FROM donations WHERE campaignId=donation_campaigns.id AND type='FINANCIAL' AND status='CONFIRMED'),0); UPDATE material_needs SET receivedQuantity=COALESCE((SELECT SUM(m.quantity) FROM material_donations m JOIN donations d ON d.id=m.donationId WHERE m.materialNeedId=material_needs.id AND m.status='RECEIVED' AND d.status='CONFIRMED'),0); UPDATE material_needs SET status=CASE WHEN receivedQuantity=0 THEN 'OPEN' WHEN receivedQuantity>=requestedQuantity THEN 'FULFILLED' ELSE 'PARTIALLY_FULFILLED' END; END;

CREATE TRIGGER totals_material_donations_DELETE AFTER DELETE ON material_donations BEGIN UPDATE donation_campaigns SET collectedAmount=COALESCE((SELECT SUM(amount) FROM donations WHERE campaignId=donation_campaigns.id AND type='FINANCIAL' AND status='CONFIRMED'),0); UPDATE material_needs SET receivedQuantity=COALESCE((SELECT SUM(m.quantity) FROM material_donations m JOIN donations d ON d.id=m.donationId WHERE m.materialNeedId=material_needs.id AND m.status='RECEIVED' AND d.status='CONFIRMED'),0); UPDATE material_needs SET status=CASE WHEN receivedQuantity=0 THEN 'OPEN' WHEN receivedQuantity>=requestedQuantity THEN 'FULFILLED' ELSE 'PARTIALLY_FULFILLED' END; END;

CREATE TRIGGER totals_material_donations_INSERT AFTER INSERT ON material_donations BEGIN UPDATE donation_campaigns SET collectedAmount=COALESCE((SELECT SUM(amount) FROM donations WHERE campaignId=donation_campaigns.id AND type='FINANCIAL' AND status='CONFIRMED'),0); UPDATE material_needs SET receivedQuantity=COALESCE((SELECT SUM(m.quantity) FROM material_donations m JOIN donations d ON d.id=m.donationId WHERE m.materialNeedId=material_needs.id AND m.status='RECEIVED' AND d.status='CONFIRMED'),0); UPDATE material_needs SET status=CASE WHEN receivedQuantity=0 THEN 'OPEN' WHEN receivedQuantity>=requestedQuantity THEN 'FULFILLED' ELSE 'PARTIALLY_FULFILLED' END; END;

CREATE TRIGGER totals_material_donations_UPDATE AFTER UPDATE ON material_donations BEGIN UPDATE donation_campaigns SET collectedAmount=COALESCE((SELECT SUM(amount) FROM donations WHERE campaignId=donation_campaigns.id AND type='FINANCIAL' AND status='CONFIRMED'),0); UPDATE material_needs SET receivedQuantity=COALESCE((SELECT SUM(m.quantity) FROM material_donations m JOIN donations d ON d.id=m.donationId WHERE m.materialNeedId=material_needs.id AND m.status='RECEIVED' AND d.status='CONFIRMED'),0); UPDATE material_needs SET status=CASE WHEN receivedQuantity=0 THEN 'OPEN' WHEN receivedQuantity>=requestedQuantity THEN 'FULFILLED' ELSE 'PARTIALLY_FULFILLED' END; END;
