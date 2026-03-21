import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:pdfrx/pdfrx.dart';

import '../models/def_sup_model.dart';
import '../models/supply_model.dart';
import 'database_helper.dart';
import 'transaction_log_service.dart';

class SupplyPriceSyncService {
  SupplyPriceSyncService._();

  static final SupplyPriceSyncService instance = SupplyPriceSyncService._();

  static const String _fpaWeeklyPricesUrl =
      'https://fpa.da.gov.ph/weekly-prices/';
  static const String _fpaBaseUrl = 'https://fpa.da.gov.ph';

  Future<SupplyPriceSyncResult> syncCatalogWithLatestSourcePrices() async {
    final reportUrls = await _fetchLatestReportUrls();
    final fertilizerCandidates =
        await _fetchFertilizerCandidates(reportUrls.fertilizerUrl);
    final pesticideCandidates =
        await _fetchPesticideCandidates(reportUrls.pesticideUrl);
    final candidates = _dedupeCandidates([
      ...fertilizerCandidates,
      ...pesticideCandidates,
    ]);

    if (candidates.isEmpty) {
      return const SupplyPriceSyncResult(
        catalogUpdated: 0,
        catalogInserted: 0,
        suppliesUpdated: 0,
      );
    }

    final db = await DatabaseHelper.instance.database;
    final existingCatalog = (await db.query(DatabaseHelper.tableDefSup))
        .map((row) => DefSup.fromMap(row))
        .toList();
    final existingSupplies = (await db.query(DatabaseHelper.tableSupplies))
        .map((row) => Supply.fromMap(row))
        .toList();

    var catalogUpdated = 0;
    var catalogInserted = 0;
    var suppliesUpdated = 0;

    await db.transaction((txn) async {
      for (final item in existingCatalog) {
        final match = _findBestCandidateForCatalogItem(item, candidates);
        if (match == null) {
          continue;
        }

        final newCost = _roundMoney(match.cost);
        if (_sameMoney(item.cost, newCost)) {
          continue;
        }

        await txn.update(
          DatabaseHelper.tableDefSup,
          <String, Object?>{'Cost': newCost},
          where: 'id = ?',
          whereArgs: [item.id],
        );
        catalogUpdated++;
      }

      for (final item in existingSupplies) {
        final match = _findBestCandidateForSupplyItem(item, candidates);
        if (match == null) {
          continue;
        }

        final newCost = _roundMoney(match.cost);
        if (_sameMoney(item.cost, newCost)) {
          continue;
        }

        final newTotal = _roundMoney(item.quantity * newCost);
        await txn.update(
          DatabaseHelper.tableSupplies,
          <String, Object?>{
            'cost': newCost,
            'total': newTotal,
          },
          where: 'id = ?',
          whereArgs: [item.id],
        );
        suppliesUpdated++;
      }

      for (final candidate in candidates) {
        if (!candidate.allowCatalogInsert) {
          continue;
        }
        final alreadyExists =
            _findExistingCatalogMatch(candidate, existingCatalog) != null;
        if (alreadyExists) {
          continue;
        }

        await txn.insert(
          DatabaseHelper.tableDefSup,
          <String, Object?>{
            'type': candidate.catalogType,
            'name': candidate.name,
            'description': candidate.description,
            'Cost': _roundMoney(candidate.cost),
          },
        );
        existingCatalog.add(
          DefSup(
            id: '',
            type: candidate.catalogType,
            name: candidate.name,
            description: candidate.description,
            cost: _roundMoney(candidate.cost),
          ),
        );
        catalogInserted++;
      }
    });

    final result = SupplyPriceSyncResult(
      catalogUpdated: catalogUpdated,
      catalogInserted: catalogInserted,
      suppliesUpdated: suppliesUpdated,
      fertilizerReportUrl: reportUrls.fertilizerUrl,
      pesticideReportUrl: reportUrls.pesticideUrl,
    );

    TransactionLogService.instance.log(
      'Supply prices synced',
      details:
          'catalogUpdated=$catalogUpdated | catalogInserted=$catalogInserted | suppliesUpdated=$suppliesUpdated',
    );

    return result;
  }

  Future<_LatestReportUrls> _fetchLatestReportUrls() async {
    final response = await http.get(
      Uri.parse(_fpaWeeklyPricesUrl),
      headers: _requestHeaders,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Failed to load weekly prices page (${response.statusCode}).',
      );
    }

