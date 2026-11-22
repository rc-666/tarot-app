import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../domain/cards.dart';
import '../../../domain/models.dart';
import '../../../services/analytics.dart';
import '../../../state/providers.dart';
import '../../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/tarot_card.dart';

/// Profile steps 1a–1h. In edit mode (6f) the same step shows the field name as the title,
/// no progress bar, no Back/Next pair, and one Save button.
class EditMode {
  const EditMode({required this.title, required this.onSave});
  final String title;
  final Future<void> Function() onSave;
}

class _Step extends StatelessWidget {
  const _Step({required this.step, required this.body, required this.onBack, required this.onNext, this.nextLabel, this.edit, this.canSave = true});
  final int step;
  final Widget body;
  final VoidCallback onBack;
  final VoidCallback? onNext;
  final String? nextLabel;
  final EditMode? edit;
  final bool canSave;

  @override
  Widget build(BuildContext context) {
    final e = edit;
    if (e != null) {
      return AppScaffold(
        title: e.title,
        body: body,
        footer: _SaveButton(onSave: canSave ? e.onSave : null),
      );
    }
    return AppScaffold(
      showBack: step > 1,
      onBack: onBack,
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        StepProgress(step: step),
        const SizedBox(height: AppSpace.xl),
        body,
      ]),
      footer: step == 1
          ? PrimaryButton(label: l10n(context).next, onPressed: onNext)
          : BackNextFooter(onBack: onBack, onNext: onNext, nextLabel: nextLabel),
    );
  }
}

class _SaveButton extends StatefulWidget {
  const _SaveButton({required this.onSave});
  final Future<void> Function()? onSave;
  @override
  State<_SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<_SaveButton> {
  bool _busy = false;
  String? _error;
  @override
  Widget build(BuildContext context) {
    final t = l10n(context);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (_error != null) ...[InlineAlert(title: t.noConnection, body: _error!, icon: Icons.wifi_off), const SizedBox(height: AppSpace.md)],
      PrimaryButton(
        label: t.save,
        loading: _busy,
        loadingLabel: t.saving,
        onPressed: widget.onSave == null
            ? null
            : () async {
                setState(() {
                  _busy = true;
                  _error = null;
                });
                try {
                  await widget.onSave!();
                  if (context.mounted) context.pop();
                } catch (_) {
                  if (mounted) setState(() => _error = t.networkError);
                } finally {
                  if (mounted) setState(() => _busy = false);
                }
              },
      ),
    ]);
  }
}

void _track(WidgetRef ref, String step) => ref.read(analyticsProvider).event(Ev.onboardingStep, {'step': step});

// ---------------- 1a Language ----------------
class LanguageStep extends ConsumerWidget {
  const LanguageStep({super.key, this.edit});
  final EditMode? edit;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = l10n(context);
    final draft = ref.watch(draftProvider);
    final current = draft.language; // in edit mode the draft is seeded from the profile
    final phone = Localizations.localeOf(context).languageCode;
    const options = {'en': 'English', 'pt': 'Português', 'es': 'Español'};
    return _Step(
      step: 1,
      edit: edit,
      onBack: () {},
      onNext: () {
        _track(ref, 'language');
        context.push('/onboarding/name');
      },
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t.langTitle, style: AppText.heading),
        const SizedBox(height: AppSpace.sm),
        Text(t.langBody, style: AppText.body),
        const SizedBox(height: AppSpace.lg),
        for (final e in options.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.sm),
            child: _RadioRow(
              label: e.value,
              sub: e.key == phone ? t.langFromPhone : null,
              selected: current == e.key,
              onTap: () => ref.read(draftProvider.notifier).update((d) => d.copyWith(language: e.key)),
            ),
          ),
      ]),
    );
  }
}

class _RadioRow extends StatelessWidget {
  const _RadioRow({required this.label, required this.selected, required this.onTap, this.sub});
  final String label;
  final String? sub;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.medium),
              border: Border.all(color: selected ? AppColors.primary : AppColors.divider, width: selected ? 2 : 1),
            ),
            child: Row(children: [
              Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? AppColors.primary : AppColors.textSecondary),
              const SizedBox(width: AppSpace.sm),
              Expanded(child: Text(label, style: AppText.bodyLarge)),
              if (sub != null) Text(sub!, style: AppText.caption),
            ]),
          ),
        ),
      );
}

