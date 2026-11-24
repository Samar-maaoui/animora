import '../../../core/enums/account_status.dart';
import '../../../core/enums/user_profile.dart';

/// Central place for registration and access rules.
abstract final class AccountPolicy {
  static const publicProfiles = [
    UserProfile.citizen,
    UserProfile.veterinarian,
    UserProfile.fosterFamily,
    UserProfile.petSitter,
  ];
  static AccountStatus initialStatus(UserProfile profile) => switch (profile) {
    UserProfile.citizen || UserProfile.admin => AccountStatus.active,
    _ => AccountStatus.pending,
  };
  static bool canTransition(AccountStatus from, AccountStatus to) =>
      (from == AccountStatus.pending && to == AccountStatus.active) ||
      (from == AccountStatus.active && to == AccountStatus.blocked) ||
      (from == AccountStatus.blocked && to == AccountStatus.active);
}
