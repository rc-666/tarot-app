import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/tarot_card.dart';

/// 6d Generic error: card back + "Something went wrong" + "Try again".
class ErrorScreen extends StatelessWidget {
  const ErrorScreen({super.key, required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final t = l10n(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.screen),
          child: Column(children: [
            const Spacer(),
            const CardFace(width: 64),
            const SizedBox(height: AppSpace.lg),
            Text(t.errorTitle, style: AppText.title.copyWith(fontSize: 24), textAlign: TextAlign.center),
            const SizedBox(height: AppSpace.sm),
            Text(t.errorBody, style: AppText.body, textAlign: TextAlign.center),
            const SizedBox(height: AppSpace.lg),
            PrimaryButton(label: t.tryAgain, onPressed: onRetry),
            const Spacer(flex: 2),
          ]),
        ),
      ),
    );
  }
}
