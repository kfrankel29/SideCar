import 'package:firebase_core/firebase_core.dart';

class FirebaseRuntimeOptions {
  const FirebaseRuntimeOptions._();

  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
  );

  static bool get isConfigured {
    return [
      apiKey,
      appId,
      messagingSenderId,
      projectId,
    ].every((value) => value.isNotEmpty);
  }

  static FirebaseOptions get current {
    if (!isConfigured) {
      throw StateError('Firebase runtime options are missing.');
    }
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      storageBucket: storageBucket.isEmpty ? null : storageBucket,
    );
  }
}