// ---------------- 1b/1c Name ----------------
class NameStep extends ConsumerStatefulWidget {
  const NameStep({super.key, this.edit, this.initial});
  final EditMode? edit;
  final String? initial;
  @override
  ConsumerState<NameStep> createState() => _NameStepState();
}

class _NameStepState extends ConsumerState<NameStep> {
  late final _c = TextEditingController(text: widget.initial ?? ref.read(draftProvider).firstName);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = l10n(context);
    final ok = _c.text.trim().isNotEmpty;
    return _Step(
      step: 2,
      edit: widget.edit,
      canSave: ok,
      onBack: () => context.pop(),
      onNext: ok
          ? () {
              _track(ref, 'name');
              context.push('/onboarding/birth-date');
            }
          : null,
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t.nameTitle, style: AppText.heading),
        const SizedBox(height: AppSpace.lg),
        LabeledField(
          label: t.nameLabel,
          child: TextField(
            controller: _c,
            autofocus: widget.edit == null,
            textCapitalization: TextCapitalization.words,
            maxLength: 60,
            decoration: fieldDecoration(hint: t.nameHint).copyWith(counterText: ''),
            style: AppText.bodyLarge,
            onChanged: (v) {
              setState(() {});
              ref.read(draftProvider.notifier).update((d) => d.copyWith(firstName: v));
            },
          ),
        ),
      ]),
    );
  }
}

// ---------------- 1d Birth date ----------------
class BirthDateStep extends ConsumerStatefulWidget {
  const BirthDateStep({super.key, this.edit, this.initial});
  final EditMode? edit;
  final DateTime? initial;
  @override
  ConsumerState<BirthDateStep> createState() => _BirthDateStepState();
}

