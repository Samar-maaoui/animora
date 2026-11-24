const _unset = Object();

class HistoireRetrouvailles {
  const HistoireRetrouvailles({
    required this.id,
    required this.announcementId,
    required this.title,
    this.photo,
    required this.publicationDate,
    required this.authorUserId,
  });
  final int id;
  final int announcementId;
  final String title;
  final String? photo;
  final DateTime publicationDate;
  final String authorUserId;
  HistoireRetrouvailles copyWith({
    int? id,
    int? announcementId,
    String? title,
    Object? photo = _unset,
    DateTime? publicationDate,
    String? authorUserId,
  }) => HistoireRetrouvailles(
    id: id ?? this.id,
    announcementId: announcementId ?? this.announcementId,
    title: title ?? this.title,
    photo: photo == _unset ? this.photo : photo as String?,
    publicationDate: publicationDate ?? this.publicationDate,
    authorUserId: authorUserId ?? this.authorUserId,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'announcementId': announcementId,
    'title': title,
    'photo': photo,
    'publicationDate': publicationDate.toIso8601String(),
    'authorUserId': authorUserId,
  };
  factory HistoireRetrouvailles.fromJson(Map<String, dynamic> j) =>
      HistoireRetrouvailles(
        id: j['id'] as int,
        announcementId: j['announcementId'] as int,
        title: j['title'] as String,
        photo: j['photo'] == null ? null : j['photo'] as String,
        publicationDate: DateTime.parse(j['publicationDate'] as String),
        authorUserId: j['authorUserId'] as String,
      );
}
