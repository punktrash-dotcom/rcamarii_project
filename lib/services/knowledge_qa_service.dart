import 'package:flutter/material.dart';

import '../models/knowledge_qa_model.dart';
import 'database_helper.dart';

class KnowledgeQaService {
  static const String defaultCategory = 'General';

  static const Map<String, IconData> categoryIcons = {
    'Soil': Icons.landscape_rounded,
    'Water': Icons.water_drop_rounded,
    'Chemicals': Icons.science_rounded,
    'Planting': Icons.spa_rounded,
    'Harvest': Icons.agriculture_rounded,
    defaultCategory: Icons.auto_stories_rounded,
  };
  static final Map<int, IconData> _iconsByCodepoint = {
    for (final entry in categoryIcons.entries)
      entry.value.codePoint: entry.value,
  };

  static String inferCategory({
    required String topic,
    required String tags,
  }) {
    final combined = '${topic.toLowerCase()} ${tags.toLowerCase()}';
    if (_containsAny(combined, const [
      'soil',
      'lupa',
      'duta',
      'ph',
      'lime',
      'acidity',
      'asid',
    ])) {
      return 'Soil';
    }
    if (_containsAny(combined, const [
      'water',
      'irrigation',
      'tubig',
      'patubig',
      'bunyag',
      'drought',
    ])) {
      return 'Water';
    }
    if (_containsAny(combined, const [
      'fertilizer',
      'abono',
      'herbicide',
      'herbisidyo',
      'pesticide',
      'pestisidyo',
      'foliar',
      'chemical',
      'lason',
      'potash',
      'urea',
    ])) {
      return 'Chemicals';
    }
    if (_containsAny(combined, const [
      'planting',
      'pagtatanim',
      'pagtanom',
      'sett',
      'cutting',
      'patubas',
    ])) {
      return 'Planting';
    }
    if (_containsAny(combined, const [
      'harvest',
      'pag-ani',
      'pag-aani',
      'ratoon',
      'stubble',
      'ani',
    ])) {
      return 'Harvest';
    }
    return defaultCategory;
  }

  static bool _containsAny(String source, List<String> values) {
    for (final value in values) {
      if (source.contains(value)) {
        return true;
      }
    }
    return false;
  }

  static IconData iconFromCodepoint(int? iconCodepoint) {
    return _iconsByCodepoint[iconCodepoint] ?? categoryIcons[defaultCategory]!;
  }

  Future<List<KnowledgeQaItem>> loadQaItems() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery('''
      SELECT
        qa.QaID,
        qa.topic,
        qa.question,
        qa.answer,
        qa.tags,
        qa.lang,
        qa.category,
        icons.IconCodepoint
      FROM ${DatabaseHelper.tableQaTable} qa
      LEFT JOIN ${DatabaseHelper.tableQaCategoryIcons} icons
        ON icons.Category = qa.category
      ORDER BY
        CASE qa.lang
          WHEN 'en' THEN 0
          WHEN 'tl' THEN 1
          WHEN 'hil' THEN 2
          ELSE 3
        END,
        qa.topic ASC,
        qa.question ASC
    ''');

    return rows.map(KnowledgeQaItem.fromMap).toList();
  }
}
