import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AudioPlayer _player = AudioPlayer();
  Timer? _syncTimer;
  Timer? _refreshTimer;

  // ВОТ ЭТИ ТРИ ПЕРЕМЕННЫЕ ТЫ СЛУЧАЙНО УДАЛИЛ:
  bool _loading = false;
  String? _error;
  String? _joinedUserId;

  List<Map<String, dynamic>> _feed = [
    {
      'id': 'u1',
      'username': 'Алексей',
      'track_title': 'Lo-Fi Study',
      'artist': 'Unknown',
      'track_url':
          'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
      'position_sec': 0,
    },
    {
      'id': 'u2',
      'username': 'Мария',
      'track_title': 'Night Drive',
      'artist': 'Unknown',
      'track_url':
          'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
      'position_sec': 0,
    },
    {
      'id': 'u3',
      'username': 'Иван',
      'track_title': 'Chill Vibes',
      'artist': 'Unknown',
      'track_url':
          'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
      'position_sec': 0,
    },
  ];

  @override
  void initState() {
    super.initState();
    // _loadFeed(); // Отключено для теста без бэкенда
  }

  Future<void> _loadFeed({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse('${AuthService.baseUrl}/feed'),
        headers: await AuthService.authHeaders(),
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _feed = data.cast<Map<String, dynamic>>();
            _error = null;
          });
        }
      } else {
        if (mounted) setState(() => _error = 'Ошибка ${res.statusCode}');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Нет связи с сервером');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _joinWave(Map<String, dynamic> item) async {
    if (_joinedUserId == item['id']) {
      await _leaveWave();
      return;
    }

    try {
      // Временно убираем запрос к серверу для join, чтобы работало без бэкенда
      int positionSec = item['position_sec'] ?? 0;

      await _player.setUrl(item['track_url']);
      await _player.seek(Duration(seconds: positionSec));
      _player.play();

      setState(() => _joinedUserId = item['id']);

      _syncTimer?.cancel();
      _syncTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
        if (_player.position == null) return;
        // Временно отключено для теста без сервера
        /*
        try {
          await http.patch(
            Uri.parse('${AuthService.baseUrl}/wave/sync'),
            headers: await AuthService.authHeaders(),
            body: jsonEncode({'position_sec': _player.position!.inSeconds}),
          );
        } catch (_) {}
        */
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка воспроизведения: $e')));
      }
    }
  }

  Future<void> _leaveWave() async {
    _syncTimer?.cancel();
    await _player.stop();
    // Временно отключено
    /*
    try {
      await http.post(
        Uri.parse('${AuthService.baseUrl}/wave/leave'),
        headers: await AuthService.authHeaders(),
      );
    } catch (_) {}
    */
    if (mounted) setState(() => _joinedUserId = null);
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _refreshTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сейчас слушают'),
        actions: [
          if (_joinedUserId != null)
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              tooltip: 'Выйти из волны',
              onPressed: _leaveWave,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadFeed(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_joinedUserId != null) _buildNowPlayingBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadFeed,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }
    if (_feed.isEmpty) {
      return const Center(
        child: Text('Пока никто не слушает. Запусти свою волну!'),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadFeed(),
      child: ListView.separated(
        itemCount: _feed.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = _feed[index];
          final isJoined = _joinedUserId == item['id'];
          final username = (item['username'] ?? 'User') as String;
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.deepPurple.shade100,
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.deepPurple),
              ),
            ),
            title: Text(username),
            subtitle: Text('${item['track_title']} • ${item['artist']}'),
            trailing: ElevatedButton.icon(
              onPressed: () => _joinWave(item),
              icon: Icon(isJoined ? Icons.logout : Icons.headphones),
              label: Text(isJoined ? 'Выйти' : 'Слушать'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isJoined ? Colors.grey : Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
            ),
          );
        },
      ),
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
              stream: _player.playerStateStream,
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
              stream: _player.playerStateStream,
              builder: (context, snap) {
                final playing = snap.data?.playing ?? false;
                return Icon(playing ? Icons.pause : Icons.play_arrow);
              },
            ),
            onPressed: () {
              if (_player.playing) {
                _player.pause();
              } else {
                _player.play();
              }
            },
          ),
        ],
      ),
    );
  }
}
