import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/config.dart';
import '../data/account_repository.dart';
import '../data/content_repository.dart';
import '../data/local_store.dart';
import '../data/sky_repository.dart';
import '../domain/cards.dart';
import '../domain/models.dart';
import '../domain/reading_assembler.dart';
import '../services/analytics.dart';
import '../services/notifications.dart';

// ---- Overridden in main() after async setup ----
final storeProvider = Provider<LocalStore>((_) => throw UnimplementedError());
final notificationsProvider = Provider<NotificationService>((_) => throw UnimplementedError());
final analyticsProvider = Provider<Analytics>((_) => throw UnimplementedError());
final phoneTzProvider = Provider<String>((_) => 'America/Sao_Paulo');

final supabaseProvider = Provider<SupabaseClient?>((_) => AppConfig.hasBackend ? Supabase.instance.client : null);

final accountProvider = Provider<AccountApi?>((ref) {
  if (AppConfig.demo) return DemoAccount(ref.watch(storeProvider));
  final sb = ref.watch(supabaseProvider);
  return sb == null ? null : SupabaseAccount(sb, ref.watch(storeProvider));
});
final skyProvider = Provider((ref) => SkyRepository(ref.watch(supabaseProvider), ref.watch(storeProvider)));
final libraryRepoProvider = Provider((ref) => LibraryRepository(ref.watch(storeProvider)));
final placesProvider = Provider((_) => PlacesRepository());

// ---- Onboarding draft (before an account exists) ----
class DraftNotifier extends Notifier<ProfileDraft> {
  @override
  ProfileDraft build() => ref.read(storeProvider).draft;
  void update(ProfileDraft Function(ProfileDraft) f) {
    state = f(state);
    ref.read(storeProvider).setDraft(state);
  }
}

final draftProvider = NotifierProvider<DraftNotifier, ProfileDraft>(DraftNotifier.new);

// ---- Saved profile ----
class ProfileNotifier extends Notifier<Profile?> {
  @override
  Profile? build() => ref.read(storeProvider).profile;
  void set(Profile? p) {
    state = p;
    ref.read(storeProvider).setProfile(p);
  }
}

final profileProvider = NotifierProvider<ProfileNotifier, Profile?>(ProfileNotifier.new);

/// App language: profile, else draft (1a picks it from the phone locale).
final languageProvider = Provider<String>((ref) => ref.watch(profileProvider)?.language ?? ref.watch(draftProvider).language);

// ---- Clock: refreshed on resume so a day change refreshes Home (spec 7) ----
class ClockNotifier extends Notifier<DateTime> with WidgetsBindingObserver {
  Timer? _timer;
  @override
  DateTime build() {
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _tick());
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _timer?.cancel();
    });
    return DateTime.now();
  }

  void _tick() {
    final now = DateTime.now();
    // Only rebuild listeners when the day or the hour changes (greeting, mood shift check).
    if (now.day != state.day || now.hour != state.hour) state = now;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) state = DateTime.now();
  }
}

final clockProvider = NotifierProvider<ClockNotifier, DateTime>(ClockNotifier.new);

String dayKey(DateTime local) =>
    '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';

final todayKeyProvider = Provider<String>((ref) => dayKey(ref.watch(clockProvider)));

// ---- Connectivity ----
final onlineProvider = StreamProvider<bool>((ref) async* {
  final c = Connectivity();
  bool online(List<ConnectivityResult> r) => r.any((x) => x != ConnectivityResult.none);
  yield online(await c.checkConnectivity());
  yield* c.onConnectivityChanged.map(online);
});

// ---- Today's cards ----
final signProvider = Provider<String?>((ref) {
  final p = ref.watch(profileProvider);
  if (p != null) return p.sunSign;
  final d = ref.watch(draftProvider).birthDate;
  return d == null ? null : sunSignFor(d);
});

final todayCardsProvider = FutureProvider<TodayCards>((ref) async {
  final sign = ref.watch(signProvider);
  final day = ref.watch(todayKeyProvider);
  final now = ref.watch(clockProvider);
  if (sign == null) throw StateError('no sign yet');
  final userId = ref.watch(accountProvider)?.userId;
  return ref.read(skyProvider).today(
        day: day,
        sign: sign,
        utcOffset: now.timeZoneOffset,
        userId: userId,
        nowUtc: now.toUtc(),
      );
});

final libraryProvider = FutureProvider<Library>((ref) async {
  final lang = ref.watch(languageProvider);
  final repo = ref.read(libraryRepoProvider);
  final lib = await repo.load(lang);
  // Background check for a newer library; next start uses it.
  unawaited(repo.refresh(lang, lib.version));
  return lib;
});

// ---- Today's reading record (topic + rating) ----
class ReadingNotifier extends Notifier<ReadingRecord?> {
  @override
  ReadingRecord? build() => ref.read(storeProvider).reading(ref.watch(todayKeyProvider));

  Future<void> start(String topic) async {
    final r = ReadingRecord(day: ref.read(todayKeyProvider), topic: topic);
    state = r;
    await _save(r);
  }

  Future<void> rate(int value) async {
    final r = state;
    if (r == null || r.rating != null) return; // one rating per day
    final nr = ReadingRecord(day: r.day, topic: r.topic, rating: value);
    state = nr;
    await _save(nr);
  }

  Future<void> _save(ReadingRecord r) async {
    final acc = ref.read(accountProvider);
    if (acc != null && acc.userId != null) {
      await acc.saveReading(r);
    } else {
      final store = ref.read(storeProvider);
      await store.setReading(r);
      await store.setFirstReading(r);
    }
  }
}

final readingProvider = NotifierProvider<ReadingNotifier, ReadingRecord?>(ReadingNotifier.new);
