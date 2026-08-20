import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sidecar/src/app.dart';
import 'package:sidecar/src/core/config/business_config_repository.dart';
import 'package:sidecar/src/core/firebase/app_bootstrap.dart';
import 'package:sidecar/src/core/firebase/firebase_runtime_options.dart';
import 'package:sidecar/src/features/auth/domain/auth_repository.dart';
import 'package:sidecar/src/features/bookings/domain/booking_repository.dart';
import 'package:sidecar/src/features/messaging/domain/messaging_repository.dart';
import 'package:sidecar/src/features/notifications/domain/notification_service.dart';
import 'package:sidecar/src/features/profile/domain/profile_repository.dart';
import 'package:sidecar/src/features/profile/domain/public_profile_repository.dart';
import 'package:sidecar/src/features/rides/domain/ride_repository.dart';
import 'package:sidecar/src/features/safety/domain/safety_repository.dart';
import 'package:sidecar/src/features/verification/domain/verification_repository.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: FirebaseRuntimeOptions.isConfigured
        ? FirebaseRuntimeOptions.current
        : null,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  final bootstrap = await AppBootstrap.initialize();

  runApp(
    ProviderScope(
      overrides: [
        appBootstrapProvider.overrideWithValue(bootstrap),
        businessConfigRepositoryProvider.overrideWithValue(
          bootstrap.businessConfigRepository,
        ),
        authRepositoryProvider.overrideWithValue(bootstrap.authRepository),
        profileRepositoryProvider.overrideWithValue(
          bootstrap.profileRepository,
        ),
        publicProfileRepositoryProvider.overrideWithValue(
          bootstrap.publicProfileRepository,
        ),
        rideRepositoryProvider.overrideWithValue(bootstrap.rideRepository),
        bookingRepositoryProvider.overrideWithValue(
          bootstrap.bookingRepository,
        ),
        messagingRepositoryProvider.overrideWithValue(
          bootstrap.messagingRepository,
        ),
        notificationServiceProvider.overrideWithValue(
          bootstrap.notificationService,
        ),
        verificationRepositoryProvider.overrideWithValue(
          bootstrap.verificationRepository,
        ),
        safetyRepositoryProvider.overrideWithValue(bootstrap.safetyRepository),
      ],
      child: const SideCarApp(),
    ),
  );
}
