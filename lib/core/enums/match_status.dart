// ignore_for_file: constant_identifier_names
enum MatchStatus { DETECTED, CONFIRMED, REJECTED }

extension MatchStatusLabel on MatchStatus {
  String get label => switch (this) {
    MatchStatus.DETECTED => 'Détectée',
    MatchStatus.CONFIRMED => 'Confirmée',
    MatchStatus.REJECTED => 'Rejetée',
  };
}
