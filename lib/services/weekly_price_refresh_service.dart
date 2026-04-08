import 'package:flutter/foundation.dart';

import '../providers/data_provider.dart';
import 'app_properties_store.dart';
import 'market_price_sync_service.dart';
import 'supply_price_sync_service.dart';

class WeeklyPriceRefreshService {
  WeeklyPriceRefreshService._();

  static final WeeklyPriceRefreshService instance =
      WeeklyPriceRefreshService._();

  static const _lastSuccessfulRefreshKey =
      'weekly_price_refresh.last_successful_refresh_at';
  static const _lastAttemptedRefreshKey =
      'weekly_price_refresh.last_attempted_refresh_at';
  static const _refreshInterval = Duration(days: 7);
  static const _retryCooldown = Duration(hours: 12);

  Future<void> refreshIfDue(DataProvider dataProvider) async {
    final lastSuccessfulRefreshRaw =
        await AppPropertiesStore.instance.getString(_lastSuccessfulRefreshKey);
    final lastAttemptedRefreshRaw =
        await AppPropertiesStore.instance.getString(_lastAttemptedRefreshKey);
    final now = DateTime.now();

    if (lastSuccessfulRefreshRaw != null) {
      final lastSuccessfulRefresh = DateTime.tryParse(lastSuccessfulRefreshRaw);
      if (lastSuccessfulRefresh != null &&
          now.difference(lastSuccessfulRefresh) < _refreshInterval) {
        return;
      }
    }

    if (lastAttemptedRefreshRaw != null) {
      final lastAttemptedRefresh = DateTime.tryParse(lastAttemptedRefreshRaw);
      if (lastAttemptedRefresh != null &&
          now.difference(lastAttemptedRefresh) < _retryCooldown) {
        return;
      }
    }

    await AppPropertiesStore.instance
        .setString(_lastAttemptedRefreshKey, now.toIso8601String());

    try {
      await MarketPriceSyncService.instance.syncLatestPriceCache();
      await SupplyPriceSyncService.instance.syncCatalogWithLatestSourcePrices();
      await dataProvider.loadDefSupsFromDb();
      await AppPropertiesStore.instance
          .setString(_lastSuccessfulRefreshKey, now.toIso8601String());
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'WeeklyPriceRefreshService.refreshIfDue skipped: '
          'online weekly price sources are unavailable right now.',
        );
      }
    }
  }
}
