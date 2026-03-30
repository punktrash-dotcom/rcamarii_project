import 'package:flutter_test/flutter_test.dart';
import 'package:nmd/providers/profile_provider.dart';
import 'package:nmd/providers/theme_provider.dart';
import 'package:nmd/services/app_defaults_service.dart';
import 'package:nmd/services/app_properties_store.dart';

void main() {
  setUp(() {
    AppPropertiesStore.instance.useMemoryStoreForTesting();
  });

  tearDown(() {
    AppPropertiesStore.instance.resetTestingOverrides();
  });

  test('ensureDefaults seeds default app and widget properties', () async {
    await AppDefaultsService.ensureDefaults();

    final values = await AppPropertiesStore.instance.exportAll();
    expect(values['app_settings.currency'], 'php');
    expect(values['app_settings.audio_sounds_volume'], 0.75);
    expect(values[ThemeProvider.themeStatusKey], isFalse);
    expect(values[ProfileProvider.nameKey], 'My Wallet');
    expect(values[AppDefaultsService.hubAutopilotEnabledKey], isTrue);
    expect(values[AppDefaultsService.trackerSelectedTabKey], 0);
    expect(values[AppDefaultsService.marketPriceFilterKey], 'all');
  });

  test('ensureDefaults does not overwrite existing property values', () async {
    AppPropertiesStore.instance.useMemoryStoreForTesting({
      'app_settings.currency': 'usd',
      AppDefaultsService.hubAutopilotEnabledKey: false,
    });

    await AppDefaultsService.ensureDefaults();

    final values = await AppPropertiesStore.instance.exportAll();
    expect(values['app_settings.currency'], 'usd');
    expect(values[AppDefaultsService.hubAutopilotEnabledKey], isFalse);
  });
}
