class ContratAdoption {
  const ContratAdoption({
    required this.id,
    required this.adoptionId,
    this.signatureDate,
    required this.conditions,
    required this.signed,
  });
  final int id, adoptionId;
  final DateTime? signatureDate;
  final String conditions;
  final bool signed;
  ContratAdoption sign(DateTime date) => ContratAdoption(
    id: id,
    adoptionId: adoptionId,
    signatureDate: date,
    conditions: conditions,
    signed: true,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'adoptionId': adoptionId,
    'signatureDate': signatureDate?.toIso8601String(),
    'conditions': conditions,
    'signed': signed,
  };
  factory ContratAdoption.fromJson(Map<String, dynamic> j) => ContratAdoption(
    id: j['id'] as int,
    adoptionId: j['adoptionId'] as int,
    signatureDate: j['signatureDate'] == null
        ? null
        : DateTime.parse(j['signatureDate'] as String),
    conditions: j['conditions'] as String,
    signed: j['signed'] as bool,
  );
}
