import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/config.dart';
import '../../../data/local_store.dart';
import '../../../domain/models.dart';
import '../../../services/analytics.dart';
import '../../../state/providers.dart';
import '../../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../home/home_screen.dart';
import '../onboarding/onboarding_screens.dart';

/// 6a Settings bottom sheet. Decision 22 Nov: two switches (Morning cards, Mood shifts) replace "Daily reminder".
Future<void> showSettingsSheet(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _SettingsSheet(),
    );

class _SettingsSheet extends ConsumerStatefulWidget {
  const _SettingsSheet();
  @override
  ConsumerState<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<_SettingsSheet> {
  Future<void> _toggle(String field, bool v) async {
    final p = ref.read(profileProvider);
    final store = ref.read(storeProvider);
    if (v && !store.flag(Flags.remindersOn)) {
      final ok = await ref.read(notificationsProvider).requestPermission();
      await store.setFlag(Flags.remindersOn, ok);
      if (!ok) return;
    }
    if (p != null) {
      try {
        final np = await ref.read(accountProvider)!.updateProfile(p, {field: v});
        ref.read(profileProvider.notifier).set(np);
      } catch (_) {
        return;
      }
    }
    if (mounted) await replanNotifications(ref, context);
    setState(() {});
  }

  /// Closes the sheet, then opens the page (router captured first: the sheet's context goes away).
  void _open(String location, {bool seed = true}) {
    final router = GoRouter.of(context);
    if (seed) seedDraftFromProfile(ref);
    Navigator.pop(context);
    router.push(location);
  }

  @override
  Widget build(BuildContext context) {
    final t = l10n(context);
    final p = ref.watch(profileProvider);
    final remindersOn = ref.read(storeProvider).flag(Flags.remindersOn);
    const langNames = {'en': 'English', 'pt': 'Português', 'es': 'Español'};
    Widget row(String label, {String? value, VoidCallback? onTap, bool destructive = false}) => InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.screen),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
            child: Row(children: [
              Expanded(child: Text(label, style: AppText.bodyLarge.copyWith(color: destructive ? AppColors.error : null))),
              if (value != null) Text(value, style: AppText.body),
              if (!destructive) const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ]),
          ),
        );
    Widget sw(String label, bool value, ValueChanged<bool> onChanged) => Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.only(left: AppSpace.screen, right: AppSpace.sm),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
          child: Row(children: [
            Expanded(child: Text(label, style: AppText.bodyLarge)),
            Switch(value: value, onChanged: onChanged, activeColor: AppColors.primary),
          ]),
        );

    return SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.screen, 0, AppSpace.xs, AppSpace.xs),
          child: Row(children: [
            Expanded(child: Text(t.settings, style: const TextStyle(fontFamily: 'Playfair Display', fontSize: 24, color: AppColors.textPrimary))),
            IconButton(tooltip: t.close, icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
          ]),
        ),
        const Divider(height: 1),
        row(t.editProfile, value: p?.firstName, onTap: () => _open('/edit-profile', seed: false)),
        row(t.focusTopics, value: t.nChosen(p?.focusTopics.length ?? 0), onTap: () => _open('/edit/topics')),
        row(t.language, value: langNames[p?.language ?? ref.read(languageProvider)], onTap: () => _open('/edit/language')),
        sw(t.morningCards, remindersOn && (p?.notifyMorning ?? true), (v) => _toggle('notify_morning', v)),
        sw(t.moodShifts, remindersOn && (p?.notifyMood ?? true), (v) => _toggle('notify_mood', v)),
        row(t.privacyPolicy, onTap: () => launchUrl(Uri.parse(AppConfig.privacyUrl))),
        row(t.deleteAccount, destructive: true, onTap: () => showDialog(context: context, builder: (_) => const _DeleteDialog())),
        const SizedBox(height: AppSpace.md),
      ]),
    );
  }
}

