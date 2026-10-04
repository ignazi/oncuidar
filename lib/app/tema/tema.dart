import 'package:flutter/material.dart';
import 'package:oncuidar/app/tema/paleta.dart';
import 'package:oncuidar/app/tema/tipografia.dart';

/// Transición de pantalla fluida estilo WhatsApp.
class _TransicionWhatsApp extends PageTransitionsBuilder {
  const _TransicionWhatsApp();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curva = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curva,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.10, 0),
          end: Offset.zero,
        ).animate(curva),
        child: child,
      ),
    );
  }
}

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
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _TransicionWhatsApp(),
          TargetPlatform.iOS: _TransicionWhatsApp(),
          TargetPlatform.windows: _TransicionWhatsApp(),
          TargetPlatform.macOS: _TransicionWhatsApp(),
          TargetPlatform.linux: _TransicionWhatsApp(),
        },
      ),
      textTheme: Tipografia.temaDeTexto(
        oscuro: Paleta.esOscura,
        color: Paleta.textoPrincipal,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Paleta.doradoPrincipal,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: Tipografia.estilo(
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
          textStyle: Tipografia.estilo(
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
