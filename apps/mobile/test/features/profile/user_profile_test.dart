import 'package:flutter_test/flutter_test.dart';
import 'package:sidecar/src/features/profile/domain/user_profile.dart';

void main() {
  const completeProfile = UserProfile(
    userId: 'user-1',
    firstName: 'Maya',
    lastName: 'Chen',
    school: 'UC Santa Barbara',
    age: 20,
    gender: 'Female',
    language: 'English',
    photoUrl: 'https://example.test/profile.jpg',
  );

  test('requires every gated profile field', () {
    expect(completeProfile.isComplete, isTrue);
    expect(completeProfile.copyWith(photoUrl: '').isComplete, isFalse);
  });

  test('serializes normalized values and completion state', () {
    final json = completeProfile.toJson();

    expect(json['displayName'], 'Maya Chen');
    expect(json['profileComplete'], isTrue);
    expect(json['age'], 20);
    expect(json['gender'], 'Female');
    expect(json['language'], 'English');
  });

  test('maps a persisted primary role', () {
    final restored = UserProfile.fromJson('user-1', {
      ...completeProfile.toJson(),
      'primaryRole': 'driver',
    });

    expect(restored.primaryRole, PrimaryRole.driver);
    expect(restored.isComplete, isTrue);
  });
}
