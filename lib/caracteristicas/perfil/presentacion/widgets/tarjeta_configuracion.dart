import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:oncuidar/app/tema/paleta.dart';

/// Acceso a la configuración de la app desde el perfil.
class TarjetaConfiguracion extends StatelessWidget {
  const TarjetaConfiguracion({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Paleta.tarjeta,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: const Key('abrirConfiguracion'),
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push('/configuracion'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Paleta.bordeTarjeta),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Paleta.doradoClaro,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  size: 20,
                  color: Paleta.doradoOscuro,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Configuración de la app',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Paleta.textoPrincipal,
                      ),
                    ),
                    Text(
                      'Tamaño del texto y avisos',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: Paleta.textoSecundario,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Paleta.textoSecundario,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
