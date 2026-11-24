// ignore_for_file: constant_identifier_names
enum AnnouncementType { LOST, FOUND }

extension AnnouncementTypeLabel on AnnouncementType {
  String get label => switch (this) {
    AnnouncementType.LOST => 'Perdu',
    AnnouncementType.FOUND => 'Trouvé',
  };
}
