import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sidecar/src/core/platform/app_haptics.dart';
import 'package:sidecar/src/features/profile/domain/profile_repository.dart';
import 'package:sidecar/src/features/profile/domain/user_profile.dart';
import 'package:sidecar/src/features/profile/presentation/account_profile_screen.dart';
import 'package:sidecar/src/features/bookings/domain/booking_repository.dart';
import 'package:sidecar/src/features/navigation/domain/tab_activation.dart';
import 'package:sidecar/src/features/navigation/presentation/final_draft_icons.dart';
import 'package:sidecar/src/features/messaging/presentation/messaging_screens.dart';
import 'package:sidecar/src/features/messaging/domain/messaging_repository.dart';
import 'package:sidecar/src/features/notifications/domain/notification_service.dart';
import 'package:sidecar/src/features/rides/presentation/driver_ride_screens.dart';
import 'package:sidecar/src/features/rides/presentation/ride_search_screens.dart';
import 'package:sidecar/src/theme/app_theme.dart';

class MainTabShell extends ConsumerWidget {
  const MainTabShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).value;
    final role = profile?.primaryRole;
    if (role == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final uid = profile?.userId ?? '';
    final unreadMessages =
        ref
            .watch(conversationsProvider)
            .value
            ?.fold<int>(0, (total, item) => total + item.unreadCount(uid)) ??
        0;
    final pendingRequests = role == PrimaryRole.driver
        ? ref.watch(driverPendingRequestCountProvider).value ?? 0
        : 0;
    final unreadRideUpdates =
        ref.watch(rideNotificationAttentionProvider).value ?? 0;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 6),
        child: MainBottomNavigation(
          role: role,
          unreadMessages: unreadMessages,
          pendingRequests: pendingRequests,
          unreadRideUpdates: unreadRideUpdates,
          selectedIndex: navigationShell.currentIndex,
          onSelected: (index) {
            AppHaptics.tap();
            if (role == PrimaryRole.driver && index == 2) {
              ref.invalidate(driverPendingRequestCountProvider);
            }
            if (index == 2) {
              unawaited(
                ref
                    .read(notificationServiceProvider)
                    .markRideUpdatesRead()
                    .whenComplete(
                      () => ref.invalidate(rideNotificationAttentionProvider),
                    ),
              );
            }
            ref.read(mainTabActivationProvider.notifier).activate(index);
            navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            );
          },
        ),
      ),
    );
  }
}

class MainBottomNavigation extends StatelessWidget {
  const MainBottomNavigation({
    required this.role,
    required this.selectedIndex,
    required this.onSelected,
    this.unreadMessages = 0,
    this.pendingRequests = 0,
    this.unreadRideUpdates = 0,
    super.key,
  });

  final PrimaryRole role;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final int unreadMessages;
  final int pendingRequests;
  final int unreadRideUpdates;

  @override
  Widget build(BuildContext context) {
    final ridesAttentionCount = pendingRequests > unreadRideUpdates
        ? pendingRequests
        : unreadRideUpdates;
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

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.ivory,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SizedBox(
        height: 65,
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
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        FinalDraftIcon(kind: icons[index], selected: selected),
                        if (index == 3 && unreadMessages > 0)
                          Positioned(
                            right: -8,
                            top: -7,
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 17),
                              height: 17,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE14942),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                unreadMessages > 9 ? '9+' : '$unreadMessages',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        if (index == 2 && ridesAttentionCount > 0)
                          Positioned(
                            right: -8,
                            top: -7,
                            child: _NavigationCountBadge(
                              key: const ValueKey('my-rides-update-count'),
                              count: ridesAttentionCount,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavigationCountBadge extends StatelessWidget {
  const _NavigationCountBadge({required this.count, super.key});

  final int count;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 17),
    height: 17,
    padding: const EdgeInsets.symmetric(horizontal: 4),
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: Color(0xFFE14942),
      shape: BoxShape.circle,
    ),
    child: Text(
      count > 9 ? '9+' : '$count',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
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
  Widget build(BuildContext context) => const MessageInboxScreen();
}

class AccountTab extends StatelessWidget {
  const AccountTab({super.key});

  @override
  Widget build(BuildContext context) => const AccountProfileScreen();
}
