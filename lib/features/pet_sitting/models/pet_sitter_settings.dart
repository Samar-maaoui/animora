class PetSitterSettings {
  const PetSitterSettings({
    required this.userId,
    required this.available,
    required this.dailyRate,
    required this.availableFrom,
    required this.availableUntil,
  });
  final String userId;
  final bool available;
  final double dailyRate;
  final DateTime availableFrom;
  final DateTime availableUntil;
  PetSitterSettings copyWith({
    String? userId,
    bool? available,
    double? dailyRate,
    DateTime? availableFrom,
    DateTime? availableUntil,
  }) => PetSitterSettings(
    userId: userId ?? this.userId,
    available: available ?? this.available,
    dailyRate: dailyRate ?? this.dailyRate,
    availableFrom: availableFrom ?? this.availableFrom,
    availableUntil: availableUntil ?? this.availableUntil,
  );
  Map<String, dynamic> toJson() => {
    'userId': userId,
    'available': available,
    'dailyRate': dailyRate,
    'availableFrom': availableFrom.toIso8601String(),
    'availableUntil': availableUntil.toIso8601String(),
  };
  factory PetSitterSettings.fromJson(Map<String, dynamic> j) =>
      PetSitterSettings(
        userId: j['userId'] as String,
        available: j['available'] as bool,
        dailyRate: (j['dailyRate'] as num).toDouble(),
        availableFrom: DateTime.parse(j['availableFrom'] as String),
        availableUntil: DateTime.parse(j['availableUntil'] as String),
      );
}
