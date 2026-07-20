import 'package:cloud_firestore/cloud_firestore.dart';

import 'alert_level.dart';
import 'vital_signs.dart';
import 'symptom_entry.dart';

class DailyRecord {
  final String id;
  final String patientId;
  final DateTime date;
  final DateTime createdAt;
  final String recordType; // "programado" | "extra"
  final VitalSigns? vitalSigns;
  final List<SymptomEntry> symptoms;
  final String? generalNotes;
  final AlertLevel alertLevel;
  final String? alertMessage;

  DailyRecord({
    required this.id,
    required this.patientId,
    required this.date,
    required this.createdAt,
    required this.recordType,
    this.vitalSigns,
    required this.symptoms,
    this.generalNotes,
    required this.alertLevel,
    this.alertMessage,
  });

  Map<String, dynamic> toMap() => {
        'date': date,
        'createdAt': createdAt,
        'recordType': recordType,
        'vitalSigns': vitalSigns?.toMap(),
        'symptoms': symptoms.map((s) => s.toMap()).toList(),
        'generalNotes': generalNotes,
        'alertLevel': alertLevel.name,
        'alertMessage': alertMessage,
      };

  factory DailyRecord.fromMap(String id, Map<String, dynamic> map) =>
      DailyRecord(
        id: id,
        patientId: map['patientId'] as String? ?? '',
        date: _parseDateTime(map['date']),
        createdAt: _parseDateTime(map['createdAt']),
        recordType: map['recordType'] as String? ?? 'programado',
        vitalSigns: map['vitalSigns'] != null
            ? VitalSigns.fromMap(map['vitalSigns'] as Map<String, dynamic>)
            : null,
        symptoms: (map['symptoms'] as List<dynamic>?)
                ?.map((s) => SymptomEntry.fromMap(s as Map<String, dynamic>))
                .toList() ??
            [],
        generalNotes: map['generalNotes'] as String?,
        alertLevel: AlertLevel.values.firstWhere(
          (e) => e.name == map['alertLevel'],
          orElse: () => AlertLevel.normal,
        ),
        alertMessage: map['alertMessage'] as String?,
      );

  static DateTime _parseDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
  }
}
