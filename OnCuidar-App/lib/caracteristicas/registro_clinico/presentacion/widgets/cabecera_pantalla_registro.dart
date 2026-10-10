import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:oncuidar/app/tema/paleta.dart';
import 'package:oncuidar/compartido/widgets/buscador.dart';
import 'package:oncuidar/compartido/widgets/encabezado_gradiente.dart';

/// Cabecera de la pantalla de registro clínico con acción de historial.
class CabeceraRegistro extends StatelessWidget {
  const CabeceraRegistro({
    super.key,
    required this.esEdicion,
    this.onVerHistorial,
  });

  final bool esEdicion;

  /// Invocado al pulsar "Ver historial", nulo en modo edición.
  final VoidCallback? onVerHistorial;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: EncabezadoGradiente(
        titulo: esEdicion ? 'Editar registro' : 'Registro clínico',
        subtitulo: esEdicion
            ? 'Actualiza signos y síntomas'
            : 'Registra el cuidado',
        logo: const AssetImage('assets/images/OnCuidar.png'),
        tamanoTitulo: 20,
        alTocarLogo: () => context.go('/dashboard'),
        accionDerecha: !esEdicion
            ? BotonCircular(
                clave: const Key('botonVerHistorial'),
                tooltip: 'Ver historial',
                alTocar: onVerHistorial ?? () {},
                // El mismo ícono que Historial tiene en el panel de inicio.
                hijo: Icon(Icons.history, color: Paleta.doradoOscuro, size: 22),
              )
            : null,
      ),
    );
  }
}
