import 'package:flutter_test/flutter_test.dart';
import 'package:maxei/src/media/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('discovery preferences persist across settings restoration', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings()
      ..preferredArtistIds = ['taylor-swift', 'bts', 'drake', 'tems', 'adele']
      ..artistSetupCompleted = true
      ..trendingCountryCode = 'MG'
      ..regionalTrendsEnabled = true
      ..regionalTrendsConsentAccepted = true;

    await settings.save();
    final restored = await AppSettings.load();

    expect(restored.preferredArtistIds, settings.preferredArtistIds);
    expect(restored.artistSetupCompleted, isTrue);
    expect(restored.trendingCountryCode, 'MG');
    expect(restored.regionalTrendsEnabled, isTrue);
    expect(restored.regionalTrendsConsentAccepted, isTrue);
  });
}
