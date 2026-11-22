import 'models.dart';

/// The explanation library for one language (`assets/library/<lang>.json`, or a newer copy from Storage).
/// Keys in `texts` (most specific first):
/// - `mood.<card>.<topic>`, then `mood.<card>`
/// - `influence.<card>.<upright|reversed>.<topic>`, then `influence.<card>.<upright|reversed>`
/// - `advice.<card>.<topic>`, then `advice.<card>`
/// - `closing.<adviceCard>.<topic>`, then `closing.<topic>`
class Library {
  final int version;
  final String language;
  final Map<String, ({String name, String? short})> cards;
  final Map<String, String> texts;
  final Map<String, List<String>> openings;

  const Library({required this.version, required this.language, required this.cards, required this.texts, required this.openings});

  factory Library.fromJson(Map<String, dynamic> j) => Library(
        version: (j['version'] as num).toInt(),
        language: j['language'] as String,
        cards: (j['cards'] as Map<String, dynamic>).map((k, v) {
          final m = v as Map<String, dynamic>;
          return MapEntry(k, (name: m['name'] as String, short: m['short'] as String?));
        }),
        texts: (j['texts'] as Map<String, dynamic>).cast<String, String>(),
        openings: (j['openings'] as Map<String, dynamic>).map((k, v) => MapEntry(k, (v as List).cast<String>())),
      );

  String cardName(String id) => cards[id]?.name ?? id;
  String? cardShort(String id) => cards[id]?.short;

  String? text(List<String> keys) {
    for (final k in keys) {
      final t = texts[k];
      if (t != null && t.isNotEmpty) return t;
    }
    return null;
  }
}

enum Position { mood, influence, advice }

class ReadingSection {
  final Position position;
  final String card;
  final bool reversed;
  final String paragraph;
  const ReadingSection(this.position, this.card, this.reversed, this.paragraph);
}

class AssembledReading {
  final String opening;
  final List<ReadingSection> sections;
  final String todaysAdvice;
  const AssembledReading(this.opening, this.sections, this.todaysAdvice);
}

/// Builds the full reading offline. Deterministic for (day, topic) so a reopened reading reads the same.
/// Called again with the new mood card after a mood shift.
AssembledReading assembleReading(Library lib, TodayCards today, String topic) {
  final seed = _hash('${today.day}|$topic');
  final openings = lib.openings[topic] ?? lib.openings['any'] ?? const [''];
  final opening = openings[seed % openings.length];

  final mood = today.mood.card;
  final inf = today.fixed.influenceCard;
  final orient = today.fixed.influenceReversed ? 'reversed' : 'upright';
  final adv = today.fixed.adviceCard;

  final sections = [
    ReadingSection(Position.mood, mood, false, lib.text(['mood.$mood.$topic', 'mood.$mood']) ?? ''),
    ReadingSection(Position.influence, inf, today.fixed.influenceReversed,
        lib.text(['influence.$inf.$orient.$topic', 'influence.$inf.$orient']) ?? ''),
    ReadingSection(Position.advice, adv, false, lib.text(['advice.$adv.$topic', 'advice.$adv']) ?? ''),
  ];
  final closing = lib.text(['closing.$adv.$topic', 'closing.$topic']) ?? '';
  return AssembledReading(opening, sections, closing);
}

int _hash(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0x7fffffff;
  }
  return h;
}
