import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sidecar/src/core/errors/app_failure.dart';
import 'package:sidecar/src/core/firebase/app_bootstrap.dart';
import 'package:sidecar/src/features/bookings/domain/booking_models.dart';
import 'package:sidecar/src/features/profile/domain/user_profile.dart';
import 'package:sidecar/src/features/safety/domain/safety_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const firstEmail = String.fromEnvironment('M5_E2E_FIRST_EMAIL');
  const firstPassword = String.fromEnvironment('M5_E2E_FIRST_PASSWORD');
  const secondEmail = String.fromEnvironment('M5_E2E_SECOND_EMAIL');
  const secondPassword = String.fromEnvironment('M5_E2E_SECOND_PASSWORD');

  testWidgets('validates live Milestone 5 services across both accounts', (
    tester,
  ) async {
    expect(firstEmail, isNotEmpty);
    expect(firstPassword, isNotEmpty);
    expect(secondEmail, isNotEmpty);
    expect(secondPassword, isNotEmpty);

    final bootstrap = await AppBootstrap.initialize();
    expect(bootstrap.firebaseReady, isTrue);

    final first = await _account(
      bootstrap,
      email: firstEmail,
      password: firstPassword,
    );
    final second = await _account(
      bootstrap,
      email: secondEmail,
      password: secondPassword,
    );
    final driver = first.role == PrimaryRole.driver ? first : second;
    final rider = identical(driver, first) ? second : first;

    await _signIn(bootstrap, rider);
    final conversation = await bootstrap.messagingRepository
        .openDirectConversation(driver.id)
        .timeout(const Duration(seconds: 20));
    final reopenedConversation = await bootstrap.messagingRepository
        .openDirectConversation(driver.id)
        .timeout(const Duration(seconds: 20));
    expect(reopenedConversation.id, conversation.id);
    final message = 'M5 end-to-end ${DateTime.now().millisecondsSinceEpoch}';
    await bootstrap.messagingRepository.sendMessage(conversation.id, message);

    await _signIn(bootstrap, driver);
    final reverseConversation = await bootstrap.messagingRepository
        .openDirectConversation(rider.id)
        .timeout(const Duration(seconds: 20));
    expect(reverseConversation.id, conversation.id);
    final delivered = await bootstrap.messagingRepository
        .watchConversations()
        .firstWhere(
          (items) => items.any(
            (item) => item.id == conversation.id && item.lastMessage == message,
          ),
        )
        .timeout(const Duration(seconds: 20));
    final deliveredConversation = delivered.firstWhere(
      (item) => item.id == conversation.id,
    );
    expect(deliveredConversation.participantIds, contains(driver.id));
    final deliveredMessages = await bootstrap.messagingRepository
        .watchMessages(conversation.id)
        .firstWhere((items) => items.any((item) => item.text == message))
        .timeout(const Duration(seconds: 20));
    expect(deliveredMessages.any((item) => item.text == message), isTrue);
    await bootstrap.messagingRepository.markRead(conversation.id);
    final readConversation = await bootstrap.messagingRepository
        .watchConversations()
        .firstWhere(
          (items) => items.any(
            (item) =>
                item.id == conversation.id && item.unreadCount(driver.id) == 0,
          ),
        )
        .timeout(const Duration(seconds: 20));
    expect(
      readConversation
          .firstWhere((item) => item.id == conversation.id)
          .unreadCount(driver.id),
      0,
    );

    await bootstrap.safetyRepository.reportUser(
      targetUserId: rider.id,
      reason: SafetyReportReason.inappropriateMessages,
      details: 'End-to-end safety verification.',
    );
    await bootstrap.safetyRepository.blockUser(rider.id);
    expect(await bootstrap.safetyRepository.isBlocked(rider.id), isTrue);
    final blocked = await bootstrap.safetyRepository.listBlockedUsers();
    expect(blocked.any((user) => user.id == rider.id), isTrue);
    await expectLater(
      bootstrap.messagingRepository.sendMessage(conversation.id, 'Blocked'),
      throwsA(isA<AppFailure>()),
    );
    await bootstrap.safetyRepository.unblockUser(rider.id);
    expect(await bootstrap.safetyRepository.isBlocked(rider.id), isFalse);

    final driverBookings = await bootstrap.bookingRepository.listRideRequests(
      forceRefresh: true,
    );
    final completedForDriver = driverBookings.where(_isCompleted).toList();
    expect(completedForDriver, isNotEmpty);
    await bootstrap.bookingRepository.rateRider(
      bookingId: completedForDriver.first.id,
      rating: 5,
      comment: 'Safe and considerate rider.',
    );
    final driverRated = await bootstrap.bookingRepository.refreshBooking(
      completedForDriver.first.id,
    );
    expect(driverRated.driverHasRated, isTrue);

    await _signIn(bootstrap, rider);
    final riderBookings = await bootstrap.bookingRepository.listMyBookings(
      forceRefresh: true,
    );
    final completedForRider = riderBookings.where(_isCompleted).toList();
    expect(completedForRider, isNotEmpty);
    await bootstrap.bookingRepository.rateTrip(
      bookingId: completedForRider.first.id,
      driverRating: 5,
      tripRating: 5,
      comment: 'Smooth and safe trip.',
    );
    final riderRated = await bootstrap.bookingRepository.refreshBooking(
      completedForRider.first.id,
    );
    expect(riderRated.riderHasRated, isTrue);

    await bootstrap.authRepository.signOut();
  });
}

bool _isCompleted(SeatBooking booking) =>
    booking.status == BookingStatus.completed ||
    booking.status == BookingStatus.payoutHeld;

Future<_Account> _account(
  AppBootstrapResult bootstrap, {
  required String email,
  required String password,
}) async {
  await bootstrap.authRepository.signOut();
  final user = await bootstrap.authRepository.signIn(
    email: email,
    password: password,
  );
  final profile = await bootstrap.profileRepository.loadCurrentProfile();
  expect(profile, isNotNull);
  expect(profile!.primaryRole, isNotNull);
  return _Account(
    id: user.id,
    email: email,
    password: password,
    role: profile.primaryRole!,
  );
}

Future<void> _signIn(AppBootstrapResult bootstrap, _Account account) async {
  await bootstrap.authRepository.signOut();
  await bootstrap.authRepository.signIn(
    email: account.email,
    password: account.password,
  );
}

class _Account {
  const _Account({
    required this.id,
    required this.email,
    required this.password,
    required this.role,
  });

  final String id;
  final String email;
  final String password;
  final PrimaryRole role;
}