class _BirthDateStepState extends ConsumerState<BirthDateStep> {
  late DateTime _d;
  late final int _maxYear;
  static const _minYear = 1930;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _maxYear = now.year - 18; // year range 1930 to (today − 18 years)
    _d = widget.initial ?? ref.read(draftProvider).birthDate ?? DateTime(1975, 6, 15);
    _commit();
  }

  void _commit() => ref.read(draftProvider.notifier).update((d) => d.copyWith(birthDate: _d));

  void _set({int? day, int? month, int? year}) {
    final y = year ?? _d.year, m = month ?? _d.month;
    final maxDay = daysInMonth(y, m);
    setState(() => _d = DateTime(y, m, (day ?? _d.day).clamp(1, maxDay)));
    _commit();
  }

  @override
  Widget build(BuildContext context) {
    final t = l10n(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final months = List.generate(12, (i) => DateFormat.MMM(locale).format(DateTime(2000, i + 1)));
    final days = daysInMonth(_d.year, _d.month); // only days that exist (Feb 29 in leap years only)
    return _Step(
      step: 3,
      edit: widget.edit,
      onBack: () => context.pop(),
      onNext: () {
        _track(ref, 'birth_date');
        context.push('/onboarding/sign');
      },
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t.birthDateTitle, style: AppText.heading),
        const SizedBox(height: AppSpace.sm),
        if (widget.edit == null) Text(t.birthDateBody, style: AppText.body),
        const SizedBox(height: AppSpace.lg),
        Row(children: [
          Expanded(child: Center(child: Text(t.day, style: AppText.body))),
          Expanded(child: Center(child: Text(t.month, style: AppText.body))),
          Expanded(child: Center(child: Text(t.year, style: AppText.body))),
        ]),
        const SizedBox(height: AppSpace.xs),
        Container(
          height: 220,
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.medium)),
          child: Row(children: [
            Expanded(child: _Wheel(key: ValueKey('d$days'), count: days, selected: _d.day - 1, label: (i) => '${i + 1}', onChanged: (i) => _set(day: i + 1))),
            Expanded(child: _Wheel(count: 12, selected: _d.month - 1, label: (i) => months[i], onChanged: (i) => _set(month: i + 1))),
            Expanded(
              child: _Wheel(
                count: _maxYear - _minYear + 1,
                selected: _d.year.clamp(_minYear, _maxYear) - _minYear,
                label: (i) => '${_minYear + i}',
                onChanged: (i) => _set(year: _minYear + i),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Wheel extends StatefulWidget {
  const _Wheel({super.key, required this.count, required this.selected, required this.label, required this.onChanged});
  final int count, selected;
  final String Function(int) label;
  final ValueChanged<int> onChanged;
  @override
  State<_Wheel> createState() => _WheelState();
}

class _WheelState extends State<_Wheel> {
  late final _c = FixedExtentScrollController(initialItem: widget.selected);
  late int _sel = widget.selected;
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CupertinoPicker.builder(
        scrollController: _c,
        itemExtent: 44,
        childCount: widget.count,
        selectionOverlay: Container(
          decoration: const BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: AppColors.primary))),
        ),
        onSelectedItemChanged: (i) {
          setState(() => _sel = i);
          widget.onChanged(i);
        },
        itemBuilder: (_, i) => Center(
          child: Text(
            widget.label(i),
            style: i == _sel
                ? AppText.bodyLarge.copyWith(fontSize: 22, fontWeight: FontWeight.w600)
                : AppText.bodyLarge.copyWith(fontSize: 18, color: AppColors.textSecondary),
          ),
        ),
      );
}

// ---------------- 1e Your sign and card ----------------
class SignRewardStep extends ConsumerWidget {
  const SignRewardStep({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = l10n(context);
    final date = ref.watch(draftProvider).birthDate ?? DateTime(1975, 6, 15);
    final sign = sunSignFor(date);
    final card = signCard[sign]!;
    final lib = ref.watch(libraryProvider).valueOrNull;
    final name = lib?.cardName(card) ?? '';
    return _Step(
      step: 3,
      nextLabel: t.continueLabel,
      onBack: () => context.pop(),
      onNext: () => context.push('/onboarding/time-place'),
      body: Column(children: [
        const SizedBox(height: AppSpace.md),
        CardFace(width: AppSize.cardReward, cardId: card, name: name),
        const SizedBox(height: AppSpace.lg),
        Text(t.signRewardTitle(signName(t, sign)), style: AppText.heading, textAlign: TextAlign.center),
        const SizedBox(height: AppSpace.sm),
        Text(t.signRewardBody(name, lib?.cardShort(card) ?? ''), style: AppText.readingBody, textAlign: TextAlign.center),
      ]),
    );
  }
}

// ---------------- 1f/1g Time and place ----------------
class TimePlaceStep extends ConsumerStatefulWidget {
  const TimePlaceStep({super.key, this.edit, this.only});
  final EditMode? edit;
  final String? only; // 'time' | 'place' in edit mode
  @override
  ConsumerState<TimePlaceStep> createState() => _TimePlaceStepState();
}

class _TimePlaceStepState extends ConsumerState<TimePlaceStep> {
  final _q = TextEditingController();
  List<Place> _results = const [];
  bool _searched = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _q.text = ref.read(draftProvider).birthPlace?.label ?? '';
  }

  @override
  void dispose() {
    _q.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _search(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () async {
      final r = await ref.read(placesProvider).search(v);
      if (mounted) {
        setState(() {
          _results = r;
          _searched = v.trim().length >= 2;
        });
      }
    });
  }

  Future<void> _pickTime() async {
    final cur = ref.read(draftProvider).birthTime;
    final init = cur == null ? const TimeOfDay(hour: 12, minute: 0) : TimeOfDay(hour: int.parse(cur.substring(0, 2)), minute: int.parse(cur.substring(3, 5)));
    final picked = await showTimePicker(context: context, initialTime: init, initialEntryMode: TimePickerEntryMode.input);
    if (picked != null) {
      final s = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      ref.read(draftProvider.notifier).update((d) => d.copyWith(birthTime: () => s));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = l10n(context);
    final draft = ref.watch(draftProvider);
    final showTime = widget.only != 'place', showPlace = widget.only != 'time';
    return _Step(
      step: 4,
      edit: widget.edit,
      onBack: () => context.pop(),
      onNext: () {
        _track(ref, 'time_place');
        context.push('/onboarding/topics');
      },
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t.timePlaceTitle, style: AppText.heading),
        const SizedBox(height: AppSpace.sm),
        Text(t.timePlaceBody, style: AppText.body),
        const SizedBox(height: AppSpace.lg),
        if (showTime)
          LabeledField(
            label: t.birthTime,
            child: Row(children: [
              Expanded(
                child: InkWell(
                  onTap: _pickTime,
                  child: InputDecorator(
                    decoration: fieldDecoration(),
                    child: Text(draft.birthTime ?? t.notKnown, style: AppText.bodyLarge.copyWith(color: draft.birthTime == null ? AppColors.textSecondary : null)),
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              TextButton(
                onPressed: () => ref.read(draftProvider.notifier).update((d) => d.copyWith(birthTime: () => null)),
                child: Text(t.dontKnow),
              ),
            ]),
          ),
        if (showTime && showPlace) const SizedBox(height: AppSpace.lg),
        if (showPlace) ...[
          LabeledField(
            label: t.birthPlace,
            child: TextField(
              controller: _q,
              decoration: fieldDecoration(hint: t.placeHint, suffix: const Icon(Icons.search)),
              style: AppText.bodyLarge,
              onChanged: (v) {
                ref.read(draftProvider.notifier).update((d) => d.copyWith(birthPlace: () => null));
                _search(v);
              },
            ),
          ),
          if (_results.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: AppSpace.xs),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.medium)),
              child: Column(children: [
                for (final p in _results)
                  InkWell(
                    onTap: () {
                      ref.read(draftProvider.notifier).update((d) => d.copyWith(birthPlace: () => p));
                      _q.text = p.label;
                      FocusScope.of(context).unfocus();
                      setState(() => _results = const []);
                    },
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 56),
                      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.xs),
                      alignment: Alignment.centerLeft,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(p.name, style: AppText.bodyLarge.copyWith(fontSize: 16)),
                        Text(p.region, style: AppText.caption),
                      ]),
                    ),
                  ),
              ]),
            )
          else if (_searched && draft.birthPlace == null) ...[
            const SizedBox(height: AppSpace.sm),
            Text(t.placeNoResults, style: AppText.bodyLarge),
            Text(t.placeNoResultsBody, style: AppText.body),
            TextButton(
              onPressed: () {
                _q.clear();
                setState(() => _searched = false);
                if (widget.edit == null) context.push('/onboarding/topics');
              },
              child: Text(t.dontKnowPlace),
            ),
          ],
        ],
      ]),
    );
  }
}

