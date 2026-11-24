class Review {
  const Review({
    required this.id,
    required this.petSittingRequestId,
    required this.reviewerUserId,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });
  final int id;
  final int petSittingRequestId;
  final String reviewerUserId;
  final int rating;
  final String comment;
  final DateTime createdAt;
  Review copyWith({
    int? id,
    int? petSittingRequestId,
    String? reviewerUserId,
    int? rating,
    String? comment,
    DateTime? createdAt,
  }) => Review(
    id: id ?? this.id,
    petSittingRequestId: petSittingRequestId ?? this.petSittingRequestId,
    reviewerUserId: reviewerUserId ?? this.reviewerUserId,
    rating: rating ?? this.rating,
    comment: comment ?? this.comment,
    createdAt: createdAt ?? this.createdAt,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'petSittingRequestId': petSittingRequestId,
    'reviewerUserId': reviewerUserId,
    'rating': rating,
    'comment': comment,
    'createdAt': createdAt.toIso8601String(),
  };
  factory Review.fromJson(Map<String, dynamic> j) => Review(
    id: j['id'] as int,
    petSittingRequestId: j['petSittingRequestId'] as int,
    reviewerUserId: j['reviewerUserId'] as String,
    rating: j['rating'] as int,
    comment: j['comment'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
  );
}
