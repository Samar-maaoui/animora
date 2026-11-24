const _unset = Object();

class PetSittingUpdate {
  const PetSittingUpdate({
    required this.id,
    required this.petSittingRequestId,
    required this.message,
    this.photo,
    required this.createdAt,
  });
  final int id;
  final int petSittingRequestId;
  final String message;
  final String? photo;
  final DateTime createdAt;
  PetSittingUpdate copyWith({
    int? id,
    int? petSittingRequestId,
    String? message,
    Object? photo = _unset,
    DateTime? createdAt,
  }) => PetSittingUpdate(
    id: id ?? this.id,
    petSittingRequestId: petSittingRequestId ?? this.petSittingRequestId,
    message: message ?? this.message,
    photo: photo == _unset ? this.photo : photo as String?,
    createdAt: createdAt ?? this.createdAt,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'petSittingRequestId': petSittingRequestId,
    'message': message,
    'photo': photo,
    'createdAt': createdAt.toIso8601String(),
  };
  factory PetSittingUpdate.fromJson(Map<String, dynamic> j) => PetSittingUpdate(
    id: j['id'] as int,
    petSittingRequestId: j['petSittingRequestId'] as int,
    message: j['message'] as String,
    photo: j['photo'] == null ? null : j['photo'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
  );
}
