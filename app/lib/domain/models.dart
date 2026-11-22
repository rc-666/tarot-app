import 'dart:convert';

/// What she has entered during onboarding, before an account exists. Kept on the phone.
class ProfileDraft {
  final String language; // en | pt | es
  final String firstName;
  final DateTime? birthDate;
  final String? birthTime; // "HH:mm" or null
  final Place? birthPlace;
  final List<String> focusTopics;

  const ProfileDraft({
    this.language = 'pt',
    this.firstName = '',
    this.birthDate,
    this.birthTime,
    this.birthPlace,
    this.focusTopics = const [],
  });

  ProfileDraft copyWith({
    String? language,
    String? firstName,
    DateTime? birthDate,
    String? Function()? birthTime,
    Place? Function()? birthPlace,
    List<String>? focusTopics,
  }) =>
      ProfileDraft(
        language: language ?? this.language,
        firstName: firstName ?? this.firstName,
        birthDate: birthDate ?? this.birthDate,
        birthTime: birthTime != null ? birthTime() : this.birthTime,
        birthPlace: birthPlace != null ? birthPlace() : this.birthPlace,
        focusTopics: focusTopics ?? this.focusTopics,
      );

  Map<String, dynamic> toJson() => {
        'language': language,
        'firstName': firstName,
        'birthDate': birthDate?.toIso8601String().substring(0, 10),
        'birthTime': birthTime,
        'birthPlace': birthPlace?.toJson(),
        'focusTopics': focusTopics,
      };

  factory ProfileDraft.fromJson(Map<String, dynamic> j) => ProfileDraft(
        language: j['language'] as String? ?? 'pt',
        firstName: j['firstName'] as String? ?? '',
        birthDate: j['birthDate'] == null ? null : DateTime.parse(j['birthDate'] as String),
        birthTime: j['birthTime'] as String?,
        birthPlace: j['birthPlace'] == null ? null : Place.fromJson(j['birthPlace'] as Map<String, dynamic>),
        focusTopics: (j['focusTopics'] as List?)?.cast<String>() ?? const [],
      );
}

class Place {
  final String name; // city
  final String region; // "São Paulo, Brazil"
  final double lat, lon;
  final String tz;
  const Place({required this.name, required this.region, required this.lat, required this.lon, required this.tz});

  String get label => '$name, $region';
  Map<String, dynamic> toJson() => {'name': name, 'region': region, 'lat': lat, 'lon': lon, 'tz': tz};
  factory Place.fromJson(Map<String, dynamic> j) => Place(
        name: j['name'] as String,
        region: j['region'] as String,
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
        tz: j['tz'] as String,
      );
}

/// Saved profile (Supabase `profiles` row).
class Profile {
  final String id;
  final String firstName;
  final DateTime birthDate;
  final String? birthTime;
  final String? birthPlace;
  final double? birthLat, birthLon;
  final String? birthTz;
  final String tz;
  final String sunSign;
  final List<String> focusTopics;
  final String language;
  final bool notifyMorning, notifyMood;

  const Profile({
    required this.id,
    required this.firstName,
    required this.birthDate,
    this.birthTime,
    this.birthPlace,
    this.birthLat,
    this.birthLon,
    this.birthTz,
    required this.tz,
    required this.sunSign,
    required this.focusTopics,
    required this.language,
    this.notifyMorning = true,
    this.notifyMood = true,
  });

  factory Profile.fromRow(Map<String, dynamic> r) => Profile(
        id: r['id'] as String,
        firstName: r['first_name'] as String,
        birthDate: DateTime.parse(r['birth_date'] as String),
        birthTime: (r['birth_time'] as String?)?.substring(0, 5),
        birthPlace: r['birth_place'] as String?,
        birthLat: (r['birth_lat'] as num?)?.toDouble(),
        birthLon: (r['birth_lon'] as num?)?.toDouble(),
        birthTz: r['birth_tz'] as String?,
        tz: r['tz'] as String,
        sunSign: r['sun_sign'] as String,
        focusTopics: (r['focus_topics'] as List).cast<String>(),
        language: r['language'] as String,
        notifyMorning: r['notify_morning'] as bool? ?? true,
        notifyMood: r['notify_mood'] as bool? ?? true,
      );

