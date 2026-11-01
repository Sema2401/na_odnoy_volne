import 'genre_tag.dart';

/// Одна трансляция («плейлист» — трек, который сейчас транслирует пользователь).
class Wave {
  final String id; // uid транслирующего
  final String username;
  final String title;
  final String artist;
  final GenreTag genre;
  final int positionSec;
  final DateTime? startedAt;

  const Wave({
    required this.id,
    required this.username,
    required this.title,
    required this.artist,
    required this.genre,
    required this.positionSec,
    required this.startedAt,
  });

  /// [data] — содержимое документа waves/{uid}; [startedAt] уже переведён из Timestamp.
  /// У старых записей без жанра получится [GenreTag.unknown].
  factory Wave.fromMap(String id, Map<String, dynamic> data, {DateTime? startedAt}) {
    final genreId = data['genre'] as String?;
    final genre = (genreId == null || genreId.isEmpty)
        ? GenreTag.unknown
        : GenreTag(genreId, (data['genre_label'] as String?) ?? genreId);

    return Wave(
      id: id,
      username: (data['username'] ?? 'User') as String,
      title: (data['track_title'] ?? '') as String,
      artist: (data['artist'] ?? '') as String,
      genre: genre,
      positionSec: (data['position_sec'] ?? 0) as int,
      startedAt: startedAt,
    );
  }

  /// Позиция воспроизведения на момент [now] (та же формула, что сейчас в home_screen).
  int currentPositionSec({DateTime? now}) {
    if (startedAt == null) return positionSec;
    return positionSec + (now ?? DateTime.now()).difference(startedAt!).inSeconds;
  }
}
