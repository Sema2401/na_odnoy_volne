import 'package:flutter_test/flutter_test.dart';
import 'package:na_odnoy_volne/logic/genre_tag.dart';
import 'package:na_odnoy_volne/logic/wave.dart';
import 'package:na_odnoy_volne/logic/wave_filter.dart';

Wave w(String id, String genreId, String label, {String user = 'u', int minsAgo = 0}) {
  return Wave(
    id: id,
    username: user,
    title: 't$id',
    artist: 'a$id',
    genre: GenreTag(genreId, label),
    positionSec: 0,
    startedAt: DateTime(2026, 1, 1, 12).subtract(Duration(minutes: minsAgo)),
  );
}

void main() {
  final waves = [
    w('1', 'rock', 'Рок', minsAgo: 10),
    w('2', 'pop', 'Поп', minsAgo: 5),
    w('3', 'rock', 'Рок', minsAgo: 1),
    w('4', 'other', 'Другое', minsAgo: 20),
  ];

  test('пустой фильтр показывает всё, новые первыми', () {
    final f = WaveFilter();
    expect(f.apply(waves).map((e) => e.id), ['3', '2', '1', '4']);
  });

  test('фильтр по одному и нескольким жанрам', () {
    final f = WaveFilter()..toggleGenre('rock');
    expect(f.apply(waves).map((e) => e.id), ['3', '1']);
    f.toggleGenre('pop');
    expect(f.apply(waves).map((e) => e.id), ['3', '2', '1']);
    f.toggleGenre('rock');
    expect(f.apply(waves).map((e) => e.id), ['2']);
  });

  test('сортировка по жанру', () {
    final f = WaveFilter()..setSort(WaveSort.genre);
    expect(f.apply(waves).map((e) => e.genre.id), ['pop', 'rock', 'rock', 'other']);
  });

  test('availableGenres считает по всему списку', () {
    final f = WaveFilter()..toggleGenre('pop');
    final tags = f.availableGenres(waves);
    expect(tags.first.tag.id, 'rock');
    expect(tags.first.count, 2);
    expect(tags.length, 3);
  });

  test('старая запись без жанра -> «Другое»', () {
    final wave = Wave.fromMap('x', {'track_title': 'a', 'artist': 'b'});
    expect(wave.genre, GenreTag.unknown);
  });
}
