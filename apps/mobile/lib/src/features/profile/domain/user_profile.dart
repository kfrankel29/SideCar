enum PrimaryRole { rider, driver }

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
      photoUrl: photoUrl ?? this.photoUrl,
      primaryRole: primaryRole ?? this.primaryRole,
    );
  }
}
