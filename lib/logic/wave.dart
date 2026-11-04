import 'genre_tag.dart';

class Wave {
  final String id;
  final String username;
  final String title;
  final String artist;
  final GenreTag genre;
  final int positionSec;
  final DateTime? startedAt;

  final bool isPlaying;
  final DateTime? pausedAt;

  const Wave({
    required this.id,
    required this.username,
    required this.title,
    required this.artist,
    required this.genre,
    required this.positionSec,
    required this.startedAt,
    this.isPlaying = true,
    this.pausedAt,
  });

  factory Wave.fromMap(
    String id,
    Map<String, dynamic> data, {
    DateTime? startedAt,
    DateTime? pausedAt,
  }) {
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
      isPlaying: (data['is_playing'] ?? true) as bool,
      pausedAt: pausedAt,
    );
  }

  int currentPositionSec({DateTime? now}) {
    if (startedAt == null) return positionSec;

    if (!isPlaying && pausedAt != null) {
      final diff = pausedAt!.difference(startedAt!).inSeconds;
      return positionSec + (diff > 0 ? diff : 0);
    }

    final diff = (now ?? DateTime.now()).difference(startedAt!).inSeconds;
    return positionSec + (diff > 0 ? diff : 0);
  }
}
