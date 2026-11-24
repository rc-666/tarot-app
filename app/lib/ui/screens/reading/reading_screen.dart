import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../domain/cards.dart';
import '../../../domain/models.dart';
import '../../../domain/reading_assembler.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/analytics.dart';
import '../../../state/providers.dart';
import '../../../theme/app_theme.dart';
import '../../widgets/ad_banner.dart';
import '../../widgets/common.dart';
import '../../widgets/tarot_card.dart';
import '../home/error_screen.dart';

enum ReadingMode { first, daily, reopen }

/// 5a Topic picker: 5 rows (64 dp), one tap continues.
class TopicPickerScreen extends ConsumerWidget {
  const TopicPickerScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = l10n(context);
    return AppScaffold(
      title: t.todaysReading,
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t.topicPickerTitle, style: AppText.heading),
        const SizedBox(height: AppSpace.sm),
        Text(t.topicPickerBody, style: AppText.body),
        const SizedBox(height: AppSpace.lg),
        for (final topic in topics)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.sm),
            child: Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.medium),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.medium),
                onTap: () async {
                  await ref.read(readingProvider.notifier).start(topic);
                  ref.read(analyticsProvider).event(Ev.readingStarted, {'topic': topic});
                  if (context.mounted) context.pushReplacement('/reading/reveal');
                },
                child: Container(
                  constraints: const BoxConstraints(minHeight: 64),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
                  child: Row(children: [
                    SizedBox(width: 32, child: Icon(topicIcon(topic), color: AppColors.primary)),
                    const SizedBox(width: AppSpace.sm),
                    Expanded(child: Text(topicName(t, topic), style: AppText.bodyLarge)),
                    const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

class ReadingScreen extends ConsumerStatefulWidget {
  const ReadingScreen({super.key, required this.mode});
  final ReadingMode mode;
  @override
  ConsumerState<ReadingScreen> createState() => _ReadingScreenState();
}

class _ReadingScreenState extends ConsumerState<ReadingScreen> {
  TodayCards? _frozen; // mood stays as opened while she is on this screen
  final _revealed = <bool>[false, false, false];
  int? _lastRevealed;
  bool _showFull = false;
  final _openingKey = GlobalKey();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.mode == ReadingMode.reopen) {
      _revealed.setAll(0, [true, true, true]);
      _showFull = true;
    }
    if (widget.mode == ReadingMode.first) {
      // 2a: topic = her first focus topic, picker skipped. Recorded so it is saved after sign-up.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ref.read(readingProvider) == null) {
          final d = ref.read(draftProvider);
          ref.read(readingProvider.notifier).start(d.focusTopics.isNotEmpty ? d.focusTopics.first : 'growth');
        }
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String get _topic {
    final r = ref.read(readingProvider);
    if (r != null) return r.topic;
    final draft = ref.read(draftProvider);
    return draft.focusTopics.isNotEmpty ? draft.focusTopics.first : (ref.read(profileProvider)?.focusTopics.first ?? 'growth');
  }

  void _onRevealed(int i) {
    setState(() => _lastRevealed = i);
    ref.read(analyticsProvider).event(Ev.cardRevealed, {'position': i});
  }

  Future<void> _readFull() async {
    final reduce = MediaQuery.of(context).disableAnimations;
    setState(() => _showFull = true);
    ref.read(analyticsProvider).event(Ev.readingOpened);
    await Future<void>.delayed(const Duration(milliseconds: 50)); // let the full reading lay out
    final ctx = _openingKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    await Scrollable.ensureVisible(ctx, duration: reduce ? Duration.zero : AppMotion.readScroll, curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final t = l10n(context);
    final cards = ref.watch(todayCardsProvider);
    final lib = ref.watch(libraryProvider);
    if (cards.hasError || lib.hasError) {
      return ErrorScreen(onRetry: () => ref.invalidate(todayCardsProvider));
    }
    if (!cards.hasValue || !lib.hasValue) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_frozen == null) {
      _frozen = cards.value!;
      final f = _frozen!;
      final w = ((MediaQuery.sizeOf(context).width - 2 * AppSpace.screen - 2 * AppSpace.xs) / 3).clamp(AppSize.cardRevealMin, AppSize.cardReveal);
      CardFace.precache(context, [f.mood.card, f.fixed.influenceCard, f.fixed.adviceCard], w);
    }
    final today = _frozen!;
    final library = lib.value!;
    final topic = _topic;
    final reading = assembleReading(library, today, topic);
    final first = widget.mode == ReadingMode.first;
    final count = _revealed.where((x) => x).length;
    final online = ref.watch(onlineProvider).valueOrNull ?? true;

    final positions = [
      (short: t.posMoodShort, long: t.posMood, card: today.mood.card, reversed: false, line: _moodLine(t, today)),
      (
        short: t.posInfluenceShort,
        long: t.posInfluence,
        card: today.fixed.influenceCard,
        reversed: today.fixed.influenceReversed,
        line: _influenceLine(t, today.fixed),
      ),
      (short: t.posAdviceShort, long: t.posAdvice, card: today.fixed.adviceCard, reversed: false, line: t.adviceLine(signName(t, today.fixed.moonSign))),
    ];

    final screenW = MediaQuery.sizeOf(context).width;
    final cardW = ((screenW - 2 * AppSpace.screen - 2 * AppSpace.xs) / 3).clamp(AppSize.cardRevealMin, AppSize.cardReveal);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        leading: first ? null : IconButton(tooltip: t.back, icon: const Icon(Icons.arrow_back_ios_new, size: 20), onPressed: () => context.go('/home')),
        automaticallyImplyLeading: false,
        titleSpacing: first ? AppSpace.screen : 0,
        title: Text(
          widget.mode == ReadingMode.reopen ? t.todaysReading : topicName(t, topic),
          style: AppText.bodyLarge.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(AppSpace.screen, AppSpace.sm, AppSpace.screen, AppSpace.lg),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (widget.mode == ReadingMode.reopen)
                  Text('${topicName(t, topic)} · ${DateFormat.MMMMEEEEd(Localizations.localeOf(context).toLanguageTag()).format(DateTime.now())}',
                      style: AppText.body)
                else ...[
                  Text(first ? t.firstReadingTitle : t.readingTitle, style: AppText.heading),
                  const SizedBox(height: AppSpace.xs),
                  Text(count == 3 ? t.readingReady : t.tapToReveal, style: AppText.body),
                ],
                const SizedBox(height: AppSpace.lg),
                // Reveal row: cards can be revealed in any order. The position label never moves.
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (var i = 0; i < 3; i++)
                    SizedBox(
                      width: cardW,
                      child: Column(children: [
                        Semantics(
                          button: !_revealed[i],
                          liveRegion: _revealed[i],
                          label: _revealed[i]
                              ? t.cardRevealedSemantics(positions[i].short, library.cardName(positions[i].card), positions[i].line)
                              : t.cardFaceDownSemantics(i + 1, positions[i].short),
                          excludeSemantics: true,
                          child: RevealCard(
                            width: cardW,
                            revealed: _revealed[i],
                            animate: widget.mode != ReadingMode.reopen,
                            cardId: positions[i].card,
                            name: library.cardName(positions[i].card),
                            reversed: positions[i].reversed,
                            onTap: () => setState(() => _revealed[i] = true),
                            onRevealed: () => _onRevealed(i),
                          ),
                        ),
                        const SizedBox(height: AppSpace.xs),
                        if (CardFace.isThumb(cardW) && _revealed[i])
                          Text(library.cardName(positions[i].card),
                              textAlign: TextAlign.center, style: AppText.caption.copyWith(color: AppColors.textPrimary)),
                        Text(positions[i].short, style: AppText.cardLabel, maxLines: 1, overflow: TextOverflow.visible, softWrap: false),
                        if (positions[i].reversed && _revealed[i])
                          Text(t.reversed, style: AppText.caption.copyWith(color: AppColors.primary)),
                      ]),
                    ),
                ]),
                const SizedBox(height: AppSpace.lg),
                if (!_showFull)
                  AnimatedSwitcher(
                    duration: MediaQuery.of(context).disableAnimations ? Duration.zero : AppMotion.panelUpdate,
                    child: _lastRevealed == null
                        ? const SizedBox.shrink()
                        : _CardPanel(
                            key: ValueKey(_lastRevealed),
                            label: positions[_lastRevealed!].long,
                            name: library.cardName(positions[_lastRevealed!].card),
                            reversed: positions[_lastRevealed!].reversed,
                            line: positions[_lastRevealed!].line,
                          ),
                  ),
                if (positions[1].reversed && _revealed[1] && !_showFull) ...[
                  const SizedBox(height: AppSpace.sm),
                  Text(t.reversedNote, style: AppText.caption.copyWith(fontStyle: FontStyle.italic)),
                ],
                if (_showFull) ...[
                  KeyedSubtree(key: _openingKey, child: Text(reading.opening, style: AppText.opening)),
                  const SizedBox(height: AppSpace.lg),
                  for (var i = 0; i < 3; i++)
                    _Section(
                      label: positions[i].long,
                      name: library.cardName(reading.sections[i].card),
                      cardId: reading.sections[i].card,
                      reversed: reading.sections[i].reversed,
                      paragraph: reading.sections[i].paragraph,
                      note: i == 0 && today.moodShiftedToday && widget.mode == ReadingMode.reopen
                          ? t.moodShiftedAt(clockTime(today.mood.at.toLocal(), Localizations.localeOf(context).toLanguageTag()))
                          : null,
                    ),
                  _AdvicePanel(title: t.todaysAdvice, text: reading.todaysAdvice),
                  const SizedBox(height: AppSpace.lg),
                  const _RatingRow(),
                  const SizedBox(height: AppSpace.lg),
                  if (first)
                    PrimaryButton(label: t.continueLabel, onPressed: () {
                      ref.read(analyticsProvider).event(Ev.firstReadingDone);
                      context.go('/save-profile');
                    })
                  else ...[
                    SecondaryButton(label: t.backHome, onPressed: () => context.go('/home')),
                    const SizedBox(height: AppSpace.xxl),
                    AdBanner(enabled: online, label: t.advertisement),
                  ],
                ],
              ]),
            ),
          ),
          if (!_showFull)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.screen, AppSpace.md, AppSpace.screen, AppSpace.lg),
              child: count == 3
                  ? AnimatedOpacity(
                      opacity: 1,
                      duration: AppMotion.readButtonFade,
                      child: PrimaryButton(label: t.readMyReading, onPressed: _readFull),
                    )
                  : SizedBox(height: AppSize.button, child: Center(child: Text(t.revealedCount(count), style: AppText.body))),
            ),
        ]),
      ),
    );
  }

  String _moodLine(AppLocalizations t, TodayCards c) {
    final part = switch (decanPart(c.mood.decan)) { 0 => t.decanStart, 1 => t.decanMiddle, _ => t.decanEnd };
    return t.moodLine(part, signName(t, decanSign(c.mood.decan)));
  }

  String _influenceLine(AppLocalizations t, DayCards f) {
    final planet = planetName(t, f.influencePlanet);
    return switch (f.influenceAspect) {
      null => t.influenceRuler(planet),
      'conjunction' => f.influenceReversed ? t.influenceTense(planet) : t.influenceConjunct(planet),
      _ => f.influenceReversed ? t.influenceTense(planet) : t.influenceHarmony(planet),
    };
  }
}

