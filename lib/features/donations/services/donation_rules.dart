class DonationFailure implements Exception {
  const DonationFailure(this.message);
  final String message;
}

String donationError(Object e) => e is DonationFailure
    ? e.message
    : 'Impossible de terminer cette opération locale. Réessayez sans effacer vos données.';
const donationNotice = 'Démonstration — aucun paiement réel n’est effectué';
const receiptNotice = 'Reçu de démonstration — aucun paiement réel effectué';

abstract final class DonationMoney {
  static int mills(double amount) {
    if (!amount.isFinite || amount <= 0 || amount > 1000000000) {
      throw const DonationFailure(
        'Indiquez un montant strictement positif, limité à 1 milliard TND.',
      );
    }
    final scaled = amount * 1000, rounded = scaled.round();
    if (rounded < 1) {
      throw const DonationFailure('Le montant minimum est de 0,001 TND.');
    }
    if ((scaled - rounded).abs() > 0.0001) {
      throw const DonationFailure(
        'Utilisez au maximum trois décimales (millimes).',
      );
    }
    return rounded;
  }

  static String format(double amount) =>
      '${amount.toStringAsFixed(3).replaceAll('.', ',')} TND';
}

String donationReference(int id) => 'DEMO-DON-${id.toString().padLeft(6, '0')}';
