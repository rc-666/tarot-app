import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models.dart';
import '../app/config.dart';
import '../domain/notification_plan.dart';
import 'demo_sky.dart';
import 'local_store.dart';

/// Today's cards, network first with an offline cache.
/// Cards 2 and 3: user_daily_cards (signed in) -> daily_cards (sign + zone) -> cache.
/// Card 1 (mood): the latest mood shift at or before now, from the cached weekly list.
class SkyRepository {
  SkyRepository(this._sb, this._store);
  final SupabaseClient? _sb; // null when no backend is configured (offline demo)
  final LocalStore _store;

  /// Daily cards depend only on the UTC instant of 06:00 local, so any zone with the same UTC
  /// offset gives the same cards. Maps the phone's current offset to a zone the server computes
  /// (SUPPORTED_TZ in sky.ts).
  static String serverZoneFor(Duration offset) {
    const byHours = {
      -2: 'America/Noronha',
      -3: 'America/Sao_Paulo',
      -4: 'America/Manaus',
      -5: 'America/Rio_Branco',
      -6: 'America/Mexico_City',
      -8: 'America/Tijuana',
    };
    final h = (offset.inMinutes / 60).round();
    if (byHours.containsKey(h)) return byHours[h]!;
    // Nearest computed offset; cards may differ slightly for markets we don't support yet.
    final nearest = byHours.keys.reduce((a, b) => (a - h).abs() <= (b - h).abs() ? a : b);
    return byHours[nearest]!;
  }

  Future<TodayCards> today({
    required String day,
    required String sign,
    required Duration utcOffset,
    required String? userId,
    required DateTime nowUtc,
  }) async {
    DayCards? fixed;
    List<MoodShift> shifts = _store.moodShifts;
    if (AppConfig.demo) {
      final demo = await DemoSky.load();
      fixed = demo.cards(day, sign);
      shifts = demo.shiftsAround(nowUtc);
      await _store.setMoodShifts(shifts.where((s) => s.at.isAfter(nowUtc.subtract(const Duration(days: 2)))).take(30).toList());
    }
    final sb = AppConfig.demo ? null : _sb;
    if (sb != null) {
      try {
        if (userId != null && fixed == null) {
          final r = await sb.from('user_daily_cards').select().eq('user_id', userId).eq('day', day).maybeSingle();
          if (r != null) fixed = DayCards.fromRow(r);
        }
        if (fixed == null) {
          final r = await sb
              .from('daily_cards')
              .select()
              .eq('day', day)
              .eq('tz', serverZoneFor(utcOffset))
              .eq('sign', sign)
              .maybeSingle();
          if (r != null) fixed = DayCards.fromRow(r);
        }
        if (fixed != null) await _store.setDayCards([fixed]);
        final needShifts = shifts.isEmpty || shifts.last.at.isBefore(nowUtc.add(const Duration(days: 3)));
        if (needShifts) {
          final rows = await sb
              .from('mood_shifts')
              .select()
              .gte('at', nowUtc.subtract(const Duration(days: 2)).toIso8601String())
              .order('at');
          shifts = rows.map(MoodShift.fromRow).toList();
          if (shifts.isNotEmpty) await _store.setMoodShifts(shifts);
        }
      } on Exception {
        // fall through to cache
      }
    }
    fixed ??= _store.dayCards(day);
    final mood = moodAt(shifts, nowUtc);
    if (fixed == null || mood == null) throw const CardsNotReady();

    final localShift = mood.at.add(utcOffset);
    final shiftedToday = '${localShift.year.toString().padLeft(4, '0')}-${_pad2(localShift.month)}-${_pad2(localShift.day)}' == day;
    return TodayCards(day: day, mood: mood, moodShiftedToday: shiftedToday, fixed: fixed);
  }

  static String _pad2(int n) => n.toString().padLeft(2, '0');
}

class CardsNotReady implements Exception {
  const CardsNotReady();
}
