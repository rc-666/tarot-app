import 'models.dart';

/// Quiet hours and caps, decided 22 Nov 2026. Mirrors notifiableShifts() in sky.ts (tested there).
const quietStartHour = 21;
const quietEndHour = 8;
const morningHour = 6;

/// [toLocal] converts a UTC instant to the user's local wall-clock time (injected so tests and
/// the `timezone` package can share this code).
List<MoodShift> notifiableShifts(List<MoodShift> shifts, DateTime Function(DateTime utc) toLocal) {
  final seen = <String>{};
  final out = <MoodShift>[];
  final sorted = [...shifts]..sort((a, b) => a.at.compareTo(b.at));
  for (final s in sorted) {
    final local = toLocal(s.at);
    if (local.hour >= quietStartHour || local.hour < quietEndHour) continue;
    final day = '${local.year}-${local.month}-${local.day}';
    if (!seen.add(day)) continue;
    out.add(s);
  }
  return out;
}

/// The mood shift in force at [now] (latest one at or before now).
MoodShift? moodAt(List<MoodShift> shifts, DateTime now) {
  MoodShift? best;
  for (final s in shifts) {
    if (!s.at.isAfter(now) && (best == null || s.at.isAfter(best.at))) best = s;
  }
  return best;
}
