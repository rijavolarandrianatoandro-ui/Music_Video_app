import 'package:shared_preferences/shared_preferences.dart';

import 'playback_controller.dart';

class AppSettings {
  AppSettings({
    this.volume = 1,
    this.speed = 1,
    this.shuffle = false,
    this.repeatMode = PlaybackRepeatMode.off,
    this.confirmDownloads = true,
  });

  double volume;
  double speed;
  bool shuffle;
  PlaybackRepeatMode repeatMode;
  bool confirmDownloads;

  static Future<AppSettings> load() async {
    final preferences = await SharedPreferences.getInstance();
    final repeatIndex = preferences.getInt('settings.repeatMode') ?? 0;
    return AppSettings(
      volume: (preferences.getDouble('settings.volume') ?? 1).clamp(0, 1),
      speed: (preferences.getDouble('settings.speed') ?? 1).clamp(0.5, 2),
      shuffle: preferences.getBool('settings.shuffle') ?? false,
      repeatMode: PlaybackRepeatMode
          .values[repeatIndex.clamp(0, PlaybackRepeatMode.values.length - 1)],
      confirmDownloads:
          preferences.getBool('settings.confirmDownloads') ?? true,
    );
  }

  Future<void> save() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble('settings.volume', volume);
    await preferences.setDouble('settings.speed', speed);
    await preferences.setBool('settings.shuffle', shuffle);
    await preferences.setInt('settings.repeatMode', repeatMode.index);
    await preferences.setBool('settings.confirmDownloads', confirmDownloads);
  }
}
