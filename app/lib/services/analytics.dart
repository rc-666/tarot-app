import 'package:posthog_flutter/posthog_flutter.dart';

import '../app/config.dart';

/// Thin PostHog wrapper. Events only; never send birth data or email.
/// The API key is set with --dart-define=POSTHOG_KEY; without it, nothing is sent.
class Analytics {
  bool _on = false;

  Future<void> init() async {
    if (AppConfig.posthogKey.isEmpty) return;
    final config = PostHogConfig(AppConfig.posthogKey)
      ..host = AppConfig.posthogHost
      ..captureApplicationLifecycleEvents = true;
    await Posthog().setup(config);
    _on = true;
  }

  void event(String name, [Map<String, Object> props = const {}]) {
    if (_on) Posthog().capture(eventName: name, properties: props);
  }

  void identify(String userId) {
    if (_on) Posthog().identify(userId: userId);
  }

  void reset() {
    if (_on) Posthog().reset();
  }
}

/// Event names in one place so the dashboard stays consistent.
class Ev {
  static const onboardingStep = 'onboarding_step';
  static const firstReadingDone = 'first_reading_done';
  static const profileSaved = 'profile_saved';
  static const signIn = 'sign_in';
  static const readingStarted = 'reading_started';
  static const cardRevealed = 'card_revealed';
  static const readingOpened = 'reading_full_opened';
  static const rated = 'reading_rated';
  static const remindersChoice = 'reminders_choice';
  static const notificationOpened = 'notification_opened';
  static const accountDeleted = 'account_deleted';
}
