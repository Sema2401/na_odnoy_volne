import 'package:flutter/foundation.dart';
import 'genre_tag.dart';
import 'wave.dart';

enum WaveSort { newest, genre, username }

class GenreCount {
  final GenreTag tag;
  final int count;
  const GenreCount(this.tag, this.count);
}

/// Состояние фильтра по жанрам + сортировки. UI подписывается через
/// ListenableBuilder / AnimatedBuilder и вызывает [apply] на актуальном списке.
///
/// Пустой набор выбранных жанров = показывать все трансляции.
class WaveFilter extends ChangeNotifier {
  final Set<String> _selected = {};
  WaveSort _sort = WaveSort.newest;

  Set<String> get selectedGenreIds => Set.unmodifiable(_selected);
  WaveSort get sort => _sort;
  bool get hasActiveFilter => _selected.isNotEmpty;

  bool isSelected(String genreId) => _selected.contains(genreId);

  void toggleGenre(String genreId) {
    if (!_selected.remove(genreId)) _selected.add(genreId);
    notifyListeners();
  }

  void clearGenres() {
    if (_selected.isEmpty) return;
    _selected.clear();
    notifyListeners();
  }

  void setSort(WaveSort sort) {
    if (_sort == sort) return;
    _sort = sort;
    notifyListeners();
  }

  /// Теги, которые реально есть среди [waves], с количеством трансляций.
  /// Считается по всему списку (а не по отфильтрованному), чтобы чипы не пропадали
  /// после выбора. Порядок: больше трансляций — выше, затем по названию.
  List<GenreCount> availableGenres(List<Wave> waves) {
    final tags = <String, GenreTag>{};
    final counts = <String, int>{};
    for (final w in waves) {
      tags[w.genre.id] = w.genre;
      counts[w.genre.id] = (counts[w.genre.id] ?? 0) + 1;
    }
    final result = [for (final e in tags.entries) GenreCount(e.value, counts[e.key]!)];
    result.sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      return byCount != 0
          ? byCount
          : a.tag.label.toLowerCase().compareTo(b.tag.label.toLowerCase());
    });
    return result;
  }

  /// Применяет выбранные жанры и сортировку. Исходный список не меняет.
  List<Wave> apply(List<Wave> waves) {
    final filtered = _selected.isEmpty
        ? List<Wave>.of(waves)
        : waves.where((w) => _selected.contains(w.genre.id)).toList();

    switch (_sort) {
      case WaveSort.newest:
        filtered.sort(_byNewest);
      case WaveSort.genre:
        filtered.sort((a, b) {
          // «Другое» всегда в конце списка
          final aUnknown = a.genre.id == GenreTag.unknown.id;
          final bUnknown = b.genre.id == GenreTag.unknown.id;
          if (aUnknown != bUnknown) return aUnknown ? 1 : -1;

          final byGenre =
              a.genre.label.toLowerCase().compareTo(b.genre.label.toLowerCase());
          return byGenre != 0 ? byGenre : _byNewest(a, b);
        });
      case WaveSort.username:
        filtered.sort(
          (a, b) => a.username.toLowerCase().compareTo(b.username.toLowerCase()),
        );
    }
    return filtered;
  }

  // Самые свежие первыми; у только что созданных (started_at ещё null) — самый верх.
  static int _byNewest(Wave a, Wave b) {
    final x = a.startedAt, y = b.startedAt;
    if (x == null && y == null) return 0;
    if (x == null) return -1;
    if (y == null) return 1;
    return y.compareTo(x);
  }
}
