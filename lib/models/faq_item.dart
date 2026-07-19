class FaqItem {
  final String id;
  final String question;
  final String answer;
  final String category;

  const FaqItem({
    required this.id,
    required this.question,
    required this.answer,
    required this.category,
  });

  Map<String, dynamic> toMap() => {
        'question': question,
        'answer': answer,
        'category': category,
      };

  factory FaqItem.fromMap(String id, Map<String, dynamic> map) => FaqItem(
        id: id,
        question: map['question'] as String? ?? '',
        answer: map['answer'] as String? ?? '',
        category: map['category'] as String? ?? '',
      );
}
