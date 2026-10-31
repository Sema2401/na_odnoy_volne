import 'package:just_audio/just_audio.dart';

class GlobalAudioService {
  static final GlobalAudioService _instance = GlobalAudioService._internal();
  factory GlobalAudioService() => _instance;
  GlobalAudioService._internal();

  final AudioPlayer player = AudioPlayer();

  String? currentJoinedUserId;

  Future<void> playTrack(String url, int positionSec) async {
    await player.stop();
    await player.setUrl(
      url,
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      },
    );
    await player.seek(Duration(seconds: positionSec));
    player.play();
  }

  Future<void> stop() async {
    await player.stop();
    currentJoinedUserId = null;
  }
}
