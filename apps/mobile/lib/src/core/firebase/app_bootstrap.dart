import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sidecar/src/core/config/business_config_repository.dart';
import 'package:sidecar/src/core/firebase/firebase_runtime_options.dart';
import 'package:sidecar/src/core/platform/install_state.dart';
import 'package:sidecar/src/features/auth/data/firebase_auth_repository.dart';
import 'package:sidecar/src/features/auth/domain/auth_repository.dart';
import 'package:sidecar/src/features/profile/data/firebase_profile_repository.dart';
import 'package:sidecar/src/features/profile/domain/profile_repository.dart';
import 'package:sidecar/src/features/safety/data/firebase_safety_repository.dart';
import 'package:sidecar/src/features/safety/domain/safety_repository.dart';
import 'package:sidecar/src/features/verification/data/firebase_verification_repository.dart';
import 'package:sidecar/src/features/verification/domain/verification_repository.dart';

class AppBootstrapResult {
  const AppBootstrapResult({
    required this.firebaseReady,
    required this.businessConfigRepository,
    required this.authRepository,
    required this.profileRepository,
    required this.verificationRepository,
    required this.safetyRepository,
    this.initializationError,
  });

  final bool firebaseReady;
  final BusinessConfigRepository businessConfigRepository;
  final AuthRepository authRepository;
  final ProfileRepository profileRepository;
  final VerificationRepository verificationRepository;
  final SafetyRepository safetyRepository;
  final Object? initializationError;
}

final appBootstrapProvider = Provider<AppBootstrapResult>(
  (ref) => throw StateError('AppBootstrapResult has not been initialized.'),
);

class AppBootstrap {
  const AppBootstrap._();

  static Future<AppBootstrapResult> initialize() async {
    try {
      if (kIsWeb && !FirebaseRuntimeOptions.isConfigured) {
        throw StateError('Firebase build configuration is missing.');
      }
      await Firebase.initializeApp(
        options: FirebaseRuntimeOptions.isConfigured
            ? FirebaseRuntimeOptions.current
            : null,
      );
      Object? appCheckError;
      try {
        await FirebaseAppCheck.instance.activate(
          providerAndroid: kReleaseMode
              ? const AndroidPlayIntegrityProvider()
              : const AndroidDebugProvider(),
          providerApple: kReleaseMode
              ? const AppleAppAttestWithDeviceCheckFallbackProvider()
              : const AppleDebugProvider(),
        );
      } on Object catch (error) {
        appCheckError = error;
        debugPrint('Firebase App Check activation failed: $error');
      }

      final auth = FirebaseAuth.instance;
      await InstallState.clearRestoredSessionIfNeeded(auth.signOut);
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      return AppBootstrapResult(
        firebaseReady: true,
        businessConfigRepository: FirebaseBusinessConfigRepository(
          FirebaseRemoteConfig.instance,
        ),
        authRepository: FirebaseAuthRepository(auth, functions),
        profileRepository: FirebaseProfileRepository(
          auth,
          FirebaseFirestore.instance,
          FirebaseStorage.instance,
        ),
        verificationRepository: FirebaseVerificationRepository(
          auth,
          FirebaseFirestore.instance,
          FirebaseStorage.instance,
          functions,
        ),
        safetyRepository: FirebaseSafetyRepository(functions),
        initializationError: appCheckError,
      );
    } catch (error) {
      return AppBootstrapResult(
        firebaseReady: false,
        initializationError: error,
        businessConfigRepository: MemoryBusinessConfigRepository(
          localDisplayConfig(),
        ),
        authRepository: const UnavailableAuthRepository(),
        profileRepository: const UnavailableProfileRepository(),
        verificationRepository: const UnavailableVerificationRepository(),
        safetyRepository: const UnavailableSafetyRepository(),
      );
    }
  }
}
