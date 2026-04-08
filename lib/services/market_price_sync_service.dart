import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class MarketPriceSyncService {
  MarketPriceSyncService._();

  static final MarketPriceSyncService instance = MarketPriceSyncService._();

  static const String ricelyticsUrl =
      'https://ricelytics.philrice.gov.ph/staging/fertilizer_prices';
  static const String ricelyticsMonthlyEndpoint =
      'https://ricelytics.philrice.gov.ph/staging/fetch/get_fertprices_monthly_data';
  static const String fpaWeeklyPricesUrl =
      'https://fpa.da.gov.ph/weekly-prices/';
  static const String da10ReferenceUrl =
      'https://cagayandeoro.da.gov.ph/?p=86756';
  static const String da10PriceIndexUrl =
      'https://cagayandeoro.da.gov.ph/?page_id=88249';

  static const String _cacheFileName = 'market_price_cache.json';
  static const Duration _requestTimeout = Duration(seconds: 8);
  static const Duration _sourceTimeout = Duration(seconds: 10);

  Future<Map<String, dynamic>>? _inFlightSync;

  Future<Map<String, dynamic>?> loadCachedSnapshot() async {
    try {
      final file = await _cacheFile();
      if (!await file.exists()) {
        return null;
      }

      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (error) {
      debugPrint('MarketPriceSyncService.loadCachedSnapshot error: $error');
    }
    return null;
  }

  Future<Map<String, dynamic>> syncLatestPriceCache() {
    final currentSync = _inFlightSync;
    if (currentSync != null) {
      return currentSync;
    }

    final future = _syncInternal();
    _inFlightSync = future;
    future.whenComplete(() => _inFlightSync = null);
    return future;
  }

  Future<Map<String, dynamic>> _syncInternal() async {
    final existingSnapshot = await loadCachedSnapshot();
    final existingSources = _sourceMapById(existingSnapshot);
    final nowIso = DateTime.now().toIso8601String();

    final sourceFutures = <Future<Map<String, dynamic>>>[
      _fetchSourceWithFallback(
        id: 'ricelytics',
        label: 'PhilRice Ricelytics',
        existingSource: existingSources['ricelytics'],
        fetcher: _fetchRicelyticsSource,
      ),
      _fetchSourceWithFallback(
        id: 'fpa',
        label: 'FPA Weekly Prices',
        existingSource: existingSources['fpa'],
        fetcher: _fetchFpaSource,
      ),
      _fetchSourceWithFallback(
        id: 'da_region_10',
        label: 'DA Region 10 Price Index',
        existingSource: existingSources['da_region_10'],
        fetcher: _fetchDaRegion10Source,
      ),
    ];

    final sources = await Future.wait(sourceFutures);

    final snapshot = <String, dynamic>{
      'schemaVersion': 1,
      'lastSyncedAt': nowIso,
      'sources': sources,
    };

    final file = await _cacheFile();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(snapshot),
      flush: true,
    );

    return snapshot;
  }

  Future<Map<String, dynamic>> _fetchSourceWithFallback({
    required String id,
    required String label,
    required Map<String, dynamic>? existingSource,
    required Future<Map<String, dynamic>> Function() fetcher,
  }) async {
    try {
      return await fetcher().timeout(
        _sourceTimeout,
        onTimeout: () => throw TimeoutException(
          '$id source timed out after ${_sourceTimeout.inSeconds}s',
        ),
      );
    } catch (error) {
      debugPrint(_sourceErrorMessage(id, error, existingSource != null));
      final fallback = <String, dynamic>{
        'id': id,
        'label': label,
        'status': existingSource == null ? 'error' : 'stale',
        'fetchedAt': existingSource?['fetchedAt'],
        'rows': existingSource?['rows'] ?? const <dynamic>[],
        'meta': existingSource?['meta'] ?? const <String, dynamic>{},
        'sourceUrl': existingSource?['sourceUrl'],
        'summary': existingSource?['summary'] ?? 'No cached data available.',
        'error': error.toString(),
      };
      if (existingSource != null) {
        fallback['cachedLastSyncedAt'] = existingSource['fetchedAt'];
      }
      return fallback;
    }
  }

  Future<Map<String, dynamic>> _fetchRicelyticsSource() async {
    final html = await _getBody(ricelyticsUrl);
    final latestWeekStart = _firstMatch(
      html,
      RegExp(r"var latest_fweek = new Date\('([^']+)'\);"),
    );
    final latestWeekEnd = _firstMatch(
      html,
      RegExp(r"var latest_lweek = new Date\('([^']+)'\);"),
    );
    final latestMonth = _firstMatch(
      html,
      RegExp(r"var fertLatestMonth = '([^']+)';"),
    );
    final latestYear = _firstMatch(
      html,
      RegExp(r"var fertLatestYear = '([^']+)';"),
    );
    final mapData = _extractJsonArray(
      html,
      RegExp(r"dbRegsMap = JSON\.parse\('(.+?)'\);", dotAll: true),
    );

    final monthlyResponse = await _post(
      ricelyticsMonthlyEndpoint,
      headers: _requestHeaders,
    );
    if (monthlyResponse.statusCode < 200 || monthlyResponse.statusCode >= 300) {
      throw HttpException(
        'Ricelytics monthly endpoint failed (${monthlyResponse.statusCode})',
      );
    }

    final monthlyDecoded = jsonDecode(monthlyResponse.body);
    final latestPeriodsRaw = monthlyDecoded is Map<String, dynamic>
        ? monthlyDecoded
        : <String, dynamic>{};
    final latestPeriods = _parseJsonArrayField(
      latestPeriodsRaw['monthly_fertprices'],
    );

    final rows = mapData
        .map((row) => <String, dynamic>{
              'location': row['location_name']?.toString() ?? '',
              'mapId': row['map_ID']?.toString() ?? '',
              'week': int.tryParse(row['week']?.toString() ?? ''),
              'start': row['start']?.toString() ?? latestWeekStart,
              'end': row['end']?.toString() ?? latestWeekEnd,
              'year': row['year']?.toString() ?? latestYear,
              'price': _toDouble(row['value']),
              'unit': 'PHP per 50-kg bag',
              'fertilizer': 'Urea',
            })
        .where((row) => (row['location'] as String).isNotEmpty)
        .toList()
      ..sort(
          (a, b) => (_toDouble(b['price'])).compareTo(_toDouble(a['price'])));

    return <String, dynamic>{
      'id': 'ricelytics',
      'label': 'PhilRice Ricelytics',
      'status': 'ok',
      'displayType': 'regional_prices',
      'fetchedAt': DateTime.now().toIso8601String(),
      'sourceUrl': ricelyticsUrl,
      'summary':
          'Latest weekly regional fertilizer prices sourced from the PhilRice Ricelytics dashboard.',
      'meta': <String, dynamic>{
        'latestWeekStart': latestWeekStart,
        'latestWeekEnd': latestWeekEnd,
        'latestMonthLabel': _joinNonEmpty([latestMonth, latestYear]),
        'unit': 'PHP per 50-kg bag',
        'latestPeriods': latestPeriods.take(12).toList(),
      },
      'rows': rows,
    };
  }

  Future<Map<String, dynamic>> _fetchFpaSource() async {
    final html = await _getBody(fpaWeeklyPricesUrl);
    final document = html_parser.parse(html);
    final cells = document.querySelectorAll('td');
    final entries = <Map<String, dynamic>>[];

    for (final cell in cells) {
      final link = cell.querySelector('a[href]');
      final href = link?.attributes['href']?.trim() ?? '';
      if (href.isEmpty || !href.toUpperCase().contains('WFP')) {
        continue;
      }

      final periodText = cell.text.split('|').first.trim();
      if (periodText.isEmpty) {
        continue;
      }

      final range = _parseFpaDateRange(periodText);
      entries.add(<String, dynamic>{
        'period': periodText,
        'start': range['start'],
        'end': range['end'],
        'reportUrl': href,
      });
    }

    entries.sort((a, b) {
      final left = DateTime.tryParse(b['end']?.toString() ?? '');
      final right = DateTime.tryParse(a['end']?.toString() ?? '');
      if (left == null || right == null) {
        return 0;
      }
      return left.compareTo(right);
    });

    return <String, dynamic>{
      'id': 'fpa',
      'label': 'FPA Weekly Prices',
      'status': 'ok',
      'displayType': 'report_links',
      'fetchedAt': DateTime.now().toIso8601String(),
      'sourceUrl': fpaWeeklyPricesUrl,
      'summary':
          'Latest fertilizer weekly price reports published by the Fertilizer and Pesticide Authority.',
      'meta': <String, dynamic>{
        'unit': 'Weekly report PDF',
        'entryCount': entries.length,
      },
      'rows': entries.take(12).toList(),
    };
  }

  Future<Map<String, dynamic>> _fetchDaRegion10Source() async {
    final html = await _getBody(da10PriceIndexUrl);
    final document = html_parser.parse(html);
    final tables = document.querySelectorAll('table');
    if (tables.isEmpty) {
      throw StateError('DA Region 10 price table not found.');
    }

    final table = tables.first;
    final rowElements = table.querySelectorAll('tr');
    if (rowElements.length < 3) {
      throw StateError('DA Region 10 price table is incomplete.');
    }

    final provinceHeaders = rowElements[1]
        .querySelectorAll('td')
        .map((cell) => _normalizeWhitespace(cell.text))
        .where((text) => text.isNotEmpty)
        .toList();

    final entries = <Map<String, dynamic>>[];
    for (final row in rowElements.skip(2)) {
      final cells = row.querySelectorAll('td');
      if (cells.isEmpty) {
        continue;
      }

      final dateText = _normalizeWhitespace(cells.first.text);
      if (dateText.isEmpty || _isMonthMarker(dateText)) {
        continue;
      }

      final parsedDate = _parseLooseDate(dateText);
      if (parsedDate == null) {
        continue;
      }

      final provinceReports = <Map<String, dynamic>>[];
      for (var index = 1;
          index < cells.length && index <= provinceHeaders.length;
          index++) {
        final link = cells[index].querySelector('a[href]');
        final href = link?.attributes['href']?.trim() ?? '';
        if (href.isEmpty) {
          continue;
        }

        provinceReports.add(<String, dynamic>{
          'province': provinceHeaders[index - 1],
          'reportUrl': href,
        });
      }

      if (provinceReports.isEmpty) {
        continue;
      }

      entries.add(<String, dynamic>{
        'date': DateFormat('yyyy-MM-dd').format(parsedDate),
        'label': dateText,
        'reports': provinceReports,
      });
    }

    entries
        .sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));

    return <String, dynamic>{
      'id': 'da_region_10',
      'label': 'DA Region 10 Price Index',
      'status': 'ok',
      'displayType': 'daily_report_links',
      'fetchedAt': DateTime.now().toIso8601String(),
      'sourceUrl': da10PriceIndexUrl,
      'summary':
          'Latest Regional Daily Price Index report links for Northern Mindanao provinces.',
      'meta': <String, dynamic>{
        'referenceUrl': da10ReferenceUrl,
        'unit': 'Daily report link',
        'entryCount': entries.length,
      },
      'rows': entries.take(10).toList(),
    };
  }

  Future<File> _cacheFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}${Platform.pathSeparator}$_cacheFileName');
  }

  Future<void> clearCache() async {
    try {
      final file = await _cacheFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (error) {
      debugPrint('MarketPriceSyncService.clearCache error: $error');
    }
  }

  Map<String, Map<String, dynamic>> _sourceMapById(
    Map<String, dynamic>? snapshot,
  ) {
    final sources = snapshot?['sources'];
    if (sources is! List) {
      return const <String, Map<String, dynamic>>{};
    }

    final mapped = <String, Map<String, dynamic>>{};
    for (final source in sources) {
      if (source is Map) {
        final asMap = Map<String, dynamic>.from(source);
        final id = asMap['id']?.toString();
        if (id != null && id.isNotEmpty) {
          mapped[id] = asMap;
        }
      }
    }
    return mapped;
  }

  Future<String> _getBody(String url) async {
    final response = await _get(url, headers: _requestHeaders);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('Request failed for $url (${response.statusCode})');
    }
    return response.body;
  }

  Future<http.Response> _get(
    String url, {
    Map<String, String>? headers,
  }) {
    return http.get(Uri.parse(url), headers: headers).timeout(
          _requestTimeout,
          onTimeout: () => throw TimeoutException(
            'GET $url timed out after ${_requestTimeout.inSeconds}s',
          ),
        );
  }

  Future<http.Response> _post(
    String url, {
    Map<String, String>? headers,
    Object? body,
  }) {
    return http.post(Uri.parse(url), headers: headers, body: body).timeout(
          _requestTimeout,
          onTimeout: () => throw TimeoutException(
            'POST $url timed out after ${_requestTimeout.inSeconds}s',
          ),
        );
  }

  Map<String, String> get _requestHeaders => const <String, String>{
        'User-Agent': 'RCAMARii/1.0 (+https://nomad.local)',
      };

  String? _firstMatch(String text, RegExp pattern) {
    final match = pattern.firstMatch(text);
    if (match == null || match.groupCount == 0) {
      return null;
    }
    return match.group(1)?.trim();
  }

  List<Map<String, dynamic>> _extractJsonArray(String text, RegExp pattern) {
    final raw = _firstMatch(text, pattern);
    if (raw == null || raw.isEmpty) {
      return const <Map<String, dynamic>>[];
    }
    return _parseJsonArrayField(raw);
  }

  List<Map<String, dynamic>> _parseJsonArrayField(dynamic raw) {
    if (raw == null) {
      return const <Map<String, dynamic>>[];
    }

    dynamic decoded = raw;
    if (decoded is String) {
      final cleaned =
          decoded.replaceAll(r"\'", "'").replaceAll('&quot;', '"').trim();
      decoded = jsonDecode(cleaned);
    }

    if (decoded is! List) {
      return const <Map<String, dynamic>>[];
    }

    return decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Map<String, String?> _parseFpaDateRange(String input) {
    final cleaned = _normalizeWhitespace(input);
    final crossYear = RegExp(
      r'^([A-Za-z]+)\s+(\d{1,2}),\s*(\d{4})-([A-Za-z]+)\s+(\d{1,2}),\s*(\d{4})$',
    ).firstMatch(cleaned);
    if (crossYear != null) {
      final start = _safeIsoDate(
        '${crossYear.group(1)} ${crossYear.group(2)}, ${crossYear.group(3)}',
      );
      final end = _safeIsoDate(
        '${crossYear.group(4)} ${crossYear.group(5)}, ${crossYear.group(6)}',
      );
      return <String, String?>{'start': start, 'end': end};
    }

    final crossMonthSameYear = RegExp(
      r'^([A-Za-z]+)\s+(\d{1,2})-([A-Za-z]+)\s+(\d{1,2}),\s*(\d{4})$',
    ).firstMatch(cleaned);
    if (crossMonthSameYear != null) {
      final start = _safeIsoDate(
        '${crossMonthSameYear.group(1)} ${crossMonthSameYear.group(2)}, ${crossMonthSameYear.group(5)}',
      );
      final end = _safeIsoDate(
        '${crossMonthSameYear.group(3)} ${crossMonthSameYear.group(4)}, ${crossMonthSameYear.group(5)}',
      );
      return <String, String?>{'start': start, 'end': end};
    }

    final sameMonth = RegExp(
      r'^([A-Za-z]+)\s+(\d{1,2})-(\d{1,2}),\s*(\d{4})$',
    ).firstMatch(cleaned);
    if (sameMonth != null) {
      final start = _safeIsoDate(
        '${sameMonth.group(1)} ${sameMonth.group(2)}, ${sameMonth.group(4)}',
      );
      final end = _safeIsoDate(
        '${sameMonth.group(1)} ${sameMonth.group(3)}, ${sameMonth.group(4)}',
      );
      return <String, String?>{'start': start, 'end': end};
    }

    final singleDate = _safeIsoDate(cleaned);
    return <String, String?>{'start': singleDate, 'end': singleDate};
  }

  DateTime? _parseLooseDate(String text) {
    final formats = <DateFormat>[
      DateFormat('MMMM d, yyyy'),
      DateFormat('MMM d, yyyy'),
    ];
    for (final format in formats) {
      try {
        return format.parseStrict(text);
      } catch (_) {}
    }
    return null;
  }

  String? _safeIsoDate(String text) {
    final parsed = _parseLooseDate(text);
    if (parsed == null) {
      return null;
    }
    return DateFormat('yyyy-MM-dd').format(parsed);
  }

  bool _isMonthMarker(String text) {
    final cleaned = text.trim();
    return RegExp(r'^[A-Z]+\s+\d{4}$').hasMatch(cleaned);
  }

  String _normalizeWhitespace(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _joinNonEmpty(List<String?> values) {
    return values
        .where((value) => value != null && value.trim().isNotEmpty)
        .map((value) => value!.trim())
        .join(' ');
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  String _sourceErrorMessage(
    String id,
    Object error,
    bool hasCachedSource,
  ) {
    final fallbackLabel = hasCachedSource ? 'using cached data' : 'no cache';
    if (error is TimeoutException) {
      return 'MarketPriceSyncService.$id timeout: $fallbackLabel.';
    }
    return 'MarketPriceSyncService.$id error: $error ($fallbackLabel)';
  }
}
