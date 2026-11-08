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

  /// Whether this install already had its 3-day dry run (kept outside the
  /// game, so restarting can't grant another one).
  Future<bool> dryRunUsed();

  Future<void> markDryRunUsed();

  /// Archived (finished, restarted or unreadable) games kept on the phone.
  Future<int> archiveCount();

  /// Permanently deletes every archived game. The current game is kept.
  Future<void> deleteArchives();
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

  static const _dryRunKey = 'doordie.dryRunUsed';

  @override
  Future<bool> dryRunUsed() async {
    if (await _prefs.getBool(_dryRunKey) ?? false) return true;
    // Installs from before this flag: any archived game had its dry run.
    final keys = await _prefs.getKeys();
    return keys.any((k) => k.startsWith('doordie.archive.'));
  }

  @override
  Future<void> markDryRunUsed() => _prefs.setBool(_dryRunKey, true);

  static bool _isArchive(String k) =>
      k.startsWith('doordie.archive.') || k.startsWith('doordie.unreadable.');

  @override
  Future<int> archiveCount() async =>
      (await _prefs.getKeys()).where(_isArchive).length;

  @override
  Future<void> deleteArchives() async {
    // The dry run stays used: deleting old trials can't buy a new one.
    await markDryRunUsed();
    for (final k in (await _prefs.getKeys()).where(_isArchive)) {
      await _prefs.remove(k);
    }
  }

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

  bool _dryRunUsed = false;

  @override
  Future<bool> dryRunUsed() async => _dryRunUsed || archived.isNotEmpty;

  @override
  Future<void> markDryRunUsed() async => _dryRunUsed = true;

  @override
  Future<int> archiveCount() async => archived.length;

  @override
  Future<void> deleteArchives() async {
    if (archived.isNotEmpty) _dryRunUsed = true;
    archived.clear();
  }

  @override
  Future<void> archive(SavedGame game) async => archived.add(
    SavedGame.fromJson(
      jsonDecode(jsonEncode(game.toJson())) as Map<String, Object?>,
    ),
  );
}
