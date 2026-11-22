import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../state/providers.dart';
import '../ui/screens/auth/auth_screens.dart';
import '../ui/screens/home/home_screen.dart';
import '../ui/screens/onboarding/onboarding_screens.dart';
import '../ui/screens/reading/reading_screen.dart';
import '../ui/screens/settings/settings_screens.dart';

/// 4 screens + settings sheet, no tab bar. System back works everywhere.
final routerProvider = Provider<GoRouter>((ref) {
  final sb = ref.read(supabaseProvider);
  final router = GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      if (state.matchedLocation != '/') return null;
      final hasProfile = ref.read(profileProvider) != null && ref.read(accountProvider)?.userId != null;
      if (hasProfile) return '/home';
      final draft = ref.read(draftProvider);
      if (draft.focusTopics.isNotEmpty && draft.birthDate != null) return '/save-profile'; // resume after the first reading
      return '/onboarding/language';
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SizedBox.shrink()),
      GoRoute(path: '/onboarding/language', builder: (_, __) => const LanguageStep()),
      GoRoute(path: '/onboarding/name', builder: (_, __) => const NameStep()),
      GoRoute(path: '/onboarding/birth-date', builder: (_, __) => const BirthDateStep()),
      GoRoute(path: '/onboarding/sign', builder: (_, __) => const SignRewardStep()),
      GoRoute(path: '/onboarding/time-place', builder: (_, __) => const TimePlaceStep()),
      GoRoute(path: '/onboarding/topics', builder: (_, __) => const TopicsStep()),
      GoRoute(path: '/first-reading', builder: (_, __) => const ReadingScreen(mode: ReadingMode.first)),
      GoRoute(path: '/save-profile', builder: (_, __) => const SaveProfileScreen()),
      GoRoute(path: '/sign-in', builder: (_, s) => SignInScreen(email: s.uri.queryParameters['email'])),
      GoRoute(path: '/forgot', builder: (_, s) => ForgotScreen(email: s.uri.queryParameters['email'])),
      GoRoute(path: '/forgot-sent', builder: (_, s) => ForgotSentScreen(email: s.uri.queryParameters['email'] ?? '')),
      GoRoute(path: '/new-password', builder: (_, __) => const NewPasswordScreen()),
      GoRoute(path: '/reminders', builder: (_, __) => const RemindersScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/reading', builder: (_, __) => const TopicPickerScreen()),
      GoRoute(path: '/reading/reveal', builder: (_, __) => const ReadingScreen(mode: ReadingMode.daily)),
      GoRoute(path: '/reading/today', builder: (_, __) => const ReadingScreen(mode: ReadingMode.reopen)),
      GoRoute(path: '/edit-profile', builder: (_, __) => const EditProfileScreen()),
      GoRoute(path: '/edit/:field', builder: (_, s) => EditFieldScreen(field: s.pathParameters['field']!)),
    ],
  );

  // The reset email's deep link signs her in with a recovery session -> 3l.
  StreamSubscription<AuthState>? sub;
  if (sb != null) {
    sub = sb.auth.onAuthStateChange.listen((s) {
      if (s.event == AuthChangeEvent.passwordRecovery) router.go('/new-password');
    });
  }
  ref.onDispose(() => sub?.cancel());
  return router;
});
