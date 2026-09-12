import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sidecar/src/core/firebase/app_bootstrap.dart';
import 'package:sidecar/src/features/profile/domain/account_security_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const useSecondAccount = bool.fromEnvironment('USE_SECOND_QA_ACCOUNT');
  const firstEmail = String.fromEnvironment('M5_E2E_FIRST_EMAIL');
  const firstPassword = String.fromEnvironment('M5_E2E_FIRST_PASSWORD');
  const secondEmail = String.fromEnvironment('M5_E2E_SECOND_EMAIL');
  const secondPassword = String.fromEnvironment('M5_E2E_SECOND_PASSWORD');
  const email = useSecondAccount ? secondEmail : firstEmail;
  const password = useSecondAccount ? secondPassword : firstPassword;

  testWidgets('uploads a profile photo and deletes the signed-in QA account', (
    tester,
  ) async {
    expect(email, isNotEmpty);
    expect(password, isNotEmpty);

    final bootstrap = await AppBootstrap.initialize().timeout(
      const Duration(seconds: 45),
    );
    expect(bootstrap.firebaseReady, isTrue);
    expect(bootstrap.initializationError, isNull);

    final credential = await FirebaseAuth.instance
        .signInWithEmailAndPassword(email: email, password: password)
        .timeout(const Duration(seconds: 45));
    final user = credential.user;
    expect(user, isNotNull);
    await user!.getIdToken(true);

    final photo = await _profilePhotoPng();
    expect(photo.lengthInBytes, greaterThan(10 * 1024));
    final photoUrl = await bootstrap.profileRepository
        .uploadProfilePhoto(bytes: photo, contentType: 'image/png')
        .timeout(const Duration(seconds: 120));
    expect(photoUrl, startsWith('https://'));

    final metadata = await FirebaseStorage.instance
        .ref('users/${user.uid}/profile/profile.jpg')
        .getMetadata()
        .timeout(const Duration(seconds: 45));
    expect(metadata.contentType, 'image/png');
    expect(metadata.size, photo.lengthInBytes);

    final deletion = FirebaseAccountSecurityRepository(
      FirebaseAuth.instance,
      FirebaseFunctions.instanceFor(region: 'us-central1'),
    );
    await deletion
        .deleteAccount(confirmation: 'DELETE', currentPassword: password)
        .timeout(const Duration(seconds: 150));
    expect(FirebaseAuth.instance.currentUser, isNull);

    await expectLater(
      FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      ),
      throwsA(isA<FirebaseAuthException>()),
    );
  });
}

Future<Uint8List> _profilePhotoPng() async {
  const size = 900.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, size, size),
    Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xff29477f), Color(0xfff3c6a8), Color(0xff4b875c)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(const Rect.fromLTWH(0, 0, size, size)),
  );
  for (var row = 0; row < 75; row++) {
    for (var column = 0; column < 75; column++) {
      final red = (row * 37 + column * 19) % 256;
      final green = (row * 13 + column * 47) % 256;
      final blue = (row * 71 + column * 7) % 256;
      canvas.drawCircle(
        Offset(column * 12.0 + 6, row * 12.0 + 6),
        5.2,
        Paint()..color = Color.fromARGB(210, red, green, blue),
      );
    }
  }
  final image = await recorder.endRecording().toImage(
    size.toInt(),
    size.toInt(),
  );
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (data == null) throw StateError('Could not encode the QA photo.');
  return data.buffer.asUint8List();
}