/// 6b Confirm dialog, with the "Deleting…" / "Couldn't delete" defaults from the dev review.
class _DeleteDialog extends ConsumerStatefulWidget {
  const _DeleteDialog();
  @override
  ConsumerState<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends ConsumerState<_DeleteDialog> {
  bool _busy = false, _failed = false;
  @override
  Widget build(BuildContext context) {
    final t = l10n(context);
    return AlertDialog(
      title: Text(t.deleteTitle, style: AppText.title.copyWith(fontSize: 24)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t.deleteBody, style: AppText.body),
        if (_failed) ...[const SizedBox(height: AppSpace.sm), Text(t.deleteFailed, style: AppText.caption.copyWith(color: AppColors.error))],
        const SizedBox(height: AppSpace.lg),
        SecondaryButton(
          label: _busy ? t.deleting : t.deleteAccount,
          color: AppColors.error,
          onPressed: _busy
              ? null
              : () async {
                  setState(() {
                    _busy = true;
                    _failed = false;
                  });
                  try {
                    await ref.read(accountProvider)!.deleteAccount();
                    await ref.read(notificationsProvider).cancelAll();
                    ref.read(analyticsProvider)
                      ..event(Ev.accountDeleted)
                      ..reset();
                    ref.read(profileProvider.notifier).set(null);
                    ref.invalidate(draftProvider);
                    ref.invalidate(readingProvider);
                    if (context.mounted) context.go('/onboarding/language');
                  } catch (_) {
                    if (mounted) setState(() => _failed = true);
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
        ),
        const SizedBox(height: AppSpace.sm),
        SecondaryButton(label: t.keepAccount, onPressed: _busy ? null : () => Navigator.pop(context)),
      ]),
    );
  }
}

/// Copies the saved profile into the draft so edit-mode steps can reuse the onboarding widgets.
void seedDraftFromProfile(WidgetRef ref) {
  final p = ref.read(profileProvider);
  if (p == null) return;
  final place = p.birthPlace == null || p.birthLat == null
      ? null
      : Place(
          name: p.birthPlace!.split(',').first,
          region: p.birthPlace!.split(',').skip(1).join(',').trim(),
          lat: p.birthLat!,
          lon: p.birthLon!,
          tz: p.birthTz ?? 'UTC',
        );
  ref.read(draftProvider.notifier).update((_) => ProfileDraft(
        language: p.language,
        firstName: p.firstName,
        birthDate: p.birthDate,
        birthTime: p.birthTime,
        birthPlace: place,
        focusTopics: p.focusTopics,
      ));
}

/// Saves the draft field(s) back to the profile.
Future<void> saveDraftToProfile(WidgetRef ref, String field) async {
  final p = ref.read(profileProvider)!;
  final d = ref.read(draftProvider);
  final changes = switch (field) {
    'name' => {'first_name': d.firstName.trim()},
    'birthDate' => {'birth_date': d.birthDate!.toIso8601String().substring(0, 10)},
    'time' => {'birth_time': d.birthTime},
    'place' => {
        'birth_place': d.birthPlace?.label,
        'birth_lat': d.birthPlace?.lat,
        'birth_lon': d.birthPlace?.lon,
        'birth_tz': d.birthPlace?.tz,
      },
    'topics' => {'focus_topics': d.focusTopics},
    'language' => {'language': d.language},
    _ => <String, dynamic>{},
  };
  final np = await ref.read(accountProvider)!.updateProfile(p, changes);
  ref.read(profileProvider.notifier).set(np);
}

/// 6e Edit profile list.
class EditProfileScreen extends ConsumerWidget {
  const EditProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = l10n(context);
    final p = ref.watch(profileProvider);
    if (p == null) return const SizedBox.shrink();
    final locale = Localizations.localeOf(context).toLanguageTag();
    Widget row(String label, String value, String field) => InkWell(
          onTap: () {
            seedDraftFromProfile(ref);
            context.push('/edit/$field');
          },
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: AppText.caption),
                  Text(value, style: AppText.bodyLarge),
                ]),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ]),
          ),
        );
    return AppScaffold(
      title: t.editProfile,
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        row(t.nameLabel, p.firstName, 'name'),
        row(t.birthDate, DateFormat.yMMMMd(locale).format(p.birthDate), 'birthDate'),
        row(t.birthTime, p.birthTime ?? t.notKnown, 'time'),
        row(t.birthPlace, p.birthPlace ?? t.notKnown, 'place'),
        const SizedBox(height: AppSpace.md),
        Text(t.birthDetailsNote, style: AppText.body),
      ]),
    );
  }
}

/// 6f One field in edit mode, reusing the profile step.
class EditFieldScreen extends ConsumerWidget {
  const EditFieldScreen({super.key, required this.field});
  final String field;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = l10n(context);
    EditMode mode(String title) => EditMode(title: title, onSave: () => saveDraftToProfile(ref, field));
    return switch (field) {
      'name' => NameStep(edit: mode(t.nameLabel), initial: ref.read(profileProvider)?.firstName),
      'birthDate' => BirthDateStep(edit: mode(t.birthDate), initial: ref.read(profileProvider)?.birthDate),
      'time' => TimePlaceStep(edit: mode(t.birthTime), only: 'time'),
      'place' => TimePlaceStep(edit: mode(t.birthPlace), only: 'place'),
      'topics' => TopicsStep(edit: mode(t.focusTopics)),
      _ => LanguageStep(edit: mode(t.language)),
    };
  }
}
