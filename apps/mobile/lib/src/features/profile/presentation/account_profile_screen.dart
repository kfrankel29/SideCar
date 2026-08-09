import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sidecar/src/core/errors/app_failure.dart';
import 'package:sidecar/src/core/platform/app_haptics.dart';
import 'package:sidecar/src/features/auth/domain/auth_repository.dart';
import 'package:sidecar/src/features/bookings/domain/booking_models.dart';
import 'package:sidecar/src/features/bookings/domain/booking_repository.dart';
import 'package:sidecar/src/features/bookings/presentation/payment_screens.dart';
import 'package:sidecar/src/features/profile/domain/profile_repository.dart';
import 'package:sidecar/src/features/profile/domain/user_profile.dart';
import 'package:sidecar/src/features/verification/domain/verification_repository.dart';
import 'package:sidecar/src/routing/app_router.dart';
import 'package:sidecar/src/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class AccountProfileScreen extends ConsumerStatefulWidget {
  const AccountProfileScreen({super.key});

  @override
  ConsumerState<AccountProfileScreen> createState() =>
      _AccountProfileScreenState();
}

class _AccountProfileScreenState extends ConsumerState<AccountProfileScreen>
    with WidgetsBindingObserver {
  bool _changingRole = false;
  bool _openingPayouts = false;
  Future<DriverPayoutStatus>? _payoutStatus;

  Future<DriverPayoutStatus> _loadPayoutStatus() => _payoutStatus ??= ref
      .read(bookingRepositoryProvider)
      .getDriverPayoutStatus();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _payoutStatus == null) return;
    setState(() => _payoutStatus = null);
  }

  Future<void> _openPayoutSetup() async {
    if (_openingPayouts) return;
    setState(() => _openingPayouts = true);
    try {
      final uri = await ref
          .read(bookingRepositoryProvider)
          .createDriverOnboardingLink();
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) throw const AppFailure('Payout setup could not be opened.');
      _payoutStatus = null;
    } on AppFailure catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _openingPayouts = false);
    }
  }

  Future<void> _openPayoutMethods() async {
    final manage = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PayoutMethodsScreen()),
    );
    if (manage == true) await _openPayoutSetup();
  }

  Future<void> _setRole(PrimaryRole role) async {
    final currentRole = ref.read(currentProfileProvider).value?.primaryRole;
    if (_changingRole || currentRole == role) return;
    setState(() => _changingRole = true);
    try {
      await ref.read(profileRepositoryProvider).setPrimaryRole(role);
      ref.invalidate(currentProfileProvider);
      final verification = await ref
          .read(verificationRepositoryProvider)
          .loadCurrentVerification();
      if (!mounted) return;
      if (!verification.canUseRideFeatures(role)) {
        context.go(AppRoutes.verification);
      }
    } on AppFailure catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _changingRole = false);
    }
  }

  Future<void> _signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    ref.invalidate(currentProfileProvider);
    ref.invalidate(currentVerificationProvider);
    if (mounted) context.go(AppRoutes.welcome);
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(currentProfileProvider);
    final profile = profileState.value;
    final verification = ref.watch(currentVerificationProvider).value;
    if (profile == null) {
      return const SafeArea(child: Center(child: CircularProgressIndicator()));
    }
    final role = profile.primaryRole ?? PrimaryRole.rider;
    final verified = verification?.canUseRideFeatures(role) == true;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
        children: [
          Text('Profile', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 24),
          _ProfileHeader(profile: profile),
          const SizedBox(height: 18),
          _ProfileStats(profile: profile),
          const SizedBox(height: 24),
          Text('Use SideCar as', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 10),
          _RoleSelector(
            role: role,
            enabled: !_changingRole,
            onSelected: _setRole,
          ),
          if (_changingRole) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(minHeight: 2),
          ],
          const SizedBox(height: 26),
          _ProfileSection(
            title: 'Account',
            children: [
              _ProfileRow(
                icon: Icons.person_outline_rounded,
                title: 'Personal information',
                subtitle:
                    '${profile.age} · ${profile.gender} · ${profile.language}',
                onTap: () => context.push(AppRoutes.profile),
              ),
              _ProfileRow(
                icon: Icons.verified_user_outlined,
                title: 'Verification',
                subtitle: verified ? 'Complete' : 'Action required',
                onTap: () => context.push(AppRoutes.verification),
              ),
              if (role == PrimaryRole.driver)
                _ProfileRow(
                  icon: Icons.directions_car_outlined,
                  title: 'Vehicle and insurance',
                  subtitle:
                      verification?.vehicle?.makeAndModel.isNotEmpty == true
                      ? verification!.vehicle!.makeAndModel
                      : 'Review driver details',
                  onTap: () => context.push(AppRoutes.verification),
                ),
              if (role == PrimaryRole.rider)
                _ProfileRow(
                  icon: Icons.credit_card_outlined,
                  title: 'Payment methods',
                  subtitle: 'Cards and ACH bank accounts',
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => const PaymentMethodsScreen(),
                    ),
                  ),
                ),
              if (role == PrimaryRole.rider)
                _ProfileRow(
                  icon: Icons.receipt_long_outlined,
                  title: 'Payment history',
                  subtitle: 'Rides, refunds, and credits',
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => const PaymentHistoryScreen(),
                    ),
                  ),
                ),
              if (role == PrimaryRole.driver)
                FutureBuilder<DriverPayoutStatus>(
                  future: _loadPayoutStatus(),
                  builder: (context, snapshot) {
                    final status = snapshot.data;
                    final subtitle = _openingPayouts
                        ? 'Opening secure setup…'
                        : status?.payoutsEnabled == true
                        ? 'Ready to receive ride payouts'
                        : snapshot.hasError
                        ? 'Tap to retry payout setup'
                        : status?.connected == true
                        ? 'Finish Stripe payout setup'
                        : 'Set up secure payouts with Stripe';
                    return _ProfileRow(
                      icon: Icons.account_balance_outlined,
                      title: 'Payout methods',
                      subtitle: subtitle,
                      onTap: _openingPayouts ? null : _openPayoutMethods,
                    );
                  },
                ),
              if (role == PrimaryRole.driver)
                _ProfileRow(
                  icon: Icons.receipt_long_outlined,
                  title: 'Payout history',
                  subtitle: 'Completed ride earnings',
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => const PayoutHistoryScreen(),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          _ProfileSection(
            title: 'Support and safety',
            children: [
              _ProfileRow(
                icon: Icons.shield_outlined,
                title: 'Safety tools',
                subtitle: 'Block or report a user',
                onTap: () => context.push(AppRoutes.safetyTools),
              ),
              const _ProfileRow(
                icon: Icons.help_outline_rounded,
                title: 'Help and support',
                subtitle: 'Frequently asked questions',
              ),
            ],
          ),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: AppHaptics.wrap(_signOut),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final initials = [profile.firstName, profile.lastName]
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase())
        .join();
    return Row(
      children: [
        _ProfileAvatar(photoUrl: profile.photoUrl, initials: initials),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.displayName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 3),
              Text(
                '${profile.age} yrs · ${profile.gender} · ${profile.language}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileStats extends StatelessWidget {
  const _ProfileStats({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ProfileStatCard(
            value: profile.rating > 0 ? profile.rating.toStringAsFixed(1) : '—',
            label: 'Rating',
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _ProfileStatCard(
            value: '${profile.tripCount}',
            label: 'Trips',
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _ProfileStatCard(
            value: _money(profile.creditCents),
            label: 'Credit',
          ),
        ),
      ],
    );
  }

  String _money(int cents) {
    final dollars = cents / 100;
    return dollars == dollars.roundToDouble()
        ? '\$${dollars.toStringAsFixed(0)}'
        : '\$${dollars.toStringAsFixed(2)}';
  }
}

class _ProfileStatCard extends StatelessWidget {
  const _ProfileStatCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.photoUrl, required this.initials});

  final String photoUrl;
  final String initials;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: AppColors.softSurface,
      child: Center(
        child: Text(initials, style: Theme.of(context).textTheme.titleLarge),
      ),
    );
    return ClipOval(
      child: SizedBox.square(
        dimension: 76,
        child: photoUrl.isEmpty
            ? fallback
            : Image.network(
                photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

class _RoleSelector extends StatelessWidget {
  const _RoleSelector({
    required this.role,
    required this.enabled,
    required this.onSelected,
  });

  final PrimaryRole role;
  final bool enabled;
  final ValueChanged<PrimaryRole> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.softSurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final option in PrimaryRole.values)
            Expanded(
              child: InkWell(
                onTap: enabled
                    ? AppHaptics.wrap(() => onSelected(option))
                    : null,
                borderRadius: BorderRadius.circular(11),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: role == option ? AppColors.ink : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    option == PrimaryRole.driver ? 'Driver' : 'Rider',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: role == option ? Colors.white : AppColors.ink,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 9),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index < children.length - 1)
                  const Divider(height: 1, indent: 58),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap == null ? null : AppHaptics.wrap(onTap),
      leading: Icon(icon),
      title: Text(title, style: Theme.of(context).textTheme.labelLarge),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      trailing: onTap == null
          ? null
          : const Icon(Icons.chevron_right_rounded, color: AppColors.mutedInk),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
    );
  }
}
