import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'saved_game.dart';

/// Loads and saves the whole game as one document.
abstract class GameStore {
  Future<SavedGame?> load();
  Future<void> save(SavedGame game);
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
}
