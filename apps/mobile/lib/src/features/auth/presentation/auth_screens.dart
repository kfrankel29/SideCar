import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sidecar/src/core/config/business_config_repository.dart';
import 'package:sidecar/src/core/errors/app_failure.dart';
import 'package:sidecar/src/core/platform/app_haptics.dart';
import 'package:sidecar/src/core/widgets/sidecar_scaffold.dart';
import 'package:sidecar/src/features/auth/domain/auth_repository.dart';
import 'package:sidecar/src/features/profile/domain/profile_repository.dart';
import 'package:sidecar/src/features/profile/domain/user_profile.dart';
import 'package:sidecar/src/routing/app_router.dart';
import 'package:sidecar/src/theme/app_theme.dart';

String? _emailError(String value) {
  final email = value.trim();
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
    return 'Enter a valid school email.';
  }
  return null;
}

const _studentEmailRequired = 'Students only — ucsb.edu email required';

void _popOrGo(BuildContext context, String fallbackRoute) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallbackRoute);
  }
}

String? _passwordError(String value) {
  if (value.length < 8 || !RegExp(r'\d').hasMatch(value)) {
    return 'Use 8+ characters with at least one number.';
  }
  return null;
}

String _routeForProfile(UserProfile profile) {
  if (!profile.isComplete) return AppRoutes.profile;
  return profile.primaryRole == null
      ? AppRoutes.onboarded
      : AppRoutes.profileGate;
}

class OpeningScreen extends ConsumerStatefulWidget {
  const OpeningScreen({super.key, this.autoContinue = true});

  final bool autoContinue;

  @override
  ConsumerState<OpeningScreen> createState() => _OpeningScreenState();
}

