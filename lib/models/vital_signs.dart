class VitalSigns {
  final double? temperature;
  final int? heartRate;
  final int? oxygenSaturation;
  final int? respiratoryRate;

  VitalSigns({
    this.temperature,
    this.heartRate,
    this.oxygenSaturation,
    this.respiratoryRate,
  });

  Map<String, dynamic> toMap() => {
        'temperature': temperature,
        'heartRate': heartRate,
        'oxygenSaturation': oxygenSaturation,
        'respiratoryRate': respiratoryRate,
      };

  factory VitalSigns.fromMap(Map<String, dynamic> map) => VitalSigns(
        temperature: (map['temperature'] as num?)?.toDouble(),
        heartRate: map['heartRate'] as int?,
        oxygenSaturation: map['oxygenSaturation'] as int?,
        respiratoryRate: map['respiratoryRate'] as int?,
      );
}
