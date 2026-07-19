class OrientationRule {
  final String id;
  final String category;
  final String subQuestion;
  final String answer;
  final String alertLevel; // "green" | "yellow" | "red"
  final List<String> tags;

  OrientationRule({
    required this.id,
    required this.category,
    required this.subQuestion,
    required this.answer,
    required this.alertLevel,
    required this.tags,
  });

  Map<String, dynamic> toMap() => {
        'category': category,
        'subQuestion': subQuestion,
        'answer': answer,
        'alertLevel': alertLevel,
        'tags': tags,
      };

  factory OrientationRule.fromMap(String id, Map<String, dynamic> map) =>
      OrientationRule(
        id: id,
        category: map['category'] as String? ?? '',
        subQuestion: map['subQuestion'] as String? ?? '',
        answer: map['answer'] as String? ?? '',
        alertLevel: map['alertLevel'] as String? ?? 'green',
        tags: (map['tags'] as List<dynamic>?)
                ?.map((t) => t.toString())
                .toList() ??
            [],
      );
}
