class RiceKnowledgeService {
  static final List<_RiceInsight> _insights = [
    _RiceInsight(
      keywords: ['statistics', 'philippine', 'farmers', 'production'],
      summary:
          'Rice fuels the Philippines: 2.5M farmers, shrinking average size (~1.4 ha), 19–20M MT rosters, and the Rice Granary remains Central Luzon plus Cagayan Valley and Western Visayas.',
      suggestion:
          'RCAMARii suggests pairing NSIC Rc 216/Rc 160 seeds with irrigated lowland fields to keep those staples in high-mechanization lanes.',
    ),
    _RiceInsight(
      keywords: ['seed', 'land preparation', 'transplanting', 'direct seeding'],
      summary:
          'The 10-step cycle starts with seed choice, plow/levelling, then transplanting or direct seeding into puddled rows.',
      suggestion:
          'Allocate early labor to nursery management, keep paddies level (hand tractor/carabao) for uniform depth, and use ALT wet/dry with 5–10 cm of water whenever possible.',
    ),
    _RiceInsight(
      keywords: ['water', 'irrigation', 'awd', 'management'],
      summary:
          'Alternate wetting and drying (AWD) trims water use while still meeting the 5–10 cm flooding depth; irrigated lowlands now support 2–3 crops a year.',
      suggestion:
          'Track pump hours, drain every 7–10 days, and re-flood just before the grand growth stage so roots oxygenate without hurting tillers.',
    ),
    _RiceInsight(
      keywords: ['fertilizer', 'pests', 'tungro', 'planthopper'],
      summary:
          'Apply fertilizers at critical stages, scout for Tungro or Brown Planthopper, and rely on IRRI/PhilRice resourced insect monitoring.',
      suggestion:
          'The Rice Competitiveness Enhancement Fund (RCEF) delivers certified seeds and fertilizer vouchers—use them, pair foliar sprays with Trichogramma cards, and always time Nitrogen to avoid encouraging pests.',
    ),
    _RiceInsight(
      keywords: ['profitability', 'subsidy', 'RCEF', 'RFFA', 'cost'],
      summary:
          '2024 averages: ₱95,906 gross, ₱59,695 input cost, ₱36,211 net per hectare. Labor (~₱29,235), seeds (~₱4,316), and farmgate price (₱23.48/kg) determine profit.',
      suggestion:
          'RCAMARii notes RFFA cash aid (~₱5–7k), mechanization grants, and APP loans reduce farmgate volatility—log every peso to make subsidies work harder.',
    ),
  ];

  static const List<String> quickTips = [
    'Levelled paddies and 5–10 cm of water keep tillers cozy; drain for 3–4 days to save water before a re-flood just ahead of grand growth.',
    'Use NSIC Rc 216 or Rc 160 from RCEF seed packets and follow the recommended row spacing to maximize tiller counts.',
    'AWD cycles and mechanical wet bed preparation allow 2–3 crops per year—budget pump hours accordingly.',
    'Cut rice at 20–25% moisture, thresh promptly, and dry to 14% before storage to minimize losses.',
    'Capture RFFA cash or APP loan data in the ledger so RCAMARii can recommend how to reinvest it into fertilizer or diesel.',
  ];

  static String answer(String prompt) {
    final lower = prompt.toLowerCase();
    final matches =
        _insights.where((insight) => insight.matches(lower)).take(2).toList();
    if (matches.isEmpty) {
      return 'Rice needs resilient varieties, carefully managed water (AWD), and disciplined fertilization—it thrives under RCAMARii tips like certified seeds, timely Nitrogen, and tracking RCEF/RFFA support.';
    }
    final buffer = StringBuffer();
    for (final insight in matches) {
      buffer.write('${insight.summary} ${insight.suggestion} ');
    }
    return buffer.toString().trim();
  }

  static bool isRelevant(String prompt) {
    final lower = prompt.toLowerCase();
    return lower.contains('rice') ||
        lower.contains('palay') ||
        lower.contains('tungro') ||
        lower.contains('planthopper') ||
        lower.contains('rcef');
  }

  static String randomTip() {
    if (quickTips.isEmpty) return '';
    final index = DateTime.now().millisecondsSinceEpoch % quickTips.length;
    return quickTips[index];
  }
}

class _RiceInsight {
  final List<String> keywords;
  final String summary;
  final String suggestion;

  const _RiceInsight({
    required this.keywords,
    required this.summary,
    required this.suggestion,
  });

  bool matches(String prompt) {
    return keywords.any((kw) => prompt.contains(kw));
  }
}
