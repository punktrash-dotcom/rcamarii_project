import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nmd/services/knowledge_qa_service.dart';

void main() {
  test('inferCategory maps soil and water topics correctly', () {
    expect(
      KnowledgeQaService.inferCategory(
        topic: 'Soil',
        tags: 'ph, acidity, lime',
      ),
      'Soil',
    );
    expect(
      KnowledgeQaService.inferCategory(
        topic: 'Pagpapatubig',
        tags: 'tubig, patubig, baha',
      ),
      'Water',
    );
  });

  test('inferCategory maps fertilizer and pesticide topics to chemicals', () {
    expect(
      KnowledgeQaService.inferCategory(
        topic: 'Abono',
        tags: 'urea, npk, potash',
      ),
      'Chemicals',
    );
    expect(
      KnowledgeQaService.inferCategory(
        topic: 'Pestisidyo',
        tags: 'borer, lason',
      ),
      'Chemicals',
    );
  });

  test('iconFromCodepoint rebuilds material icons from stored values', () {
    final icon = KnowledgeQaService.iconFromCodepoint(
      Icons.water_drop_rounded.codePoint,
    );

    expect(icon.codePoint, Icons.water_drop_rounded.codePoint);
    expect(icon.fontFamily, 'MaterialIcons');
  });
}
