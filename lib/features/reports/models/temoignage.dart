const _unset = Object();

class Temoignage {
  const Temoignage({
    required this.id,
    required this.announcementId,
    required this.userId,
    this.latitude,
    this.longitude,
    required this.date,
    this.photo,
    required this.comment,
  });
  final int id;
  final int announcementId;
  final String userId;
  final double? latitude;
  final double? longitude;
  final DateTime date;
  final String? photo;
  final String comment;
  Temoignage copyWith({
    int? id,
    int? announcementId,
    String? userId,
    Object? latitude = _unset,
    Object? longitude = _unset,
    DateTime? date,
    Object? photo = _unset,
    String? comment,
  }) => Temoignage(
    id: id ?? this.id,
    announcementId: announcementId ?? this.announcementId,
    userId: userId ?? this.userId,
    latitude: latitude == _unset
        ? this.latitude
        : (latitude as num?)?.toDouble(),
    longitude: longitude == _unset
        ? this.longitude
        : (longitude as num?)?.toDouble(),
    date: date ?? this.date,
    photo: photo == _unset ? this.photo : photo as String?,
    comment: comment ?? this.comment,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'announcementId': announcementId,
    'userId': userId,
    'latitude': latitude,
    'longitude': longitude,
    'date': date.toIso8601String(),
    'photo': photo,
    'comment': comment,
  };
  factory Temoignage.fromJson(Map<String, dynamic> j) => Temoignage(
    id: j['id'] as int,
    announcementId: j['announcementId'] as int,
    userId: j['userId'] as String,
    latitude: j['latitude'] == null ? null : (j['latitude'] as num).toDouble(),
    longitude: j['longitude'] == null
        ? null
        : (j['longitude'] as num).toDouble(),
    date: DateTime.parse(j['date'] as String),
    photo: j['photo'] == null ? null : j['photo'] as String,
    comment: j['comment'] as String,
  );
}
