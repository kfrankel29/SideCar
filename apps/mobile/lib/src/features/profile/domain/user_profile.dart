enum PrimaryRole { rider, driver }

const supportedSpokenLanguages = <String>[
  'English',
  'Spanish',
  'Mandarin Chinese',
  'Cantonese',
  'Hindi',
  'Punjabi',
  'Vietnamese',
  'Korean',
  'Japanese',
  'Arabic',
  'French',
  'Persian',
  'Russian',
  'Portuguese',
  'German',
  'Italian',
  'Tagalog',
  'Urdu',
  'Uzbek',
];

class UserProfile {
  const UserProfile({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.school,
    required this.photoUrl,
    this.age = 0,
    this.gender = '',
    this.language = '',
    this.homeBase = '',
    this.major = '',
    this.graduationYear = 0,
    this.rating = 0,
    this.tripCount = 0,
    this.creditCents = 0,
    this.totalEarningsCents = 0,
    this.primaryRole,
  });

  final String userId;
  final String firstName;
  final String lastName;
  final String school;
  final int age;
  final String gender;
  final String language;

  // Kept as optional extension points for later rider-specific profile work.
  final String homeBase;
  final String major;
  final int graduationYear;
  final double rating;
  final int tripCount;
  final int creditCents;
  final int totalEarningsCents;

  final String photoUrl;
  final PrimaryRole? primaryRole;

  String get displayName => '$firstName $lastName'.trim();

  bool get isComplete {
    return firstName.trim().isNotEmpty &&
        lastName.trim().isNotEmpty &&
        school.trim().isNotEmpty &&
        age >= 18 &&
        age <= 100 &&
        gender.trim().isNotEmpty &&
        language.trim().isNotEmpty &&
        photoUrl.trim().isNotEmpty;
  }

  factory UserProfile.fromJson(String userId, Map<String, dynamic> json) {
    final roleValue = json['primaryRole'];
    return UserProfile(
      userId: userId,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      school: json['school'] as String? ?? '',
      age: (json['age'] as num?)?.toInt() ?? 0,
      gender: json['gender'] as String? ?? '',
      language: json['language'] as String? ?? '',
      homeBase: json['homeBase'] as String? ?? '',
      major: json['major'] as String? ?? '',
      graduationYear: (json['graduationYear'] as num?)?.toInt() ?? 0,
      rating:
          (json['rating'] as num?)?.toDouble() ??
          (json['driverRating'] as num?)?.toDouble() ??
          0,
      tripCount:
          (json['tripCount'] as num?)?.toInt() ??
          (json['driverTrips'] as num?)?.toInt() ??
          0,
      creditCents: (json['creditCents'] as num?)?.toInt() ?? 0,
      totalEarningsCents: (json['totalEarningsCents'] as num?)?.toInt() ?? 0,
      photoUrl: json['photoUrl'] as String? ?? '',
      primaryRole: switch (roleValue) {
        'rider' => PrimaryRole.rider,
        'driver' => PrimaryRole.driver,
        _ => null,
      },
    );
  }

  Map<String, Object?> toJson() {
    return {
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'displayName': displayName,
      'school': school.trim(),
      'age': age,
      'gender': gender.trim(),
      'language': language.trim(),
      'homeBase': homeBase.trim(),
      'major': major.trim(),
      'graduationYear': graduationYear,
      'photoUrl': photoUrl.trim(),
      'profileComplete': isComplete,
      if (primaryRole != null) 'primaryRole': primaryRole!.name,
    };
  }

  UserProfile copyWith({
    int? age,
    String? gender,
    String? language,
    String? photoUrl,
    PrimaryRole? primaryRole,
  }) {
    return UserProfile(
      userId: userId,
      firstName: firstName,
      lastName: lastName,
      school: school,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      language: language ?? this.language,
      homeBase: homeBase,
      major: major,
      graduationYear: graduationYear,
      rating: rating,
      tripCount: tripCount,
      creditCents: creditCents,
      totalEarningsCents: totalEarningsCents,
      photoUrl: photoUrl ?? this.photoUrl,
      primaryRole: primaryRole ?? this.primaryRole,
    );
  }
}
