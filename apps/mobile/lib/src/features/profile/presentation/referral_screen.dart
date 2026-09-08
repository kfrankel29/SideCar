import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sidecar/src/core/errors/app_failure.dart';
import 'package:sidecar/src/core/widgets/app_notice.dart';
import 'package:sidecar/src/features/navigation/presentation/final_draft_icons.dart';
import 'package:sidecar/src/features/profile/domain/profile_repository.dart';
import 'package:sidecar/src/theme/app_theme.dart';

class _ReferralSummary {
  const _ReferralSummary({required this.code, required this.creditCents});

  final String code;
  final int creditCents;
}

class ReferralScreen extends ConsumerStatefulWidget {
  const ReferralScreen({super.key});

  @override
  ConsumerState<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends ConsumerState<ReferralScreen> {
  final _code = TextEditingController();
  late Future<_ReferralSummary> _summary;
  bool _redeeming = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _summary = _loadSummary();
  }

  Future<_ReferralSummary> _loadSummary() async {
    try {
      final result = await FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable('getReferralCode').call();
      final data = Map<String, dynamic>.from(result.data as Map);
      return _ReferralSummary(
        code: data['code'] as String? ?? '',
        creditCents: (data['creditCents'] as num?)?.toInt() ?? 0,
      );
    } on FirebaseFunctionsException catch (error) {
      throw AppFailure(
        error.message ?? 'We could not load your referral code.',
      );
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    if (_redeeming) return;
    final code = _code.text.trim();
    if (!RegExp(r'^\d{5}$').hasMatch(code)) {
      showAppNotice(
        context,
        'Enter a valid 5-digit referral code.',
        kind: AppNoticeKind.error,
      );
      return;
    }
    setState(() => _redeeming = true);
    try {
      await FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable('redeemReferralCode').call({'code': code});
      ref.invalidate(currentProfileProvider);
      _code.clear();
      if (mounted) {
        showAppNotice(context, '\$5 credit added to both accounts.');
        setState(_load);
      }
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        showAppNotice(
          context,
          error.message ?? 'We could not redeem that code.',
          kind: AppNoticeKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _redeeming = false);
    }
  }

  String _shareText(String code) =>
      'Use my SideCar referral code $code. We will both get \$5 ride credit. '
      'https://www.ride-sidecar.com/';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<_ReferralSummary>(
          future: _summary,
          builder: (context, snapshot) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
              children: [
                SizedBox(
                  height: 42,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          tooltip: 'Back',
                          padding: EdgeInsets.zero,
                          onPressed: Navigator.of(context).pop,
                          icon: const FinalDraftBackIcon(size: 30),
                        ),
                      ),
                      Text(
                        'Invite & earn',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  'Give \$5, get \$5',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'When a friend redeems your code, both accounts receive ride credit. Your credit is automatically applied to your next ride.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 28),
                if (snapshot.connectionState != ConnectionState.done)
                  const Center(child: CircularProgressIndicator())
                else if (snapshot.hasError)
                  OutlinedButton(
                    onPressed: () => setState(_load),
                    child: const Text('Could not load code · Try again'),
                  )
                else ...[
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Your referral code',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          snapshot.data!.code,
                          key: const ValueKey('referral-code'),
                          style: Theme.of(
                            context,
                          ).textTheme.displayMedium?.copyWith(letterSpacing: 6),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: snapshot.data!.code),
                                  );
                                  if (context.mounted) {
                                    showAppNotice(context, 'Code copied.');
                                  }
                                },
                                icon: const Icon(Icons.copy_outlined),
                                label: const Text('Copy'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.icon(
                                style: AppButtonStyles.primaryFilled,
                                onPressed: () => SharePlus.instance.share(
                                  ShareParams(
                                    text: _shareText(snapshot.data!.code),
                                  ),
                                ),
                                icon: const Icon(Icons.ios_share_outlined),
                                label: const Text('Share'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Redeem a code',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey('redeem-referral-code'),
                    controller: _code,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(5),
                    ],
                    decoration: const InputDecoration(hintText: '5-digit code'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    style: AppButtonStyles.primaryFilled,
                    onPressed: _redeeming ? null : _redeem,
                    child: Text(_redeeming ? 'Redeeming…' : 'Redeem code'),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Available credit: \$${(snapshot.data!.creditCents / 100).toStringAsFixed(2)}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
