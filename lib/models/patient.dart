class Patient {
  final String id;
  final String caregiverId;
  final String fullName;
  final int? age;
  final DateTime? birthDate;
  final String diagnosis;
  final DateTime? diagnosisDate;
  final String? treatmentPhase;
  final String? healthCenterName;
  final String? healthCenterAddress;
  final String? healthCenterPhone;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final int maxRecordsPerDay;
  final bool notificationsEnabled;
  final DateTime createdAt;

  Patient({
    required this.id,
    required this.caregiverId,
    required this.fullName,
    this.age,
    this.birthDate,
    required this.diagnosis,
    this.diagnosisDate,
    this.treatmentPhase,
    this.healthCenterName,
    this.healthCenterAddress,
    this.healthCenterPhone,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.maxRecordsPerDay = 3,
    this.notificationsEnabled = true,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'fullName': fullName,
        'age': age,
        'birthDate': birthDate,
        'diagnosis': diagnosis,
        'diagnosisDate': diagnosisDate,
        'treatmentPhase': treatmentPhase,
        'healthCenterName': healthCenterName,
        'healthCenterAddress': healthCenterAddress,
        'healthCenterPhone': healthCenterPhone,
        'emergencyContactName': emergencyContactName,
        'emergencyContactPhone': emergencyContactPhone,
        'notificationsEnabled': notificationsEnabled,
        'maxRecordsPerDay': maxRecordsPerDay,
        'createdAt': createdAt,
      };

  factory Patient.fromMap(String id, Map<String, dynamic> map) => Patient(
        id: id,
        caregiverId: map['caregiverId'] as String? ?? '',
        fullName: map['fullName'] as String? ?? '',
        age: map['age'] as int?,
        birthDate: map['birthDate'] is DateTime
            ? map['birthDate'] as DateTime
            : DateTime.tryParse(map['birthDate']?.toString() ?? ''),
        diagnosis: map['diagnosis'] as String? ?? '',
        diagnosisDate: map['diagnosisDate'] is DateTime
            ? map['diagnosisDate'] as DateTime
            : DateTime.tryParse(map['diagnosisDate']?.toString() ?? ''),
        treatmentPhase: map['treatmentPhase'] as String?,
        healthCenterName: map['healthCenterName'] as String?,
        healthCenterAddress: map['healthCenterAddress'] as String?,
        healthCenterPhone: map['healthCenterPhone'] as String?,
        emergencyContactName: map['emergencyContactName'] as String?,
        emergencyContactPhone: map['emergencyContactPhone'] as String?,
        notificationsEnabled: map['notificationsEnabled'] as bool? ?? true,
        maxRecordsPerDay: map['maxRecordsPerDay'] as int? ?? 3,
        createdAt: map['createdAt'] is DateTime
            ? map['createdAt'] as DateTime
            : DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      );
}
