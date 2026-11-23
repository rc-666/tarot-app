import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../data/local_store.dart';
import '../../../data/sky_repository.dart';
import '../../../domain/notification_plan.dart';
import '../../../services/analytics.dart';
import '../../../state/providers.dart';
import '../../../theme/app_theme.dart';
import '../../widgets/ad_banner.dart';
import '../../widgets/common.dart';
import '../../widgets/tarot_card.dart';
import '../settings/settings_screens.dart';
import 'error_screen.dart';

/// Re-plans local notifications from the current profile and cached mood shifts.
Future<void> replanNotifications(WidgetRef ref, BuildContext context) async {
  final store = ref.read(storeProvider);
  final p = ref.read(profileProvider);
  final on = store.flag(Flags.remindersOn);
  final t = l10n(context);
  await ref.read(notificationsProvider).plan(
        morning: on && (p?.notifyMorning ?? true),
        mood: on && (p?.notifyMood ?? true),
        shifts: store.moodShifts,
        text: (
          morningTitle: t.notifMorningTitle,
          morningBody: t.notifMorningBody,
          moodTitle: t.notifMoodTitle,
          moodBody: t.notifMoodBody,
          channel: t.notifChannelName,
        ),
      );
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _slow;
  late final _notifications = ref.read(notificationsProvider); // kept so dispose() doesn't use ref
  bool _tooSlow = false;

  @override
  void initState() {
    super.initState();
    // Cards not ready (nightly job late): loading, then 6d after 10 s (spec 7).
    _slow = Timer(const Duration(seconds: 10), () {
      if (mounted && !ref.read(todayCardsProvider).hasValue) setState(() => _tooSlow = true);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final p = await ref.read(accountProvider)?.fetchProfile();
      if (p != null) ref.read(profileProvider.notifier).set(p);
      if (mounted) await replanNotifications(ref, context);
    });
    _notifications.opened.addListener(_fromNotification);
  }

  void _fromNotification() {
    ref.read(analyticsProvider).event(Ev.notificationOpened);
    ref.invalidate(todayCardsProvider);
  }

  @override
  void dispose() {
    _slow?.cancel();
    _notifications.opened.removeListener(_fromNotification);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = l10n(context);
    final store = ref.watch(storeProvider);
    final profile = ref.watch(profileProvider);
    final cards = ref.watch(todayCardsProvider);
    final lib = ref.watch(libraryProvider).valueOrNull;
    final reading = ref.watch(readingProvider);
    final online = ref.watch(onlineProvider).valueOrNull ?? true;
    final now = ref.watch(clockProvider);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final name = profile?.firstName ?? ref.watch(draftProvider).firstName;
    final firstDay = !store.flag(Flags.firstDayTipDone);
    final remindersOn = store.flag(Flags.remindersOn);

    if ((cards.hasError && cards.error is! CardsNotReady) || (_tooSlow && !cards.hasValue)) {
      return ErrorScreen(onRetry: () {
        setState(() => _tooSlow = false);
        ref.invalidate(todayCardsProvider);
      });
    }
    final loading = !cards.hasValue || lib == null;

    final greeting = firstDay
        ? t.welcomeName(name)
        : now.hour < 12
            ? t.goodMorning(name)
            : now.hour < 18
                ? t.goodAfternoon(name)
                : t.goodEvening(name);
    final nextAt = DateFormat.Hm(locale).format(DateTime(2000, 1, 1, morningHour));

    return Scaffold(
      body: Column(children: [
        if (!online) const OfflineBar(),
        Expanded(
          child: SafeArea(
            top: online,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(AppSpace.screen, AppSpace.sm, AppSpace.screen, AppSpace.lg),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: t.settingsLabel,
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => showSettingsSheet(context),
                  ),
                ),
                if (loading) ..._skeleton() else ...[
                  Text(greeting, style: AppText.display),
                  const SizedBox(height: AppSpace.xxs),
                  Text(DateFormat.MMMMEEEEd(locale).format(now), style: AppText.body),
                  const SizedBox(height: AppSpace.xl),
                  if (firstDay && reading != null) ...[
                    _Tip(remindersOn: remindersOn, time: nextAt, onDone: () => setState(() {})),
                    const SizedBox(height: AppSpace.lg),
                  ],
                  Text(
                    upper(reading == null ? t.todaysCards : t.todaysCardsTopic(topicName(t, reading.topic))),
                    style: AppText.label,
                  ),
                  const SizedBox(height: AppSpace.md),
                  _CardsRow(revealed: reading != null),
                  if (reading != null && cards.value!.moodShiftedToday) ...[
                    const SizedBox(height: AppSpace.sm),
                    Text(t.moodShiftedAt(DateFormat.Hm(locale).format(cards.value!.mood.at.toLocal())),
                        style: AppText.caption.copyWith(color: AppColors.primary)),
                  ],
                  const SizedBox(height: AppSpace.lg),
                  if (reading == null)
                    PrimaryButton(label: t.revealTodaysCards, onPressed: () => context.push('/reading'))
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpace.md),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.medium)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(t.nextCardsTomorrow(nextAt), style: AppText.bodyLarge),
                        const SizedBox(height: AppSpace.xxs),
                        Text(t.tapCardToReread, style: AppText.body),
                      ]),
                    ),
                ],
              ]),
            ),
          ),
        ),
        // Ad: Home bottom only; not while loading or offline; collapses on failure.
        SafeArea(top: false, child: AdBanner(enabled: !loading && online)),
      ]),
    );
  }

  List<Widget> _skeleton() => [
        const Skeleton(width: 200, height: 32),
        const SizedBox(height: AppSpace.sm),
        const Skeleton(width: 120, height: 16),
        const SizedBox(height: AppSpace.xl),
        const Skeleton(width: 90, height: 14),
        const SizedBox(height: AppSpace.md),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (var i = 0; i < 3; i++) Skeleton(width: AppSize.cardHome, height: AppSize.card(AppSize.cardHome).height),
        ]),
        const SizedBox(height: AppSpace.lg),
        const Skeleton(width: double.infinity, height: 56),
      ];
}