class _CardPanel extends StatelessWidget {
  const _CardPanel({super.key, required this.label, required this.name, required this.reversed, required this.line});
  final String label, name, line;
  final bool reversed;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.medium)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(), style: AppText.label.copyWith(color: AppColors.primary)),
          const SizedBox(height: AppSpace.xxs),
          Text.rich(TextSpan(text: name, style: AppText.title, children: [
            if (reversed) TextSpan(text: ' · ${l10n(context).reversed}', style: AppText.caption.copyWith(color: AppColors.primary)),
          ])),
          const SizedBox(height: AppSpace.xxs),
          Text(line, style: AppText.body),
        ]),
      );
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.name, required this.cardId, required this.reversed, required this.paragraph, this.note});
  final String label, name, cardId, paragraph;
  final bool reversed;
  final String? note;
  @override
  Widget build(BuildContext context) {
    final t = l10n(context);
    return Container(
      padding: const EdgeInsets.only(top: AppSpace.md, bottom: AppSpace.lg),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CardFace(width: AppSize.cardSection, cardId: cardId, reversed: reversed),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label.toUpperCase(), style: AppText.label),
              Text(name, style: AppText.title),
              if (reversed) Text(t.reversed, style: AppText.caption.copyWith(color: AppColors.primary)),
              if (note != null) Text(note!, style: AppText.caption.copyWith(color: AppColors.primary)),
            ]),
          ),
        ]),
        const SizedBox(height: AppSpace.sm),
        Text(paragraph, style: AppText.readingBody),
      ]),
    );
  }
}

