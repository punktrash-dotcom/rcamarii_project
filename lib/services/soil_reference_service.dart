import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../models/farm_model.dart';

@immutable
class SoilReferenceLink {
  const SoilReferenceLink({
    required this.code,
    required this.label,
    required this.detailUrl,
  });

  final String code;
  final String label;
  final String detailUrl;
}

@immutable
class SoilReferenceLookupResult {
  const SoilReferenceLookupResult({
    required this.sourceLabel,
    required this.lookupScope,
    required this.links,
    required this.exactNpkAvailable,
    required this.note,
  });

  final String sourceLabel;
  final String lookupScope;
  final List<SoilReferenceLink> links;
  final bool exactNpkAvailable;
  final String note;
}

class SoilReferenceService {
  static const String _mapIndexUrl = 'https://www.bswm.da.gov.ph/bswm-maps/';

  static Future<SoilReferenceLookupResult> lookupForFarm(Farm farm) async {
    final cropKey = _cropKey(farm.type);
    if (cropKey == null) {
      return SoilReferenceLookupResult(
        sourceLabel: 'BSWM official reference',
        lookupScope: '${farm.province} / ${farm.type}',
        links: const [],
        exactNpkAvailable: false,
        note:
            'Official BSWM provincial nutrient maps are publicly indexed for rice and corn. For this crop, use a lab soil test or manual values.',
      );
    }

    final response = await http.get(Uri.parse(_mapIndexUrl));
    if (response.statusCode != 200) {
      throw StateError(
        'Failed to load BSWM maps index (${response.statusCode}).',
      );
    }

    final provinceToken = _slugifyProvince(farm.province);
    final document = html_parser.parse(response.body);
    final rows = document.querySelectorAll('tr');
    final links = <SoilReferenceLink>[];

    for (final row in rows) {
      final cells = row.querySelectorAll('td');
      final anchor = row.querySelector('a[href*="/map/"]');
      if (cells.length < 2 || anchor == null) {
        continue;
      }

      final code = cells.first.text.trim();
      final label = cells[1].text.trim();
      final lowerCode = code.toLowerCase();
      if (!lowerCode.contains(provinceToken) || !lowerCode.contains(cropKey)) {
        continue;
      }

      links.add(
        SoilReferenceLink(
          code: code,
          label: label,
          detailUrl: anchor.attributes['href'] ?? '',
        ),
      );
    }

    links.sort(
        (left, right) => _priority(left.code).compareTo(_priority(right.code)));

    return SoilReferenceLookupResult(
      sourceLabel: 'BSWM official reference',
      lookupScope: '${farm.province} / ${cropKey.toUpperCase()}',
      links: links,
      exactNpkAvailable: false,
      note: links.isEmpty
          ? 'No public BSWM provincial map entries were found for this province and crop. Enter actual soil-test values manually.'
          : 'These are official provincial BSWM reference maps. They help guide nutrient decisions, but they are not a farm-specific exact NPK lab result.',
    );
  }

  static String? _cropKey(String cropType) {
    final normalized = cropType.trim().toLowerCase();
    if (normalized.contains('rice') || normalized.contains('palay')) {
      return 'rice';
    }
    if (normalized.contains('corn') || normalized.contains('maize')) {
      return 'corn';
    }
    return null;
  }

  static String _slugifyProvince(String province) {
    final normalized = province.trim().toLowerCase();
    return normalized.replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(
          RegExp(r'^-|-$'),
          '',
        );
  }

  static int _priority(String code) {
    final value = code.toLowerCase();
    if (value.contains('fgm')) {
      return 0;
    }
    if (value.contains('nsm-n')) {
      return 1;
    }
    if (value.contains('nsm-p')) {
      return 2;
    }
    if (value.contains('nsm-k')) {
      return 3;
    }
    if (value.contains('soil-ph')) {
      return 4;
    }
    return 10;
  }
}
