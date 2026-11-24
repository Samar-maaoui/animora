import '../../../core/enums/report_type.dart';
import '../../../core/enums/report_status.dart';

const _unset = Object();

class Signalement {
  const Signalement({
    required this.id,
    required this.userId,
    required this.type,
    required this.description,
    this.photo,
    this.latitude,
    this.longitude,
    required this.urgencyLevel,
    required this.status,
    required this.createdAt,
  });
  final int id;
  final String userId;
  final ReportType type;
  final String description;
  final String? photo;
  final double? latitude;
  final double? longitude;
  final int urgencyLevel;
  final ReportStatus status;
  final DateTime createdAt;
  Signalement copyWith({
    int? id,
    String? userId,
    ReportType? type,
    String? description,
    Object? photo = _unset,
    Object? latitude = _unset,
    Object? longitude = _unset,
    int? urgencyLevel,
    ReportStatus? status,
    DateTime? createdAt,
  }) => Signalement(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    type: type ?? this.type,
    description: description ?? this.description,
    photo: photo == _unset ? this.photo : photo as String?,
    latitude: latitude == _unset
        ? this.latitude
        : (latitude as num?)?.toDouble(),
    longitude: longitude == _unset
        ? this.longitude
        : (longitude as num?)?.toDouble(),
    urgencyLevel: urgencyLevel ?? this.urgencyLevel,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'type': type.name,
    'description': description,
    'photo': photo,
    'latitude': latitude,
    'longitude': longitude,
    'urgencyLevel': urgencyLevel,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
  };
  factory Signalement.fromJson(Map<String, dynamic> j) => Signalement(
    id: j['id'] as int,
    userId: j['userId'] as String,
    type: ReportType.values.byName(j['type'] as String),
    description: j['description'] as String,
    photo: j['photo'] == null ? null : j['photo'] as String,
    latitude: j['latitude'] == null ? null : (j['latitude'] as num).toDouble(),
    longitude: j['longitude'] == null
        ? null
        : (j['longitude'] as num).toDouble(),
    urgencyLevel: j['urgencyLevel'] as int,
    status: ReportStatus.values.byName(j['status'] as String),
    createdAt: DateTime.parse(j['createdAt'] as String),
  );
}
