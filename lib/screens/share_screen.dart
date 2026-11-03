import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_media_controller/flutter_media_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'audio_service.dart';
import '../logic/genre_service.dart';
import '../theme.dart';

class ShareScreen extends StatefulWidget {
  const ShareScreen({super.key});

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> {
  String _title = 'Ничего не играет';
  String _artist = '';
  bool _loading = true;
  bool _isSharing = false;

  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _checkIfAlreadySharing();
    _initMediaController();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
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
    } catch (_) {}
  }

  Future<void> _initMediaController() async {
    setState(() => _loading = true);

    try {
      await FlutterMediaController.requestPermissions();
    } catch (e) {
      debugPrint('requestPermissions error: $e');
    }

    await _pollOnce();

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      await _pollOnce();
    });
  }

  Future<void> _pollOnce() async {
    try {
      final info = await FlutterMediaController.getCurrentMediaInfo();
      debugPrint(
        'MediaInfo: track=${info.track}, artist=${info.artist}, playing=${info.isPlaying}',
      );
      if (!mounted) return;

      if (info.track.isNotEmpty) {
        setState(() {
          _title = info.track;
          _artist = info.artist;
          _loading = false;
        });
      } else {
        if (_title == 'Слушаем...' || _title == 'Ничего не играет') {
          setState(() {
            _title = 'Ничего не играет';
            _artist = '';
            _loading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('getCurrentMediaInfo error: $e');
      if (mounted && _loading) {
        setState(() {
          _loading = false;
          _title = 'Ничего не играет';
        });
      }
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

      final genre =
          await GenreService.instance.resolveTrackGenre(_artist, _title);

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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.graphic_eq,
                      size: 64, color: AppTheme.pink),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Сейчас в твоем телефоне играет:',
                        style: TextStyle(
                            color: AppTheme.muted, fontSize: 16),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh,
                            color: AppTheme.muted),
                        tooltip: 'Обновить',
                        onPressed: _initMediaController,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _artist,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 18, color: AppTheme.pink),
                  ),
                  const SizedBox(height: 48),
                  if (!_isSharing)
                    SizedBox(
                      height: 54,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: AppTheme.grad,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: AppTheme.glow,
                        ),
                        child: FilledButton.icon(
                          onPressed: _shareToFirestore,
                          icon: const Icon(Icons.share),
                          label: const Text('Поделиться этой песней'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                          ),
                        ),
                      ),
                    )
                  else
                    FilledButton.icon(
                      onPressed: _stopSharing,
                      icon: const Icon(Icons.stop),
                      label: const Text('Остановить трансляцию'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  if (_isSharing) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Ты в эфире! Другие видят тебя в ленте.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}