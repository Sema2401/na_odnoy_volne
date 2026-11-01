/// Жанр-тег: [id] — код от бэкенда (по нему фильтруем), [label] — название для UI.
class GenreTag {
  final String id;
  final String label;
  const GenreTag(this.id, this.label);

  /// Для треков, жанр которых не удалось определить, и для старых записей в Firestore.
  static const unknown = GenreTag('other', 'Другое');

  factory GenreTag.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as String?) ?? unknown.id;
    return GenreTag(id, (json['label'] as String?) ?? id);
  }

  @override
  bool operator ==(Object other) => other is GenreTag && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'GenreTag($id, $label)';
}
