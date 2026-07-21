import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sidecar/src/app.dart';
import 'package:sidecar/src/core/config/business_config_repository.dart';
import 'package:sidecar/src/core/firebase/app_bootstrap.dart';
import 'package:sidecar/src/features/auth/domain/auth_repository.dart';
import 'package:sidecar/src/features/profile/domain/profile_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
      ],
      child: const SideCarApp(),
    ),
  );
}
