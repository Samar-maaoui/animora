class ZoneRecherche {
  const ZoneRecherche({
    required this.id,
    required this.announcementId,
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.createdAt,
  });
  final int id;
  final int announcementId;
  final double latitude;
  final double longitude;
  final double radius;
  final DateTime createdAt;
  ZoneRecherche copyWith({
    int? id,
    int? announcementId,
    double? latitude,
    double? longitude,
    double? radius,
    DateTime? createdAt,
  }) => ZoneRecherche(
    id: id ?? this.id,
    announcementId: announcementId ?? this.announcementId,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    radius: radius ?? this.radius,
    createdAt: createdAt ?? this.createdAt,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'announcementId': announcementId,
    'latitude': latitude,
    'longitude': longitude,
    'radius': radius,
    'createdAt': createdAt.toIso8601String(),
  };
  factory ZoneRecherche.fromJson(Map<String, dynamic> j) => ZoneRecherche(
    id: j['id'] as int,
    announcementId: j['announcementId'] as int,
    latitude: (j['latitude'] as num).toDouble(),
    longitude: (j['longitude'] as num).toDouble(),
    radius: (j['radius'] as num).toDouble(),
    createdAt: DateTime.parse(j['createdAt'] as String),
  );
}