    final document = html_parser.parse(response.body);
    final seenUrls = <String>{};
    final orderedPdfUrls = <String>[];

    for (final link in document.querySelectorAll('a[href]')) {
      final href = link.attributes['href']?.trim();
      if (href == null || !href.toLowerCase().endsWith('.pdf')) {
        continue;
      }

      final resolved = Uri.parse(_fpaBaseUrl).resolve(href).toString();
      if (seenUrls.add(resolved)) {
        orderedPdfUrls.add(resolved);
      }
    }

    final fertilizerUrl = orderedPdfUrls.firstWhere(
      (url) => url.toUpperCase().contains('WFP-WK'),
      orElse: () => '',
    );
    final pesticideUrl = orderedPdfUrls.firstWhere(
      (url) => url.toLowerCase().contains('pesticide'),
      orElse: () => '',
    );

    if (fertilizerUrl.isEmpty || pesticideUrl.isEmpty) {
      throw StateError('Latest FPA fertilizer and pesticide reports not found.');
    }

    return _LatestReportUrls(
      fertilizerUrl: fertilizerUrl,
      pesticideUrl: pesticideUrl,
    );
  }

  Future<List<_SupplyPriceCandidate>> _fetchFertilizerCandidates(
    String reportUrl,
  ) async {
    final bytes = await _downloadPdfBytes(reportUrl);
    final document = await PdfDocument.openData(
      bytes,
      sourceName: 'latest_fertilizer_prices.pdf',
    );

    try {
      final firstPage = document.pages.isEmpty ? null : document.pages.first;
      if (firstPage == null) {
        return const <_SupplyPriceCandidate>[];
      }

      final rawText = await firstPage.loadText();
      final text = rawText?.fullText ?? '';
      final lines = _splitPdfLines(text);
      final averageLineIndex = lines.indexWhere(
        (line) => line.toUpperCase().startsWith('AVERAGE PRICE'),
      );
      if (averageLineIndex == -1) {
        return const <_SupplyPriceCandidate>[];
      }

      final summaryText = [
        lines[averageLineIndex],
        if (averageLineIndex + 1 < lines.length) lines[averageLineIndex + 1],
      ].join(' ');
      final prices = _extractPriceValues(summaryText);
      if (prices.length < 7) {
        return const <_SupplyPriceCandidate>[];
      }

      const entries = <_FertilizerEntry>[
        _FertilizerEntry(
          sourceName: 'UREA (PRILLED)',
          catalogName: 'UREA(PRILLED)',
          description: '46-0-0',
          aliases: <String>['UREA PRILLED', '46-0-0'],
        ),
        _FertilizerEntry(
          sourceName: 'UREA (GRANULAR)',
          catalogName: 'UREA(GRANULAR)',
          description: '46-0-0',
          aliases: <String>['UREA GRANULAR', '46-0-0'],
        ),
        _FertilizerEntry(
          sourceName: 'AMMOSUL',
          catalogName: 'AMMOSUL',
          description: '21-0-0',
          aliases: <String>['AMMONIUM SULFATE', '21-0-0'],
        ),
        _FertilizerEntry(
          sourceName: 'COMPLETE',
          catalogName: 'COMPLETE',
          description: '14-14-14',
          aliases: <String>['14-14-14'],
        ),
        _FertilizerEntry(
          sourceName: 'AMMOPHOS',
          catalogName: 'AMMOPHOS M',
          description: '16-20-0',
          aliases: <String>['AMMOPHOS', '16-20-0'],
        ),
        _FertilizerEntry(
          sourceName: 'MURIATE OF POTASH',
          catalogName: 'MURIATE OF POTASH',
          description: '0-0-60',
          aliases: <String>['URIATEOF POTASH', '0-0-60'],
        ),
        _FertilizerEntry(
          sourceName: 'DIAMMONIUM PHOSPHATE',
          catalogName: 'DIAMMONIUM PHOSPHATE',
          description: '18-46-0',
          aliases: <String>['18-46-0'],
        ),
      ];

      return List<_SupplyPriceCandidate>.generate(entries.length, (index) {
        final entry = entries[index];
        return _SupplyPriceCandidate(
          name: entry.catalogName,
          catalogType: 'FERTILIZER',
          description: entry.description,
          cost: prices[index],
          aliases: {
            entry.sourceName,
            ...entry.aliases,
          },
          allowCatalogInsert: true,
        );
      });
    } finally {
      document.dispose();
    }
  }

  Future<List<_SupplyPriceCandidate>> _fetchPesticideCandidates(
    String reportUrl,
  ) async {
    final bytes = await _downloadPdfBytes(reportUrl);
    final document = await PdfDocument.openData(
      bytes,
      sourceName: 'latest_pesticide_prices.pdf',
    );

    final candidates = <_SupplyPriceCandidate>[];
    var carrySection = '';

    try {
      for (final page in document.pages) {
        final rawText = await page.loadText();
        final text = rawText?.fullText ?? '';
        if (text.trim().isEmpty) {
          continue;
        }

        final detectedSection = _extractPesticideSection(text);
        if (detectedSection.isNotEmpty) {
          carrySection = detectedSection;
        }
        if (carrySection.isEmpty) {
          continue;
        }

        final blocks = _extractPesticideBlocks(
          lines: _splitPdfLines(text),
          section: carrySection,
        );
        for (final block in blocks) {
          final candidate =
              _candidateFromPesticideBlock(section: carrySection, block: block);
          if (candidate != null) {
            candidates.add(candidate);
          }
        }
      }
    } finally {
      document.dispose();
    }

    return candidates;
  }

  Future<Uint8List> _downloadPdfBytes(String url) async {
    final response = await http.get(Uri.parse(url), headers: _requestHeaders);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Failed to download PDF ($url): ${response.statusCode}');
    }
    return response.bodyBytes;
  }

  List<List<String>> _extractPesticideBlocks({
    required List<String> lines,
    required String section,
  }) {
    final blocks = <List<String>>[];
    List<String>? currentBlock;

    for (final rawLine in lines) {
      final line = _normalizeWhitespace(rawLine);
      if (line.isEmpty) {
        continue;
      }
      if (_isPesticideNoiseLine(line, section: section)) {
        continue;
      }

      if (_looksLikePesticideEntryStart(line)) {
        if (currentBlock != null && currentBlock.isNotEmpty) {
          blocks.add(currentBlock);
        }
        currentBlock = <String>[line];
        continue;
      }

      if (currentBlock != null) {
        currentBlock.add(line);
      }
    }

    if (currentBlock != null && currentBlock.isNotEmpty) {
      blocks.add(currentBlock);
    }

    return blocks;
  }

  _SupplyPriceCandidate? _candidateFromPesticideBlock({
    required String section,
    required List<String> block,
  }) {
    if (block.isEmpty) {
      return null;
    }

    final firstLine = block.first;
    final firstLineTokens = firstLine.split(' ');
    final firstPriceIndex = _firstPriceTokenIndex(firstLineTokens);
    final prePriceTokens = firstPriceIndex == -1
        ? firstLineTokens
        : firstLineTokens.sublist(0, firstPriceIndex);
    final brandStartIndex = _findBrandStartIndex(prePriceTokens);
    if (brandStartIndex == null || brandStartIndex <= 0) {
      return null;
    }

    final activeIngredient =
        _cleanDisplayText(prePriceTokens.sublist(0, brandStartIndex).join(' '));
    final brandName =
        _cleanDisplayText(prePriceTokens.sublist(brandStartIndex).join(' '));
    if (brandName.isEmpty) {
      return null;
    }

    final allText = block.join(' ');
    final prices = _extractPriceValues(allText);
    if (prices.isEmpty) {
      return null;
    }

    return _SupplyPriceCandidate(
      name: brandName,
      catalogType: _catalogTypeForPesticideSection(section),
      description: activeIngredient,
      cost: prices.reduce((sum, value) => sum + value) / prices.length,
      aliases: {
        if (activeIngredient.isNotEmpty) activeIngredient,
        ..._expandNameAliases(brandName),
      },
      allowCatalogInsert: _isConfidentCatalogName(brandName),
    );
  }

  _SupplyPriceCandidate? _findBestCandidateForCatalogItem(
    DefSup item,
    List<_SupplyPriceCandidate> candidates,
  ) {
    final onlyFertilizer = item.type.toUpperCase().contains('FERT');
    _SupplyPriceCandidate? best;
    var bestScore = 0.0;

    for (final candidate in candidates) {
      final eligible = onlyFertilizer
          ? candidate.catalogType == 'FERTILIZER'
          : candidate.catalogType != 'FERTILIZER';
      if (!eligible) {
        continue;
      }

      final score = _candidateScore(
        name: item.name,
        description: item.description,
        candidate: candidate,
      );
      if (score > bestScore) {
        bestScore = score;
        best = candidate;
      }
    }

    return bestScore >= 0.82 ? best : null;
  }

  _SupplyPriceCandidate? _findBestCandidateForSupplyItem(
    Supply item,
    List<_SupplyPriceCandidate> candidates,
  ) {
    _SupplyPriceCandidate? best;
    var bestScore = 0.0;

    for (final candidate in candidates) {
      final score = _candidateScore(
        name: item.name,
        description: item.description,
        candidate: candidate,
      );
      if (score > bestScore) {
        bestScore = score;
        best = candidate;
      }
    }

    return bestScore >= 0.86 ? best : null;
  }

  DefSup? _findExistingCatalogMatch(
    _SupplyPriceCandidate candidate,
    List<DefSup> existingCatalog,
  ) {
    DefSup? best;
    var bestScore = 0.0;

    for (final item in existingCatalog) {
      final score = _candidateScore(
        name: item.name,
        description: item.description,
        candidate: candidate,
      );
      if (score > bestScore) {
        bestScore = score;
        best = item;
      }
    }

    return bestScore >= 0.86 ? best : null;
  }

  double _candidateScore({
    required String name,
    required String description,
    required _SupplyPriceCandidate candidate,
  }) {
    final normalizedName = _normalizedKey(name);
    if (normalizedName.isEmpty) {
      return 0.0;
    }

    final candidateKeys = <String>{
      _normalizedKey(candidate.name),
      ...candidate.aliases.map(_normalizedKey),
    }..removeWhere((value) => value.isEmpty);
    if (candidateKeys.isEmpty) {
      return 0.0;
    }

    var bestScore = 0.0;
    for (final candidateKey in candidateKeys) {
      if (normalizedName == candidateKey) {
        bestScore = math.max(bestScore, 1.0);
      } else if (candidateKey.contains(normalizedName) ||
          normalizedName.contains(candidateKey)) {
        final shorter =
            math.min(normalizedName.length, candidateKey.length).toDouble();
        final longer =
            math.max(normalizedName.length, candidateKey.length).toDouble();
        bestScore = math.max(bestScore, 0.9 + (shorter / longer) * 0.08);
      }

      bestScore = math.max(
        bestScore,
        _levenshteinSimilarity(normalizedName, candidateKey),
      );
      bestScore = math.max(
        bestScore,
        _tokenOverlapScore(normalizedName, candidateKey),
      );
    }

    final normalizedDescription = _normalizedKey(description);
    final candidateDescription = _normalizedKey(candidate.description);
    if (normalizedDescription.isNotEmpty && candidateDescription.isNotEmpty) {
      bestScore = math.max(
        bestScore,
        _tokenOverlapScore(normalizedDescription, candidateDescription) * 0.92,
      );
      bestScore = math.max(
        bestScore,
        _levenshteinSimilarity(normalizedDescription, candidateDescription) *
            0.9,
      );
    }

    return bestScore.clamp(0.0, 1.0);
  }

  List<_SupplyPriceCandidate> _dedupeCandidates(
    List<_SupplyPriceCandidate> items,
  ) {
    final deduped = <String, _SupplyPriceCandidate>{};

    for (final item in items) {
      final key = _normalizedKey(item.name);
      if (key.isEmpty) {
        continue;
      }

      final existing = deduped[key];
      if (existing == null) {
        deduped[key] = item;
        continue;
      }

      final mergedPrice = ((existing.cost * existing.sampleCount) +
              (item.cost * item.sampleCount)) /
          (existing.sampleCount + item.sampleCount);
      deduped[key] = existing.copyWith(
        cost: mergedPrice,
        aliases: {
          ...existing.aliases,
          ...item.aliases,
        },
        allowCatalogInsert:
            existing.allowCatalogInsert || item.allowCatalogInsert,
        sampleCount: existing.sampleCount + item.sampleCount,
      );
    }

    return deduped.values.toList();
  }

  String _extractPesticideSection(String text) {
    final match = RegExp(
      r'PRICES OF PESTICIDE(?:S)? PER REGION - ([A-Z-]+)',
      caseSensitive: false,
    ).firstMatch(text.toUpperCase());
    return match?.group(1)?.trim() ?? '';
  }

  bool _looksLikePesticideEntryStart(String line) {
    final tokens = line.split(' ');
    final firstPriceIndex = _firstPriceTokenIndex(tokens);
    final prePriceTokens =
        firstPriceIndex == -1 ? tokens : tokens.sublist(0, firstPriceIndex);
    final brandStartIndex = _findBrandStartIndex(prePriceTokens);
    return brandStartIndex != null && brandStartIndex > 0;
  }

  int? _findBrandStartIndex(List<String> tokens) {
    if (tokens.length < 2) {
      return null;
    }

    for (var index = 1; index < tokens.length; index++) {
      final token = tokens[index];
      final nextToken = index + 1 < tokens.length ? tokens[index + 1] : '';
      final currentStartsBrand =
          _containsLowercase(token) || _containsLowercase(nextToken);
      final hasIngredientPrefix = tokens
          .take(index)
          .any((value) => _looksLikeIngredientToken(value));
      if (currentStartsBrand && hasIngredientPrefix) {
        return index;
      }
    }
    return null;
  }

  int _firstPriceTokenIndex(List<String> tokens) {
    for (var index = 0; index < tokens.length; index++) {
      if (_looksLikePriceToken(tokens[index])) {
        return index;
      }
    }
    return -1;
  }

  bool _looksLikeIngredientToken(String token) {
    if (token.isEmpty) {
      return false;
    }
    final compact = token.replaceAll(RegExp(r'[^A-Za-z0-9,+/-]'), '');
    if (compact.isEmpty) {
      return false;
    }
    return compact == compact.toUpperCase();
  }

  bool _containsLowercase(String token) {
    return token.contains(RegExp(r'[a-z]'));
  }

  bool _looksLikePriceToken(String token) {
    return RegExp(r'^\*?₱?\s*\d[\d,]*(?:\.\d+)?(?:/[A-Za-z0-9%.-]+)?$')
        .hasMatch(token);
  }

  bool _isPesticideNoiseLine(String line, {required String section}) {
    final upper = line.toUpperCase();
    if (upper == section) {
      return true;
    }

    const prefixes = <String>[
      'ACTIVE INGREDIENT',
      'ACTIVE INGREDIENTS',
      'BRAND NAME',
      'REGIONS',
      'REGION',
      'PRICE (PHP)',
      'PRICE/LITER',
      'PRICE/KG',
      'PRICE/L',
      '*PRICE INDICATED',
      'PREPARED BY',
      'NOTED BY',
      'APPROVED',
      'EXECUTIVE DIRECTOR',
      'SENIOR AGRICULTURIST',
      'ADMINISTRATIVE ASSISTANT',
      'AS OF ',
      'PRICES OF PESTICIDE',
      'PRICES OF PESTICIDES',
    ];

    if (prefixes.any(upper.startsWith)) {
      return true;
    }

    if (RegExp(r'^\d{1,2}[/-]\d{1,2}[/-]\d{2,4}$').hasMatch(upper)) {
      return true;
    }

    if (upper == '(PRICE/LITER)' || upper == '(PRICE/KG)') {
      return true;
    }

    return false;
  }

  List<double> _extractPriceValues(String text) {
    final matches = RegExp(
      r'(?:(?:\*|₱)\s*)?(\d{1,3}(?:,\d{3})*(?:\.\d+)|\d+\.\d+)',
    ).allMatches(text);

    final prices = <double>[];
    for (final match in matches) {
      final raw = match.group(1);
      if (raw == null) {
        continue;
      }
      final value = double.tryParse(raw.replaceAll(',', ''));
      if (value == null || value <= 10) {
        continue;
      }
      prices.add(value);
    }
    return prices;
  }

  List<String> _splitPdfLines(String text) {
    return text
        .split(RegExp(r'[\r\n]+'))
        .map(_normalizeWhitespace)
        .where((line) => line.isNotEmpty)
        .toList();
  }

  String _catalogTypeForPesticideSection(String section) {
    return section == 'HERBICIDES' ? 'HERBICIDE' : 'PESTICIDE';
  }

  Set<String> _expandNameAliases(String value) {
    final aliases = <String>{value};
    final cleaned = value
        .replaceAll('/', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    aliases.add(cleaned);
    aliases.add(cleaned.replaceAll(RegExp(r'\b(?:BOX|SACHET|GAL|L|ML|G)\b'), ''));
    return aliases.map(_cleanDisplayText).where((item) => item.isNotEmpty).toSet();
  }

  bool _isConfidentCatalogName(String name) {
    final tokenCount =
        name.split(' ').where((part) => part.trim().isNotEmpty).length;
    return tokenCount <= 3 || name.contains(RegExp(r'[0-9/]'));
  }

  String _cleanDisplayText(String value) {
    return value
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[^A-Za-z0-9]+|[^A-Za-z0-9]+$'), '')
        .trim();
  }

  String _normalizeWhitespace(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _normalizedKey(String value) {
    return value
        .toUpperCase()
        .replaceAll('0', 'O')
        .replaceAll('1', 'I')
        .replaceAll('5', 'S')
        .replaceAll(RegExp(r'[^A-Z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  double _tokenOverlapScore(String left, String right) {
    final leftTokens = left.split(' ').where((token) => token.isNotEmpty).toSet();
    final rightTokens =
        right.split(' ').where((token) => token.isNotEmpty).toSet();
    if (leftTokens.isEmpty || rightTokens.isEmpty) {
      return 0.0;
    }

    final common = leftTokens.intersection(rightTokens).length.toDouble();
    final total = math.max(leftTokens.length, rightTokens.length).toDouble();
    return common / total;
  }

  double _levenshteinSimilarity(String left, String right) {
    if (left.isEmpty || right.isEmpty) {
      return 0.0;
    }
    if (left == right) {
      return 1.0;
    }

    final leftLength = left.length;
    final rightLength = right.length;
    final matrix = List<List<int>>.generate(
      leftLength + 1,
      (i) => List<int>.filled(rightLength + 1, 0),
    );

    for (var i = 0; i <= leftLength; i++) {
      matrix[i][0] = i;
    }
    for (var j = 0; j <= rightLength; j++) {
      matrix[0][j] = j;
    }

    for (var i = 1; i <= leftLength; i++) {
      for (var j = 1; j <= rightLength; j++) {
        final substitutionCost = left[i - 1] == right[j - 1] ? 0 : 1;
        matrix[i][j] = math.min(
          math.min(
            matrix[i - 1][j] + 1,
            matrix[i][j - 1] + 1,
          ),
          matrix[i - 1][j - 1] + substitutionCost,
        );
      }
    }

    final distance = matrix[leftLength][rightLength].toDouble();
    final maxLength = math.max(leftLength, rightLength).toDouble();
    return 1.0 - (distance / maxLength);
  }

  bool _sameMoney(double left, double right) {
    return (left - right).abs() < 0.01;
  }

  double _roundMoney(double value) {
    return double.parse(value.toStringAsFixed(2));
  }

  Map<String, String> get _requestHeaders => const <String, String>{
        'User-Agent': 'RCAMARii/1.0 (+https://nomad.local)',
      };
}

class SupplyPriceSyncResult {
  final int catalogUpdated;
  final int catalogInserted;
  final int suppliesUpdated;
  final String? fertilizerReportUrl;
  final String? pesticideReportUrl;

  const SupplyPriceSyncResult({
    required this.catalogUpdated,
    required this.catalogInserted,
    required this.suppliesUpdated,
    this.fertilizerReportUrl,
    this.pesticideReportUrl,
  });
}

class _LatestReportUrls {
  final String fertilizerUrl;
  final String pesticideUrl;

  const _LatestReportUrls({
    required this.fertilizerUrl,
    required this.pesticideUrl,
  });
}

class _SupplyPriceCandidate {
  final String name;
  final String catalogType;
  final String description;
  final double cost;
  final Set<String> aliases;
  final bool allowCatalogInsert;
  final int sampleCount;

  const _SupplyPriceCandidate({
    required this.name,
    required this.catalogType,
    required this.description,
    required this.cost,
    required this.aliases,
    required this.allowCatalogInsert,
    this.sampleCount = 1,
  });

  _SupplyPriceCandidate copyWith({
    String? name,
    String? catalogType,
    String? description,
    double? cost,
    Set<String>? aliases,
    bool? allowCatalogInsert,
    int? sampleCount,
  }) {
    return _SupplyPriceCandidate(
      name: name ?? this.name,
      catalogType: catalogType ?? this.catalogType,
      description: description ?? this.description,
      cost: cost ?? this.cost,
      aliases: aliases ?? this.aliases,
      allowCatalogInsert: allowCatalogInsert ?? this.allowCatalogInsert,
      sampleCount: sampleCount ?? this.sampleCount,
    );
  }
}

class _FertilizerEntry {
  final String sourceName;
  final String catalogName;
  final String description;
  final List<String> aliases;

  const _FertilizerEntry({
    required this.sourceName,
    required this.catalogName,
    required this.description,
    required this.aliases,
  });
}
