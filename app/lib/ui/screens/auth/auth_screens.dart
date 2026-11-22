import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/config.dart';
import '../../../data/account_repository.dart';
import '../../../data/local_store.dart';
import '../../../services/analytics.dart';
import '../../../state/providers.dart';
import '../../../theme/app_theme.dart';
import '../../widgets/common.dart';

final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');
bool validEmail(String s) => _emailRe.hasMatch(s.trim());

class _PasswordField extends StatefulWidget {
  const _PasswordField({required this.controller, required this.hint, this.error, this.enabled = true, this.onChanged});
  final TextEditingController controller;
  final String hint;
  final String? error;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _show = false;
  @override
  Widget build(BuildContext context) {
    final t = l10n(context);
    return LabeledField(
      label: t.password,
      error: widget.error,
      child: TextField(
        controller: widget.controller,
        enabled: widget.enabled,
        obscureText: !_show,
        autofillHints: const [AutofillHints.password],
        onChanged: widget.onChanged,
        style: AppText.bodyLarge,
        decoration: fieldDecoration(
          hint: widget.hint,
          error: widget.error != null,
          suffix: IconButton(
            tooltip: _show ? t.hidePassword : t.showPassword,
            icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            onPressed: () => setState(() => _show = !_show),
          ),
        ),
      ),
    );
  }
}

class _EmailField extends StatelessWidget {
  const _EmailField({required this.controller, this.error, this.enabled = true, this.onChanged, this.focusNode});
  final TextEditingController controller;
  final String? error;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  @override
  Widget build(BuildContext context) {
    final t = l10n(context);
    return LabeledField(
      label: t.email,
      error: error,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        autocorrect: false,
        onChanged: onChanged,
        style: AppText.bodyLarge,
        decoration: fieldDecoration(hint: t.emailHint, error: error != null),
      ),
    );
  }
}

Widget _privacyLink(BuildContext context) {
  final t = l10n(context);
  return Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
    Text('${t.privacyNote} ', style: AppText.caption),
    InkWell(
      onTap: () => launchUrl(Uri.parse(AppConfig.privacyUrl)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
        child: Text(t.privacyPolicy, style: AppText.caption.copyWith(color: AppColors.primary, decoration: TextDecoration.underline)),
      ),
    ),
  ]);
}

// ---------------- 3a–3h Save profile ----------------
class SaveProfileScreen extends ConsumerStatefulWidget {
  const SaveProfileScreen({super.key});
  @override
  ConsumerState<SaveProfileScreen> createState() => _SaveProfileScreenState();
}

class _SaveProfileScreenState extends ConsumerState<SaveProfileScreen> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  final _emailFocus = FocusNode();
  bool _adult = false, _saving = false, _emailTouched = false, _pwTouched = false;
  SaveError? _error;

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(() {
      if (!_emailFocus.hasFocus) setState(() => _emailTouched = true); // validate on blur
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  bool get _ready => validEmail(_email.text) && _pw.text.length >= 8 && _adult;

  Future<void> _save() async {
    setState(() {
      _emailTouched = _pwTouched = true;
    });
    if (!_ready) return;
    final acc = ref.read(accountProvider);
    if (acc == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final p = await acc.signUpWithDraft(
        email: _email.text.trim(),
        password: _pw.text,
        draft: ref.read(draftProvider),
        phoneTz: ref.read(phoneTzProvider),
      );
      ref.read(profileProvider.notifier).set(p);
      ref.read(analyticsProvider)
        ..identify(p.id)
        ..event(Ev.profileSaved);
      if (mounted) context.go('/reminders');
    } on AccountException catch (e) {
      setState(() => _error = e.kind as SaveError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = l10n(context);
    final emailErr = _emailTouched && _email.text.isNotEmpty && !validEmail(_email.text) ? t.emailInvalid : null;
    final pwErr = _pwTouched && _pw.text.isNotEmpty && _pw.text.length < 8 ? t.passwordShort : null;
    final used = _error == SaveError.emailUsed;
    return AppScaffold(
      showBack: false,
      body: AutofillGroup(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: AppSpace.lg),
          Text(t.saveTitle, style: AppText.heading),
          const SizedBox(height: AppSpace.sm),
          Text(t.saveBody, style: AppText.body),
          const SizedBox(height: AppSpace.lg),
          if (used) ...[InlineAlert(title: t.emailUsedTitle, body: t.emailUsedBody), const SizedBox(height: AppSpace.md)],
          if (_error == SaveError.network || _error == SaveError.other) ...[
            InlineAlert(title: t.noConnection, body: t.saveNetworkError, icon: Icons.wifi_off),
            const SizedBox(height: AppSpace.md),
          ],
          _EmailField(controller: _email, focusNode: _emailFocus, error: emailErr, enabled: !_saving, onChanged: (_) => setState(() => _error = null)),
          const SizedBox(height: AppSpace.md),
          _PasswordField(
            controller: _pw,
            hint: t.passwordHint,
            error: pwErr,
            enabled: !_saving,
            onChanged: (_) => setState(() => _pwTouched = _pw.text.length >= 8 || _pwTouched),
          ),
          const SizedBox(height: AppSpace.sm),
          InkWell(
            onTap: _saving ? null : () => setState(() => _adult = !_adult),
            child: SizedBox(
              height: 48,
              child: Row(children: [
                Checkbox(value: _adult, onChanged: _saving ? null : (v) => setState(() => _adult = v ?? false)),
                Expanded(child: Text(t.adultCheck, style: AppText.bodyLarge)),
              ]),
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          _privacyLink(context),
        ]),
      ),
      footer: Column(mainAxisSize: MainAxisSize.min, children: [
        if (used)
          PrimaryButton(label: t.signInInstead, onPressed: () => context.push('/sign-in?email=${Uri.encodeComponent(_email.text.trim())}'))
        else
          PrimaryButton(
            label: _error == SaveError.network ? t.tryAgain : t.saveMyProfile,
            loading: _saving,
            loadingLabel: t.saving,
            onPressed: _ready ? _save : null,
          ),
        const SizedBox(height: AppSpace.xs),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(t.haveAccount, style: AppText.body),
          TextButton(onPressed: _saving ? null : () => context.push('/sign-in'), child: Text(t.signIn)),
        ]),
      ]),
    );
  }
}

