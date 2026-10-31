import 'package:just_audio/just_audio.dart';

class GlobalAudioService {
  static final GlobalAudioService _instance = GlobalAudioService._internal();
  factory GlobalAudioService() => _instance;
  GlobalAudioService._internal();

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
