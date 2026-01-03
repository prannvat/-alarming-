import 'package:audioplayers/audioplayers.dart';

class AlarmSoundService {
  static final AlarmSoundService _instance = AlarmSoundService._internal();
  factory AlarmSoundService() => _instance;
  AlarmSoundService._internal();

  AudioPlayer? _audioPlayer;
  bool _isPlaying = false;

  bool get isPlaying => _isPlaying;

  Future<void> playAlarm() async {
    if (_isPlaying) {
      print('🔊 Alarm already playing, skipping...');
      return;
    }

    try {
      print('🔊 Starting alarm sound...');
      
      // Create a fresh player each time for reliability
      _audioPlayer?.dispose();
      _audioPlayer = AudioPlayer();
      
      final player = _audioPlayer!;
      
      // Configure for alarm playback - this overrides silent mode
      await player.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {
              AVAudioSessionOptions.duckOthers,
            },
          ),
          android: AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.alarm,
            audioFocus: AndroidAudioFocus.gainTransientExclusive,
          ),
        ),
      );
      
      // Set to loop continuously
      await player.setReleaseMode(ReleaseMode.loop);
      
      // Max volume
      await player.setVolume(1.0);
      
      // Play the alarm sound
      await player.play(AssetSource('sounds/alarm.mp3'));
      
      _isPlaying = true;
      print('🔊 ✅ Alarm sound playing');
      
    } catch (e, stackTrace) {
      print('❌ Error playing alarm sound: $e');
      print('❌ Stack trace: $stackTrace');
    }
  }

  Future<void> stopAlarm() async {
    if (!_isPlaying && _audioPlayer == null) return;

    try {
      print('🔇 Stopping alarm sound...');
      await _audioPlayer?.stop();
      await _audioPlayer?.dispose();
      _audioPlayer = null;
      _isPlaying = false;
      print('🔇 Alarm sound stopped');
    } catch (e) {
      print('❌ Error stopping alarm sound: $e');
    }
  }

  Future<void> dispose() async {
    await _audioPlayer?.dispose();
    _audioPlayer = null;
  }
}
