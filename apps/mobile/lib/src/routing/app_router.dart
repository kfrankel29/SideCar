import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sidecar/src/features/auth/domain/auth_repository.dart';
import 'package:sidecar/src/features/auth/presentation/auth_screens.dart';
import 'package:sidecar/src/features/diagnostics/presentation/config_diagnostics_screen.dart';
import 'package:sidecar/src/features/navigation/presentation/main_tab_shell.dart';
import 'package:sidecar/src/features/profile/presentation/profile_screens.dart';
import 'package:sidecar/src/features/profile/presentation/public_profile_screen.dart';
import 'package:sidecar/src/features/rides/domain/ride_models.dart';
import 'package:sidecar/src/features/rides/presentation/ride_details_screen.dart';
import 'package:sidecar/src/features/rides/presentation/ride_home_screen.dart';
import 'package:sidecar/src/features/rides/presentation/ride_search_screens.dart';
import 'package:sidecar/src/features/safety/presentation/safety_screens.dart';
import 'package:sidecar/src/features/verification/presentation/verification_screens.dart';

abstract final class AppRoutes {
  static const opening = '/opening';
  static const welcome = '/welcome';
  static const login = '/login';
  static const signUp = '/sign-up';
  static const verifyEmail = '/verify-email';
  static const forgotPassword = '/forgot-password';
  static const resetCode = '/reset-code';
  static const newPassword = '/new-password';
  static const passwordResetComplete = '/password-reset-complete';
  static const profile = '/profile';
  static const photoPermission = '/photo-permission';
  static const onboarded = '/onboarded';
  static const profileGate = '/profile-gate';
  static const verification = '/verification';
  static const identityVerification = '/verification/identity';
  static const driverLicense = '/verification/driver-license';
  static const vehicleProfile = '/verification/vehicle';
  static const insuranceVerification = '/verification/insurance';
  static const insuranceFallback = '/verification/insurance/manual';
  static const verificationComplete = '/verification/complete';
  static const safetyTools = '/safety';
  static const blockUser = '/safety/block';
  static const reportUser = '/safety/report';
  static const diagnostics = '/diagnostics/config';
  static const home = '/home';
  static const action = '/rides/action';
  static const searchRides = action;
  static const searchResults = '/rides/results';
  static const leavingSoon = '/rides/leaving-soon';
  static const rideDetails = '/rides/:rideId';
  static const postRide = action;
  static const myRides = '/rides/mine';
  static const messages = '/messages';
  static const account = '/account';
  static const publicProfile = '/profiles/:userId';
  static const stripeRedirect = '/stripe-redirect';

