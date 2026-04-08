import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/def_sup_model.dart';
import '../providers/data_provider.dart';
import '../services/app_defaults_service.dart';
import '../services/app_properties_store.dart';
import '../services/market_price_sync_service.dart';

class MarketPriceListScreen extends StatefulWidget {
  const MarketPriceListScreen({
    super.key,
    this.initialCatalogFilter = 'All',
  });

  final String initialCatalogFilter;

  @override
  State<MarketPriceListScreen> createState() => _MarketPriceListScreenState();
}

class _MarketPriceListScreenState extends State<MarketPriceListScreen> {
  static const String _allRegionsOption = 'All regions';
  static const String _allCatalogTypesOption = 'All';

  final AppPropertiesStore _store = AppPropertiesStore.instance;
  Map<String, dynamic>? _snapshot;
  bool _isLoading = true;
  bool _isRefreshing = false;
  final Map<String, String> _selectedRegionsBySourceId = <String, String>{};
  late String _selectedCatalogFilter;

  @override
  void initState() {
    super.initState();
    _selectedCatalogFilter = _normalizeCatalogFilter(
      widget.initialCatalogFilter,
    );
    _restoreSavedState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dataProvider = context.read<DataProvider>();
      if (dataProvider.defSups.isEmpty) {
        dataProvider.loadDefSupsFromDb();
      }
    });
    _loadSnapshot(refresh: true);
  }

  Future<void> _restoreSavedState() async {
    final savedRegionsRaw = await _store.getString(
      AppDefaultsService.marketPriceSelectedRegionsKey,
    );

    final restoredRegions = <String, String>{};
    if (savedRegionsRaw != null && savedRegionsRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(savedRegionsRaw);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final key = entry.key.toString().trim();
            final value = entry.value.toString().trim();
            if (key.isNotEmpty && value.isNotEmpty) {
              restoredRegions[key] = value;
            }
          }
        }
      } catch (_) {
        restoredRegions.clear();
      }
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _selectedRegionsBySourceId
        ..clear()
        ..addAll(restoredRegions);
    });
  }

  Future<void> _persistSelectedRegions() async {
    await _store.setString(
      AppDefaultsService.marketPriceSelectedRegionsKey,
      jsonEncode(_selectedRegionsBySourceId),
    );
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
        color: scheme.surface.withValues(alpha: 0.74),
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
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.74),
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
  }) {
    final scheme = Theme.of(context).colorScheme;
    final visibleSections = <Widget>[
      if (_shouldShowCatalogSection('Fertilizer'))
        _buildTypeSection(
          context,
          title: 'Fertilizer',
          items: fertilizerItems,
          accent: Colors.green.shade700,
        ),
      if (_shouldShowCatalogSection('Herbicide'))
        _buildTypeSection(
          context,
          title: 'Herbicide',
          items: herbicideItems,
          accent: Colors.orange.shade700,
        ),
      if (_shouldShowCatalogSection('Pesticide'))
        _buildTypeSection(
          context,
          title: 'Pesticide',
          items: pesticideItems,
          accent: Colors.red.shade700,
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.74),
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCatalogFilterChip(_allCatalogTypesOption),
                const SizedBox(width: 8),
                _buildCatalogFilterChip('Fertilizer'),
                const SizedBox(width: 8),
                _buildCatalogFilterChip('Herbicide'),
                const SizedBox(width: 8),
                _buildCatalogFilterChip('Pesticide'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (visibleSections.isEmpty)
            Text(
              'No catalog items are available for the selected filter.',
              style: TextStyle(
                color: scheme.onSurface.withValues(alpha: 0.65),
              ),
            )
          else
            ..._intersperseSpacing(visibleSections, const SizedBox(height: 12)),
        ],
      ),
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
                  color: scheme.surface.withValues(alpha: 0.74),
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
    final sourceId = source['id']?.toString() ??
        source['label']?.toString() ??
        'market-price-source';
    final displayType = source['displayType']?.toString() ?? '';
    final sourceUrl = source['sourceUrl']?.toString();
    final selectedRegion =
        _selectedRegionsBySourceId[sourceId] ?? _allRegionsOption;
    final visibleRegionalRows = displayType == 'regional_prices'
        ? _filterRegionalRows(rows, selectedRegion)
        : const <Map<String, dynamic>>[];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.74),
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
                    if (source['description'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          source['description'].toString(),
                          style: TextStyle(
                            color: scheme.onSurface.withValues(alpha: 0.72),
                            height: 1.45,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (sourceUrl != null && sourceUrl.isNotEmpty)
                IconButton(
                  onPressed: () => launchUrl(Uri.parse(sourceUrl)),
                  icon: const Icon(Icons.public_rounded),
                  tooltip: 'Open official source',
                ),
              IconButton(
                onPressed: () => _showExportPreview(source),
                icon: const Icon(Icons.picture_as_pdf_rounded),
                tooltip: 'Export as PDF',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSourceRows(
            context,
            source: source,
            displayType: displayType,
            rows: rows,
            visibleRegionalRows: visibleRegionalRows,
          ),
        ],
      ),
    );
  }

  Widget _buildSourceRows(
    BuildContext context, {
    required Map<String, dynamic> source,
    required String displayType,
    required List<Map<String, dynamic>> rows,
    required List<Map<String, dynamic>> visibleRegionalRows,
  }) {
    switch (displayType) {
      case 'regional_prices':
        return _buildRegionalTable(context, source, rows, visibleRegionalRows);
      case 'report_links':
        return _buildReportLinksTable(context, rows);
      case 'daily_report_links':
        return _buildDailyReportLinksTable(context, rows);
      default:
        return _buildStandardTable(context, rows);
    }
  }

  Widget _buildStandardTable(
      BuildContext context, List<Map<String, dynamic>> rows) {
    final scheme = Theme.of(context).colorScheme;
    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        ...rows.map((row) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _rowLabel(row),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        if (row['unit'] != null)
                          Text(
                            row['unit'].toString(),
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurface.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    _formatPeso(row['price']),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildRegionalTable(
    BuildContext context,
    Map<String, dynamic> source,
    List<Map<String, dynamic>> allRows,
    List<Map<String, dynamic>> visibleRows,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final sourceId = source['id']?.toString() ?? '';
    final regions = allRows.map(_rowRegion).toSet().toList()..sort();
    final selectedRegion =
        _selectedRegionsBySourceId[sourceId] ?? _allRegionsOption;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildRegionChip(
                  _allRegionsOption, selectedRegion == _allRegionsOption,
                  (selected) {
                if (selected) {
                  setState(() {
                    _selectedRegionsBySourceId[sourceId] = _allRegionsOption;
                  });
                  _persistSelectedRegions();
                }
              }),
              ...regions.map((region) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _buildRegionChip(region, selectedRegion == region,
                        (selected) {
                      if (selected) {
                        setState(() {
                          _selectedRegionsBySourceId[sourceId] = region;
                        });
                        _persistSelectedRegions();
                      }
                    }),
                  )),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...visibleRows.map((row) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _rowLabel(row),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Row(
                          children: [
                            Text(
                              _rowRegion(row),
                              style: TextStyle(
                                fontSize: 11,
                                color: scheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (row['unit'] != null) ...[
                              Text(
                                ' • ',
                                style: TextStyle(
                                    color: scheme.onSurface
                                        .withValues(alpha: 0.3)),
                              ),
                              Text(
                                row['unit'].toString(),
                                style: TextStyle(
                                  fontSize: 11,
                                  color:
                                      scheme.onSurface.withValues(alpha: 0.6),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatPeso(row['price']),
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildReportLinksTable(
    BuildContext context,
    List<Map<String, dynamic>> rows,
  ) {
    final scheme = Theme.of(context).colorScheme;
    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        ...rows.map((row) {
          final period = _firstNonEmptyString([
                row['label'],
                row['period'],
              ]) ??
              'Weekly report';
          final reportUrl = row['reportUrl']?.toString();
          final dateRange = _formatDateRange(
            row['start']?.toString(),
            row['end']?.toString(),
          );

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        period,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      if (dateRange != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            dateRange,
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurface.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.tonalIcon(
                  onPressed: reportUrl == null
                      ? null
                      : () => _openExternalUrl(reportUrl),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Open PDF'),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDailyReportLinksTable(
    BuildContext context,
    List<Map<String, dynamic>> rows,
  ) {
    final scheme = Theme.of(context).colorScheme;
    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        ...rows.map((row) {
          final reports =
              (row['reports'] as List<dynamic>? ?? const <dynamic>[])
                  .whereType<Map>()
                  .map((report) => Map<String, dynamic>.from(report))
                  .toList();

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row['label']?.toString() ?? 'Daily report',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (reports.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: reports.map((report) {
                      final province =
                          report['province']?.toString() ?? 'Province';
                      final reportUrl = report['reportUrl']?.toString();
                      return OutlinedButton.icon(
                        onPressed: reportUrl == null
                            ? null
                            : () => _openExternalUrl(reportUrl),
                        icon: const Icon(Icons.description_outlined, size: 16),
                        label: Text(province),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRegionChip(
      String label, bool selected, ValueChanged<bool> onSelected) {
    final scheme = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      selectedColor: scheme.primary.withValues(alpha: 0.12),
      backgroundColor: Colors.transparent,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color:
            selected ? scheme.primary : scheme.onSurface.withValues(alpha: 0.6),
      ),
      side: BorderSide(
        color:
            selected ? scheme.primary : scheme.outline.withValues(alpha: 0.2),
      ),
      showCheckmark: false,
    );
  }

  Widget _buildCatalogFilterChip(String label) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _selectedCatalogFilter == label;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (nextSelected) {
        if (!nextSelected) {
          return;
        }
        setState(() {
          _selectedCatalogFilter = label;
        });
      },
      selectedColor: scheme.primary.withValues(alpha: 0.12),
      backgroundColor: Colors.transparent,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color:
            selected ? scheme.primary : scheme.onSurface.withValues(alpha: 0.6),
      ),
      side: BorderSide(
        color:
            selected ? scheme.primary : scheme.outline.withValues(alpha: 0.2),
      ),
      showCheckmark: false,
    );
  }

  List<Map<String, dynamic>> _filterRegionalRows(
      List<Map<String, dynamic>> rows, String selectedRegion) {
    if (selectedRegion == _allRegionsOption) return rows;
    return rows.where((r) => _rowRegion(r) == selectedRegion).toList();
  }

  List<DefSup> _catalogItemsForType(List<DefSup> items, String type) {
    return items.where((item) => item.type == type).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  bool _shouldShowCatalogSection(String title) {
    return _selectedCatalogFilter == _allCatalogTypesOption ||
        _selectedCatalogFilter == title;
  }

  String _normalizeCatalogFilter(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'fertilizer':
        return 'Fertilizer';
      case 'herbicide':
        return 'Herbicide';
      case 'pesticide':
        return 'Pesticide';
      default:
        return _allCatalogTypesOption;
    }
  }

  List<Widget> _intersperseSpacing(List<Widget> children, Widget spacing) {
    if (children.length < 2) {
      return children;
    }

    final result = <Widget>[];
    for (var index = 0; index < children.length; index++) {
      if (index > 0) {
        result.add(spacing);
      }
      result.add(children[index]);
    }
    return result;
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp).toLocal();
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return timestamp;
    }
  }

  String _formatPeso(dynamic value) {
    final price = double.tryParse(value?.toString() ?? '0') ?? 0.0;
    return '₱${price.toStringAsFixed(2)}';
  }

  String? _firstNonEmptyString(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  String _rowLabel(Map<String, dynamic> row) {
    return _firstNonEmptyString([
          row['label'],
          row['fertilizer'],
          row['name'],
          row['period'],
          row['location'],
        ]) ??
        'Unknown Item';
  }

  String _rowRegion(Map<String, dynamic> row) {
    return _firstNonEmptyString([
          row['region'],
          row['location'],
          row['province'],
        ]) ??
        'Unknown region';
  }

  String? _formatDateRange(String? start, String? end) {
    final startLabel =
        start == null || start.isEmpty ? null : _formatShortDate(start);
    final endLabel = end == null || end.isEmpty ? null : _formatShortDate(end);

    if (startLabel == null && endLabel == null) {
      return null;
    }
    if (startLabel != null && endLabel != null) {
      return startLabel == endLabel ? startLabel : '$startLabel to $endLabel';
    }
    return startLabel ?? endLabel;
  }

  String _formatShortDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      const months = <String>[
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  Future<void> _openExternalUrl(String url) async {
    await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _showExportPreview(Map<String, dynamic> source) async {
    final pdfData = await _generatePdf(source);
    if (!mounted) return;

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfData,
      name: '${source['label'] ?? 'PriceList'}.pdf',
    );
  }

  Future<Uint8List> _generatePdf(Map<String, dynamic> source) async {
    final pdf = pw.Document();
    final rows = (source['rows'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          pw.Header(
            level: 0,
            child: pw.Text(source['label']?.toString() ?? 'Price List',
                style:
                    pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          ),
          if (source['description'] != null)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 20),
              child: pw.Text(source['description'].toString()),
            ),
          pw.TableHelper.fromTextArray(
            headers: ['Item', 'Region', 'Unit', 'Price'],
            data: rows
                .map((row) => [
                      row['label']?.toString() ?? '',
                      row['region']?.toString() ?? 'N/A',
                      row['unit']?.toString() ?? 'N/A',
                      _formatPeso(row['price']),
                    ])
                .toList(),
          ),
        ],
      ),
    );

    return pdf.save();
  }
}
