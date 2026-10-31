import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'audio_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = false;

  final GlobalAudioService _audioService = GlobalAudioService();
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    if (_audioService.player.playing ||
        _audioService.currentJoinedUserId != null) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  Future<void> _joinWave(
    String userId,
    String artist,
    String title,
    int positionSec,
  ) async {
    if (_audioService.currentJoinedUserId == userId) {
      await _leaveWave();
      return;
    }

    setState(() => _loading = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Загружаем трек...'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      final query = Uri.encodeComponent('$artist $title');
      final res = await http
          .get(Uri.parse('http://153.80.251.185:8000/search?query=$query'))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['error'] == null) {
          final trackUrl = data['url'];

          final encodedUrl = Uri.encodeComponent(trackUrl);
          final streamUrl = 'http://153.80.251.185:8000/stream?url=$encodedUrl';

          await _audioService.playTrack(streamUrl, positionSec);
          _audioService.currentJoinedUserId = userId;

          setState(() {});
          return;
        } else {
          throw Exception(data['error']);
        }
      }
      throw Exception('Сервер вернул код ${res.statusCode}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _leaveWave() async {
    _syncTimer?.cancel();
    await _audioService.stop();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final joinedId = _audioService.currentJoinedUserId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Сейчас слушают'),
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
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('waves')
          .snapshots(includeMetadataChanges: false),
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

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('Пока никто не слушает. Запусти свою волну!'),
          );
        }

        final waves = snapshot.data!.docs;

        return ListView.separated(
          itemCount: waves.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final data = waves[index].data() as Map<String, dynamic>;
            final id = waves[index].id;
            final isJoined = joinedId == id;
            final username = (data['username'] ?? 'User') as String;

            int positionSec = data['position_sec'] ?? 0;
            if (data['started_at'] != null) {
              final startTime = (data['started_at'] as Timestamp).toDate();
              final now = DateTime.now();
              positionSec += now.difference(startTime).inSeconds;
            }

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.deepPurple.shade100,
                child: Text(
                  username.isNotEmpty ? username[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.deepPurple),
                ),
              ),
              title: Text(username),
              subtitle: Text('${data['track_title']} • ${data['artist']}'),
              trailing: ElevatedButton.icon(
                onPressed: _loading
                    ? null
                    : () => _joinWave(
                        id,
                        data['artist'] ?? '',
                        data['track_title'] ?? '',
                        positionSec,
                      ),
                icon: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(isJoined ? Icons.logout : Icons.headphones),
                label: Text(isJoined ? 'Выйти' : 'Слушать'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isJoined ? Colors.grey : Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNowPlayingBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.deepPurple.shade50,
      child: Row(
        children: [
          const Icon(Icons.music_note, color: Colors.deepPurple),
          const SizedBox(width: 8),
          Expanded(
            child: StreamBuilder<PlayerState>(
              stream: _audioService.player.playerStateStream,
              builder: (context, snap) {
                final playing = snap.data?.playing ?? false;
                return Text(
                  playing ? 'Слушаем вместе...' : 'Пауза',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                );
              },
            ),
          ),
          IconButton(
            icon: StreamBuilder<PlayerState>(
              stream: _audioService.player.playerStateStream,
              builder: (context, snap) {
                final playing = snap.data?.playing ?? false;
                return Icon(playing ? Icons.pause : Icons.play_arrow);
              },
            ),
            onPressed: () {
              if (_audioService.player.playing) {
                _audioService.player.pause();
              } else {
                _audioService.player.play();
              }
            },
          ),
        ],
      ),
    );
  }
}
