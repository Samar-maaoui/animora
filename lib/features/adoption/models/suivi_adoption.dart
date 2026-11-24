class SuiviAdoption {
  const SuiviAdoption({
    required this.id,
    required this.adoptionId,
    required this.date,
    required this.news,
    this.photo,
    required this.visitType,
  });
  final int id, adoptionId;
  final DateTime date;
  final String news, visitType;
  final String? photo;
  Map<String, dynamic> toJson() => {
    'id': id,
    'adoptionId': adoptionId,
    'date': date.toIso8601String(),
    'news': news,
    'photo': photo,
    'visitType': visitType,
  };
  factory SuiviAdoption.fromJson(Map<String, dynamic> j) => SuiviAdoption(
    id: j['id'] as int,
    adoptionId: j['adoptionId'] as int,
    date: DateTime.parse(j['date'] as String),
    news: j['news'] as String,
    photo: j['photo'] as String?,
    visitType: j['visitType'] as String,
  );
}
