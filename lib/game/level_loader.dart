import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/level.dart';

/// Loads levels from the chapter files in `assets/levels/`.
///
/// Only the chapter the player is currently in is held as decoded JSON, and
/// only a handful of [Level] objects are built from it: the current one plus
/// the next three. See section 6.6.
class LevelLoader {
  LevelLoader._();

  static final LevelLoader instance = LevelLoader._();

  int? _loadedChapter;
  List<Map<String, dynamic>>? _raw;

  /// Small ordered cache: current level plus the next three.
  final Map<int, Level> _cache = <int, Level>{};
  static const int _cacheSize = 4;

  Future<void> _ensureChapter(int chapter) async {
    if (_loadedChapter == chapter && _raw != null) return;
    final path = chapterInfo(chapter).assetPath;
    final text = await rootBundle.loadString(path);
    final decoded = jsonDecode(text) as Map<String, dynamic>;
    _raw = (decoded['levels'] as List).cast<Map<String, dynamic>>();
    _loadedChapter = chapter;
    _cache.clear();
  }

  /// A chapter whose file is not in the bundle throws here; the game screen
  /// catches it and shows the "still being mapped" screen rather than crashing.
  Future<Level> load(int levelId) async {
    final cached = _cache[levelId];
    if (cached != null) return cached;

    final chapter = chapterOf(levelId);
    await _ensureChapter(chapter);

    final level = _build(levelId);
    _remember(levelId, level);

    // Warm the next three without blocking the caller.
    _prefetch(levelId);
    return level;
  }

  Level _build(int levelId) {
    final raw = _raw!;
    final indexInChapter = (levelId - 1) % 100;
    if (indexInChapter < raw.length) {
      final candidate = raw[indexInChapter];
      if (candidate['id'] == levelId) return Level.fromJson(candidate);
    }
    // Fall back to a scan if the file is not in id order.
    final match = raw.firstWhere(
      (m) => m['id'] == levelId,
      orElse: () =>
          throw StateError('level $levelId is not in its chapter file'),
    );
    return Level.fromJson(match);
  }

  void _prefetch(int levelId) {
    final chapter = chapterOf(levelId);
    for (var i = 1; i <= 3; i++) {
      final id = levelId + i;
      if (id > kLevelCount) break;
      if (chapterOf(id) != chapter) break; // do not pull in another file
      if (_cache.containsKey(id)) continue;
      try {
        _remember(id, _build(id));
      } catch (_) {
        break;
      }
    }
  }

  void _remember(int id, Level level) {
    _cache[id] = level;
    while (_cache.length > _cacheSize) {
      _cache.remove(_cache.keys.first);
    }
  }

  /// Test seam.
  void debugReset() {
    _loadedChapter = null;
    _raw = null;
    _cache.clear();
  }
}
