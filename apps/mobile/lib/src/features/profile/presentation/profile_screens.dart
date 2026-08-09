import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sidecar/src/core/errors/app_failure.dart';
import 'package:sidecar/src/core/platform/app_haptics.dart';
import 'package:sidecar/src/core/widgets/device_settings.dart';
import 'package:sidecar/src/core/widgets/sidecar_scaffold.dart';
import 'package:sidecar/src/features/auth/domain/auth_repository.dart';
import 'package:sidecar/src/features/profile/domain/profile_repository.dart';
import 'package:sidecar/src/features/profile/domain/user_profile.dart';
import 'package:sidecar/src/features/verification/domain/verification_repository.dart';
import 'package:sidecar/src/routing/app_router.dart';
import 'package:sidecar/src/theme/app_theme.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _age = TextEditingController();
  final _picker = ImagePicker();
  UserProfile? _existing;
  String _gender = 'Female';
  String? _language;
  Uint8List? _photoBytes;
  String _photoContentType = 'image/jpeg';
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
      final profile = await ref
          .read(profileRepositoryProvider)
          .loadCurrentProfile();
      if (!mounted) return;
      _existing = profile;
      _age.text = profile?.age == 0 ? '' : profile!.age.toString();
      _gender = profile?.gender.isNotEmpty == true ? profile!.gender : 'Female';
      _language = profile?.language.isNotEmpty == true
          ? profile!.language
          : null;
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Object {
      if (mounted) {
        setState(() => _error = 'We could not load your profile. Try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _age.dispose();
    super.dispose();
  }

  Future<void> _leaveProfileSetup() async {
    if (context.canPop()) {
      context.pop();
      return;
    }
    await ref.read(authRepositoryProvider).signOut();
    if (mounted) context.go(AppRoutes.welcome);
  }

  Future<void> _choosePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      useSafeArea: true,
      builder: (context) => const _PhotoSourceSheet(),
    );
    if (source == null) return;
    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 1600,
        preferredCameraDevice: CameraDevice.front,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photoBytes = bytes;
        _photoContentType = image.mimeType ?? 'image/jpeg';
        _error = null;
      });
    } on PlatformException {
      if (mounted) context.push(AppRoutes.photoPermission);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final currentUser = ref.read(authRepositoryProvider).currentUser;
    if (currentUser == null) {
      setState(() => _error = 'Please sign in again.');
      return;
    }
    if (_photoBytes == null && (_existing?.photoUrl.isEmpty ?? true)) {
      setState(() => _error = 'Add a profile photo to continue.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repository = ref.read(profileRepositoryProvider);
      var photoUrl = _existing?.photoUrl ?? '';
      if (_photoBytes != null) {
        photoUrl = await repository.uploadProfilePhoto(
          bytes: _photoBytes!,
          contentType: _photoContentType,
        );
      }
      final emailName = currentUser.email.split('@').first;
      final nameParts = emailName
          .split(RegExp(r'[._-]'))
          .where((part) => part.isNotEmpty)
          .toList();
      final profile = UserProfile(
        userId: currentUser.id,
        firstName: _existing?.firstName.isNotEmpty == true
            ? _existing!.firstName
            : (nameParts.isEmpty ? 'Student' : _capitalize(nameParts.first)),
        lastName: _existing?.lastName.isNotEmpty == true
            ? _existing!.lastName
            : (nameParts.length > 1 ? _capitalize(nameParts.last) : 'Member'),
        school: _existing?.school.isNotEmpty == true
            ? _existing!.school
            : 'UC Santa Barbara',
        age: int.parse(_age.text.trim()),
        gender: _gender,
        language: _language!,
        homeBase: _existing?.homeBase ?? '',
        major: _existing?.major ?? '',
        graduationYear: _existing?.graduationYear ?? 0,
        photoUrl: photoUrl,
        primaryRole: _existing?.primaryRole,
      );
      await repository.saveProfile(profile);
      ref.invalidate(currentProfileProvider);
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(
          profile.primaryRole == null
              ? AppRoutes.onboarded
              : AppRoutes.verification,
        );
      }
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Object {
      if (mounted) {
        setState(
          () => _error = 'We could not save your profile. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1).toLowerCase()}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final initials = [_existing?.firstName, _existing?.lastName]
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .map((value) => value[0])
        .join();

    return SideCarScaffold(
      showBack: true,
      onBack: _leaveProfileSetup,
      bottom: FilledButton(
        onPressed: AppHaptics.wrap(_saving ? null : _submit),
        child: Text(_saving ? 'Saving…' : 'Continue'),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text(
                'Set up your profile',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Semantics(
                button: true,
                label: 'Choose profile photo',
                child: GestureDetector(
                  onTap: AppHaptics.wrap(_choosePhoto),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: 43,
                        backgroundColor: const Color(0xFFE8E8E8),
                        foregroundImage: _photoBytes == null
                            ? null
                            : MemoryImage(_photoBytes!),
                        child: _photoBytes == null
                            ? Text(
                                initials.isEmpty ? 'SC' : initials,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(color: AppColors.secondaryInk),
                              )
                            : null,
                      ),
                      const Positioned(
                        right: -1,
                        bottom: 1,
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: AppColors.ink,
                          child: Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: FormFieldBlock(
                    label: 'Age',
                    child: TextFormField(
                      controller: _age,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      decoration: const InputDecoration(hintText: '20'),
                      validator: (value) {
                        final age = int.tryParse(value?.trim() ?? '');
                        if (age == null || age < 18 || age > 100) {
                          return 'Enter a valid age';
                        }
                        return null;
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FormFieldBlock(
                    label: 'Gender',
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _gender,
                      items: const [
                        DropdownMenuItem(
                          value: 'Female',
                          child: Text('Female'),
                        ),
                        DropdownMenuItem(value: 'Male', child: Text('Male')),
                        DropdownMenuItem(
                          value: 'Non-binary',
                          child: Text('Non-binary'),
                        ),
                        DropdownMenuItem(
                          value: 'Prefer not to say',
                          child: Text('Prefer not to say'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _gender = value);
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            FormFieldBlock(
              label: 'Language',
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _language,
                hint: const Text('Select spoken language'),
                items: [
                  for (final language in {
                    ...supportedSpokenLanguages,
                    ?_language,
                  })
                    DropdownMenuItem(value: language, child: Text(language)),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _language = value),
                validator: (value) => value == null || value.isEmpty
                    ? 'Select your spoken language'
                    : null,
              ),
            ),
            SideCarErrorText(_error),
          ],
        ),
      ),
    );
  }
}

class _PhotoSourceSheet extends StatelessWidget {
  const _PhotoSourceSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Add a profile photo',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a clear photo of yourself.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 22),
          _PhotoSourceTile(
            icon: Icons.camera_alt_outlined,
            title: 'Take a photo',
            subtitle: 'Use your camera',
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
          const SizedBox(height: 10),
          _PhotoSourceTile(
            icon: Icons.photo_library_outlined,
            title: 'Choose from library',
            subtitle: 'Pick an existing photo',
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
      ),
    );
  }
}

class _PhotoSourceTile extends StatelessWidget {
  const _PhotoSourceTile({
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
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: AppHaptics.wrap(onTap),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(icon, size: 25),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.labelLarge),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class PhotoPermissionScreen extends StatelessWidget {
  const PhotoPermissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SideCarScaffold(
      showBack: true,
      onBack: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(AppRoutes.profile);
        }
      },
      bottom: FilledButton(
        onPressed: AppHaptics.wrap(DeviceSettings.openAppSettings),
        child: const Text('Open Settings'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ScreenIntro(
            title: 'Photo access needed',
            description:
                'Allow photo access in Settings to choose a profile picture.',
          ),
          const SizedBox(height: 24),
          const SideCarInfoCard(
            title: 'Your privacy matters',
            message:
                'SideCar only accesses the photo you choose for your profile.',
            icon: Icons.photo_library_outlined,
          ),
        ],
      ),
    );
  }
}

class OnboardedScreen extends ConsumerWidget {
  const OnboardedScreen({super.key});

  Future<void> _chooseRole(
    BuildContext context,
    WidgetRef ref,
    PrimaryRole role,
  ) async {
    try {
      await ref.read(profileRepositoryProvider).setPrimaryRole(role);
      ref.invalidate(currentProfileProvider);
      final verification = await ref
          .read(verificationRepositoryProvider)
          .loadCurrentVerification();
      if (!context.mounted) return;
      context.go(
        verification.canUseRideFeatures(role)
            ? AppRoutes.home
            : AppRoutes.verification,
      );
    } on AppFailure catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).value;
    final firstName = profile?.firstName ?? 'there';
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            children: [
              const Spacer(flex: 3),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppColors.softSurface,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_rounded, size: 18),
                    SizedBox(width: 5),
                    Text('Verified'),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Welcome aboard, $firstName',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              Text(
                "You're all set!\nHow will you mostly use SideCar?",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(flex: 2),
              FilledButton(
                onPressed: AppHaptics.wrap(
                  () => _chooseRole(context, ref, PrimaryRole.rider),
                ),
                child: const Text('Book a ride'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: AppHaptics.wrap(
                  () => _chooseRole(context, ref, PrimaryRole.driver),
                ),
                child: const Text('Post a ride'),
              ),
              const SizedBox(height: 14),
              Text(
                'You can switch between being a rider or a driver\nanytime in settings.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileGateScreen extends ConsumerWidget {
  const ProfileGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final profile = ref.watch(currentProfileProvider).value;
    final isComplete = profile?.isComplete == true;
    final hasRole = profile?.primaryRole != null;
    return SideCarScaffold(
      showBack: true,
      onBack: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(AppRoutes.onboarded);
        }
      },
      bottom: FilledButton(
        onPressed: AppHaptics.wrap(
          isComplete && hasRole
              ? () => context.go(AppRoutes.verification)
              : isComplete
              ? () => context.go(AppRoutes.onboarded)
              : () => context.go(AppRoutes.profile),
        ),
        child: Text(
          isComplete && hasRole
              ? 'Change ride preference'
              : isComplete
              ? 'Choose ride preference'
              : 'Finish profile',
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScreenIntro(
            title: isComplete
                ? 'Your profile is ready'
                : 'Complete your profile',
            description: isComplete
                ? 'Your details are complete and your account is ready to use.'
                : 'Finish the required details before requesting or posting a ride.',
          ),
          const SizedBox(height: 24),
          _GateStep(
            title: 'School email',
            subtitle: user?.email ?? 'Required',
            complete: user?.emailVerified == true,
          ),
          const SizedBox(height: 10),
          _GateStep(
            title: 'Personal details',
            subtitle: profile == null
                ? 'Required'
                : '${profile.displayName} · ${profile.age} · ${profile.gender}',
            complete:
                profile != null &&
                profile.displayName.isNotEmpty &&
                profile.age >= 18 &&
                profile.gender.isNotEmpty &&
                profile.language.isNotEmpty,
          ),
          const SizedBox(height: 10),
          _GateStep(
            title: 'Profile photo',
            subtitle: profile?.photoUrl.isNotEmpty == true
                ? 'Added'
                : 'Required',
            complete: profile?.photoUrl.isNotEmpty == true,
          ),
          const SizedBox(height: 18),
          Text(
            isComplete
                ? 'You can update these details from your profile at any time.'
                : 'Ride actions stay locked until every required profile item is complete.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (isComplete) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: AppHaptics.wrap(() async {
                  await ref.read(authRepositoryProvider).signOut();
                  if (context.mounted) context.go(AppRoutes.welcome);
                }),
                child: const Text('Log out'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GateStep extends StatelessWidget {
  const _GateStep({
    required this.title,
    required this.subtitle,
    required this.complete,
  });

  final String title;
  final String subtitle;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
            complete
                ? Icons.check_circle_outline_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 23,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.labelLarge),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Text(
            complete ? 'Complete' : 'Required',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
