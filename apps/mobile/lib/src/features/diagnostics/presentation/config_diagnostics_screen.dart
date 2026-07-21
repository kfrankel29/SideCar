import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sidecar/src/core/config/business_config.dart';
import 'package:sidecar/src/core/config/business_config_repository.dart';
import 'package:sidecar/src/core/firebase/app_bootstrap.dart';
import 'package:sidecar/src/core/platform/app_haptics.dart';
import 'package:sidecar/src/core/widgets/sidecar_scaffold.dart';

class ConfigDiagnosticsScreen extends ConsumerWidget {
  const ConfigDiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(appBootstrapProvider);
    final config = ref.watch(businessConfigProvider);
    return SideCarScaffold(
      showBack: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ScreenIntro(
            title: 'Connection status',
            description: 'Configuration and service availability.',
          ),
          const SizedBox(height: 24),
          _StatusRow(
            label: 'Firebase',
            value: bootstrap.firebaseReady ? 'Connected' : 'Not configured',
          ),
          const SizedBox(height: 10),
          config.when(
            data: (value) => _ConfigValues(config: value),
            error: (error, _) =>
                _StatusRow(label: 'Remote Config', value: '$error'),
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
          const SizedBox(height: 22),
          OutlinedButton(
            onPressed: AppHaptics.wrap(() async {
              await ref.read(businessConfigRepositoryProvider).refresh();
              ref.invalidate(businessConfigProvider);
            }),
            child: const Text('Refresh backend config'),
          ),
        ],
      ),
    );
  }
}

class _ConfigValues extends StatelessWidget {
  const _ConfigValues({required this.config});

  final BusinessConfig config;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _StatusRow(label: 'Config version', value: config.version),
        const SizedBox(height: 10),
        _StatusRow(
          label: 'Allowed schools',
          value: config.allowedSchoolDomains.join(', '),
        ),
        const SizedBox(height: 10),
        _StatusRow(
          label: 'IRS mileage rate',
          value: '\$${config.irsMileageRate.toStringAsFixed(2)}/mile',
        ),
        const SizedBox(height: 10),
        _StatusRow(
          label: 'Service fee',
          value: config.serviceFeeType == ServiceFeeType.percentage
              ? '${config.serviceFeeValue.toStringAsFixed(0)}%'
              : '\$${config.serviceFeeValue.toStringAsFixed(2)}',
        ),
        const SizedBox(height: 10),
        _StatusRow(
          label: 'Payment window',
          value: '${config.paymentExpirationHours} hours',
        ),
        const SizedBox(height: 10),
        _StatusRow(
          label: 'Auto-complete',
          value: '${config.tripAutoCompleteHours} hours',
        ),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F4),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
