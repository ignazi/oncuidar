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
        date: map['date'] is DateTime
            ? map['date'] as DateTime
            : DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now(),
        createdAt: map['createdAt'] is DateTime
            ? map['createdAt'] as DateTime
            : DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
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
}