// ---------------- 3i / 3g Sign in ----------------
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key, this.email});
  final String? email;
  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  late final _email = TextEditingController(text: widget.email ?? '');
  final _pw = TextEditingController();
  bool _busy = false;
  SignInError? _error;

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final acc = ref.read(accountProvider);
    if (acc == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final p = await acc.signIn(_email.text.trim(), _pw.text);
      ref.read(profileProvider.notifier).set(p);
      ref.read(analyticsProvider)
        ..identify(p.id)
        ..event(Ev.signIn);
      if (mounted) context.go(ref.read(storeProvider).flag(Flags.remindersAsked) ? '/home' : '/reminders');
    } on AccountException catch (e) {
      setState(() => _error = e.kind as SignInError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = l10n(context);
    final ready = _email.text.trim().isNotEmpty && _pw.text.isNotEmpty;
    return AppScaffold(
      body: AutofillGroup(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.welcomeBack, style: AppText.heading),
          const SizedBox(height: AppSpace.sm),
          Text(t.signInBody, style: AppText.body),
          const SizedBox(height: AppSpace.lg),
          if (_error == SignInError.network || _error == SignInError.other) ...[
            InlineAlert(title: t.noConnection, body: t.networkError, icon: Icons.wifi_off),
            const SizedBox(height: AppSpace.md),
          ],
          _EmailField(controller: _email, enabled: !_busy, onChanged: (_) => setState(() {})),
          const SizedBox(height: AppSpace.md),
          _PasswordField(
            controller: _pw,
            hint: t.passwordHintSignIn,
            enabled: !_busy,
            error: _error == SignInError.wrongPassword ? t.wrongPassword : null,
            onChanged: (_) => setState(() => _error = null),
          ),
          TextButton(
            onPressed: () => context.push('/forgot?email=${Uri.encodeComponent(_email.text.trim())}'),
            child: Text(t.forgotPassword),
          ),
        ]),
      ),
      footer: PrimaryButton(label: t.signIn, loading: _busy, onPressed: ready ? _signIn : null),
    );
  }
}

// ---------------- 3j Forgot password ----------------
class ForgotScreen extends ConsumerStatefulWidget {
  const ForgotScreen({super.key, this.email});
  final String? email;
  @override
  ConsumerState<ForgotScreen> createState() => _ForgotScreenState();
}

