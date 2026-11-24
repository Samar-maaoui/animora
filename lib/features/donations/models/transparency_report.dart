const _unset = Object();

class TransparencyReport {
  const TransparencyReport({
    required this.id,
    required this.campaignId,
    required this.description,
    required this.content,
    required this.createdAt,
    this.documentPath,
    required this.financialTotal,
    required this.receivedMaterialCount,
    required this.receivedMaterialSummary,
  });
  final int id;
  final int campaignId;
  final String description;
  final String content;
  final DateTime createdAt;
  final String? documentPath;
  final double financialTotal;
  final int receivedMaterialCount;
  final String receivedMaterialSummary;
  TransparencyReport copyWith({
    int? id,
    int? campaignId,
    String? description,
    String? content,
    DateTime? createdAt,
    Object? documentPath = _unset,
    double? financialTotal,
    int? receivedMaterialCount,
    String? receivedMaterialSummary,
  }) => TransparencyReport(
    id: id ?? this.id,
    campaignId: campaignId ?? this.campaignId,
    description: description ?? this.description,
    content: content ?? this.content,
    createdAt: createdAt ?? this.createdAt,
    documentPath: documentPath == _unset
        ? this.documentPath
        : documentPath as String?,
    financialTotal: financialTotal ?? this.financialTotal,
    receivedMaterialCount: receivedMaterialCount ?? this.receivedMaterialCount,
    receivedMaterialSummary:
        receivedMaterialSummary ?? this.receivedMaterialSummary,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'campaignId': campaignId,
    'description': description,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
    'documentPath': documentPath,
    'financialTotal': financialTotal,
    'receivedMaterialCount': receivedMaterialCount,
    'receivedMaterialSummary': receivedMaterialSummary,
  };
  factory TransparencyReport.fromJson(Map<String, dynamic> j) =>
      TransparencyReport(
        id: j['id'] as int,
        campaignId: j['campaignId'] as int,
        description: j['description'] as String,
        content: j['content'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        documentPath: j['documentPath'] == null
            ? null
            : j['documentPath'] as String,
        financialTotal: (j['financialTotal'] as num).toDouble(),
        receivedMaterialCount: j['receivedMaterialCount'] as int,
        receivedMaterialSummary: j['receivedMaterialSummary'] as String,
      );
}
