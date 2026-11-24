import '../../../core/enums/event_type.dart';
import '../../../core/enums/event_status.dart';

const _unset = Object();

class Event {
  const Event({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.location,
    required this.city,
    this.latitude,
    this.longitude,
    required this.startDate,
    required this.endDate,
    required this.capacity,
    required this.status,
    this.image,
    required this.organizerUserId,
  });
  final int id;
  final String title;
  final String description;
  final EventType type;
  final String location;
  final String city;
  final double? latitude;
  final double? longitude;
  final DateTime startDate;
  final DateTime endDate;
  final int capacity;
  final EventStatus status;
  final String? image;
  final String organizerUserId;
  Event copyWith({
    int? id,
    String? title,
    String? description,
    EventType? type,
    String? location,
    String? city,
    Object? latitude = _unset,
    Object? longitude = _unset,
    DateTime? startDate,
    DateTime? endDate,
    int? capacity,
    EventStatus? status,
    Object? image = _unset,
    String? organizerUserId,
  }) => Event(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    type: type ?? this.type,
    location: location ?? this.location,
    city: city ?? this.city,
    latitude: latitude == _unset
        ? this.latitude
        : (latitude as num?)?.toDouble(),
    longitude: longitude == _unset
        ? this.longitude
        : (longitude as num?)?.toDouble(),
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    capacity: capacity ?? this.capacity,
    status: status ?? this.status,
    image: image == _unset ? this.image : image as String?,
    organizerUserId: organizerUserId ?? this.organizerUserId,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'type': type.name,
    'location': location,
    'city': city,
    'latitude': latitude,
    'longitude': longitude,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'capacity': capacity,
    'status': status.name,
    'image': image,
    'organizerUserId': organizerUserId,
  };
  factory Event.fromJson(Map<String, dynamic> j) => Event(
    id: j['id'] as int,
    title: j['title'] as String,
    description: j['description'] as String,
    type: EventType.values.byName(j['type'] as String),
    location: j['location'] as String,
    city: j['city'] as String,
    latitude: (j['latitude'] as num?)?.toDouble(),
    longitude: (j['longitude'] as num?)?.toDouble(),
    startDate: DateTime.parse(j['startDate'] as String),
    endDate: DateTime.parse(j['endDate'] as String),
    capacity: j['capacity'] as int,
    status: EventStatus.values.byName(j['status'] as String),
    image: j['image'] as String?,
    organizerUserId: j['organizerUserId'] as String,
  );
}
