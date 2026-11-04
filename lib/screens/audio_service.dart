import 'package:just_audio/just_audio.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GlobalAudioService {
  static final GlobalAudioService _instance = GlobalAudioService._internal();
  factory GlobalAudioService() => _instance;
  GlobalAudioService._internal() {
    _initPlayerListener();
  }

  final AudioPlayer player = AudioPlayer(
    audioLoadConfiguration: AudioLoadConfiguration(
      androidLoadControl: AndroidLoadControl(
        minBufferDuration: const Duration(seconds: 3),
        maxBufferDuration: const Duration(seconds: 10),
        bufferForPlaybackDuration: const Duration(seconds: 1),
        bufferForPlaybackAfterRebufferDuration: const Duration(seconds: 3),
      ),
    ),
  );

  String? currentJoinedUserId;

  bool isBroadcasting = false;

  void _initPlayerListener() {
    player.playerStateStream.listen((state) {
      final user = FirebaseAuth.instance.currentUser;

      if (!isBroadcasting || user == null) return;

      if (state.playing) {
        FirebaseFirestore.instance
            .collection('waves')
            .doc(user.uid)
            .update({
              'is_playing': true,
              'started_at': FieldValue.serverTimestamp(),
              'position_sec': player.position.inSeconds,
              'paused_at': null,
            })
            .catchError((_) {});
      } else if (state.processingState == ProcessingState.ready ||
          state.processingState == ProcessingState.idle) {
        // Нажали Pause
        FirebaseFirestore.instance
            .collection('waves')
            .doc(user.uid)
            .update({
              'is_playing': false,
              'paused_at': FieldValue.serverTimestamp(),
            })
            .catchError((_) {});
      }
    });
  }

  Future<void> playTrack(String url, int positionSec) async {
    await player.stop();

    await player.setUrl(url).timeout(const Duration(seconds: 20));

    if (positionSec > 0) {
      final dur = player.duration;
      final target = (dur != null && positionSec >= dur.inSeconds)
          ? dur.inSeconds - 1
          : positionSec;
      if (target > 0) {
        try {
          await player.seek(Duration(seconds: target));
        } catch (_) {}
      }
    }

    player.play();
  }

  Future<void> stop() async {
    try {
      await player.stop();
    } catch (_) {}
    currentJoinedUserId = null;
  }
}
