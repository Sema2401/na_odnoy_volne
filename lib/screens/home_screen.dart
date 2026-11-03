import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

import '../logic/api_config.dart';
import '../logic/genre_tag.dart';
import '../logic/wave.dart';
import '../logic/wave_filter.dart';
import '../logic/wave_repository.dart';
import '../theme.dart';
import 'audio_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalAudioService _audio = GlobalAudioService();
  final WaveFilter _filter = WaveFilter();

  bool _loadingJoin = false;
  String? _loadingWaveId;

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  Future<void> _joinWave(Wave wave) async {
    if (_audio.currentJoinedUserId == wave.id) {
      await _leaveWave();
      return;
    }

    setState(() {
      _loadingJoin = true;
      _loadingWaveId = wave.id;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Загружаем трек...'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      final query = Uri.encodeComponent('${wave.artist} ${wave.title}');
      final res = await http
          .get(Uri.parse('$kApiBaseUrl/search?query=$query'))
          .timeout(const Duration(seconds: 12));

      if (res.statusCode != 200) {
        throw Exception('Сервер вернул код ${res.statusCode}');
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['error'] != null) {
        throw Exception(data['error']);
      }

      final trackUrl = data['url'] as String?;
      if (trackUrl == null || trackUrl.isEmpty) {
        throw Exception('Сервер не вернул URL трека');
      }

      final encodedUrl = Uri.encodeComponent(trackUrl);
      final streamUrl = '$kApiBaseUrl/stream?url=$encodedUrl';

      final positionSec = wave.currentPositionSec();
      await _audio.playTrack(streamUrl, positionSec);
      _audio.currentJoinedUserId = wave.id;

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingJoin = false;
          _loadingWaveId = null;
        });
      }
    }
  }

  Future<void> _leaveWave() async {
    await _audio.stop();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final joinedId = _audio.currentJoinedUserId;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Сейчас слушают'),
        centerTitle: false,
        actions: [
          if (joinedId != null)
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              tooltip: 'Выйти из волны',
              onPressed: _leaveWave,
            ),
        ],
      ),
      body: Column(
        children: [
          if (joinedId != null) _buildNowPlayingBar(),
          Expanded(child: _buildBody(joinedId)),
        ],
      ),
    );
  }

  Widget _buildBody(String? joinedId) {
    return StreamBuilder<List<Wave>>(
      stream: WaveRepository.watchWaves(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Ищем, кто сейчас в эфире...'),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(child: Text('Ошибка: ${snapshot.error}'));
        }

        final waves = snapshot.data ?? const <Wave>[];

        if (waves.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.waves, size: 64, color: AppTheme.pink),
                  SizedBox(height: 16),
                  Text(
                    'Пока никто не слушает.\nЗапусти свою волну!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          );
        }

        return ListenableBuilder(
          listenable: _filter,
          builder: (context, _) {
            final available = _filter.availableGenres(waves);
            final filtered = _filter.apply(waves);

            return Column(
              children: [
                _buildFilterBar(available),
                _buildSortBar(),
                const Divider(height: 1),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text('Нет треков в выбранных жанрах'),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final wave = filtered[index];
                            return _WaveCard(
                              wave: wave,
                              isJoined: joinedId == wave.id,
                              isLoading: _loadingJoin &&
                                  _loadingWaveId == wave.id,
                              onTap: () => _joinWave(wave),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFilterBar(List<GenreCount> available) {
    if (available.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('Все'),
              selected: !_filter.hasActiveFilter,
              onSelected: (_) => _filter.clearGenres(),
              selectedColor: AppTheme.pink.withValues(alpha: 0.25),
              checkmarkColor: AppTheme.pink,
            ),
          ),
          for (final g in available)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text('${g.tag.label} · ${g.count}'),
                selected: _filter.isSelected(g.tag.id),
                onSelected: (_) => _filter.toggleGenre(g.tag.id),
                selectedColor: AppTheme.pink.withValues(alpha: 0.25),
                checkmarkColor: AppTheme.pink,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSortBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Row(
        children: [
          const Icon(Icons.sort, size: 18, color: AppTheme.muted),
          const SizedBox(width: 6),
          DropdownButton<WaveSort>(
            value: _filter.sort,
            underline: const SizedBox.shrink(),
            isDense: true,
            dropdownColor: AppTheme.surface,
            items: const [
              DropdownMenuItem(
                value: WaveSort.newest,
                child: Text('Сначала новые'),
              ),
              DropdownMenuItem(
                value: WaveSort.genre,
                child: Text('По жанру'),
              ),
              DropdownMenuItem(
                value: WaveSort.username,
                child: Text('По имени'),
              ),
            ],
            onChanged: (v) {
              if (v != null) _filter.setSort(v);
            },
          ),
          const Spacer(),
          if (_filter.hasActiveFilter)
            TextButton.icon(
              onPressed: _filter.clearGenres,
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Сбросить'),
            ),
        ],
      ),
    );
  }

  Widget _buildNowPlayingBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: AppTheme.surface.withValues(alpha: 0.6),
      child: Row(
        children: [
          const Icon(Icons.music_note, color: AppTheme.pink),
          const SizedBox(width: 8),
          Expanded(
            child: StreamBuilder<PlayerState>(
              stream: _audio.player.playerStateStream,
              builder: (context, snap) {
                final state = snap.data;
                final playing = state?.playing ?? false;
                final processing = state?.processingState;

                String label;
                if (processing == ProcessingState.loading ||
                    processing == ProcessingState.buffering) {
                  label = 'Буферизация...';
                } else if (!playing) {
                  label = 'Пауза';
                } else {
                  label = 'Слушаем вместе...';
                }

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (processing == ProcessingState.loading ||
                        processing == ProcessingState.buffering) ...[
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          IconButton(
            icon: StreamBuilder<PlayerState>(
              stream: _audio.player.playerStateStream,
              builder: (context, snap) {
                final playing = snap.data?.playing ?? false;
                return Icon(playing ? Icons.pause : Icons.play_arrow);
              },
            ),
            onPressed: () async {
              if (_audio.player.playing) {
                await _audio.player.pause();
              } else {
                // ignore: unawaited_futures
                _audio.player.play();
              }
            },
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Карточка волны ─────────────────────────

class _WaveCard extends StatelessWidget {
  final Wave wave;
  final bool isJoined;
  final bool isLoading;
  final VoidCallback onTap;

  const _WaveCard({
    required this.wave,
    required this.isJoined,
    required this.isLoading,
    required this.onTap,
  });

  Color _genreColor(String genreId) {
    const palette = [
      AppTheme.pink,
      AppTheme.violet,
      Colors.teal,
      Colors.orange,
      Colors.pink,
      Colors.blueGrey,
    ];
    if (genreId == GenreTag.unknown.id) return Colors.blueGrey;
    return palette[genreId.hashCode.abs() % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final color = _genreColor(wave.genre.id);
    final initial =
        wave.username.isNotEmpty ? wave.username[0].toUpperCase() : '?';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: isLoading ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: color.withValues(alpha: 0.15),
                    child: Text(
                      initial,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  if (isJoined)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: AppTheme.surface,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.graphic_eq,
                          size: 14,
                          color: color,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      wave.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      wave.title.isEmpty ? 'Без названия' : wave.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                    if (wave.artist.isNotEmpty)
                      Text(
                        wave.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.muted,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            wave.genre.label,
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${wave.currentPositionSec()} сек',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.muted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 96,
                child: FilledButton.icon(
                  onPressed: isLoading ? null : onTap,
                  icon: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          isJoined ? Icons.logout : Icons.headphones,
                          size: 18,
                        ),
                  label: Text(
                    isJoined ? 'Выйти' : 'Слушать',
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: isJoined ? Colors.grey.shade700 : color,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}