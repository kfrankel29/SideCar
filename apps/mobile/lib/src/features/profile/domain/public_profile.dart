class PublicProfile {
  const PublicProfile({
    required this.userId,
    required this.displayName,
    required this.photoUrl,
    required this.age,
    required this.gender,
    required this.language,
    required this.rating,
    required this.tripCount,
    this.reviews = const [],
  });

  factory PublicProfile.fromJson(Map<String, dynamic> json) => PublicProfile(
    userId: json['userId'] as String? ?? '',
    displayName: json['displayName'] as String? ?? '',
    photoUrl: json['photoUrl'] as String? ?? '',
    age: (json['age'] as num?)?.toInt() ?? 0,
    gender: json['gender'] as String? ?? '',
    language: json['language'] as String? ?? '',
    rating: (json['rating'] as num?)?.toDouble() ?? 0,
    tripCount: (json['tripCount'] as num?)?.toInt() ?? 0,
    reviews: (json['reviews'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => PublicReview.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false),
  );

  final String userId;
  final String displayName;
  final String photoUrl;
  final int age;
  final String gender;
  final String language;
  final double rating;
  final int tripCount;
  final List<PublicReview> reviews;

  String get initials => displayName
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0])
      .join()
      .toUpperCase();
}

class PublicReview {
  const PublicReview({
    required this.reviewId,
    required this.reviewerName,
    required this.reviewerPhotoUrl,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory PublicReview.fromJson(Map<String, dynamic> json) => PublicReview(
    reviewId: json['reviewId'] as String? ?? '',
    reviewerName: json['reviewerName'] as String? ?? 'SideCar rider',
    reviewerPhotoUrl: json['reviewerPhotoUrl'] as String? ?? '',
    rating: (json['rating'] as num?)?.toDouble() ?? 0,
    comment: json['comment'] as String? ?? '',
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
  );

  final String reviewId;
  final String reviewerName;
  final String reviewerPhotoUrl;
  final double rating;
  final String comment;
  final DateTime? createdAt;

  String get reviewerInitials => reviewerName
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0])
      .join()
      .toUpperCase();
}
