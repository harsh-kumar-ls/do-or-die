import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'saved_game.dart';

/// Loads and saves the whole game as one document.
abstract class GameStore {
  Future<SavedGame?> load();
  Future<void> save(SavedGame game);

  /// Keeps a finished or abandoned game (with its full log) for later review.
  Future<void> archive(SavedGame game);

  /// Removes the current game (after it has been archived).
  Future<void> clear();
}

/// Stores the game as a JSON string. Works on Android and web.
class PrefsGameStore implements GameStore {
  PrefsGameStore(this._prefs);

  static const _key = 'doordie.save.v1';

  final SharedPreferencesAsync _prefs;

  @override
  Future<SavedGame?> load() async {
    final raw = await _prefs.getString(_key);
    if (raw == null) return null;
    return SavedGame.fromJson(jsonDecode(raw) as Map<String, Object?>);
  }

  @override
  Future<void> save(SavedGame game) =>
      _prefs.setString(_key, jsonEncode(game.toJson()));

  @override
  Future<void> clear() => _prefs.remove(_key);

  /// The saved game exactly as stored, for export when it can't be read.
  Future<String?> raw() => _prefs.getString(_key);

  /// Keeps an unreadable save under its own key (never deleted) and removes
  /// it from the current slot, so a new game can start.
  Future<void> setAsideUnreadable() async {
    final raw = await _prefs.getString(_key);
    if (raw != null) {
      await _prefs.setString(
        'doordie.unreadable.${DateTime.now().millisecondsSinceEpoch}',
        raw,
      );
    }
    await _prefs.remove(_key);
  }

  /// Each archive gets its own key; nothing is ever overwritten.
  @override
  Future<void> archive(SavedGame game) => _prefs.setString(
    'doordie.archive.${DateTime.now().millisecondsSinceEpoch}',
    jsonEncode(game.toJson()),
  );
}

/// For tests.
class MemoryGameStore implements GameStore {
  String? _raw;

  /// Number of saves, for tests that check writes happen.
  int saves = 0;

  @override
  Future<SavedGame?> load() async => _raw == null
      ? null
      : SavedGame.fromJson(jsonDecode(_raw!) as Map<String, Object?>);

  @override
  Future<void> save(SavedGame game) async {
    // Round-trip through JSON so tests exercise the real codec.
    _raw = jsonEncode(game.toJson());
    saves++;
  }

  @override
  Future<void> clear() async => _raw = null;

  /// Archived games, oldest first.
  final archived = <SavedGame>[];

  @override
  Future<void> archive(SavedGame game) async => archived.add(
    SavedGame.fromJson(
      jsonDecode(jsonEncode(game.toJson())) as Map<String, Object?>,
    ),
  );
}
