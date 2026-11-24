// ignore_for_file: constant_identifier_names
enum AnnouncementStatus { ACTIVE, CLOSED }

extension AnnouncementStatusLabel on AnnouncementStatus {
  String get label => switch (this) {
    AnnouncementStatus.ACTIVE => 'Active',
    AnnouncementStatus.CLOSED => 'Clôturée',
  };
}
