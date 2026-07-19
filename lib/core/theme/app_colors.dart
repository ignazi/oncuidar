import 'package:flutter/material.dart';

class AppColors {
  // ══════════════════════════════════════
  // PRIMARIOS — Dorado / Crema
  // ══════════════════════════════════════
  static const Color goldPrimary = Color(0xFFD99A16);
  static const Color goldMid = Color(0xFFE8A820);
  static const Color goldLight = Color(0xFFFFF0C2);
  static const Color goldDark = Color(0xFFC08808);
  static const Color goldDeep = Color(0xFF9A6405);
  static const Color cream = Color(0xFFFFFBF5);
  static const Color creamDark = Color(0xFFF5EDE0);
  static const Color warmWhite = Color(0xFFFFFDF8);
  static const Color creamCard = Color(0xFFFFFAF0);
  static const Color goldLightest = Color(0xFFFFF4D0);

  // ══════════════════════════════════════
  // GRADIENTES — Header dorado
  // ══════════════════════════════════════
  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment(-0.6, -0.8),
    end: Alignment(1.0, 1.0),
    colors: [
      Color(0xFFC08808),
      Color(0xFFE8A820),
      Color(0xFFF5C842),
    ],
  );

  // ══════════════════════════════════════
  // SECUNDARIOS — Naranjo suave / Verde azulado
  // ══════════════════════════════════════
  static const Color softOrange = Color(0xFFF07830);
  static const Color tealSoft = Color(0xFF4EC4D4);

  // ══════════════════════════════════════
  // SEMAFORIZACIÓN CLÍNICA
  // ══════════════════════════════════════
  static const Color alertGreen = Color(0xFF10B981);
  static const Color alertGreenBg = Color(0xFFECFDF5);
  static const Color alertYellow = Color(0xFFF59E0B);
  static const Color alertYellowBg = Color(0xFFFFFBEB);
  static const Color alertRed = Color(0xFFEF4444);
  static const Color alertRedBg = Color(0xFFFEF2F2);

  // ══════════════════════════════════════
  // NEUTROS — Tonos cálidos marrón
  // ══════════════════════════════════════
  static const Color textPrimary = Color(0xFF2C1A00);
  static const Color textSecondary = Color(0xFF9A8060);
  static const Color textTertiary = Color(0xFF8A5A05);
  static const Color textHint = Color(0xFFB8954A);
  static const Color divider = Color(0xFFE0D5C0); // Neutral cálido
  static const Color dividerLight = Color(0x1DE8A820); // 12% opacity dorado
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color cardBgWarm = Color(0xFFFFFBF0);
  static const Color inputBg = Color(0xFFFFF8F0);
  static const Color screenBg = Color(0xFFF5EDE0);
  static const Color borderCard = Color(0x33E8A820); // 20% opacity
  static const Color borderCardLight = Color(0x1AE8A820); // 10% opacity

  // ══════════════════════════════════════
  // ESTADOS
  // ══════════════════════════════════════
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);
  static const Color info = Color(0xFF3B82F6);
}
