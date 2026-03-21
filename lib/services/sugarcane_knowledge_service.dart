class SugarcaneKnowledgeService {
  static final List<_SugarcaneInsight> _insights = [
    _SugarcaneInsight(
      keywords: ['climate', 'temperature', 'soil', 'water'],
      summary:
          'Sugarcane loves 20-33°C, well-drained loamy soils with pH 5.5-8.5, and 1,500–2,500 mm of moisture per year.',
      suggestion:
          'RCAMARii recommends deep plowing (30–45 cm), 10–15 t/ha of compost, and ridges/furrows to keep the coverage even and prevent waterlogging.',
    ),
    _SugarcaneInsight(
      keywords: ['setts', 'planting', 'spacing', 'methods'],
      summary:
          'Use 30–45 cm setts with 2–3 buds spaced 75–150 cm; choose flat, furrow, or trench planting depending on drainage.',
      suggestion:
          'Keep the furrows just deep enough (8–25 cm) so young shoots see moisture but avoid drowning the eye, and cover cuttings right after band-placing fertilizer.',
    ),
    _SugarcaneInsight(
      keywords: ['fertilizer', 'nitrogen', 'phosphorus', 'potassium', 'npk'],
      summary:
          'Split NPK: apply all P and a third of K at planting, split Nitrogen (bulk between 30–90 days), and shift to Potassium for grand growth then stop Nitrogen 2 months before harvest.',
      suggestion:
          'RCAMARii advises band placement to cut losses, add press mud or FYM for organics, and avoid late Nitrogen so the cane stores sucrose instead of lush leaves.',
    ),
    _SugarcaneInsight(
      keywords: ['irrigation', 'water management', 'drip', 'drying'],
      summary:
          'Drip irrigation saves 40–70% of water and enables fertigation; stress the crop 2–4 weeks before harvest to concentrate sugar.',
      suggestion:
          'Pair the grand growth phase with the highest water demand (~1,000 mm) and keep moisture steady until the drying-off window.',
    ),
    _SugarcaneInsight(
      keywords: ['pest', 'disease', 'borer', 'red rot', 'smut'],
      summary:
          'The crop is vulnerable to borers, woolly aphids, grubs, red rot, and smut; biological checks like Trichogramma cards cut chemical use.',
      suggestion:
          'Monitor for deadhearts, rotate contact sprays, and keep the canopy breathable by detrashing before humidity spikes.',
    ),
    _SugarcaneInsight(
      keywords: ['ratoon', 'mechanical', 'shaving', 'stubble'],
      summary:
          'Mechanical stubble shaving 5 cm below ground within 10–15 days after harvest encourages uniform ratoons and can bump yields 28–43%.',
      suggestion:
          'RCAMARii recommends off-barring, trash mulching, and fertigation during the wake-up phase to unlock the full 100+ ton/ha potential.',
    ),
  ];

  static const List<String> quickTips = [
    'Band placement fertilizer can lift yields 15–19% versus broadcasting; cover each row with soil right after application.',
    'Drip irrigation plus fertigation saves 40–70% water and keeps nutrients available when the cane is in grand growth.',
    'Use press mud or 15 t/ha of FYM to reduce chemical NPK inputs by 25% while improving soil structure.',
    'Apply Trichogramma cards early to cut borer pressure, and keep the canopy open through detrashing before humid weather.',
    'Shave stubble 5 cm below grade within two weeks after harvest; the ratoon will sprout deeper roots for better sugar recovery.',
  ];

  static String answer(String prompt) {
    final lower = prompt.toLowerCase();
    final matches =
        _insights.where((insight) => insight.matches(lower)).take(2).toList();
    if (matches.isEmpty) {
      return 'Sugarcane needs tropical heat, 1,500–2,500 mm water, and disciplined NPK timing; focus on deep plowing, vigorous ratooning, and integrated pest monitoring with the RCAMARii tips.';
    }
    final buffer = StringBuffer();
    for (final insight in matches) {
      buffer.write('${insight.summary} ${insight.suggestion} ');
    }
    return buffer.toString().trim();
  }

  static bool isRelevant(String prompt) {
    final lower = prompt.toLowerCase();
    return lower.contains('sugarcane') ||
        lower.contains('sugar cane') ||
        lower.contains('cane') ||
        lower.contains('ratoon');
  }

  static String randomTip() {
    if (quickTips.isEmpty) return '';
    final index = DateTime.now().millisecondsSinceEpoch % quickTips.length;
    return quickTips[index];
  }
}

class _SugarcaneInsight {
  final List<String> keywords;
  final String summary;
  final String suggestion;

  const _SugarcaneInsight({
    required this.keywords,
    required this.summary,
    required this.suggestion,
  });

  bool matches(String prompt) {
    return keywords.any((kw) => prompt.contains(kw));
  }
}