class _ForgotScreenState extends ConsumerState<ForgotScreen> {
  late final _email = TextEditingController(text: widget.email ?? '');
  bool _busy = false;
  bool _failed = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await ref.read(accountProvider)!.sendReset(_email.text.trim());
      if (mounted) context.pushReplacement('/forgot-sent?email=${Uri.encodeComponent(_email.text.trim())}');
    } catch (_) {
      setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = l10n(context);
    return AppScaffold(
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t.resetTitle, style: AppText.heading),
        const SizedBox(height: AppSpace.sm),
        Text(t.resetBody, style: AppText.body),
        const SizedBox(height: AppSpace.lg),
        if (_failed) ...[InlineAlert(title: t.noConnection, body: t.networkError, icon: Icons.wifi_off), const SizedBox(height: AppSpace.md)],
        _EmailField(controller: _email, enabled: !_busy, onChanged: (_) => setState(() {})),
      ]),
      footer: PrimaryButton(label: t.sendResetLink, loading: _busy, onPressed: validEmail(_email.text) ? _send : null),
    );
  }
}

// ---------------- 3k Link sent ----------------
class ForgotSentScreen extends ConsumerStatefulWidget {
  const ForgotSentScreen({super.key, required this.email});
  final String email;
  @override
  ConsumerState<ForgotSentScreen> createState() => _ForgotSentScreenState();
}

class _ForgotSentScreenState extends ConsumerState<ForgotSentScreen> {
  int _wait = 60; // Supabase allows a new email after 60 s
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _wait = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (tm) {
      if (!mounted) return;
      setState(() => _wait--);
      if (_wait <= 0) tm.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = l10n(context);
    return AppScaffold(
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t.checkEmailTitle, style: AppText.heading),
        const SizedBox(height: AppSpace.sm),
        Text(t.checkEmailBody(widget.email), style: AppText.body),
        const SizedBox(height: AppSpace.md),
        Text(t.checkSpam, style: AppText.caption),
      ]),
      footer: Column(mainAxisSize: MainAxisSize.min, children: [
        SecondaryButton(label: t.backToSignIn, onPressed: () => context.go('/sign-in?email=${Uri.encodeComponent(widget.email)}')),
        const SizedBox(height: AppSpace.xs),
        TextButton(
          onPressed: _wait > 0
              ? null
              : () async {
                  try {
                    await ref.read(accountProvider)!.sendReset(widget.email);
                  } catch (_) {}
                  setState(_start);
                },
          child: Text(_wait > 0 ? t.sendAgainIn(_wait) : t.sendAgain),
        ),
      ]),
    );
  }
}

// ---------------- 3l Set a new password (from the email link) ----------------
class NewPasswordScreen extends ConsumerStatefulWidget {
  const NewPasswordScreen({super.key});
  @override
  ConsumerState<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends ConsumerState<NewPasswordScreen> {
  final _pw = TextEditingController();
  bool _busy = false, _expired = false, _touched = false;

  @override
  void dispose() {
    _pw.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final acc = ref.read(accountProvider)!;
    setState(() => _busy = true);
    try {
      await acc.setNewPassword(_pw.text);
      final p = await acc.fetchProfile();
      if (p != null) ref.read(profileProvider.notifier).set(p);
      if (mounted) context.go('/home');
    } catch (_) {
      setState(() => _expired = true); // session from the link is gone or used
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = l10n(context);
    final email = ref.read(accountProvider)?.email ?? '';
    if (_expired || (ref.read(accountProvider)?.userId == null)) {
      // Default for the undesigned expired-link state (dev review): message + "Send a new link".
      return AppScaffold(
        body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.linkExpiredTitle, style: AppText.heading),
          const SizedBox(height: AppSpace.sm),
          Text(t.linkExpiredBody, style: AppText.body),
        ]),
        footer: PrimaryButton(label: t.sendNewLink, onPressed: () => context.go('/forgot?email=${Uri.encodeComponent(email)}')),
      );
    }
    final err = _touched && _pw.text.isNotEmpty && _pw.text.length < 8 ? t.passwordShort : null;
    return AppScaffold(
      showBack: false,
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: AppSpace.lg),
        Text(t.newPasswordTitle, style: AppText.heading),
        const SizedBox(height: AppSpace.sm),
        Text(t.newPasswordFor(email), style: AppText.body),
        const SizedBox(height: AppSpace.lg),
        _PasswordField(controller: _pw, hint: t.passwordHint, error: err, enabled: !_busy, onChanged: (_) => setState(() => _touched = true)),
      ]),
      footer: PrimaryButton(label: t.saveAndSignIn, loading: _busy, loadingLabel: t.saving, onPressed: _pw.text.length >= 8 ? _save : null),
    );
  }
}
