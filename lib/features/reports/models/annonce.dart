import '../../../core/enums/announcement_type.dart';
import '../../../core/enums/announcement_status.dart';

const _unset = Object();

class Annonce {
  const Annonce({
    required this.id,
    required this.userId,
    required this.type,
    required this.species,
    this.breed,
    required this.color,
    required this.description,
    this.distinguishingSigns,
    this.photo,
    this.latitude,
    this.longitude,
    required this.date,
    required this.status,
    this.hidden = false,
  });
  final int id;
  final String userId;
  final AnnouncementType type;
  final String species;
  final String? breed;
  final String color;
  final String description;
  final String? distinguishingSigns;
  final String? photo;
  final double? latitude;
  final double? longitude;
  final DateTime date;
  final AnnouncementStatus status;
  final bool hidden;
  Annonce copyWith({
    int? id,
    String? userId,
    AnnouncementType? type,
    String? species,
    Object? breed = _unset,
    String? color,
    String? description,
    Object? distinguishingSigns = _unset,
    Object? photo = _unset,
    Object? latitude = _unset,
    Object? longitude = _unset,
    DateTime? date,
    AnnouncementStatus? status,
    bool? hidden,
  }) => Annonce(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    type: type ?? this.type,
    species: species ?? this.species,
    breed: breed == _unset ? this.breed : breed as String?,
    color: color ?? this.color,
    description: description ?? this.description,
    distinguishingSigns: distinguishingSigns == _unset
        ? this.distinguishingSigns
        : distinguishingSigns as String?,
    photo: photo == _unset ? this.photo : photo as String?,
    latitude: latitude == _unset
        ? this.latitude
        : (latitude as num?)?.toDouble(),
    longitude: longitude == _unset
        ? this.longitude
        : (longitude as num?)?.toDouble(),
    date: date ?? this.date,
    status: status ?? this.status,
    hidden: hidden ?? this.hidden,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'type': type.name,
    'species': species,
    'breed': breed,
    'color': color,
    'description': description,
    'distinguishingSigns': distinguishingSigns,
    'photo': photo,
    'latitude': latitude,
    'longitude': longitude,
    'date': date.toIso8601String(),
    'status': status.name,
    'hidden': hidden,
  };
  factory Annonce.fromJson(Map<String, dynamic> j) => Annonce(
    id: j['id'] as int,
    userId: j['userId'] as String,
    type: AnnouncementType.values.byName(j['type'] as String),
    species: j['species'] as String,
    breed: j['breed'] == null ? null : j['breed'] as String,
    color: j['color'] as String,
    description: j['description'] as String,
    distinguishingSigns: j['distinguishingSigns'] == null
        ? null
        : j['distinguishingSigns'] as String,
    photo: j['photo'] == null ? null : j['photo'] as String,
    latitude: j['latitude'] == null ? null : (j['latitude'] as num).toDouble(),
    longitude: j['longitude'] == null
        ? null
        : (j['longitude'] as num).toDouble(),
    date: DateTime.parse(j['date'] as String),
    status: AnnouncementStatus.values.byName(j['status'] as String),
    hidden: j['hidden'] as bool? ?? false,
  );
}
