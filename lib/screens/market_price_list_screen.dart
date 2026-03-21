import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/def_sup_model.dart';
import '../providers/data_provider.dart';
import '../services/market_price_sync_service.dart';

enum MarketPriceCategoryFilter { all, fertilizer, herbicide, pesticide }

class MarketPriceListScreen extends StatefulWidget {
  final MarketPriceCategoryFilter initialFilter;

  const MarketPriceListScreen({
    super.key,
    this.initialFilter = MarketPriceCategoryFilter.all,
  });

  @override
  State<MarketPriceListScreen> createState() => _MarketPriceListScreenState();
}

class _MarketPriceListScreenState extends State<MarketPriceListScreen> {
  Map<String, dynamic>? _snapshot;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;
  late MarketPriceCategoryFilter _selectedFilter;

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dataProvider = context.read<DataProvider>();
      if (dataProvider.defSups.isEmpty) {
        dataProvider.loadDefSupsFromDb();
      }
    });
    _loadSnapshot(refresh: true);
  }

  Future<void> _loadSnapshot({required bool refresh}) async {
    if (refresh) {
      setState(() {
        _isRefreshing = true;
        _error = null;
      });
    } else {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    final cached = await MarketPriceSyncService.instance.loadCachedSnapshot();
    if (cached != null && mounted) {
      setState(() => _snapshot = cached);
    }

    if (!refresh) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final fresh =
          await MarketPriceSyncService.instance.syncLatestPriceCache();
      if (!mounted) {
        return;
      }
      setState(() {
        _snapshot = fresh;
        _isLoading = false;
        _isRefreshing = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dataProvider = context.watch<DataProvider>();
    final fertilizerItems = _catalogItemsForType(
      dataProvider.defSups,
      'Fertilizer',
    );
    final herbicideItems = _catalogItemsForType(
      dataProvider.defSups,
      'Herbicide',
    );
    final pesticideItems = _catalogItemsForType(
      dataProvider.defSups,
      'Pesticide',
    );
    final showFertilizer =
        _selectedFilter == MarketPriceCategoryFilter.all ||
            _selectedFilter == MarketPriceCategoryFilter.fertilizer;
    final showHerbicide =
        _selectedFilter == MarketPriceCategoryFilter.all ||
            _selectedFilter == MarketPriceCategoryFilter.herbicide;
    final showPesticide =
        _selectedFilter == MarketPriceCategoryFilter.all ||
            _selectedFilter == MarketPriceCategoryFilter.pesticide;
    final sources =
        (_snapshot?['sources'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map>()
            .map((source) => Map<String, dynamic>.from(source))
            .toList();
    final lastSyncedAt = _snapshot?['lastSyncedAt']?.toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Latest Price List'),
        actions: [
          IconButton(
            onPressed:
                _isRefreshing ? null : () => _loadSnapshot(refresh: true),
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh price cache',
          ),
        ],
      ),
      body: Container(
        color: scheme.surface,
        child: _isLoading && _snapshot == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () => _loadSnapshot(refresh: true),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildHeaderCard(
                      context: context,
                      lastSyncedAt: lastSyncedAt,
                      error: _error,
                    ),
                    const SizedBox(height: 16),
                    _buildCatalogSectionsCard(
                      context: context,
                      fertilizerItems: fertilizerItems,
                      herbicideItems: herbicideItems,
                      pesticideItems: pesticideItems,
                      showFertilizer: showFertilizer,
                      showHerbicide: showHerbicide,
                      showPesticide: showPesticide,
                    ),
                    const SizedBox(height: 16),
                    if (sources.isEmpty)
                      _buildEmptyCard(context)
                    else
                      ...sources.map((source) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildSourceCard(context, source),
                          )),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeaderCard({
    required BuildContext context,
    required String? lastSyncedAt,
    required String? error,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cached locally for offline use',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            lastSyncedAt == null
                ? 'No local snapshot yet. Pull down or tap refresh when connected.'
                : 'Last sync: ${_formatTimestamp(lastSyncedAt)}',
            style: TextStyle(
              height: 1.45,
              color: scheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The app refreshes these sources on launch and stores the normalized JSON snapshot on-device.',
            style: TextStyle(
              height: 1.45,
              color: scheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
          if (error != null && error.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Refresh issue: $error',
              style: TextStyle(
                color: scheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        'No price data is available yet. Connect to the internet and refresh once.',
        style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.75)),
      ),
    );
  }

  Widget _buildCatalogSectionsCard({
    required BuildContext context,
    required List<DefSup> fertilizerItems,
    required List<DefSup> herbicideItems,
    required List<DefSup> pesticideItems,
    required bool showFertilizer,
    required bool showHerbicide,
    required bool showPesticide,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Supply Prices by Type',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Each item is grouped under its catalog type and shows the current stored price.',
            style: TextStyle(
              height: 1.45,
              color: scheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 14),
          _buildFilterChips(context),
          const SizedBox(height: 14),
          if (showFertilizer)
            _buildTypeSection(
              context,
              title: 'Fertilizer',
              items: fertilizerItems,
              accent: Colors.green.shade700,
            ),
          if (showFertilizer && (showHerbicide || showPesticide))
            const SizedBox(height: 12),
          if (showHerbicide)
            _buildTypeSection(
              context,
              title: 'Herbicide',
              items: herbicideItems,
              accent: Colors.orange.shade700,
            ),
          if (showHerbicide && showPesticide) const SizedBox(height: 12),
          if (showPesticide)
            _buildTypeSection(
              context,
              title: 'Pesticide',
              items: pesticideItems,
              accent: Colors.red.shade700,
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget buildChip(String label, MarketPriceCategoryFilter filter) {
      final selected = _selectedFilter == filter;
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() {
            _selectedFilter = filter;
          });
        },
        selectedColor: scheme.primary,
        backgroundColor: scheme.surfaceContainerHighest,
        labelStyle: TextStyle(
          color: selected ? Colors.white : scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        showCheckmark: false,
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        buildChip('All', MarketPriceCategoryFilter.all),
        buildChip('Fertilizer', MarketPriceCategoryFilter.fertilizer),
        buildChip('Herbicide', MarketPriceCategoryFilter.herbicide),
        buildChip('Pesticide', MarketPriceCategoryFilter.pesticide),
      ],
    );
  }

  Widget _buildTypeSection(
    BuildContext context, {
    required String title,
    required List<DefSup> items,
    required Color accent,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  title,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${items.length} item${items.length == 1 ? '' : 's'}',
                style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: 0.65),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text(
              'No items found for this type.',
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.65),
              ),
            )
          else
            ...items.map(
              (item) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: scheme.outline.withValues(alpha: 0.18),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    Text(
                      _formatPeso(item.cost),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSourceCard(BuildContext context, Map<String, dynamic> source) {
    final scheme = Theme.of(context).colorScheme;
    final rows = (source['rows'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    final meta = source['meta'] is Map
        ? Map<String, dynamic>.from(source['meta'] as Map)
        : const <String, dynamic>{};
    final displayType = source['displayType']?.toString() ?? '';
    final status = source['status']?.toString() ?? 'unknown';
    final sourceUrl = source['sourceUrl']?.toString();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      source['label']?.toString() ?? 'Unnamed source',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      source['summary']?.toString() ?? '',
                      style: TextStyle(
                        height: 1.45,
                        color: scheme.onSurface.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusChip(context, status),
            ],
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildMetaWrap(context, meta),
          ],
          if (sourceUrl != null && sourceUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () => _openUrl(sourceUrl),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Open source'),
            ),
          ],
          const SizedBox(height: 8),
          if (displayType == 'regional_prices')
            _buildRegionalPriceRows(context, rows)
          else if (displayType == 'report_links')
            _buildReportRows(context, rows)
          else if (displayType == 'daily_report_links')
            _buildDailyReportRows(context, rows)
          else
            Text(
              'No renderer for this source format.',
              style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.6)),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, String status) {
    final scheme = Theme.of(context).colorScheme;
    final isHealthy = status == 'ok';
    final isStale = status == 'stale';
    final color = isHealthy
        ? Colors.green.shade700
        : isStale
            ? Colors.orange.shade700
            : scheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildMetaWrap(BuildContext context, Map<String, dynamic> meta) {
    final scheme = Theme.of(context).colorScheme;
    final items = <String>[
      if (_metaRange(meta) case final range?) range,
      if (meta['latestMonthLabel']?.toString().isNotEmpty ?? false)
        'Month: ${meta['latestMonthLabel']}',
      if (meta['unit']?.toString().isNotEmpty ?? false) meta['unit'].toString(),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map((item) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  item,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
              ))
          .toList(),
    );
  }

  String? _metaRange(Map<String, dynamic> meta) {
    final start = meta['latestWeekStart']?.toString();
    final end = meta['latestWeekEnd']?.toString();
    if (start == null || end == null || start.isEmpty || end.isEmpty) {
      return null;
    }
    return 'Week: $start to $end';
  }

  Widget _buildRegionalPriceRows(
    BuildContext context,
    List<Map<String, dynamic>> rows,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final visibleRows = rows.take(12).toList();
    return Column(
      children: visibleRows
          .map(
            (row) => Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row['location']?.toString() ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '₱${(row['price'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildReportRows(
    BuildContext context,
    List<Map<String, dynamic>> rows,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: rows
          .map(
            (row) => Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row['period']?.toString() ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _openUrl(row['reportUrl']?.toString()),
                    child: const Text('Open PDF'),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildDailyReportRows(
    BuildContext context,
    List<Map<String, dynamic>> rows,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: rows
          .map(
            (row) => Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row['label']?.toString() ?? row['date']?.toString() ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: (row['reports'] as List<dynamic>? ??
                            const <dynamic>[])
                        .whereType<Map>()
                        .map((report) => Map<String, dynamic>.from(report))
                        .map(
                          (report) => ActionChip(
                            label:
                                Text(report['province']?.toString() ?? 'Open'),
                            onPressed: () =>
                                _openUrl(report['reportUrl']?.toString()),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Future<void> _openUrl(String? rawUrl) async {
    if (rawUrl == null || rawUrl.isEmpty) {
      return;
    }

    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      return;
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _formatTimestamp(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return raw;
    }
    final local = parsed.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  List<DefSup> _catalogItemsForType(List<DefSup> items, String type) {
    final normalizedType = type.toLowerCase();
    final filtered = items.where((item) {
      final itemType = item.type.trim().toLowerCase();
      if (normalizedType == 'fertilizer') {
        return itemType.contains('fert');
      }
      if (normalizedType == 'herbicide') {
        return itemType.contains('herb');
      }
      if (normalizedType == 'pesticide') {
        return itemType.contains('pest') ||
            itemType.contains('insect') ||
            itemType.contains('fungicide');
      }
      return itemType == normalizedType;
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return filtered;
  }

  String _formatPeso(double value) => 'PHP ${value.toStringAsFixed(2)}';
}