  Map<String, dynamic> toRow() => {
        'id': id,
        'first_name': firstName,
        'birth_date': birthDate.toIso8601String().substring(0, 10),
        'birth_time': birthTime,
        'birth_place': birthPlace,
        'birth_lat': birthLat,
        'birth_lon': birthLon,
        'birth_tz': birthTz,
        'tz': tz,
        'sun_sign': sunSign,
        'focus_topics': focusTopics,
        'language': language,
        'notify_morning': notifyMorning,
        'notify_mood': notifyMood,
      };

  String toJson() => jsonEncode(toRow());
  static Profile fromJson(String s) => Profile.fromRow(jsonDecode(s) as Map<String, dynamic>);
}

/// Cards 2 and 3 for one local day (from `user_daily_cards` or `daily_cards`).
class DayCards {
  final String day; // YYYY-MM-DD local
  final String influencePlanet;
  final String influenceCard;
  final bool influenceReversed;
  final String? influenceAspect; // null = ruler fallback
  final String adviceCard;
  final String moonSign;

  const DayCards({
    required this.day,
    required this.influencePlanet,
    required this.influenceCard,
    required this.influenceReversed,
    required this.influenceAspect,
    required this.adviceCard,
    required this.moonSign,
  });

  factory DayCards.fromRow(Map<String, dynamic> r) => DayCards(
        day: (r['day'] as String).substring(0, 10),
        influencePlanet: r['influence_planet'] as String,
        influenceCard: r['influence_card'] as String,
        influenceReversed: r['influence_reversed'] as bool,
        influenceAspect: r['influence_aspect'] as String?,
        adviceCard: r['advice_card'] as String,
        moonSign: r['moon_sign'] as String,
      );

  Map<String, dynamic> toRow() => {
        'day': day,
        'influence_planet': influencePlanet,
        'influence_card': influenceCard,
        'influence_reversed': influenceReversed,
        'influence_aspect': influenceAspect,
        'advice_card': adviceCard,
        'moon_sign': moonSign,
      };
}

/// A Moon decan ingress: the mood card changes at [at].
class MoodShift {
  final DateTime at; // UTC
  final int decan;
  final String card;
  final String moonSign;
  const MoodShift({required this.at, required this.decan, required this.card, required this.moonSign});

  factory MoodShift.fromRow(Map<String, dynamic> r) => MoodShift(
        at: DateTime.parse(r['at'] as String).toUtc(),
        decan: (r['decan'] as num).toInt(),
        card: r['card'] as String,
        moonSign: r['moon_sign'] as String,
      );
  Map<String, dynamic> toRow() => {'at': at.toIso8601String(), 'decan': decan, 'card': card, 'moon_sign': moonSign};
}

/// Everything the reading needs for one day.
class TodayCards {
  final String day;
  final MoodShift mood; // card 1, live sky
  final bool moodShiftedToday; // show "Your mood shifted at HH:MM"
  final DayCards fixed; // cards 2 and 3
  const TodayCards({required this.day, required this.mood, required this.moodShiftedToday, required this.fixed});
}

class ReadingRecord {
  final String day;
  final String topic;
  final int? rating; // -1, 1
  const ReadingRecord({required this.day, required this.topic, this.rating});
  Map<String, dynamic> toJson() => {'day': day, 'topic': topic, 'rating': rating};
  factory ReadingRecord.fromJson(Map<String, dynamic> j) =>
      ReadingRecord(day: j['day'] as String, topic: j['topic'] as String, rating: j['rating'] as int?);
}
