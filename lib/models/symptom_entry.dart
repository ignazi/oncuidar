class SymptomEntry {
  final String name;
  final int intensity; // 1 a 10
  final String? notes;

  SymptomEntry({required this.name, required this.intensity, this.notes});

  Map<String, dynamic> toMap() => {
        'name': name,
        'intensity': intensity,
        'notes': notes,
      };

  factory SymptomEntry.fromMap(Map<String, dynamic> map) => SymptomEntry(
        name: map['name'] as String,
        intensity: map['intensity'] as int,
        notes: map['notes'] as String?,
      );
}
