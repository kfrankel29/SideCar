import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sidecar/src/core/errors/app_failure.dart';
import 'package:sidecar/src/core/platform/app_haptics.dart';
import 'package:sidecar/src/core/widgets/sidecar_scaffold.dart';
import 'package:sidecar/src/features/profile/domain/profile_repository.dart';
import 'package:sidecar/src/features/profile/domain/user_profile.dart';
import 'package:sidecar/src/features/verification/domain/verification_models.dart';
import 'package:sidecar/src/features/verification/domain/verification_repository.dart';
import 'package:sidecar/src/routing/app_router.dart';
import 'package:sidecar/src/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class VerificationHubScreen extends ConsumerWidget {
  const VerificationHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).value;
    final role = profile?.primaryRole ?? PrimaryRole.rider;
    final verification = ref.watch(currentVerificationProvider);
    final summary = verification.value ?? const VerificationSummary();
    final ready = summary.canUseRideFeatures(role);

    return SideCarScaffold(
      showBack: true,
      onBack: () =>
          context.canPop() ? context.pop() : context.go(AppRoutes.onboarded),
      bottom: FilledButton(
        onPressed: AppHaptics.wrap(
          ready
              ? () => context.go(AppRoutes.verificationComplete)
              : () => _nextStep(context, role, summary),
        ),
        child: Text(ready ? 'Done' : 'Continue verification'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ScreenIntro(
            title: 'One quick check',
            description:
                'Everyone on SideCar is ID-verified. It protects you as much as everyone else.',
          ),
          const SizedBox(height: 24),
          _VerificationTile(
            icon: Icons.badge_outlined,
            title: 'Snap your ID / driver license',
            subtitle: _statusText(
              summary.identity,
              idle: 'Verified securely by Stripe in about 30 seconds',
            ),
            complete: summary.identityComplete,
            onTap: () => context.push(
              role == PrimaryRole.driver
                  ? AppRoutes.driverLicense
                  : AppRoutes.identityVerification,
            ),
          ),
          if (role == PrimaryRole.driver) ...[
            const SizedBox(height: 12),
            _VerificationTile(
              icon: Icons.directions_car_outlined,
              title: 'Add your vehicle',
              subtitle: summary.vehicleComplete
                  ? summary.vehicle!.makeAndModel
                  : 'Year, make, model, color, and license plate',
              complete: summary.vehicleComplete,
              onTap: () => context.push(AppRoutes.vehicleProfile),
            ),
            const SizedBox(height: 12),
            _VerificationTile(
              icon: Icons.car_crash_outlined,
              title: 'Verify car insurance',
              subtitle: _statusText(
                summary.insurance,
                idle: 'Automatic check through Axle',
              ),
              complete: summary.insuranceComplete,
              onTap: () => context.push(AppRoutes.insuranceVerification),
            ),
          ],
          if (verification.isLoading) ...[
            const SizedBox(height: 18),
            const LinearProgressIndicator(),
          ],
          if (verification.hasError) ...[
            const SizedBox(height: 12),
            const SideCarErrorText(
              'We could not refresh your verification status. Pull down or try again.',
            ),
          ],
          const SizedBox(height: 22),
          Text(
            'Your documents are handled by the verification provider. SideCar stores only the result needed to keep the community safe.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 14),
            TextButton(
              onPressed: AppHaptics.wrap(
                () => context.push(AppRoutes.safetyTools),
              ),
              child: const Text('Safety & reporting'),
            ),
          ],
        ],
      ),
    );
  }

  void _nextStep(
    BuildContext context,
    PrimaryRole role,
    VerificationSummary summary,
  ) {
    if (!summary.identityComplete) {
      context.push(
        role == PrimaryRole.driver
            ? AppRoutes.driverLicense
            : AppRoutes.identityVerification,
      );
    } else if (role == PrimaryRole.driver && !summary.vehicleComplete) {
      context.push(AppRoutes.vehicleProfile);
    } else if (role == PrimaryRole.driver && !summary.insuranceComplete) {
      context.push(AppRoutes.insuranceVerification);
    }
  }
}

