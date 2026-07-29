import 'package:flutter/material.dart';

class SymptomEntry {
  final String name;
  final int intensity; // 0 a 10 (ESAS)
  final String? notes;

  SymptomEntry({required this.name, required this.intensity, this.notes});

  Color get color => colorFor(intensity);

  static Color colorFor(int intensity) {
    return switch (intensity) {
      0 => const Color(0xFF6BA368),
      1 || 2 => const Color(0xFF8BC34A),
      3 || 4 => const Color(0xFFE8A820),
      5 || 6 => const Color(0xFFEF8A17),
      7 || 8 => const Color(0xFFD9534F),
      9 || 10 => const Color(0xFFB71C1C),
      _ => const Color(0xFF9A8060),
    };
  }

  String get label => labelFor(intensity);

  static String labelFor(int intensity) {
    return switch (intensity) {
      0 => 'Mínimo síntoma',
      1 || 2 => 'Leve',
      3 || 4 => 'Moderado',
      5 || 6 => 'Intenso',
      7 || 8 => 'Severo',
      9 || 10 => 'Insoportable',
      _ => '',
    };
  }

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
