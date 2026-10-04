import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:oncuidar/caracteristicas/configuracion/dominio/tipo_letra.dart';

/// Tipografía vigente de la app. Se lee en cada build, igual que [Paleta].
class Tipografia {
  static TipoLetra _actual = TipoLetra.sistema;

  static TipoLetra get actual => _actual;

  /// Cambia la tipografía; devuelve true si cambió.
  static bool usar(TipoLetra tipo) {
    if (_actual == tipo) return false;
    _actual = tipo;
    return true;
  }

  static bool get _esApple =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  /// Estilo de texto con la tipografía vigente.
  static TextStyle estilo({
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    Color? color,
    double? height,
    double? letterSpacing,
    List<Shadow>? shadows,
  }) => estiloDe(
    _actual,
    fontSize: fontSize,
    fontWeight: fontWeight,
    fontStyle: fontStyle,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
    shadows: shadows,
  );

  /// Estilo con una tipografía concreta (para las vistas previas).
  static TextStyle estiloDe(
    TipoLetra tipo, {
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    Color? color,
    double? height,
    double? letterSpacing,
    List<Shadow>? shadows,
  }) {
    switch (tipo) {
      case TipoLetra.nunito:
        return GoogleFonts.nunito(
          fontSize: fontSize,
          fontWeight: fontWeight,
          fontStyle: fontStyle,
          color: color,
          height: height,
          letterSpacing: letterSpacing,
          shadows: shadows,
        );
      case TipoLetra.estiloIos when !_esApple:
        return GoogleFonts.inter(
          fontSize: fontSize,
          fontWeight: fontWeight,
          fontStyle: fontStyle,
          color: color,
          height: height,
          letterSpacing: letterSpacing,
          shadows: shadows,
        );
      case TipoLetra.sistema:
      case TipoLetra.estiloIos:
        // Sin familia: Flutter usa la del sistema (San Francisco en iPhone).
        return TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          fontStyle: fontStyle,
          color: color,
          height: height,
          letterSpacing: letterSpacing,
          shadows: shadows,
        );
    }
  }

  /// Tema de texto con la tipografía vigente y los colores indicados.
  static TextTheme temaDeTexto({required bool oscuro, required Color color}) {
    final base = Typography.material2021(platform: defaultTargetPlatform);
    final plano = oscuro ? base.white : base.black;
    final TextTheme conFuente = switch (_actual) {
      TipoLetra.nunito => GoogleFonts.nunitoTextTheme(plano),
      TipoLetra.estiloIos when !_esApple => GoogleFonts.interTextTheme(plano),
      _ => plano,
    };
    return conFuente.apply(bodyColor: color, displayColor: color);
  }
}
