import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'genre_tag.dart';

/// Запросы к бэкенду за жанрами.
class GenreService {
  GenreService._();
  static final GenreService instance = GenreService._();

  final Map<String, GenreTag> _trackCache = {};
  List<GenreTag>? _allCache;

  /// Жанр трека по «артист + название». При ошибке возвращает [GenreTag.unknown]
  /// (и не кэширует его, чтобы можно было повторить позже).
  Future<GenreTag> resolveTrackGenre(String artist, String title) async {
    final key = '$artist|$title'.toLowerCase();
    final cached = _trackCache[key];
    if (cached != null) return cached;

    try {
      final query = Uri.encodeComponent('$artist $title');
      final res = await http
          .get(Uri.parse('$kApiBaseUrl/genre?query=$query'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['error'] == null) {
          final id = (data['genre'] as String?) ?? GenreTag.unknown.id;
          final tag = GenreTag(id, (data['genre_label'] as String?) ?? id);
          _trackCache[key] = tag;
          return tag;
        }
      }
    } catch (_) {
      // сеть недоступна, таймаут и т.п. — отдаём «Другое»
    }
    return GenreTag.unknown;
  }

  /// Полный справочник жанров с бэкенда (для экрана, где нужен весь список тегов).
  Future<List<GenreTag>> fetchAllGenres({bool forceRefresh = false}) async {
    if (_allCache != null && !forceRefresh) return _allCache!;
    final res = await http
        .get(Uri.parse('$kApiBaseUrl/genres'))
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw Exception('Сервер вернул код ${res.statusCode}');
    }
    final list = (jsonDecode(res.body) as List)
        .map((e) => GenreTag.fromJson(e as Map<String, dynamic>))
        .toList();
    _allCache = list;
    return list;
  }
}
