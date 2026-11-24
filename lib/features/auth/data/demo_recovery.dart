import 'package:flutter/foundation.dart';

import '../../../core/enums/account_status.dart';
import '../../../core/enums/user_profile.dart';
import '../../users/models/user.dart';
import 'demo_accounts.dart';

/// Explicit opt-in only. Release AND profile builds always reject recovery.
abstract final class DemoRecovery {
  static const enabled =
      kDebugMode &&
      bool.fromEnvironment('ANIMORA_DEMO_SEED', defaultValue: false);
  static bool permitted({required bool requested, required bool debugBuild}) =>
      requested && debugBuild;

  // Mohamed's role/status were explicitly confirmed by the user. Other fields
  // below are labelled demo placeholders, not recovered personal information.
  static final users = <User>[
    ...DemoAccounts.users,
    User(
      id: 'demo-mohamed',
      firstName: 'Mohamed',
      lastName: 'Démo',
      email: 'mohamed@animora.test',
      city: 'Non renseignée',
      profile: UserProfile.citizen,
      status: AccountStatus.active,
      createdAt: DateTime.utc(2026, 11, 10),
    ),
  ];
}

class DemoRecoveryResult {
  const DemoRecoveryResult({
    this.created = const [],
    this.preserved = const [],
    this.conflicts = const [],
    this.passwordMismatches = const [],
  });
  final List<String> created, preserved, conflicts, passwordMismatches;
}
