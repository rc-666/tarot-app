import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models.dart';

/// Small on-phone cache (SharedPreferences). Everything the app needs offline for today lives here.
class LocalStore {
  LocalStore(this._p);
  final SharedPreferences _p;

  static const _draft = 'draft';
  static const _profile = 'profile';
  static const _dayCards = 'dayCards'; // map day -> row
  static const _shifts = 'moodShifts';
  static const _reading = 'reading'; // today's reading record
  static const _flags = 'flags';
  static const _library = 'library'; // newer library json from Storage
  static const _firstReading = 'firstReading';

  ProfileDraft get draft {
    final s = _p.getString(_draft);
    return s == null ? const ProfileDraft() : ProfileDraft.fromJson(jsonDecode(s) as Map<String, dynamic>);
  }

  Future<void> setDraft(ProfileDraft d) => _p.setString(_draft, jsonEncode(d.toJson()));
  Future<void> clearDraft() => _p.remove(_draft);

  Profile? get profile {
    final s = _p.getString(_profile);
    return s == null ? null : Profile.fromJson(s);
  }

  Future<void> setProfile(Profile? p) => p == null ? _p.remove(_profile) : _p.setString(_profile, p.toJson());

  DayCards? dayCards(String day) {
    final s = _p.getString(_dayCards);
    if (s == null) return null;
    final m = jsonDecode(s) as Map<String, dynamic>;
    final r = m[day] as Map<String, dynamic>?;
    return r == null ? null : DayCards.fromRow(r);
  }

  /// Keeps only the given days (today + tomorrow) to stay small.
  Future<void> setDayCards(List<DayCards> cards) =>
      _p.setString(_dayCards, jsonEncode({for (final c in cards) c.day: c.toRow()}));

  List<MoodShift> get moodShifts {
    final s = _p.getString(_shifts);
    if (s == null) return const [];
    return (jsonDecode(s) as List).map((e) => MoodShift.fromRow(e as Map<String, dynamic>)).toList();
  }

  Future<void> setMoodShifts(List<MoodShift> s) => _p.setString(_shifts, jsonEncode(s.map((e) => e.toRow()).toList()));

  ReadingRecord? reading(String day) {
    final s = _p.getString(_reading);
    if (s == null) return null;
    final r = ReadingRecord.fromJson(jsonDecode(s) as Map<String, dynamic>);
    return r.day == day ? r : null;
  }

  Future<void> setReading(ReadingRecord r) => _p.setString(_reading, jsonEncode(r.toJson()));

  /// The first reading is shown before sign-up; remember its day and topic so it can be saved after.
  ReadingRecord? get firstReading {
    final s = _p.getString(_firstReading);
    return s == null ? null : ReadingRecord.fromJson(jsonDecode(s) as Map<String, dynamic>);
  }

  Future<void> setFirstReading(ReadingRecord r) => _p.setString(_firstReading, jsonEncode(r.toJson()));

  bool flag(String name) => (_p.getStringList(_flags) ?? const []).contains(name);
  Future<void> setFlag(String name, bool on) {
    final f = {...?_p.getStringList(_flags)};
    on ? f.add(name) : f.remove(name);
    return _p.setStringList(_flags, f.toList());
  }

  String? get libraryJson => _p.getString(_library);
  Future<void> setLibraryJson(String s) => _p.setString(_library, s);

  /// Sign out / delete: wipe everything personal.
  Future<void> clearPersonal() async {
    for (final k in [_draft, _profile, _dayCards, _reading, _flags, _firstReading]) {
      await _p.remove(k);
    }
  }
}

/// Flags used across screens.
class Flags {
  static const remindersAsked = 'remindersAsked';
  static const remindersOn = 'remindersOn';
  static const firstDayTipDone = 'firstDayTipDone';
  static const firstDay = 'firstDay';
}
