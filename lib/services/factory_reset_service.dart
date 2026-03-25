import 'package:shared_preferences/shared_preferences.dart';

import 'app_properties_store.dart';
import 'data_seeder.dart';
import 'database_helper.dart';
import 'market_price_sync_service.dart';

class FactoryResetService {
  FactoryResetService._();

  static Future<void> resetAppToFactorySettings() async {
    await DatabaseHelper.instance.resetAppData();
    await AppPropertiesStore.instance.clear();

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    await MarketPriceSyncService.instance.clearCache();
    DataSeeder.resetForFactorySettings();
    await DataSeeder.ensureSeeded();
  }
}
