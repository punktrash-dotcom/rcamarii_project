import '../providers/profile_provider.dart';
import '../providers/theme_provider.dart';
import 'app_properties_store.dart';

class AppDefaultsService {
  AppDefaultsService._();

  static const String selectedFarmIdKey = 'farm_provider.selected_farm_id';
  static const String farmDetailsVisibleKey =
      'farm_provider.is_showing_activities';
  static const String trackerSelectedTabKey = 'ui.scr_tracker.selected_tab';
  static const String knowledgeSelectedCategoryKey =
      'ui.tab_knowledge.selected_category';
  static const String marketPriceFilterKey = 'ui.market_price.filter';
  static const String marketPriceSelectedRegionsKey =
      'ui.market_price.selected_regions_json';

  static const Map<String, dynamic> _defaultValues = <String, dynamic>{
    'app_settings.currency': 'php',
    'app_settings.launch_destination': 'hub',
    'app_settings.user_name': '',
    'app_settings.user_setup_complete': false,
    'app_settings.app_lock_enabled': false,
    'app_settings.audio_sounds_enabled': false,
    'app_settings.audio_sounds_volume': 0.75,
    'app_settings.audio_sound_style': 'serious',
    'app_settings.farm_alerts_enabled': true,
    'app_settings.weather_auto_refresh': true,
    'app_settings.reduced_motion': false,
    'app_settings.interaction_mode': 'detailed',
    ThemeProvider.themeStatusKey: false,
    ProfileProvider.nameKey: 'My Wallet',
    selectedFarmIdKey: '',
    farmDetailsVisibleKey: false,
    trackerSelectedTabKey: 0,
    knowledgeSelectedCategoryKey: '',
    marketPriceFilterKey: 'all',
    marketPriceSelectedRegionsKey: '{}',
  };

  static Future<void> ensureDefaults() async {
    final store = AppPropertiesStore.instance;
    await store.ready;

    for (final entry in _defaultValues.entries) {
      if (await store.containsKey(entry.key)) {
        continue;
      }
      await _writeValue(store, entry.key, entry.value);
    }
  }

  static Future<void> _writeValue(
    AppPropertiesStore store,
    String key,
    dynamic value,
  ) async {
    if (value is bool) {
      await store.setBool(key, value);
      return;
    }
    if (value is int) {
      await store.setInt(key, value);
      return;
    }
    if (value is double) {
      await store.setDouble(key, value);
      return;
    }
    if (value is List<String>) {
      await store.setStringList(key, value);
      return;
    }
    await store.setString(key, value.toString());
  }
}
