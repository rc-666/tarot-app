import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';

AppLocalizations l10n(BuildContext c) => AppLocalizations.of(c);

String signName(AppLocalizations t, String s) => switch (s) {
      'aries' => t.sign_aries,
      'taurus' => t.sign_taurus,
      'gemini' => t.sign_gemini,
      'cancer' => t.sign_cancer,
      'leo' => t.sign_leo,
      'virgo' => t.sign_virgo,
      'libra' => t.sign_libra,
      'scorpio' => t.sign_scorpio,
      'sagittarius' => t.sign_sagittarius,
      'capricorn' => t.sign_capricorn,
      'aquarius' => t.sign_aquarius,
      _ => t.sign_pisces,
    };

String planetName(AppLocalizations t, String p) => switch (p) {
      'sun' => t.planet_sun,
      'moon' => t.planet_moon,
      'mercury' => t.planet_mercury,
      'venus' => t.planet_venus,
      'mars' => t.planet_mars,
      'jupiter' => t.planet_jupiter,
      'saturn' => t.planet_saturn,
      'uranus' => t.planet_uranus,
      'neptune' => t.planet_neptune,
      _ => t.planet_pluto,
    };

String topicName(AppLocalizations t, String topic) => switch (topic) {
      'love' => t.topic_love,
      'family' => t.topic_family,
      'money' => t.topic_money,
      'health' => t.topic_health,
      _ => t.topic_growth,
    };

IconData topicIcon(String topic) => switch (topic) {
      'love' => Icons.favorite_border,
      'family' => Icons.home_outlined,
      'money' => Icons.work_outline,
      'health' => Icons.spa_outlined,
      _ => Icons.auto_awesome_outlined,
    }; // placeholder icons until the design agent delivers the set

/// Screen with a top bar, scrolling content and a pinned footer (spec 3).
class AppScaffold extends StatelessWidget {
  const AppScaffold({super.key, this.title, this.showBack = true, this.onBack, required this.body, this.footer, this.actions});
  final String? title;
  final bool showBack;
  final VoidCallback? onBack;
  final Widget body;
  final Widget? footer;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: (showBack || title != null || actions != null)
          ? AppBar(
              backgroundColor: AppColors.background,
              surfaceTintColor: Colors.transparent,
              toolbarHeight: AppSize.topBar,
              automaticallyImplyLeading: false,
              leading: showBack
                  ? IconButton(
                      tooltip: l10n(context).back,
                      icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                      onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                    )
                  : null,
              titleSpacing: showBack ? 0 : AppSpace.screen,
              title: title == null ? null : Text(title!, style: AppText.bodyLarge.copyWith(fontWeight: FontWeight.w500)),
              actions: actions,
            )
          : null,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(AppSpace.screen, AppSpace.md, AppSpace.screen, AppSpace.lg),
                child: body,
              ),
            ),
            if (footer != null)
              Padding(padding: const EdgeInsets.fromLTRB(AppSpace.screen, AppSpace.md, AppSpace.screen, AppSpace.lg), child: footer),
          ],
        ),
      ),
    );
  }
}

/// Main action. Loading shows spinner + verb ("Saving…"). Grows when the label wraps.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, this.onPressed, this.loading = false, this.loadingLabel});
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final String? loadingLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
          child: loading
              ? Row(mainAxisSize: MainAxisSize.min, children: [
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textPrimary)),
                  const SizedBox(width: AppSpace.sm),
                  Flexible(child: Text(loadingLabel ?? label, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textPrimary))),
                ])
              : Text(label, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.label, this.onPressed, this.color});
  final String label;
  final VoidCallback? onPressed;
  final Color? color; // error for destructive
  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: onPressed,
          style: color == null ? null : OutlinedButton.styleFrom(foregroundColor: color, side: BorderSide(color: color!)),
          child: Padding(padding: const EdgeInsets.symmetric(vertical: AppSpace.xs), child: Text(label, textAlign: TextAlign.center)),
        ),
      );
}

/// Profile steps: Back (120 dp) + Next (fills the rest).
class BackNextFooter extends StatelessWidget {
  const BackNextFooter({super.key, required this.onBack, required this.onNext, this.nextLabel});
  final VoidCallback onBack;
  final VoidCallback? onNext;
  final String? nextLabel;
  @override
  Widget build(BuildContext context) {
    final t = l10n(context);
    return Row(children: [
      SizedBox(
        width: 120,
        child: OutlinedButton(onPressed: onBack, child: Text(t.back)),
      ),
      const SizedBox(width: AppSpace.sm),
      Expanded(child: PrimaryButton(label: nextLabel ?? t.next, onPressed: onNext)),
    ]);
  }
}

/// 5 segments, 4 dp high, gap 6; "Step 3 of 5" below.
class StepProgress extends StatelessWidget {
  const StepProgress({super.key, required this.step, this.total = 5});
  final int step, total;
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        for (var i = 1; i <= total; i++) ...[
          Expanded(
            child: Container(height: 4, decoration: BoxDecoration(color: i <= step ? AppColors.primary : AppColors.divider, borderRadius: BorderRadius.circular(2))),
          ),
          if (i < total) const SizedBox(width: 6),
        ],
      ]),
      const SizedBox(height: AppSpace.xs),
      Text(l10n(context).stepOf(step, total), style: AppText.body),
    ]);
  }
}

/// Label above the field, never only a placeholder (spec 4).
class LabeledField extends StatelessWidget {
  const LabeledField({super.key, required this.label, required this.child, this.error});
  final String label;
  final Widget child;
  final String? error;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppText.body.copyWith(fontSize: 15, fontWeight: FontWeight.w500)),
        const SizedBox(height: AppSpace.xs),
        child,
        if (error != null)
          Semantics(
            liveRegion: true,
            child: Padding(padding: const EdgeInsets.only(top: AppSpace.xs), child: Text(error!, style: AppText.caption.copyWith(color: AppColors.error))),
          ),
      ]);
}

InputDecoration fieldDecoration({String? hint, bool error = false, Widget? suffix}) => InputDecoration(
      hintText: hint,
      suffixIcon: suffix,
      enabledBorder: error
          ? OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.medium), borderSide: const BorderSide(color: AppColors.error, width: 2))
          : null,
    );

/// Inline alert used for network errors (3h) and "email already used" (3f).
class InlineAlert extends StatelessWidget {
  const InlineAlert({super.key, required this.title, required this.body, this.icon});
  final String title, body;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpace.md),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.medium)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (icon != null) ...[Icon(icon, color: AppColors.error, size: 22), const SizedBox(width: AppSpace.sm)],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: AppText.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: AppSpace.xxs),
                Text(body, style: AppText.body),
              ]),
            ),
          ]),
        ),
      );
}

class OfflineBar extends StatelessWidget {
  const OfflineBar({super.key});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: AppColors.surfaceRaised,
        padding: EdgeInsets.fromLTRB(AppSpace.screen, MediaQuery.paddingOf(context).top + AppSpace.sm, AppSpace.screen, AppSpace.sm),
        child: Row(children: [
          const Icon(Icons.wifi_off, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: AppSpace.sm),
          Expanded(child: Text(l10n(context).offlineBar, style: AppText.body.copyWith(color: AppColors.textPrimary))),
        ]),
      );
}

class Skeleton extends StatelessWidget {
  const Skeleton({super.key, required this.width, required this.height});
  final double width, height;
  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: AppColors.surfaceRaised, borderRadius: BorderRadius.circular(AppRadius.small)),
      );
}

