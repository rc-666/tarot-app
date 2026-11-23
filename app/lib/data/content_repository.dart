import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models.dart';
import '../domain/reading_assembler.dart';
import 'local_store.dart';

/// Explanation library: bundled copy first, newer copy from Storage when the version is higher.
/// Storage layout (bucket `library`): `manifest.json` = `{"en": 3, "pt": 2}`, `<lang>.json`.
class LibraryRepository {
  LibraryRepository(this._store, this._sb);
  final LocalStore _store;
  final SupabaseClient? _sb; // null in the demo build

  Future<Library> load(String language) async {
    final cached = _store.libraryJson;
    if (cached != null) {
      final lib = Library.fromJson(jsonDecode(cached) as Map<String, dynamic>);
      if (lib.language == language) return lib;
    }
    return _bundled(language);
  }

  Future<Library> _bundled(String language) async {
    String raw;
    try {
      raw = await rootBundle.loadString('assets/library/$language.json');
    } catch (_) {
      raw = await rootBundle.loadString('assets/library/en.json'); // until the translation agent delivers pt/es
    }
    return Library.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Checks once per app start; downloads only when the manifest has a higher version (prepaid data).
  Future<Library?> refresh(String language, int currentVersion) async {
    final sb = _sb;
    if (sb == null) return null;
    final bucket = sb.storage.from('library');
    try {
      final m = await bucket.download('manifest.json').timeout(const Duration(seconds: 8));
      final v = (jsonDecode(utf8.decode(m)) as Map<String, dynamic>)[language] as int?;
      if (v == null || v <= currentVersion) return null;
      final body = utf8.decode(await bucket.download('$language.json').timeout(const Duration(seconds: 30)));
      final lib = Library.fromJson(jsonDecode(body) as Map<String, dynamic>);
      await _store.setLibraryJson(body);
      return lib;
    } catch (_) {
      return null;
    }
  }
}

/// Offline place search over assets/places/places.tsv (GeoNames, built by tool/build_places.py).
class PlacesRepository {
  List<Place>? _all;

  Future<List<Place>> _load() async {
    if (_all != null) return _all!;
    final raw = await rootBundle.loadString('assets/places/places.tsv');
    _all = [
      for (final line in const LineSplitter().convert(raw))
        if (line.isNotEmpty && !line.startsWith('#'))
          () {
            final p = line.split('\t');
            return Place(name: p[0], region: p[1], lat: double.parse(p[2]), lon: double.parse(p[3]), tz: p[4]);
          }(),
    ];
    return _all!;
  }

  /// Type-ahead: min 2 characters, up to 5 results, accent-insensitive, prefix matches first.
  Future<List<Place>> search(String q) async {
    final query = fold(q.trim());
    if (query.length < 2) return const [];
    final all = await _load();
    final prefix = <Place>[], inside = <Place>[];
    for (final p in all) {
      final n = fold(p.name);
      if (n.startsWith(query)) {
        prefix.add(p);
      } else if (n.contains(query)) {
        inside.add(p);
      }
      if (prefix.length >= 5) break;
    }
    return [...prefix, ...inside].take(5).toList();
  }

  static String fold(String s) {
    const from = 'áàâãäéèêëíìîïóòôõöúùûüçñÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ';
    const to = 'aaaaaeeeeiiiiooooouuuucnaaaaaeeeeiiiiooooouuuucn';
    final b = StringBuffer();
    for (final ch in s.split('')) {
      final i = from.indexOf(ch);
      b.write(i >= 0 ? to[i] : ch.toLowerCase());
    }
    return b.toString();
  }
}
