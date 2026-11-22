import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../domain/models.dart';

/// Demo build only: real cards from the server's sky engine, pre-computed for ~7 months
/// (São Paulo time, 06:00 reference) and bundled as assets/demo/sky.json.
/// Outside that range the days wrap around, so the demo never runs dry.
class DemoSky {
  static DemoSky? _instance;
  DemoSky._(this._from, this._days, this._cards, this.shifts);

  final DateTime _from;
  final int _days;
  final Map<String, dynamic> _cards;
  final List<MoodShift> shifts;

  static Future<DemoSky> load() async {
    if (_instance != null) return _instance!;
    final j = jsonDecode(await rootBundle.loadString('assets/demo/sky.json')) as Map<String, dynamic>;
    final shifts = [
      for (final r in j['moodShifts'] as List)
        MoodShift(
          at: DateTime.parse((r as List)[0] as String).toUtc(),
          decan: (r[1] as num).toInt(),
          card: r[2] as String,
          moonSign: r[3] as String,
        ),
    ];
    return _instance = DemoSky._(DateTime.parse(j['from'] as String), (j['days'] as num).toInt(), j['cards'] as Map<String, dynamic>, shifts);
  }

  DayCards cards(String day, String sign) {
    var key = day;
    if (!_cards.containsKey(key)) {
      final offset = DateTime.parse(day).difference(_from).inDays % _days;
      key = _from.add(Duration(days: offset)).toIso8601String().substring(0, 10);
    }
    final r = (_cards[key] as Map<String, dynamic>)[sign] as List;
    return DayCards(
      day: day,
      influencePlanet: r[0] as String,
      influenceCard: r[1] as String,
      influenceReversed: r[2] as bool,
      influenceAspect: r[3] as String?,
      adviceCard: r[4] as String,
      moonSign: r[5] as String,
    );
  }

  /// Mood in force at [now]; past the bundled range, wraps the shift list by whole weeks.
  List<MoodShift> shiftsAround(DateTime now) {
    final last = shifts.last.at;
    if (now.isBefore(last)) return shifts;
    final span = last.difference(shifts.first.at);
    final weeks = (span.inDays ~/ 7) * 7;
    final loops = now.difference(shifts.first.at).inDays ~/ weeks;
    final shift = Duration(days: loops * weeks);
    return [for (final s in shifts) MoodShift(at: s.at.add(shift), decan: s.decan, card: s.card, moonSign: s.moonSign)];
  }
}