String _statusText(VerificationStatus status, {required String idle}) {
  return switch (status) {
    VerificationStatus.notStarted => idle,
    VerificationStatus.pending => 'Verification is being reviewed',
    VerificationStatus.verified => 'Verified',
    VerificationStatus.requiresAction => 'More information is required',
    VerificationStatus.failed => 'Verification was not completed',
  };
}

class _VerificationTile extends StatelessWidget {
  const _VerificationTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.complete,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool complete;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: AppHaptics.wrap(onTap),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
        decoration: BoxDecoration(
          color: complete ? AppColors.success : Colors.white,
          border: Border.all(
            color: complete ? Colors.transparent : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              complete ? Icons.check_circle_outline_rounded : icon,
              size: 24,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 22),
          ],
        ),
      ),
    );
  }
}

class IdentityVerificationScreen extends ConsumerStatefulWidget {
  const IdentityVerificationScreen({super.key});

  @override
  ConsumerState<IdentityVerificationScreen> createState() =>
      _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState
    extends ConsumerState<IdentityVerificationScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uri = await ref
          .read(verificationRepositoryProvider)
          .createIdentityVerificationSession();
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        throw const AppFailure('We could not open Stripe verification.');
      }
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Object {
      if (mounted) {
        setState(
          () => _error = 'We could not start verification. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status =
        ref.watch(currentVerificationProvider).value?.identity ??
        VerificationStatus.notStarted;
    final complete = status == VerificationStatus.verified;
    return SideCarScaffold(
      showBack: true,
      bottom: FilledButton(
        onPressed: AppHaptics.wrap(
          complete
              ? () => context.pop()
              : _loading
              ? null
              : _start,
        ),
        child: Text(
          complete
              ? 'Done'
              : _loading
              ? 'Opening Stripe…'
              : 'Verify with Stripe',
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ScreenIntro(
            title: 'Verify your identity',
            description:
                'Use a valid U.S. ID or driver license. Make sure every detail is readable.',
          ),
          const SizedBox(height: 24),
          SideCarInfoCard(
            title: complete
                ? 'Identity verified'
                : 'Secure Stripe verification',
            message: complete
                ? 'Stripe completed your document and identity checks.'
                : 'Stripe securely collects and checks your document. SideCar does not store the document image.',
            icon: complete
                ? Icons.verified_user_outlined
                : Icons.badge_outlined,
            color: complete ? AppColors.success : AppColors.information,
          ),
          const SizedBox(height: 14),
          const _DocumentRequirement(
            title: 'Government-issued ID',
            subtitle: 'Driver license, state ID, or passport',
          ),
          const SizedBox(height: 10),
          const _DocumentRequirement(
            title: 'Live selfie',
            subtitle: 'Used by Stripe to match your document',
          ),
          const SizedBox(height: 16),
          Text(
            _statusText(status, idle: 'Not started'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          SideCarErrorText(_error),
        ],
      ),
    );
  }
}

class DriverLicenseUploadScreen extends ConsumerStatefulWidget {
  const DriverLicenseUploadScreen({super.key});

  @override
  ConsumerState<DriverLicenseUploadScreen> createState() =>
      _DriverLicenseUploadScreenState();
}

class _DriverLicenseUploadScreenState
    extends ConsumerState<DriverLicenseUploadScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uri = await ref
          .read(verificationRepositoryProvider)
          .createIdentityVerificationSession();
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        throw const AppFailure('We could not open Stripe verification.');
      }
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Object {
      if (mounted) {
        setState(
          () => _error = 'We could not start verification. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final complete =
        ref.watch(currentVerificationProvider).value?.identityComplete == true;
    return SideCarScaffold(
      showBack: true,
      bottom: FilledButton(
        onPressed: AppHaptics.wrap(
          complete
              ? () => context.pop()
              : _loading
              ? null
              : _start,
        ),
        child: Text(
          complete
              ? 'Done'
              : _loading
              ? 'Opening Stripe…'
              : 'Continue',
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ScreenIntro(
            title: 'Add your driver license',
            description:
                'Use a valid U.S. driver license. Make sure every detail is readable.',
          ),
          const SizedBox(height: 22),
          _DocumentRequirement(
            title: 'License front',
            subtitle: complete ? 'Verified' : 'Required · not uploaded',
            onTap: complete || _loading ? null : _start,
          ),
          const SizedBox(height: 10),
          _DocumentRequirement(
            title: 'License back',
            subtitle: complete ? 'Verified' : 'Required · not uploaded',
            onTap: complete || _loading ? null : _start,
          ),
          const SizedBox(height: 14),
          const SideCarInfoCard(
            title: 'Stored securely',
            message:
                'License images are encrypted and used only for verification.',
            icon: Icons.verified_user_outlined,
            color: AppColors.information,
          ),
          SideCarErrorText(_error),
        ],
      ),
    );
  }
}

class _DocumentRequirement extends StatelessWidget {
  const _DocumentRequirement({
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap == null ? null : AppHaptics.wrap(onTap!),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.open_in_new_rounded, size: 23),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.labelLarge),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class VehicleProfileScreen extends ConsumerStatefulWidget {
  const VehicleProfileScreen({super.key});

  @override
  ConsumerState<VehicleProfileScreen> createState() =>
      _VehicleProfileScreenState();
}

class _VehicleProfileScreenState extends ConsumerState<VehicleProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _year = TextEditingController();
  final _makeAndModel = TextEditingController();
  final _color = TextEditingController();
  final _plate = TextEditingController();
  final _picker = ImagePicker();
  String _photoUrl = '';
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final vehicle =
          (await ref
                  .read(verificationRepositoryProvider)
                  .loadCurrentVerification())
              .vehicle;
      if (!mounted || vehicle == null) return;
      _year.text = vehicle.year == 0 ? '' : vehicle.year.toString();
      _makeAndModel.text = vehicle.makeAndModel;
      _color.text = vehicle.color;
      _plate.text = vehicle.licensePlate;
      _photoUrl = vehicle.photoUrl;
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _year.dispose();
    _makeAndModel.dispose();
    _color.dispose();
    _plate.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_photoUrl.isEmpty) {
      setState(() => _error = 'Add a clear exterior vehicle photo.');
      return;
    }
    final makeAndModel = _splitMakeAndModel(_makeAndModel.text);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(verificationRepositoryProvider)
          .saveVehicle(
            VehicleProfile(
              year: int.parse(_year.text),
              make: makeAndModel.$1,
              model: makeAndModel.$2,
              color: _color.text,
              licensePlate: _plate.text,
              photoUrl: _photoUrl,
            ),
          );
      ref.invalidate(currentVerificationProvider);
      if (mounted) context.pop();
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _chooseVehiclePhoto() async {
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from library'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
      if (source == null || !mounted) return;
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 2200,
      );
      if (image == null) return;
      setState(() {
        _saving = true;
        _error = null;
      });
      final url = await ref
          .read(verificationRepositoryProvider)
          .uploadVehiclePhoto(
            bytes: await image.readAsBytes(),
            contentType: image.mimeType ?? 'image/jpeg',
          );
      if (mounted) setState(() => _photoUrl = url);
    } on PlatformException {
      if (mounted) {
        setState(
          () => _error =
              'Allow camera or photo access in Settings and try again.',
        );
      }
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SideCarScaffold(
      showBack: true,
      bottom: FilledButton(
        onPressed: AppHaptics.wrap(_saving || _loading ? null : _save),
        child: Text(_saving ? 'Saving…' : 'Save vehicle'),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ScreenIntro(
              title: 'Your vehicle',
              description:
                  'This information appears to riders after a booking is confirmed.',
            ),
            const SizedBox(height: 22),
            FormFieldBlock(
              label: 'Year',
              child: TextFormField(
                controller: _year,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                decoration: const InputDecoration(hintText: '2021'),
                validator: (value) {
                  final year = int.tryParse(value ?? '');
                  if (year == null ||
                      year < 1980 ||
                      year > DateTime.now().year + 1) {
                    return 'Enter a valid year';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 16),
            FormFieldBlock(
              label: 'Make and model',
              child: TextFormField(
                controller: _makeAndModel,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                inputFormatters: [LengthLimitingTextInputFormatter(80)],
                decoration: const InputDecoration(hintText: 'Honda CR-V'),
                validator: (value) {
                  if (_splitMakeAndModel(value ?? '').$2.isEmpty) {
                    return 'Enter make and model';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: FormFieldBlock(
                    label: 'Color',
                    child: _requiredField(
                      _color,
                      'White',
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FormFieldBlock(
                    label: 'License plate',
                    child: _requiredField(
                      _plate,
                      '8ABC123',
                      capitalization: TextCapitalization.characters,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _DocumentAction(
              icon: Icons.directions_car_outlined,
              title: 'Vehicle photo',
              subtitle: _photoUrl.isEmpty
                  ? 'Add a clear exterior photo'
                  : 'Photo added',
              onTap: _chooseVehiclePhoto,
            ),
            SideCarErrorText(_error),
          ],
        ),
      ),
    );
  }

  (String, String) _splitMakeAndModel(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    final separator = normalized.lastIndexOf(' ');
    if (separator < 1 || separator == normalized.length - 1) {
      return (normalized, '');
    }
    return (
      normalized.substring(0, separator),
      normalized.substring(separator + 1),
    );
  }

  TextFormField _requiredField(
    TextEditingController controller,
    String hint, {
    TextInputAction textInputAction = TextInputAction.done,
    TextCapitalization capitalization = TextCapitalization.words,
  }) {
    return TextFormField(
      controller: controller,
      textInputAction: textInputAction,
      textCapitalization: capitalization,
      inputFormatters: [LengthLimitingTextInputFormatter(40)],
      decoration: InputDecoration(hintText: hint),
      validator: (value) =>
          value == null || value.trim().isEmpty ? 'Required' : null,
    );
  }
}

class InsuranceVerificationScreen extends ConsumerWidget {
  const InsuranceVerificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary =
        ref.watch(currentVerificationProvider).value ??
        const VerificationSummary();
    final manualReviewAvailable =
        summary.insurance == VerificationStatus.requiresAction ||
        summary.insurance == VerificationStatus.failed;
    return SideCarScaffold(
      showBack: true,
      bottom: FilledButton(
        onPressed: AppHaptics.wrap(
          summary.insuranceComplete
              ? () => context.pop()
              : manualReviewAvailable
              ? () => context.push(AppRoutes.insuranceFallback)
              : null,
        ),
        child: Text(
          summary.insuranceComplete
              ? 'Done'
              : manualReviewAvailable
              ? 'Upload insurance document'
              : 'Automatic check unavailable',
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ScreenIntro(
            title: 'Verify auto insurance',
            description:
                'Drivers need an active policy for the vehicle they post on SideCar.',
          ),
          const SizedBox(height: 24),
          SideCarInfoCard(
            title: summary.insuranceComplete
                ? 'Insurance verified'
                : 'Automatic check through Axle',
            message: summary.insuranceComplete
                ? 'Your current policy is verified.'
                : manualReviewAvailable
                ? 'Axle could not confirm this policy automatically. You can submit a current insurance card for review.'
                : 'Automatic insurance verification is temporarily unavailable. Please try again later.',
            icon: Icons.car_crash_outlined,
            color: summary.insuranceComplete
                ? AppColors.success
                : AppColors.warning,
          ),
          const SizedBox(height: 16),
          Text(
            summary.manualInsuranceSubmitted
                ? 'Your document is waiting for review. Most reviews are completed within one business day.'
                : 'If the automatic check cannot confirm your policy, upload a current insurance card for review.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class InsuranceFallbackScreen extends ConsumerStatefulWidget {
  const InsuranceFallbackScreen({super.key});

  @override
  ConsumerState<InsuranceFallbackScreen> createState() =>
      _InsuranceFallbackScreenState();
}

class _InsuranceFallbackScreenState
    extends ConsumerState<InsuranceFallbackScreen> {
  final _picker = ImagePicker();
  Uint8List? _bytes;
  String _contentType = 'image/jpeg';
  String _fileName = '';
  bool _saving = false;
  String? _error;

  Future<void> _takePhoto() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
        maxWidth: 2000,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _contentType = image.mimeType ?? 'image/jpeg';
        _fileName = image.name;
        _error = null;
      });
    } on PlatformException {
      if (mounted) {
        setState(
          () => _error = 'Allow camera access in Settings and try again.',
        );
      }
    }
  }

  Future<void> _chooseFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
        withData: true,
      );
      final file = result?.files.single;
      if (file?.bytes == null) return;
      final extension = file!.extension?.toLowerCase();
      setState(() {
        _bytes = file.bytes;
        _fileName = file.name;
        _contentType = switch (extension) {
          'png' => 'image/png',
          'pdf' => 'application/pdf',
          _ => 'image/jpeg',
        };
        _error = null;
      });
    } on PlatformException {
      if (mounted) {
        setState(() => _error = 'We could not open that file. Try again.');
      }
    }
  }

  Future<void> _submit() async {
    if (_bytes == null) {
      setState(() => _error = 'Choose your insurance document first.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(verificationRepositoryProvider)
          .submitInsuranceDocument(bytes: _bytes!, contentType: _contentType);
      ref.invalidate(currentVerificationProvider);
      if (mounted) context.pop();
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SideCarScaffold(
      showBack: true,
      bottom: FilledButton(
        onPressed: AppHaptics.wrap(_saving ? null : _submit),
        child: Text(_saving ? 'Submitting…' : 'Submit for review'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ScreenIntro(
            title: 'Verify auto insurance',
            description:
                'We couldn’t confirm this policy automatically through Axle.',
          ),
          const SizedBox(height: 22),
          const SideCarInfoCard(
            title: 'Manual review available',
            message:
                'Upload a current insurance card showing your name, vehicle, and policy dates.',
            icon: Icons.car_crash_outlined,
            color: AppColors.warning,
          ),
          const SizedBox(height: 16),
          _DocumentAction(
            icon: Icons.camera_alt_outlined,
            title: 'Take a photo',
            subtitle: 'Photograph your insurance card',
            onTap: _takePhoto,
          ),
          const SizedBox(height: 10),
          _DocumentAction(
            icon: Icons.upload_file_outlined,
            title: 'Choose a file',
            subtitle: 'Upload JPG, PNG, or PDF',
            onTap: _chooseFile,
          ),
          if (_fileName.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Selected: $_fileName',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Most manual reviews are completed within one business day.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          SideCarErrorText(_error),
        ],
      ),
    );
  }
}

class _DocumentAction extends StatelessWidget {
  const _DocumentAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: AppHaptics.wrap(onTap),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 24),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.labelLarge),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class VerificationCompleteScreen extends StatelessWidget {
  const VerificationCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SideCarScaffold(
      bottom: FilledButton(
        onPressed: AppHaptics.wrap(() => context.go(AppRoutes.home)),
        child: const Text('Continue to SideCar'),
      ),
      fillViewport: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.verified_user_outlined, size: 42),
          const SizedBox(height: 20),
          Text(
            'Verification complete',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 9),
          Text(
            'Your account is ready for the ride features included in your selected role.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
