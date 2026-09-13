import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sidecar/src/core/platform/app_haptics.dart';
import 'package:sidecar/src/features/auth/domain/auth_repository.dart';
import 'package:sidecar/src/features/auth/presentation/pending_auth_destination.dart';
import 'package:sidecar/src/routing/app_router.dart';
import 'package:sidecar/src/theme/app_theme.dart';

export 'package:sidecar/src/features/auth/presentation/pending_auth_destination.dart';

enum _GuestAuthChoice { signUp, logIn }

Future<bool> requireSignedIn(
  BuildContext context,
  WidgetRef ref, {
  required String destination,
  String title = 'Join SideCar',
  String message =
      'Create an account or log in to use this feature with verified UCSB students.',
}) async {
  if (ref.read(authRepositoryProvider).currentUser != null) return true;

  final choice = await showModalBottomSheet<_GuestAuthChoice>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: AppColors.ivory,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _GuestAuthSheet(title: title, message: message),
  );
  if (choice == null || !context.mounted) return false;

  ref.read(pendingAuthDestinationProvider.notifier).remember(destination);
  await context.push(
    choice == _GuestAuthChoice.signUp ? AppRoutes.signUp : AppRoutes.login,
  );
  return false;
}

class _GuestAuthSheet extends StatelessWidget {
  const _GuestAuthSheet({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        20 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 25),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.softSurface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.directions_car_outlined,
                color: AppColors.primary,
                size: 26,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(title, style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 25),
          FilledButton(
            style: AppButtonStyles.primaryFilled,
            onPressed: AppHaptics.wrap(
              () => Navigator.of(context).pop(_GuestAuthChoice.signUp),
            ),
            child: const Text('Create account'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: AppHaptics.wrap(
              () => Navigator.of(context).pop(_GuestAuthChoice.logIn),
            ),
            child: const Text('Log in'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: AppHaptics.wrap(() => Navigator.of(context).pop()),
            child: const Text('Continue browsing'),
          ),
        ],
      ),
    );
  }
}