class _OpeningScreenState extends ConsumerState<OpeningScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.autoContinue) unawaited(_continueFromLaunch());
  }

  Future<void> _continueFromLaunch() async {
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;

    try {
      final authRepository = ref.read(authRepositoryProvider);
      final user = await authRepository.validateCurrentSession();
      if (!mounted) return;
      if (user == null) {
        context.go(AppRoutes.welcome);
        return;
      }
      final profile = await ref
          .read(profileRepositoryProvider)
          .loadCurrentProfile();
      if (!mounted) return;
      if (profile == null) {
        await authRepository.signOut();
        if (mounted) context.go(AppRoutes.welcome);
        return;
      }
      if (!user.emailVerified) {
        context.go(
          '${AppRoutes.verifyEmail}?email=${Uri.encodeQueryComponent(user.email)}',
        );
        return;
      }
      context.go(_routeForProfile(profile));
    } on Object {
      try {
        await ref.read(authRepositoryProvider).signOut();
      } on Object {
        // Server state could not be verified, so continue to the signed-out UI.
      }
      if (mounted) context.go(AppRoutes.welcome);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'SideCar',
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Call it. Ride it.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 30,
              child: Center(
                child: SizedBox(
                  width: 36,
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: Color(0xFFE4E4E4),
                    color: AppColors.ink,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            children: [
              const SizedBox(height: 88),
              GestureDetector(
                onLongPress: AppHaptics.wrap(
                  () => context.push(AppRoutes.diagnostics),
                ),
                child: Text(
                  'SideCar',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
              ),
              const SizedBox(height: 109),
              Text(
                'Never ride the 101 alone',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Catch rides between the Bay and UCSB\nwith verified students.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 64),
              FilledButton(
                onPressed: AppHaptics.wrap(
                  () => context.push(AppRoutes.signUp),
                ),
                child: const Text('Create account'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: AppHaptics.wrap(() => context.push(AppRoutes.login)),
                child: const Text('Log in'),
              ),
              const SizedBox(height: 27),
              Text(
                _studentEmailRequired,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await ref
          .read(authRepositoryProvider)
          .signIn(email: _email.text, password: _password.text);
      if (!mounted) return;
      if (!user.emailVerified) {
        context.push(
          '${AppRoutes.verifyEmail}?email=${Uri.encodeQueryComponent(user.email)}',
        );
        return;
      }
      final profile = await ref
          .read(profileRepositoryProvider)
          .loadCurrentProfile();
      if (!mounted) return;
      if (profile == null) {
        await ref.read(authRepositoryProvider).signOut();
        if (mounted) context.go(AppRoutes.welcome);
        return;
      }
      context.go(_routeForProfile(profile));
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _continueWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      final profile = await ref
          .read(profileRepositoryProvider)
          .loadCurrentProfile();
      if (!mounted) return;
      if (profile == null) {
        await ref.read(authRepositoryProvider).signOut();
        if (mounted) context.go(AppRoutes.welcome);
        return;
      }
      context.go(_routeForProfile(profile));
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SideCarScaffold(
      showBack: true,
      onBack: () => _popOrGo(context, AppRoutes.welcome),
      fillViewport: true,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ScreenIntro(
              title: 'Welcome back',
              description: 'Log in to catch your next ride.',
            ),
            const SizedBox(height: 30),
            FormFieldBlock(
              label: 'School email',
              child: TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                validator: (value) => _emailError(value ?? ''),
              ),
            ),
            const SizedBox(height: 18),
            FormFieldBlock(
              label: 'Password',
              child: TextFormField(
                controller: _password,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _submit(),
                validator: (value) => value == null || value.isEmpty
                    ? 'Enter your password.'
                    : null,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: AppHaptics.wrap(
                  () => context.push(AppRoutes.forgotPassword),
                ),
                child: const Text('Forgot password?'),
              ),
            ),
            SideCarErrorText(_error),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: AppHaptics.wrap(_loading ? null : _submit),
              child: Text(_loading ? 'Signing in…' : 'Log in'),
            ),
            const SizedBox(height: 24),
            const _OrDivider(),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: AppHaptics.wrap(_loading ? null : _continueWithGoogle),
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.softSurface,
                side: BorderSide.none,
              ),
              child: const Text('Continue with Google'),
            ),
            const Spacer(),
            Center(
              child: TextButton(
                onPressed: AppHaptics.wrap(
                  () => context.push(AppRoutes.signUp),
                ),
                child: const Text('New here? Sign up'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _domainError;
  String? _error;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _domainError = null;
      _error = null;
    });
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final config = await ref.read(businessConfigRepositoryProvider).refresh();
      if (!config.allowsEmail(_email.text)) {
        if (mounted) setState(() => _domainError = _studentEmailRequired);
        return;
      }
      final user = await ref
          .read(authRepositoryProvider)
          .createStudentAccount(
            firstName: _firstName.text,
            lastName: _lastName.text,
            email: _email.text,
            password: _password.text,
          );
      if (!mounted) return;
      if (!user.emailVerified) {
        context.push(
          '${AppRoutes.verifyEmail}?email=${Uri.encodeQueryComponent(user.email)}',
        );
        return;
      }
      final profile = await ref
          .read(profileRepositoryProvider)
          .loadCurrentProfile();
      if (!mounted) return;
      if (profile == null) {
        await ref.read(authRepositoryProvider).signOut();
        if (mounted) context.go(AppRoutes.welcome);
        return;
      }
      context.go(_routeForProfile(profile));
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Object {
      if (mounted) {
        setState(
          () => _error = 'We could not create your account. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SideCarScaffold(
      showBack: true,
      onBack: () => _popOrGo(context, AppRoutes.welcome),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ScreenIntro(
              title: 'Create an account',
              description: 'Use your ucsb.edu email to sign up for SideCar.',
            ),
            const SizedBox(height: 28),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: FormFieldBlock(
                    label: 'First name',
                    child: TextFormField(
                      controller: _firstName,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Required'
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FormFieldBlock(
                    label: 'Last name',
                    child: TextFormField(
                      controller: _lastName,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Required'
                          : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            FormFieldBlock(
              label: 'School email',
              child: TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                onChanged: (_) {
                  if (_domainError != null) {
                    setState(() => _domainError = null);
                  }
                },
                validator: (value) => _emailError(value ?? ''),
                decoration: InputDecoration(errorText: _domainError),
              ),
            ),
            const SizedBox(height: 18),
            FormFieldBlock(
              label: 'Password',
              child: TextFormField(
                controller: _password,
                obscureText: true,
                onChanged: (_) => setState(() {}),
                validator: (value) => _passwordError(value ?? ''),
                decoration: const InputDecoration(hintText: '8+ characters'),
              ),
            ),
            SideCarErrorText(_error),
            const SizedBox(height: 45),
            FilledButton(
              onPressed: AppHaptics.wrap(_loading ? null : _submit),
              child: Text(_loading ? 'Creating account…' : 'Continue'),
            ),
            const SizedBox(height: 19),
            Text(
              'By clicking continue, you agree to the Terms of Service and Privacy Policy.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class OtpCodeInput extends StatefulWidget {
  const OtpCodeInput({
    required this.onChanged,
    super.key,
    this.autofocus = true,
  });

  final ValueChanged<String> onChanged;
  final bool autofocus;

  @override
  State<OtpCodeInput> createState() => _OtpCodeInputState();
}

class _OtpCodeInputState extends State<OtpCodeInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final code = _controller.text;
    return Semantics(
      textField: true,
      label: 'Six digit verification code',
      child: GestureDetector(
        onTap: _focusNode.requestFocus,
        child: Stack(
          children: [
            Row(
              children: List.generate(6, (index) {
                final filled = index < code.length;
                return Expanded(
                  child: Container(
                    height: 60,
                    margin: EdgeInsets.only(right: index == 5 ? 0 : 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: filled ? AppColors.softSurface : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: filled ? Colors.transparent : AppColors.border,
                      ),
                    ),
                    child: Text(
                      filled ? code[index] : '',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(fontSize: 24),
                    ),
                  ),
                );
              }),
            ),
            Positioned.fill(
              child: Opacity(
                opacity: 0.01,
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: widget.autofocus,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  onChanged: (value) {
                    setState(() {});
                    widget.onChanged(value);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({required this.email, super.key});

  final String email;

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  String _code = '';
  bool _loading = false;
  String? _error;
  int _seconds = 42;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _seconds = 42;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_seconds == 0) {
        timer.cancel();
      } else {
        setState(() => _seconds--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_code.length != 6) {
      setState(() => _error = 'Enter the complete six-digit code.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).verifyEmailCode(_code);
      if (mounted) context.go(AppRoutes.profile);
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_seconds > 0) return;
    try {
      await ref.read(authRepositoryProvider).resendEmailVerificationCode();
      setState(() => _error = null);
      _startTimer();
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SideCarScaffold(
      showBack: true,
      onBack: () async {
        await ref.read(authRepositoryProvider).signOut();
        if (!context.mounted) return;
        _popOrGo(context, AppRoutes.welcome);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScreenIntro(
            title: 'Check your inbox',
            description: 'We sent a 6-digit code to ${widget.email}',
          ),
          const SizedBox(height: 32),
          OtpCodeInput(onChanged: (value) => _code = value),
          const SizedBox(height: 20),
          TextButton(
            onPressed: AppHaptics.wrap(_seconds == 0 ? _resend : null),
            child: Text(
              _seconds == 0
                  ? "Didn't get it? Resend"
                  : "Didn't get it? Resend · 0:${_seconds.toString().padLeft(2, '0')}",
            ),
          ),
          SideCarErrorText(_error),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: AppHaptics.wrap(_loading ? null : _verify),
            child: Text(_loading ? 'Verifying…' : 'Verify email'),
          ),
        ],
      ),
    );
  }
}

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _loading = false;
  String? _domainError;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _domainError = null;
      _error = null;
    });
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final config = await ref.read(businessConfigRepositoryProvider).refresh();
      if (!config.allowsEmail(_email.text)) {
        if (mounted) setState(() => _domainError = _studentEmailRequired);
        return;
      }
      await ref
          .read(authRepositoryProvider)
          .requestPasswordResetCode(_email.text);
      if (!mounted) return;
      context.push(
        '${AppRoutes.resetCode}?email=${Uri.encodeQueryComponent(_email.text.trim().toLowerCase())}',
      );
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SideCarScaffold(
      showBack: true,
      onBack: () => _popOrGo(context, AppRoutes.login),
      bottom: FilledButton(
        onPressed: AppHaptics.wrap(_loading ? null : _submit),
        child: Text(_loading ? 'Sending…' : 'Send reset code'),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ScreenIntro(
              title: 'Reset your password',
              description:
                  "Enter your approved school email and we'll send a six-digit code.",
            ),
            const SizedBox(height: 28),
            FormFieldBlock(
              label: 'School email',
              child: TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                onChanged: (_) {
                  if (_domainError != null) {
                    setState(() => _domainError = null);
                  }
                },
                validator: (value) => _emailError(value ?? ''),
                decoration: InputDecoration(errorText: _domainError),
              ),
            ),
            const SizedBox(height: 18),
            const SideCarInfoCard(
              title: 'School account protection',
              message:
                  'Reset codes expire after ten minutes and can be used once.',
            ),
            SideCarErrorText(_error),
          ],
        ),
      ),
    );
  }
}

class PasswordResetCodeScreen extends ConsumerStatefulWidget {
  const PasswordResetCodeScreen({required this.email, super.key});

  final String email;

  @override
  ConsumerState<PasswordResetCodeScreen> createState() =>
      _PasswordResetCodeScreenState();
}

class _PasswordResetCodeScreenState
    extends ConsumerState<PasswordResetCodeScreen> {
  String _code = '';
  bool _loading = false;
  bool _resending = false;
  String? _error;

  Future<void> _resend() async {
    if (_resending) return;
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .requestPasswordResetCode(widget.email);
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Object {
      if (mounted) {
        setState(() => _error = 'We could not resend the code. Try again.');
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _verify() async {
    if (_code.length != 6) {
      setState(() => _error = 'Enter the complete six-digit code.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await ref
          .read(authRepositoryProvider)
          .verifyPasswordResetCode(email: widget.email, code: _code);
      if (!mounted) return;
      context.push(
        '${AppRoutes.newPassword}?email=${Uri.encodeQueryComponent(widget.email)}&token=${Uri.encodeQueryComponent(token)}',
      );
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SideCarScaffold(
      showBack: true,
      onBack: () => _popOrGo(context, AppRoutes.forgotPassword),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScreenIntro(
            title: 'Check your inbox',
            description: 'We sent a 6-digit code to ${widget.email}',
          ),
          const SizedBox(height: 32),
          OtpCodeInput(onChanged: (value) => _code = value),
          const SizedBox(height: 20),
          TextButton(
            onPressed: AppHaptics.wrap(_resending ? null : _resend),
            child: Text(
              _resending ? 'Sending another code…' : "Didn't get it? Resend",
            ),
          ),
          SideCarErrorText(_error),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: AppHaptics.wrap(_loading ? null : _verify),
            child: Text(_loading ? 'Verifying…' : 'Verify email'),
          ),
        ],
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('or', style: Theme.of(context).textTheme.bodySmall),
        ),
        const Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }
}

class NewPasswordScreen extends ConsumerStatefulWidget {
  const NewPasswordScreen({
    required this.email,
    required this.resetToken,
    super.key,
  });

  final String email;
  final String resetToken;

  @override
  ConsumerState<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends ConsumerState<NewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .completePasswordReset(
            email: widget.email,
            resetToken: widget.resetToken,
            newPassword: _password.text,
          );
      if (mounted) context.go(AppRoutes.passwordResetComplete);
    } on AppFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SideCarScaffold(
      showBack: true,
      onBack: () => _popOrGo(
        context,
        '${AppRoutes.resetCode}?email=${Uri.encodeQueryComponent(widget.email)}',
      ),
      bottom: FilledButton(
        onPressed: AppHaptics.wrap(_loading ? null : _submit),
        child: Text(_loading ? 'Updating…' : 'Update password'),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ScreenIntro(
              title: 'Create a new password',
              description: 'Use at least eight characters with one number.',
            ),
            const SizedBox(height: 28),
            FormFieldBlock(
              label: 'New password',
              child: TextFormField(
                controller: _password,
                obscureText: true,
                validator: (value) => _passwordError(value ?? ''),
              ),
            ),
            const SizedBox(height: 18),
            FormFieldBlock(
              label: 'Confirm new password',
              child: TextFormField(
                controller: _confirmation,
                obscureText: true,
                onChanged: (_) => setState(() {}),
                validator: (value) =>
                    value != _password.text ? 'Passwords must match.' : null,
              ),
            ),
            const SizedBox(height: 8),
            if (_confirmation.text.isNotEmpty &&
                _confirmation.text == _password.text)
              Text(
                'Passwords match',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 16),
            const SideCarInfoCard(
              title: 'Secure password',
              message: 'Your previous password will stop working immediately.',
              color: AppColors.success,
            ),
            SideCarErrorText(_error),
          ],
        ),
      ),
    );
  }
}

class PasswordResetCompleteScreen extends StatelessWidget {
  const PasswordResetCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SideCarScaffold(
      showBack: true,
      onBack: () => _popOrGo(context, AppRoutes.login),
      bottom: FilledButton(
        onPressed: AppHaptics.wrap(() => context.go(AppRoutes.login)),
        child: const Text('Back to sign in'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ScreenIntro(title: 'Password reset', description: ''),
          const SizedBox(height: 20),
          const SideCarInfoCard(
            title: 'Password updated',
            message: 'You can now sign in with your new password.',
            icon: Icons.check_circle_outline_rounded,
            color: AppColors.success,
          ),
          const SizedBox(height: 18),
          Text(
            'For your security, other active sessions will be signed out.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
