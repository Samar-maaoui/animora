import '../../../core/enums/user_profile.dart';

class RegisterRequest {
  const RegisterRequest({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.city,
    required this.password,
    required this.profile,
    this.professionalCardNumber,
  });
  final String firstName, lastName, email, phone, city, password;
  final UserProfile profile;

  /// Veterinarians only: number read (OCR) or typed from the professional card.
  final String? professionalCardNumber;
}

/// Why a one-time e-mail code was issued.
enum EmailCodePurpose { verifyEmail, resetPassword }

/// One-time 6-digit code sent by e-mail, created by the repository.
class EmailCodeTicket {
  const EmailCodeTicket({
    required this.email,
    required this.firstName,
    required this.code,
    required this.expiresAt,
    this.purpose = EmailCodePurpose.resetPassword,
  });
  final String email, firstName, code;
  final DateTime expiresAt;
  final EmailCodePurpose purpose;
}

typedef PasswordResetTicket = EmailCodeTicket;

class ProfileUpdate {
  const ProfileUpdate({
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.city,
  });
  final String firstName, lastName, phone, city;
}

enum AuthFailureCode {
  invalidCredentials,
  duplicateEmail,
  invalidInput,
  forbidden,
  storage,
  cryptographyUnavailable,
  hashing,
  serialization,
  unknown,
  locked,
  busy,
}

class AuthFailure implements Exception {
  const AuthFailure(this.code, this.message, {this.field, this.diagnostic});
  final AuthFailureCode code;
  final String message;
  final String? field;
  final String? diagnostic;
  @override
  String toString() => message;
}
