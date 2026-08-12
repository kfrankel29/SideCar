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
  );

  final String userId;
  final String displayName;
  final String photoUrl;
  final int age;
  final String gender;
  final String language;
  final double rating;
  final int tripCount;

  String get initials => displayName
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0])
      .join()
      .toUpperCase();
}
