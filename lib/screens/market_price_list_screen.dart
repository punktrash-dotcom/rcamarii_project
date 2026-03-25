import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
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
  static const String _allRegionsOption = 'All regions';

  Map<String, dynamic>? _snapshot;
  bool _isLoading = true;
  bool _isRefreshing = false;
  late MarketPriceCategoryFilter _selectedFilter;
  final Map<String, String> _selectedRegionsBySourceId = <String, String>{};

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
      });
    } else {
      setState(() {
        _isLoading = true;
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
    final showFertilizer = _selectedFilter == MarketPriceCategoryFilter.all ||
        _selectedFilter == MarketPriceCategoryFilter.fertilizer;
    final showHerbicide = _selectedFilter == MarketPriceCategoryFilter.all ||
        _selectedFilter == MarketPriceCategoryFilter.herbicide;
    final showPesticide = _selectedFilter == MarketPriceCategoryFilter.all ||
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
                    _buildCatalogSectionsCard(
                      context: context,
                      lastSyncedAt: lastSyncedAt,
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
    required String? lastSyncedAt,
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
        color: scheme.surface,
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
            lastSyncedAt == null
                ? 'Last updated: not available yet'
                : 'Last updated: ${_formatTimestamp(lastSyncedAt)}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: scheme.primary,
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
          color: selected ? scheme.onPrimary : scheme.onSurface,
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
                  color: scheme.surface,
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
    final sourceId = source['id']?.toString() ??
        source['label']?.toString() ??
        'market-price-source';
    final displayType = source['displayType']?.toString() ?? '';
    final status = source['status']?.toString() ?? 'unknown';
    final sourceUrl = source['sourceUrl']?.toString();
    final selectedRegion =
        _selectedRegionsBySourceId[sourceId] ?? _allRegionsOption;
    final visibleRegionalRows = displayType == 'regional_prices'
        ? _filterRegionalRows(rows, selectedRegion)
        : const <Map<String, dynamic>>[];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
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
          if (displayType == 'regional_prices') ...[
            const SizedBox(height: 12),
            _buildRegionalControls(
              context,
              sourceId: sourceId,
              sourceLabel: source['label']?.toString() ?? 'Regional prices',
              selectedRegion: selectedRegion,
              allRows: rows,
              visibleRows: visibleRegionalRows,
              meta: meta,
              fetchedAt: source['fetchedAt']?.toString(),
            ),
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
            _buildRegionalPriceRows(
              context,
              visibleRegionalRows,
              selectedRegion: selectedRegion,
            )
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

  Widget _buildRegionalControls(
    BuildContext context, {
    required String sourceId,
    required String sourceLabel,
    required String selectedRegion,
    required List<Map<String, dynamic>> allRows,
    required List<Map<String, dynamic>> visibleRows,
    required Map<String, dynamic> meta,
    required String? fetchedAt,
  }) {
    final regionOptions = <String>[
      _allRegionsOption,
      ..._regionOptionsForRows(allRows),
    ];
    final effectiveRegion = regionOptions.contains(selectedRegion)
        ? selectedRegion
        : _allRegionsOption;
    final dropdown = DropdownButtonFormField<String>(
      initialValue: effectiveRegion,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Region to display',
      ),
      items: regionOptions
          .map(
            (region) => DropdownMenuItem<String>(
              value: region,
              child: Text(region),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value == null) {
          return;
        }
        setState(() {
          _selectedRegionsBySourceId[sourceId] = value;
        });
      },
    );
    final printButton = OutlinedButton.icon(
      onPressed: visibleRows.isEmpty
          ? null
          : () => _openRegionalPricePrintPreview(
                context,
                sourceLabel: sourceLabel,
                selectedRegion: effectiveRegion,
                rows: visibleRows,
                meta: meta,
                fetchedAt: fetchedAt,
              ),
      icon: const Icon(Icons.print_rounded),
      label: const Text('Print list'),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 620;
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              dropdown,
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: printButton),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: dropdown),
            const SizedBox(width: 12),
            printButton,
          ],
        );
      },
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
      BuildContext context, List<Map<String, dynamic>> rows,
      {required String selectedRegion}) {
    final scheme = Theme.of(context).colorScheme;
    if (rows.isEmpty) {
      final emptyLabel = selectedRegion == _allRegionsOption
          ? 'No regional price rows are available right now.'
          : 'No price rows are available for $selectedRegion.';
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(
          emptyLabel,
          style: TextStyle(
            color: scheme.onSurface.withValues(alpha: 0.65),
          ),
        ),
      );
    }

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
                      row['location']?.toString() ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    _formatPeso(_priceFromRow(row)),
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

  Future<void> _openRegionalPricePrintPreview(
    BuildContext context, {
    required String sourceLabel,
    required String selectedRegion,
    required List<Map<String, dynamic>> rows,
    required Map<String, dynamic> meta,
    required String? fetchedAt,
  }) async {
    if (rows.isEmpty) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _MarketPricePrintPreviewScreen(
          title: 'Market Price Print Preview',
          buildPdf: (format) => _buildRegionalPricePdf(
            format,
            sourceLabel: sourceLabel,
            selectedRegion: selectedRegion,
            rows: rows,
            meta: meta,
            fetchedAt: fetchedAt,
          ),
        ),
      ),
    );
  }

  Future<Uint8List> _buildRegionalPricePdf(
    PdfPageFormat format, {
    required String sourceLabel,
    required String selectedRegion,
    required List<Map<String, dynamic>> rows,
    required Map<String, dynamic> meta,
    required String? fetchedAt,
  }) async {
    final doc = pw.Document();
    final generatedAt = _formatTimestamp(DateTime.now().toIso8601String());
    final fetchedAtLabel =
        fetchedAt == null ? null : _formatTimestamp(fetchedAt);
    final range = _metaRange(meta);
    final unit = meta['unit']?.toString();

    doc.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(
            'RCAMARii Market Price List',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            sourceLabel,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text('Region: $selectedRegion'),
          if (unit != null && unit.isNotEmpty) pw.Text('Unit: $unit'),
          if (range != null) pw.Text(range),
          if (fetchedAtLabel != null) pw.Text('Latest sync: $fetchedAtLabel'),
          pw.Text('Generated: $generatedAt'),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: const ['Region', 'Price'],
            data: rows
                .map(
                  (row) => [
                    row['location']?.toString() ?? '',
                    _formatPeso(_priceFromRow(row)),
                  ],
                )
                .toList(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.green700,
            ),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: <int, pw.Alignment>{
              1: pw.Alignment.centerRight,
            },
            cellStyle: const pw.TextStyle(fontSize: 11),
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300),
              ),
            ),
          ),
        ],
      ),
    );

    return doc.save();
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

  List<String> _regionOptionsForRows(List<Map<String, dynamic>> rows) {
    final regions = rows
        .map((row) => row['location']?.toString().trim() ?? '')
        .where((region) => region.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return regions;
  }

  List<Map<String, dynamic>> _filterRegionalRows(
    List<Map<String, dynamic>> rows,
    String selectedRegion,
  ) {
    if (selectedRegion == _allRegionsOption) {
      return rows.take(12).toList();
    }
    return rows
        .where(
          (row) => (row['location']?.toString().trim() ?? '') == selectedRegion,
        )
        .toList();
  }

  double _priceFromRow(Map<String, dynamic> row) {
    final price = row['price'];
    if (price is num) {
      return price.toDouble();
    }
    return double.tryParse(price?.toString() ?? '') ?? 0.0;
  }

  String _formatPeso(double value) => 'PHP ${value.toStringAsFixed(2)}';
}

class _MarketPricePrintPreviewScreen extends StatelessWidget {
  const _MarketPricePrintPreviewScreen({
    required this.title,
    required this.buildPdf,
  });

  final String title;
  final Future<Uint8List> Function(PdfPageFormat format) buildPdf;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: scheme.onSurface,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: PdfPreview(
        build: buildPdf,
        allowPrinting: true,
        allowSharing: true,
        canChangeOrientation: false,
        canChangePageFormat: true,
        pdfFileName: 'rcamarii-market-price-list.pdf',
        previewPageMargin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        scrollViewDecoration: BoxDecoration(
          color: scheme.surface,
        ),
        pdfPreviewPageDecoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
      ),
    );
  }
}
