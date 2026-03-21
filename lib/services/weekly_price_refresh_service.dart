import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/data_provider.dart';
import 'market_price_sync_service.dart';
import 'supply_price_sync_service.dart';

class WeeklyPriceRefreshService {
  WeeklyPriceRefreshService._();

  static final WeeklyPriceRefreshService instance =
      WeeklyPriceRefreshService._();

  static const _lastSuccessfulRefreshKey =
      'weekly_price_refresh.last_successful_refresh_at';
  static const _refreshInterval = Duration(days: 7);

  Future<void> refreshIfDue(DataProvider dataProvider) async {
    final prefs = await SharedPreferences.getInstance();
    final lastSuccessfulRefreshRaw =
        prefs.getString(_lastSuccessfulRefreshKey);
    final now = DateTime.now();

    if (lastSuccessfulRefreshRaw != null) {
      final lastSuccessfulRefresh = DateTime.tryParse(lastSuccessfulRefreshRaw);
      if (lastSuccessfulRefresh != null &&
          now.difference(lastSuccessfulRefresh) < _refreshInterval) {
        return;
      }
    }

    try {
      await MarketPriceSyncService.instance.syncLatestPriceCache();
      await SupplyPriceSyncService.instance.syncCatalogWithLatestSourcePrices();
      await dataProvider.loadDefSupsFromDb();
      await prefs.setString(_lastSuccessfulRefreshKey, now.toIso8601String());
    } catch (error) {
      debugPrint('WeeklyPriceRefreshService.refreshIfDue error: $error');
    }
  }
}
