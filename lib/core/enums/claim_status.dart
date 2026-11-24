// ignore_for_file: constant_identifier_names
enum ClaimStatus { PENDING, VERIFIED, REJECTED }

extension ClaimStatusLabel on ClaimStatus {
  String get label => switch (this) {
    ClaimStatus.PENDING => 'En attente',
    ClaimStatus.VERIFIED => 'Vérifiée',
    ClaimStatus.REJECTED => 'Rejetée',
  };
}
