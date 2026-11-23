import 'package:flutter_test/flutter_test.dart';
import 'package:tarot_app/data/content_repository.dart';
import 'package:tarot_app/data/sky_repository.dart';
import 'package:tarot_app/domain/cards.dart';
import 'package:tarot_app/domain/models.dart';
import 'package:tarot_app/domain/notification_plan.dart';
import 'package:tarot_app/domain/reading_assembler.dart';

void main() {
  test('sun sign by date, including cusps', () {
    expect(sunSignFor(DateTime(1972, 8, 14)), 'leo');
    expect(sunSignFor(DateTime(1980, 1, 1)), 'capricorn');
    expect(sunSignFor(DateTime(1980, 1, 20)), 'aquarius');
    expect(sunSignFor(DateTime(1980, 12, 25)), 'capricorn');
    expect(sunSignFor(DateTime(1980, 3, 21)), 'aries');
    expect(signCard['leo'], 'm08');
  });

  test('days in month: Feb 29 only in leap years', () {
    expect(daysInMonth(2024, 2), 29);
    expect(daysInMonth(2023, 2), 28);
    expect(daysInMonth(2000, 2), 29);
    expect(daysInMonth(1900, 2), 28);
    expect(daysInMonth(1975, 4), 30);
  });

  test('decan helpers', () {
    expect(decanSign(10), 'cancer');
    expect(decanPart(10), 1); // middle
  });

  MoodShift s(String iso) => MoodShift(at: DateTime.parse(iso), decan: 0, card: 'x', moonSign: 'aries');

  test('quiet hours 21-08 and one mood notification per day (same cases as sky.test.ts)', () {
    DateTime sp(DateTime utc) => utc.subtract(const Duration(hours: 3)); // São Paulo, UTC-3
    final picks = notifiableShifts([
      s('2026-11-23T01:00:00Z'),
      s('2026-11-23T10:30:00Z'),
      s('2026-11-23T11:00:00Z'),
      s('2026-11-23T20:00:00Z'),
      s('2026-11-24T23:59:00Z'),
    ], sp);
    expect(picks.map((e) => e.at.toIso8601String()), ['2026-11-23T11:00:00.000Z', '2026-11-24T23:59:00.000Z']);
  });

  test('mood in force is the latest shift at or before now', () {
    final list = [s('2026-11-22T00:00:00Z'), s('2026-11-22T18:00:00Z'), s('2026-11-23T12:00:00Z')];
    expect(moodAt(list, DateTime.parse('2026-11-22T20:00:00Z'))!.at, DateTime.parse('2026-11-22T18:00:00Z'));
    expect(moodAt(list, DateTime.parse('2026-11-21T20:00:00Z')), isNull);
  });

  test('phone offset maps to a zone the server computes', () {
    expect(SkyRepository.serverZoneFor(const Duration(hours: -3)), 'America/Sao_Paulo');
    expect(SkyRepository.serverZoneFor(const Duration(hours: -2)), 'America/Noronha');
    expect(SkyRepository.serverZoneFor(const Duration(hours: -6)), 'America/Mexico_City');
    expect(SkyRepository.serverZoneFor(const Duration(hours: 1)), 'America/Noronha'); // nearest
  });

  test('accent-insensitive place search folding', () {
    expect(PlacesRepository.fold('São Paulo'), 'sao paulo');
    expect(PlacesRepository.fold('Ceará'), 'ceara');
  });

  test('reading assembly is deterministic and falls back to generic texts', () {
    final lib = Library.fromJson({
      'version': 1,
      'language': 'en',
      'cards': {'c03': {'name': 'Three of Cups'}},
      'texts': {'mood.c03': 'generic', 'mood.c03.family': 'family text', 'closing.family': 'close'},
      'openings': {'family': ['a', 'b', 'c']},
    });
    final today = TodayCards(
      day: '2026-11-22',
      mood: MoodShift(at: DateTime.utc(2026, 11, 22), decan: 10, card: 'c03', moonSign: 'cancer'),
      moodShiftedToday: false,
      fixed: const DayCards(
        day: '2026-11-22', influencePlanet: 'venus', influenceCard: 'm03', influenceReversed: false,
        influenceAspect: 'trine', adviceCard: 'm07', moonSign: 'cancer'),
    );
    final a = assembleReading(lib, today, 'family');
    final b = assembleReading(lib, today, 'family');
    expect(a.opening, b.opening);
    expect(a.sections[0].paragraph, 'family text');
    expect(assembleReading(lib, today, 'love').sections[0].paragraph, 'generic');
    expect(a.todaysAdvice, 'close');
  });
}