class _AdvicePanel extends StatelessWidget {
  const _AdvicePanel({required this.title, required this.text});
  final String title, text;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: const Border(top: BorderSide(color: AppColors.primary, width: 2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title.toUpperCase(), style: AppText.label.copyWith(color: AppColors.primary)),
          const SizedBox(height: AppSpace.xs),
          Text(text, style: AppText.readingBody.copyWith(fontSize: 19)),
        ]),
      );
}

/// Ask -> thank-you. One rating per day.
class _RatingRow extends ConsumerWidget {
  const _RatingRow();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = l10n(context);
    final rec = ref.watch(readingProvider);
    if (rec?.rating != null) {
      return Container(
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.medium)),
        child: Row(children: [
          const Icon(Icons.check, color: AppColors.primary),
          const SizedBox(width: AppSpace.sm),
          Expanded(child: Semantics(liveRegion: true, child: Text(t.thanksRating, style: AppText.body))),
        ]),
      );
    }
    Future<void> rate(int v) async {
      if (rec == null) {
        await ref.read(readingProvider.notifier).start(
              ref.read(draftProvider).focusTopics.firstOrNull ?? ref.read(profileProvider)?.focusTopics.first ?? 'growth',
            );
      }
      await ref.read(readingProvider.notifier).rate(v);
      ref.read(analyticsProvider).event(Ev.rated, {'value': v});
    }

    return Row(children: [
      Expanded(child: Text(t.wasThisHelpful, style: AppText.bodyLarge)),
      SizedBox(width: 64, height: 56, child: IconButton(tooltip: t.helpful, onPressed: () => rate(1), icon: const Icon(Icons.thumb_up_outlined))),
      const SizedBox(width: AppSpace.xs),
      SizedBox(width: 64, height: 56, child: IconButton(tooltip: t.notHelpful, onPressed: () => rate(-1), icon: const Icon(Icons.thumb_down_outlined))),
    ]);
  }
}
