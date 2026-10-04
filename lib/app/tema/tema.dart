import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:oncuidar/app/tema/paleta.dart';

class Tema {
  /// Tema armado con los colores vigentes de [Paleta] (claros u oscuros).
  static ThemeData obtener() {
    final brillo = Paleta.esOscura ? Brightness.dark : Brightness.light;
    final esquema = ColorScheme.fromSeed(
      brightness: brillo,
      seedColor: Paleta.doradoPrincipal,
      primary: Paleta.doradoPrincipal,
      secondary: Paleta.doradoMedio,
      surface: Paleta.tarjeta,
      onSurface: Paleta.textoPrincipal,
      error: Paleta.error,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brillo,
      colorScheme: esquema,
      scaffoldBackgroundColor: Paleta.crema,
      dialogTheme: DialogThemeData(backgroundColor: Paleta.tarjeta),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Paleta.tarjeta,
        modalBackgroundColor: Paleta.tarjeta,
      ),
      dividerColor: Paleta.bordeTarjeta,
      // Android: transición de Android 14 (la pantalla entra y la anterior se
      // desliza y se apaga). iPhone: la de iOS, con gesto de volver. El fondo
      // evita el destello negro entre dos pantallas.
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(
            backgroundColor: Paleta.crema,
          ),
          TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: const CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(
            backgroundColor: Paleta.crema,
          ),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(
            backgroundColor: Paleta.crema,
          ),
        },
      ),
      textTheme: GoogleFonts.nunitoTextTheme().apply(
        bodyColor: Paleta.textoPrincipal,
        displayColor: Paleta.textoPrincipal,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Paleta.doradoPrincipal,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.nunito(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Paleta.doradoPrincipal,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 54),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Paleta.fondoEntrada,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}