class _CardsRow extends ConsumerWidget {
  const _CardsRow({required this.revealed});
  final bool revealed;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(todayCardsProvider).value!;
    final lib = ref.watch(libraryProvider).value!;
    final ids = [c.mood.card, c.fixed.influenceCard, c.fixed.adviceCard];
    final w = ((MediaQuery.sizeOf(context).width - 2 * AppSpace.screen - 2 * AppSpace.xs) / 3).clamp(80.0, AppSize.cardHome);
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var i = 0; i < 3; i++)
        SizedBox(
          width: w,
          child: GestureDetector(
            // 4b: tap any card -> 5h reopened, no animation
            onTap: revealed ? () => context.push('/reading/today') : null,
            child: Column(children: [
              CardFace(width: w, cardId: revealed ? ids[i] : null, reversed: i == 1 && c.fixed.influenceReversed),
              if (revealed) ...[
                const SizedBox(height: AppSpace.xs),
                Text(lib.cardName(ids[i]), textAlign: TextAlign.center, style: AppText.body.copyWith(color: AppColors.textSecondary)),
              ],
            ]),
          ),
        ),
    ]);
  }
}

/// 4c / 4h one-time tip.
class _Tip extends ConsumerWidget {
  const _Tip({required this.remindersOn, required this.time, required this.onDone});
  final bool remindersOn;
  final String time;
  final VoidCallback onDone;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = l10n(context);
    final store = ref.read(storeProvider);
    Future<void> done() async {
      await store.setFlag(Flags.firstDayTipDone, true);
      onDone(); // rebuild Home without the tip
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpace.md, AppSpace.md, AppSpace.md, AppSpace.xs),
      decoration: BoxDecoration(border: Border.all(color: AppColors.primary), borderRadius: BorderRadius.circular(AppRadius.medium)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(remindersOn ? t.tipReminders(time) : t.tipRemindersOff, style: AppText.bodyLarge),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          if (!remindersOn)
            TextButton(
              onPressed: () async {
                final ok = await ref.read(notificationsProvider).requestPermission();
                await store.setFlag(Flags.remindersOn, ok);
                if (context.mounted) await replanNotifications(ref, context);
                await done();
              },
              child: Text(t.turnOnReminders),
            ),
          TextButton(onPressed: done, child: Text(t.gotIt)),
        ]),
      ]),
    );
  }
}

/// 4f Reminder explainer, shown once after sign-in, before Android's permission prompt (4g).
class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = l10n(context);
    final store = ref.read(storeProvider);
    Future<void> finish(bool on) async {
      await store.setFlag(Flags.remindersAsked, true);
      await store.setFlag(Flags.remindersOn, on);
      ref.read(analyticsProvider).event(Ev.remindersChoice, {'on': on});
      if (context.mounted) context.go('/home');
    }

    return AppScaffold(
      showBack: false,
      body: Column(children: [
        const SizedBox(height: AppSpace.xl),
        const CardFace(width: 80),
        const SizedBox(height: AppSpace.xl),
        Text(t.remindersTitle, style: AppText.heading),
        const SizedBox(height: AppSpace.sm),
        Text(t.remindersBody, style: AppText.bodyLarge.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: AppSpace.md),
        Text(t.remindersFootnote, style: AppText.body),
      ]),
      footer: Column(mainAxisSize: MainAxisSize.min, children: [
        PrimaryButton(
          label: t.turnOnReminders,
          onPressed: () async {
            final ok = await ref.read(notificationsProvider).requestPermission(); // 4g system dialog
            await finish(ok);
          },
        ),
        const SizedBox(height: AppSpace.xs),
        TextButton(onPressed: () => finish(false), child: Text(t.notNow)),
      ]),
    );
  }
}
