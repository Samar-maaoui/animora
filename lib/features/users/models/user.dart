import '../../../core/enums/user_profile.dart';
import '../../../core/enums/account_status.dart';

/// Shared, immutable account model. Never contains credentials.
class User {
  const User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.phone,
    this.photo,
    required this.city,
    required this.profile,
    required this.status,
    required this.createdAt,
    this.professionalCardNumber,
  });
  final String id, firstName, lastName, email, city;
  final String? phone, photo;

  /// Veterinarians: professional card number, checked by the admin.
  final String? professionalCardNumber;
  final UserProfile profile;
  final AccountStatus status;
  final DateTime createdAt;
  String get fullName => '$firstName $lastName';

  User copyWith({
    String? firstName,
    String? lastName,
    String? phone,
    String? city,
    AccountStatus? status,
  }) => User(
    id: id,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    email: email,
    phone: phone ?? this.phone,
    photo: photo,
    city: city ?? this.city,
    profile: profile,
    status: status ?? this.status,
    createdAt: createdAt,
    professionalCardNumber: professionalCardNumber,
  );

  /// Separate from [copyWith] because a photo can be removed (null).
  User withPhoto(String? photo) => User(
    id: id,
    firstName: firstName,
    lastName: lastName,
    email: email,
    phone: phone,
    photo: photo,
    city: city,
    profile: profile,
    status: status,
    createdAt: createdAt,
    professionalCardNumber: professionalCardNumber,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'firstName': firstName,
    'lastName': lastName,
    'email': email,
    'phone': phone,
    'photo': photo,
    'city': city,
    'profile': profile.name,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    // Omitted when absent: keeps older stored documents byte-identical.
    if (professionalCardNumber != null)
      'professionalCardNumber': professionalCardNumber,
  };
  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] as String,
    firstName: json['firstName'] as String,
    lastName: json['lastName'] as String,
    email: json['email'] as String,
    phone: json['phone'] as String?,
    photo: json['photo'] as String?,
    city: json['city'] as String,
    profile: UserProfile.values.byName(json['profile'] as String),
    status: AccountStatus.values.byName(json['status'] as String),
    createdAt: DateTime.parse(json['createdAt'] as String),
    professionalCardNumber: json['professionalCardNumber'] as String?,
  );
}
