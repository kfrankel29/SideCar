enum PrimaryRole { rider, driver }

class UserProfile {
  const UserProfile({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.school,
    required this.homeBase,
    required this.major,
    required this.graduationYear,
    required this.photoUrl,
    this.primaryRole,
  });

  final String userId;
  final String firstName;
  final String lastName;
  final String school;
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
        homeBase.trim().isNotEmpty &&
        major.trim().isNotEmpty &&
        graduationYear > 0 &&
        photoUrl.trim().isNotEmpty;
  }

  factory UserProfile.fromJson(String userId, Map<String, dynamic> json) {
    final roleValue = json['primaryRole'];
    return UserProfile(
      userId: userId,
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      school: json['school'] as String? ?? '',
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
      'homeBase': homeBase.trim(),
      'major': major.trim(),
      'graduationYear': graduationYear,
      'photoUrl': photoUrl.trim(),
      'profileComplete': isComplete,
      if (primaryRole != null) 'primaryRole': primaryRole!.name,
    };
  }

  UserProfile copyWith({String? photoUrl, PrimaryRole? primaryRole}) {
    return UserProfile(
      userId: userId,
      firstName: firstName,
      lastName: lastName,
      school: school,
      homeBase: homeBase,
      major: major,
      graduationYear: graduationYear,
      photoUrl: photoUrl ?? this.photoUrl,
      primaryRole: primaryRole ?? this.primaryRole,
    );
  }
}
