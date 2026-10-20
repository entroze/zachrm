import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/book_reading_progress.dart';

abstract interface class ReadingProgressStore {
  Future<BookReadingProgress?> load(String bookPath);

  Future<void> save(String bookPath, BookReadingProgress progress);
}

class SharedPreferencesReadingProgressStore implements ReadingProgressStore {
  SharedPreferencesReadingProgressStore({SharedPreferences? preferences})
    : _providedPreferences = preferences;

  static const _keyPrefix = 'reading-progress:';

  final SharedPreferences? _providedPreferences;
  SharedPreferences? _cachedPreferences;

  Future<SharedPreferences> get _preferences async {
    final provided = _providedPreferences;
    if (provided != null) return provided;
    return _cachedPreferences ??= await SharedPreferences.getInstance();
  }

  String _key(String path) => '$_keyPrefix${Uri.encodeComponent(path)}';

  @override
  Future<BookReadingProgress?> load(String bookPath) async {
    final encoded = (await _preferences).getString(_key(bookPath));
    if (encoded == null) return null;

    final data = jsonDecode(encoded);
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid saved reading progress.');
    }
    final currentPage = data['currentPage'];
    final totalPages = data['totalPages'];
    if (currentPage is! int || totalPages is! int || totalPages < 1) {
      throw const FormatException('Invalid saved reading progress values.');
    }

    return BookReadingProgress(
      currentPage: currentPage.clamp(1, totalPages),
      totalPages: totalPages,
    );
  }

  @override
  Future<void> save(String bookPath, BookReadingProgress progress) async {
    await (await _preferences).setString(
      _key(bookPath),
      jsonEncode({
        'currentPage': progress.currentPage,
        'totalPages': progress.totalPages,
      }),
    );
  }
}
