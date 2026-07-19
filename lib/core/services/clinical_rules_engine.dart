import '../../models/vital_signs.dart';
import '../../models/symptom_entry.dart';
import '../../models/alert_level.dart';

class AlertEvaluation {
  final AlertLevel level;
  final List<String> messages;
  AlertEvaluation({required this.level, required this.messages});
}

class ClinicalRulesEngine {
  static AlertEvaluation evaluate(
      VitalSigns? vitals, List<SymptomEntry> symptoms) {
    AlertLevel level = AlertLevel.normal;
    List<String> messages = [];

    // ── Evaluación de signos vitales ──
    if (vitals != null) {
      if (vitals.temperature != null) {
        final temp = vitals.temperature!;
        if (temp > 39.5) {
          level = AlertLevel.critico;
          messages.add('Fiebre alta ($temp°C)');
        } else if (temp > 38.5) {
          if (level != AlertLevel.critico) level = AlertLevel.alerta;
          messages.add('Fiebre moderada ($temp°C)');
        }
      }

      if (vitals.oxygenSaturation != null) {
        final o2 = vitals.oxygenSaturation!;
        if (o2 < 90) {
          level = AlertLevel.critico;
          messages.add('Saturación de O₂ muy baja ($o2%)');
        } else if (o2 < 92) {
          if (level != AlertLevel.critico) level = AlertLevel.alerta;
          messages.add('Saturación de O₂ baja ($o2%)');
        }
      }
    }

    // ── Evaluación de síntomas (escala 1-10) ──
    int criticalSymptoms = symptoms.where((s) => s.intensity >= 8).length;
    int severeSymptoms =
        symptoms.where((s) => s.intensity >= 5 && s.intensity < 8).length;
    int totalSymptoms = symptoms.length;

    if (criticalSymptoms >= 2 ||
        (criticalSymptoms >= 1 && severeSymptoms >= 2)) {
      level = AlertLevel.critico;
      messages.add('$criticalSymptoms síntomas en nivel crítico');
    } else if (severeSymptoms >= 3 || totalSymptoms >= 5) {
      if (level != AlertLevel.critico) level = AlertLevel.alerta;
      messages
          .add('$severeSymptoms síntomas severos, $totalSymptoms en total');
    } else if (totalSymptoms > 0 && level == AlertLevel.normal) {
      messages.add('$totalSymptoms síntomas leves registrados');
    }

    return AlertEvaluation(
      level: level,
      messages: messages.isEmpty ? ['Sin síntomas preocupantes'] : messages,
    );
  }
}
