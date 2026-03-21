import 'package:flutter/material.dart';

@immutable
class KnowledgeQaItem {
  final int id;
  final String topic;
  final String question;
  final String answer;
  final String tags;
  final String lang;
  final String category;
  final int? iconCodepoint;

  const KnowledgeQaItem({
    required this.id,
    required this.topic,
    required this.question,
    required this.answer,
    required this.tags,
    required this.lang,
    required this.category,
    this.iconCodepoint,
  });

  factory KnowledgeQaItem.fromMap(Map<String, dynamic> map) {
    return KnowledgeQaItem(
      id: (map['QaID'] as num?)?.toInt() ??
          (map['id'] as num?)?.toInt() ??
          (map['qa_id'] as num?)?.toInt() ??
          0,
      topic: map['topic']?.toString() ?? '',
      question: map['question']?.toString() ?? '',
      answer: map['answer']?.toString() ?? '',
      tags: map['tags']?.toString() ?? '',
      lang: map['lang']?.toString() ?? '',
      category: map['category']?.toString() ?? 'General',
      iconCodepoint: (map['IconCodepoint'] as num?)?.toInt() ??
          (map['iconCodepoint'] as num?)?.toInt(),
    );
  }
}
