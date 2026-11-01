import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nowplaying/nowplaying.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
<<<<<<< HEAD
import 'audio_service.dart';
=======
import '../logic/genre_service.dart';
>>>>>>> 679d0f4 (сделал систему жанров (не тестировалось))

class ShareScreen extends StatefulWidget {
  const ShareScreen({super.key});

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  String _title = 'Ничего не играет';
  String _artist = '';
  bool _hasPermission = false;
  bool _loading = true;
  bool _isSharing = false;

  StreamSubscription? _nowPlayingSubscription;
  bool _npStarted = false;

  @override
  void initState() {
    super.initState();
    _checkIfAlreadySharing();
    _initNowPlaying();
  }

  @override
  void dispose() {
    _nowPlayingSubscription?.cancel();
    if (_npStarted) {
      NowPlaying.instance.stop();
    }
    super.dispose();
  }

  Future<void> _checkIfAlreadySharing() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('waves')
          .doc(user.uid)
          .get();
      if (mounted && doc.exists) {
        setState(() => _isSharing = true);
      }
    } catch (_) {
      //
    }
  }

  Future<void> _initNowPlaying() async {
    _hasPermission = await NowPlaying.instance.isEnabled();
    if (!mounted) return;

    if (!_hasPermission) {
      setState(() => _loading = false);
      return;
    }

    await _nowPlayingSubscription?.cancel();
    _nowPlayingSubscription = null;
    if (_npStarted) {
      NowPlaying.instance.stop();
      _npStarted = false;
    }

    setState(() {
      _loading = true;
      _title = 'Слушаем...';
      _artist = '';
    });

    try {
      await NowPlaying.instance.start();
      _npStarted = true;
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _title = 'Ничего не играет';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось запустить NowPlaying: $e')),
        );
      }
      return;
    }

    _nowPlayingSubscription = NowPlaying.instance.stream.listen(
      (track) {
        if (!mounted) return;
        if (track.title != null && track.title!.isNotEmpty) {
          setState(() {
            _title = track.title!;
            _artist = track.artist ?? '';
            _loading = false;
          });
        }
      },
      onError: (_) {
        if (mounted) setState(() => _loading = false);
      },
    );

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _loading) setState(() => _loading = false);
    });
  }

  Future<void> _requestPermission() async {
    await NowPlaying.instance.requestPermissions();
    _hasPermission = await NowPlaying.instance.isEnabled();
    if (!mounted) return;
    if (_hasPermission) {
      await _initNowPlaying();
    } else {
      setState(() {});
    }
  }

  Future<void> _shareToFirestore() async {
    if (_title == 'Ничего не играет' ||
        _title == 'Неизвестный трек' ||
        _title == 'Слушаем...') {
      return;
    }

    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final genre = await GenreService.instance.resolveTrackGenre(_artist, _title);

      await FirebaseFirestore.instance.collection('waves').doc(user.uid).set({
        'username': user.email?.split('@').first ?? 'User',
        'track_title': _title,
        'artist': _artist,
        'genre': genre.id,
        'genre_label': genre.label,
        'track_url': '',
        'position_sec': 0,
        'started_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() => _isSharing = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ты в эфире! Трек отправлен в ленту.')),
        );
      }
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

  Future<void> _stopSharing() async {
    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('waves')
            .doc(user.uid)
            .delete();
      }
      if (mounted) setState(() => _isSharing = false);
      await GlobalAudioService().stop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (!_hasPermission) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.hearing_disabled, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Чтобы делиться музыкой, нам нужно видеть,\nчто играет в твоем телефоне.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _requestPermission,
                child: const Text('Разрешить доступ'),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.graphic_eq, size: 64, color: Colors.deepPurple),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Сейчас в твоем телефоне играет:',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.grey),
                tooltip: 'Обновить',
                onPressed: _initNowPlaying,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Text(
            _artist,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, color: Colors.deepPurple),
          ),
          const SizedBox(height: 48),
          if (!_isSharing)
            FilledButton.icon(
              onPressed: _shareToFirestore,
              icon: const Icon(Icons.share),
              label: const Text('Поделиться этой песней'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            )
          else
            FilledButton.icon(
              onPressed: _stopSharing,
              icon: const Icon(Icons.stop),
              label: const Text('Остановить трансляцию'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          if (_isSharing) ...[
            const SizedBox(height: 16),
            const Text(
              'Ты в эфире! Другие видят тебя в ленте.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
