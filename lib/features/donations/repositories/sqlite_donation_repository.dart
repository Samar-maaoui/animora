import 'local_donation_repository.dart';

/// Keeps existing access checks and business rules, backed by relational storage.
class SqliteDonationRepository extends LocalDonationRepository {
  SqliteDonationRepository(super.database, super.currentUser, {super.clock});
}
