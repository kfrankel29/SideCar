import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sidecar/src/core/platform/app_haptics.dart';
import 'package:sidecar/src/features/profile/domain/profile_repository.dart';
import 'package:sidecar/src/features/profile/domain/user_profile.dart';
import 'package:sidecar/src/features/profile/presentation/account_profile_screen.dart';
import 'package:sidecar/src/features/navigation/domain/tab_activation.dart';
import 'package:sidecar/src/features/navigation/presentation/final_draft_icons.dart';
import 'package:sidecar/src/features/rides/presentation/driver_ride_screens.dart';
import 'package:sidecar/src/features/rides/presentation/ride_search_screens.dart';
import 'package:sidecar/src/theme/app_theme.dart';

class MainTabShell extends ConsumerWidget {
  const MainTabShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentProfileProvider).value?.primaryRole;
    if (role == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: MainBottomNavigation(
        role: role,
        selectedIndex: navigationShell.currentIndex,
        onSelected: (index) {
          AppHaptics.tap();
          ref.read(mainTabActivationProvider.notifier).activate(index);
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
      ),
    );
  }
}

class MainBottomNavigation extends StatelessWidget {
  const MainBottomNavigation({
    required this.role,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final PrimaryRole role;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final icons = <FinalDraftIconKind>[
      FinalDraftIconKind.home,
      role == PrimaryRole.driver
          ? FinalDraftIconKind.post
          : FinalDraftIconKind.search,
      FinalDraftIconKind.rides,
      FinalDraftIconKind.messages,
      FinalDraftIconKind.profile,
    ];
    final labels = <String>[
      'Home',
      role == PrimaryRole.driver ? 'Post' : 'Search',
      'My rides',
      'Messages',
      'Profile',
    ];

    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFECECEE))),
      ),
      child: SizedBox(
        height: 55 + bottomInset,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Row(
            children: List.generate(labels.length, (index) {
              final selected = selectedIndex == index;
              return Expanded(
                child: Semantics(
                  selected: selected,
                  button: true,
                  label: labels[index],
                  child: InkResponse(
                    key: ValueKey('ride-nav-$index'),
                    onTap: () => onSelected(index),
                    radius: 28,
                    child: Center(
                      child: FinalDraftIcon(
                        kind: icons[index],
                        selected: selected,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class RoleActionTab extends ConsumerWidget {
  const RoleActionTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentProfileProvider).value?.primaryRole;
    return role == PrimaryRole.driver
        ? const PostRideScreen()
        : const SearchRidesScreen();
  }
}

class RoleMyRidesTab extends ConsumerWidget {
  const RoleMyRidesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentProfileProvider).value?.primaryRole;
    return role == PrimaryRole.driver
        ? const MyRidesScreen()
        : const RiderMyRidesScreen();
  }
}

class MessagesTabScreen extends StatelessWidget {
  const MessagesTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _RefreshableEmptyTabScreen(
      title: 'Messages',
      icon: Icons.chat_bubble_outline_rounded,
      message: 'Ride conversations will appear here.',
    );
  }
}

class _RefreshableEmptyTabScreen extends StatelessWidget {
  const _RefreshableEmptyTabScreen({
    required this.title,
    required this.icon,
    required this.message,
  });

  final String title;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () =>
            Future<void>.delayed(const Duration(milliseconds: 150)),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
              sliver: SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const Spacer(),
                    Icon(icon, size: 42, color: AppColors.mutedInk),
                    const SizedBox(height: 14),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AccountTab extends StatelessWidget {
  const AccountTab({super.key});

  @override
  Widget build(BuildContext context) => const AccountProfileScreen();
}
