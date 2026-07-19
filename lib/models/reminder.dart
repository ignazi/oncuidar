import 'package:cloud_firestore/cloud_firestore.dart';

class Reminder {
  final String id;
  final String patientId;
  final String type; // "medicamento" | "medicion" | "cita" | "otro"
  final String title;
  final String? description;
  final DateTime dateTime;
  final List<String>? repeatDays; // ["lun","mar","mie",...]
  final bool isActive;
  final DateTime createdAt;

  Reminder({
    required this.id,
    required this.patientId,
    required this.type,
    required this.title,
    this.description,
    required this.dateTime,
    this.repeatDays,
    required this.isActive,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'type': type,
        'title': title,
        'description': description,
        'dateTime': dateTime.toIso8601String(),
        'repeatDays': repeatDays,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Reminder.fromMap(String id, Map<String, dynamic> map) => Reminder(
        id: id,
        patientId: map['patientId'] as String? ?? '',
        type: map['type'] as String? ?? 'otro',
        title: map['title'] as String? ?? '',
        description: map['description'] as String?,
        dateTime: _parseDateTime(map['dateTime']),
        repeatDays: (map['repeatDays'] as List<dynamic>?)
                ?.map((d) => d.toString())
                .toList() ??
            [],
        isActive: map['isActive'] as bool? ?? true,
        createdAt: _parseDateTime(map['createdAt']),
      );

  static DateTime _parseDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
  }
}
