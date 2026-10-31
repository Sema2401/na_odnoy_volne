import 'package:just_audio/just_audio.dart';

class GlobalAudioService {
  static final GlobalAudioService _instance = GlobalAudioService._internal();
  factory GlobalAudioService() => _instance;
  GlobalAudioService._internal();

  final AudioPlayer player = AudioPlayer(
    audioLoadConfiguration: AudioLoadConfiguration(
      androidLoadControl: AndroidLoadControl(
        minBufferDuration: const Duration(seconds: 5),
        maxBufferDuration: const Duration(seconds: 15),
        bufferForPlaybackDuration: const Duration(seconds: 1),
        bufferForPlaybackAfterRebufferDuration: const Duration(seconds: 3),
      ),
    ),
  );

  String? currentJoinedUserId;

  Future<void> playTrack(String url, int positionSec) async {
    await player.stop();
    await player.setUrl(url);
    await player.seek(Duration(seconds: positionSec));
    player.play();
  }

  Future<void> stop() async {
    await player.stop();
    currentJoinedUserId = null;
  }
}