  static String get initialLocation {
    const buildRoute = String.fromEnvironment('SIDECAR_INITIAL_ROUTE');
    if (buildRoute.isNotEmpty) return buildRoute;
    if (kDebugMode) {
      final runtimeRoute = Platform.environment['SIDECAR_INITIAL_ROUTE'];
      if (runtimeRoute != null && runtimeRoute.isNotEmpty) return runtimeRoute;
    }
    return opening;
  }
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _homeNavigatorKey = GlobalKey<NavigatorState>();
final _actionNavigatorKey = GlobalKey<NavigatorState>();
final _ridesNavigatorKey = GlobalKey<NavigatorState>();
final _messagesNavigatorKey = GlobalKey<NavigatorState>();
final _accountNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.initialLocation,
    redirect: (_, state) {
      if (!isStripeReturnLocation(state.uri)) return null;
      return stripeReturnDestination(
        state.uri,
        signedIn: ref.read(authRepositoryProvider).currentUser != null,
      );
    },
    routes: [
      GoRoute(
        path: AppRoutes.opening,
        builder: (_, state) => OpeningScreen(
          autoContinue:
              !(kDebugMode && state.uri.queryParameters['visualQa'] == 'true'),
        ),
      ),
      GoRoute(
        path: AppRoutes.welcome,
        builder: (_, _) => const WelcomeScreen(),
      ),
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: AppRoutes.signUp, builder: (_, _) => const SignUpScreen()),
      GoRoute(
        path: AppRoutes.verifyEmail,
        builder: (_, state) => EmailVerificationScreen(
          email: state.uri.queryParameters['email'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.resetCode,
        builder: (_, state) => PasswordResetCodeScreen(
          email: state.uri.queryParameters['email'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.newPassword,
        builder: (_, state) => NewPasswordScreen(
          email: state.uri.queryParameters['email'] ?? '',
          resetToken: state.uri.queryParameters['token'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.passwordResetComplete,
        builder: (_, _) => const PasswordResetCompleteScreen(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (_, _) => const ProfileSetupScreen(),
      ),
      GoRoute(
        path: AppRoutes.photoPermission,
        builder: (_, _) => const PhotoPermissionScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarded,
        builder: (_, _) => const OnboardedScreen(),
      ),
      GoRoute(
        path: AppRoutes.profileGate,
        builder: (_, _) => const ProfileGateScreen(),
      ),
      GoRoute(
        path: AppRoutes.verification,
        builder: (_, _) => const VerificationHubScreen(),
      ),
      GoRoute(
        path: AppRoutes.identityVerification,
        builder: (_, _) => const IdentityVerificationScreen(),
      ),
      GoRoute(
        path: AppRoutes.driverLicense,
        builder: (_, _) => const DriverLicenseUploadScreen(),
      ),
      GoRoute(
        path: AppRoutes.vehicleProfile,
        builder: (_, _) => const VehicleProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.insuranceVerification,
        builder: (_, _) => const InsuranceVerificationScreen(),
      ),
      GoRoute(
        path: AppRoutes.insuranceFallback,
        builder: (_, _) => const InsuranceFallbackScreen(),
      ),
      GoRoute(
        path: AppRoutes.verificationComplete,
        builder: (_, _) => const VerificationCompleteScreen(),
      ),
      GoRoute(
        path: AppRoutes.safetyTools,
        builder: (_, _) => const SafetyToolsScreen(),
      ),
      GoRoute(
        path: AppRoutes.blockUser,
        builder: (_, state) => BlockUserScreen(
          targetUserId: state.uri.queryParameters['uid'] ?? '',
          name: state.uri.queryParameters['name'] ?? 'User',
        ),
      ),
      GoRoute(
        path: AppRoutes.reportUser,
        builder: (_, state) => ReportUserScreen(
          targetUserId: state.uri.queryParameters['uid'] ?? '',
          name: state.uri.queryParameters['name'] ?? 'User',
        ),
      ),
      GoRoute(
        path: AppRoutes.diagnostics,
        builder: (_, _) => const ConfigDiagnosticsScreen(),
      ),
      GoRoute(
        path: AppRoutes.stripeRedirect,
        redirect: (_, _) => AppRoutes.account,
      ),
      GoRoute(
        path: AppRoutes.publicProfile,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) =>
            PublicProfileScreen(userId: state.pathParameters['userId'] ?? ''),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) =>
            MainTabShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _homeNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.home,
                pageBuilder: (_, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const RideHomeScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _actionNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.action,
                pageBuilder: (_, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const RoleActionTab(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _ridesNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.myRides,
                pageBuilder: (_, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const RoleMyRidesTab(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _messagesNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.messages,
                pageBuilder: (_, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const MessagesTabScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _accountNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.account,
                pageBuilder: (_, state) => NoTransitionPage(
                  key: state.pageKey,
                  child: const AccountTab(),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.searchResults,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) => SearchResultsScreen(
          criteria:
              state.extra as RideSearchCriteria? ??
              RideSearchCriteria(
                originQuery: 'UCSB / Isla Vista',
                destinationQuery: 'San Mateo / Peninsula',
                pickupPlaceId: '',
                dropoffPlaceId: '',
                startAt: DateTime.now(),
                endAt: DateTime.now().add(const Duration(days: 1)),
              ),
        ),
      ),
      GoRoute(
        path: AppRoutes.leavingSoon,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const LeavingSoonScreen(),
      ),
      GoRoute(
        path: AppRoutes.rideDetails,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) =>
            RideDetailsScreen(rideId: state.pathParameters['rideId'] ?? ''),
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});

bool isStripeReturnLocation(Uri uri) {
  if (uri.scheme == 'sidecar' && uri.host == 'stripe-redirect') return true;
  if (uri.scheme == 'sidecar' &&
      uri.host == 'app' &&
      uri.path == AppRoutes.stripeRedirect) {
    return true;
  }
  return uri.scheme.isEmpty && uri.path == AppRoutes.stripeRedirect;
}

String? stripeReturnDestination(Uri uri, {required bool signedIn}) {
  if (!isStripeReturnLocation(uri)) return null;
  return signedIn ? AppRoutes.account : AppRoutes.opening;
}
