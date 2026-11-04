import 'package:shared_preferences/shared_preferences.dart';

import 'playback_controller.dart';

class AppSettings {
  AppSettings({
    this.volume = 1,
    this.speed = 1,
    this.shuffle = false,
    this.repeatMode = PlaybackRepeatMode.off,
    this.confirmDownloads = true,
    this.dismissedRecapMonth,
    this.preferredArtistIds = const [],
    this.artistSetupCompleted = false,
    this.regionalTrendsEnabled = false,
    this.trendingCountryCode,
    this.regionalTrendsConsentAccepted = false,
  });

  double volume;
  double speed;
  bool shuffle;
  PlaybackRepeatMode repeatMode;
  bool confirmDownloads;
  String? dismissedRecapMonth;
  List<String> preferredArtistIds;
  bool artistSetupCompleted;
  bool regionalTrendsEnabled;
  String? trendingCountryCode;
  bool regionalTrendsConsentAccepted;

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
      dismissedRecapMonth: preferences.getString(
        'settings.dismissedRecapMonth',
      ),
      preferredArtistIds:
          preferences.getStringList('discovery.preferredArtistIds') ?? const [],
      artistSetupCompleted:
          preferences.getBool('discovery.artistSetupCompleted') ?? false,
      regionalTrendsEnabled:
          preferences.getBool('discovery.regionalTrendsEnabled') ?? false,
      trendingCountryCode: preferences.getString(
        'discovery.trendingCountryCode',
      ),
      regionalTrendsConsentAccepted:
          preferences.getBool('discovery.regionalTrendsConsentAccepted') ??
          false,
    );
  }

  Future<void> save() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble('settings.volume', volume);
    await preferences.setDouble('settings.speed', speed);
    await preferences.setBool('settings.shuffle', shuffle);
    await preferences.setInt('settings.repeatMode', repeatMode.index);
    await preferences.setBool('settings.confirmDownloads', confirmDownloads);
    final dismissedRecapMonth = this.dismissedRecapMonth;
    if (dismissedRecapMonth == null) {
      await preferences.remove('settings.dismissedRecapMonth');
    } else {
      await preferences.setString(
        'settings.dismissedRecapMonth',
        dismissedRecapMonth,
      );
    }
    await preferences.setStringList(
      'discovery.preferredArtistIds',
      preferredArtistIds,
    );
    await preferences.setBool(
      'discovery.artistSetupCompleted',
      artistSetupCompleted,
    );
    await preferences.setBool(
      'discovery.regionalTrendsEnabled',
      regionalTrendsEnabled,
    );
    await preferences.setBool(
      'discovery.regionalTrendsConsentAccepted',
      regionalTrendsConsentAccepted,
    );
    final trendingCountryCode = this.trendingCountryCode;
    if (trendingCountryCode == null) {
      await preferences.remove('discovery.trendingCountryCode');
    } else {
      await preferences.setString(
        'discovery.trendingCountryCode',
        trendingCountryCode,
      );
    }
  }
}
