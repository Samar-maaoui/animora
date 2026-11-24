import '../../../core/enums/account_status.dart';
import '../../../core/enums/user_profile.dart';
import '../../users/models/user.dart';

/// Development fixtures ONLY. No demo account is created by public registration.
abstract final class DemoAccounts {
  static const password = 'Animora2026!';
  static final users = [
    _user('citizen', 'Amine', 'Ben Ali', UserProfile.citizen),
    _user('veterinarian', 'Sarra', 'Mansour', UserProfile.veterinarian),
    _user('pet-sitter', 'Yasmine', 'Trabelsi', UserProfile.petSitter),
    _user('foster', 'Karim', 'Saidi', UserProfile.fosterFamily),
    _user(
      'pending',
      'Nour',
      'Haddad',
      UserProfile.veterinarian,
      AccountStatus.pending,
    ),
    _user('admin', 'Salma', 'Admin', UserProfile.admin),
    _user(
      'blocked',
      'Sami',
      'Demo',
      UserProfile.citizen,
      AccountStatus.blocked,
    ),
  ];
  static User _user(
    String id,
    String firstName,
    String lastName,
    UserProfile profile, [
    AccountStatus status = AccountStatus.active,
  ]) => User(
    id: 'demo-$id',
    firstName: firstName,
    lastName: lastName,
    email: '$id@animora.test',
    phone: '+216 20 123 456',
    city: 'Tunis',
    profile: profile,
    status: status,
    createdAt: DateTime.utc(2026, 1, 15),
  );
}
