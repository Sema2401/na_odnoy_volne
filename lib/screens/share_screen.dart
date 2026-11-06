import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_media_controller/flutter_media_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'audio_service.dart';
import '../theme.dart';

class ShareScreen extends StatefulWidget {
  const ShareScreen({super.key});

  @override
  State<ShareScreen> createState() => _ShareScreenState();
}

class _ShareScreenState extends State<ShareScreen> with WidgetsBindingObserver {
  String _title = 'Ничего не играет';
  String _artist = '';
  bool _loading = true;
  bool _isSharing = false;

  Timer? _pollTimer;
  Timer? _autoStopTimer;
  Timer? _backgroundTimer;
  bool _isMusicCurrentlyPlaying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkIfAlreadySharing();
    _initMediaController();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _autoStopTimer?.cancel();
    _backgroundTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _backgroundTimer?.cancel();
      _backgroundTimer = Timer(const Duration(seconds: 15), () async {
        if (mounted &&
            _isSharing &&
            WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.paused) {
          await _stopSharing();
        }
      });
    } else if (state == AppLifecycleState.resumed) {
      _backgroundTimer?.cancel();
    }
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
        GlobalAudioService().isBroadcasting = true;
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
      if (!mounted) return;

      _isMusicCurrentlyPlaying = info.isPlaying;

      if (_isSharing) {
        if (!_isMusicCurrentlyPlaying || info.track.isEmpty) {
          _autoStopTimer?.cancel();
          _autoStopTimer = Timer(const Duration(seconds: 5), () async {
            if (mounted && _isSharing && !_isMusicCurrentlyPlaying) {
              await _stopSharing();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Музыка остановлена. Трансляция завершена.'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            }
          });
        } else {
          _autoStopTimer?.cancel();
        }
      }

      if (info.track.isNotEmpty) {
        if (info.track != _title || info.artist != _artist) {
          setState(() {
            _title = info.track;
            _artist = info.artist;
            _loading = false;
          });

          if (_isSharing) {
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              try {
                await FirebaseFirestore.instance
                    .collection('waves')
                    .doc(user.uid)
                    .update({
                      'track_title': _title,
                      'artist': _artist,
                      'position_sec': 0,
                      'started_at': FieldValue.serverTimestamp(),
                      'is_playing': true,
                    });
              } catch (_) {}
            }
          }
        }
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
    if (_title == 'Ничего не играет' || _title == 'Слушаем...') {
      return;
    }

    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      GlobalAudioService().isBroadcasting = true;

      await FirebaseFirestore.instance.collection('waves').doc(user.uid).set({
        'username': user.email?.split('@').first ?? 'User',
        'track_title': _title,
        'artist': _artist,
        'track_url': '',
        'position_sec': 0,
        'started_at': FieldValue.serverTimestamp(),
        'is_playing': true,
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
    _autoStopTimer?.cancel();
    _backgroundTimer?.cancel();
    setState(() => _loading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('waves')
            .doc(user.uid)
            .delete();
      }

      GlobalAudioService().isBroadcasting = false;

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

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.graphic_eq, size: 64, color: AppTheme.pink),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Сейчас в твоем телефоне играет:',
                style: TextStyle(color: AppTheme.muted, fontSize: 16),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: AppTheme.muted),
                tooltip: 'Обновить',
                onPressed: _initMediaController,
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
            style: const TextStyle(fontSize: 18, color: AppTheme.pink),
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
    );
  }
}
