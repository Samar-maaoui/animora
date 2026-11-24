// ignore_for_file: constant_identifier_names
enum HebergementStatus { ACTIVE, COMPLETED, CANCELLED }

extension HebergementStatusLabel on HebergementStatus {
  String get label => switch (this) {
    HebergementStatus.ACTIVE => 'En cours',
    HebergementStatus.COMPLETED => 'Terminé',
    HebergementStatus.CANCELLED => 'Annulé',
  };
}
