class UserChecklist {
  final String id;
  final String title;
  final List<String> items;
  final List<int> checkedIndices;
  final DateTime createdAt;

  UserChecklist({
    required this.id,
    required this.title,
    required this.items,
    this.checkedIndices = const [],
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'title': title,
        'items': items,
        'checkedIndices': checkedIndices,
        'createdAt': createdAt.toIso8601String(),
      };

  factory UserChecklist.fromMap(String id, Map<String, dynamic> map) =>
      UserChecklist(
        id: id,
        title: map['title'] as String? ?? '',
        items: (map['items'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        checkedIndices: (map['checkedIndices'] as List<dynamic>?)
                ?.map((e) => (e as num).toInt())
                .toList() ??
            [],
        createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
            DateTime.now(),
      );
}
