const _unset = Object();

class Care {
  const Care({
    required this.id,
    required this.animalId,
    required this.veterinarianUserId,
    required this.type,
    required this.date,
    required this.description,
    this.cost,
    required this.veterinarianName,
  });
  final int id;
  final int animalId;
  final String veterinarianUserId;
  final String type;
  final DateTime date;
  final String description;
  final double? cost;
  final String veterinarianName;
  Care copyWith({
    int? id,
    int? animalId,
    String? veterinarianUserId,
    String? type,
    DateTime? date,
    String? description,
    Object? cost = _unset,
    String? veterinarianName,
  }) => Care(
    id: id ?? this.id,
    animalId: animalId ?? this.animalId,
    veterinarianUserId: veterinarianUserId ?? this.veterinarianUserId,
    type: type ?? this.type,
    date: date ?? this.date,
    description: description ?? this.description,
    cost: cost == _unset ? this.cost : (cost as num?)?.toDouble(),
    veterinarianName: veterinarianName ?? this.veterinarianName,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'animalId': animalId,
    'veterinarianUserId': veterinarianUserId,
    'type': type,
    'date': date.toIso8601String(),
    'description': description,
    'cost': cost,
    'veterinarianName': veterinarianName,
  };
  factory Care.fromJson(Map<String, dynamic> j) => Care(
    id: j['id'] as int,
    animalId: j['animalId'] as int,
    veterinarianUserId: j['veterinarianUserId'] as String,
    type: j['type'] as String,
    date: DateTime.parse(j['date'] as String),
    description: j['description'] as String,
    cost: j['cost'] == null ? null : (j['cost'] as num).toDouble(),
    veterinarianName: j['veterinarianName'] as String,
  );
}
