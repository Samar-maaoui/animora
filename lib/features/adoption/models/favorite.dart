class Favorite {
  const Favorite({
    required this.userId,
    required this.animalId,
    required this.addedAt,
  });
  final String userId;
  final int animalId;
  final DateTime addedAt;
  Map<String, dynamic> toJson() => {
    'userId': userId,
    'animalId': animalId,
    'addedAt': addedAt.toIso8601String(),
  };
  factory Favorite.fromJson(Map<String, dynamic> json) => Favorite(
    userId: json['userId'] as String,
    animalId: json['animalId'] as int,
    addedAt: DateTime.parse(json['addedAt'] as String),
  );
}