// ---------------- 1h Focus topics ----------------
class TopicsStep extends ConsumerStatefulWidget {
  const TopicsStep({super.key, this.edit});
  final EditMode? edit;
  @override
  ConsumerState<TopicsStep> createState() => _TopicsStepState();
}

class _TopicsStepState extends ConsumerState<TopicsStep> {
  bool _limitHint = false;

  @override
  Widget build(BuildContext context) {
    final t = l10n(context);
    final sel = ref.watch(draftProvider).focusTopics;
    return _Step(
      step: 5,
      edit: widget.edit,
      canSave: sel.isNotEmpty,
      nextLabel: t.seeMyCards,
      onBack: () => context.pop(),
      onNext: sel.isEmpty
          ? null
          : () {
              _track(ref, 'topics');
              context.go('/first-reading');
            },
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t.topicsTitle, style: AppText.heading),
        const SizedBox(height: AppSpace.sm),
        Text(t.topicsBody, style: AppText.body),
        const SizedBox(height: AppSpace.lg),
        for (final topic in topics)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.sm),
            child: _TopicChip(
              topic: topic,
              selected: sel.contains(topic),
              onTap: () {
                final cur = [...sel];
                if (cur.contains(topic)) {
                  cur.remove(topic);
                } else if (cur.length >= 2) {
                  setState(() => _limitHint = true); // decision: block the 3rd tap
                  return;
                } else {
                  cur.add(topic);
                }
                setState(() => _limitHint = false);
                ref.read(draftProvider.notifier).update((d) => d.copyWith(focusTopics: cur));
              },
            ),
          ),
        if (_limitHint) Semantics(liveRegion: true, child: Text(t.topicsLimit, style: AppText.caption.copyWith(color: AppColors.primary))),
      ]),
    );
  }
}

class _TopicChip extends StatelessWidget {
  const _TopicChip({required this.topic, required this.selected, required this.onTap});
  final String topic;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final t = l10n(context);
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.xs),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.medium),
            border: Border.all(color: selected ? AppColors.primary : AppColors.divider, width: selected ? 2 : 1),
          ),
          child: Row(children: [
            SizedBox(width: 28, child: Icon(topicIcon(topic), color: AppColors.primary, size: 22)),
            const SizedBox(width: AppSpace.sm),
            Expanded(child: Text(topicName(t, topic), style: AppText.bodyLarge)),
            if (selected) const Icon(Icons.check, color: AppColors.primary),
          ]),
        ),
      ),
    );
  }
}
