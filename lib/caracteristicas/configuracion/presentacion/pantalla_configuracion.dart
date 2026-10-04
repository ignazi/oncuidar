import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:oncuidar/app/tema/paleta.dart';
import 'package:oncuidar/caracteristicas/configuracion/dominio/escala_texto.dart';
import 'package:oncuidar/caracteristicas/configuracion/presentacion/proveedores_configuracion.dart';
import 'package:oncuidar/caracteristicas/recordatorios/presentacion/controlador_recordatorios.dart';
import 'package:oncuidar/compartido/widgets/encabezado_gradiente.dart';

/// Ajustes de la app: tamaño de texto y silencio de los avisos.
class PantallaConfiguracion extends ConsumerStatefulWidget {
  const PantallaConfiguracion({super.key});

  @override
  ConsumerState<PantallaConfiguracion> createState() =>
      _PantallaConfiguracionState();
}

class _PantallaConfiguracionState extends ConsumerState<PantallaConfiguracion> {
  bool _silenciadas = false;

  @override
  void initState() {
    super.initState();
    unawaited(_cargarSilencio());
  }

  Future<void> _cargarSilencio() async {
    final guardado = await ControladorRecordatorios.silencioGuardado();
    if (mounted) setState(() => _silenciadas = guardado);
  }

  Future<void> _alternarSilencio(bool silenciar) async {
    setState(() => _silenciadas = silenciar);
    await ref.read(controladorRecordatoriosProvider).fijarSilencio(silenciar);
  }

  @override
  Widget build(BuildContext context) {
    final escala = ref.watch(escalaTextoProvider);
    return Scaffold(
      backgroundColor: Paleta.crema,
      body: Column(
        children: [
          EncabezadoGradiente(
            titulo: 'Configuración',
            subtitulo: 'Ajusta la app a tu gusto',
            mostrarRetroceso: true,
            iconoRetroceso: Icons.arrow_back_rounded,
            alRetroceder: () => context.pop(),
            tamanoTitulo: 20,
            alto: 100,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                const _TituloSeccion('Tamaño del texto'),
                _Tarjeta(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final opcion in EscalaTexto.values)
                            _OpcionEscala(
                              escala: opcion,
                              activa: opcion == escala,
                              alPulsar: () => unawaited(
                                ref
                                    .read(escalaTextoProvider.notifier)
                                    .fijar(opcion),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Así se verá el texto en toda la app.',
                        key: const Key('vistaPreviaTexto'),
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          color: Paleta.textoPrincipal,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const _TituloSeccion('Notificaciones'),
                _Tarjeta(
                  child: SwitchListTile(
                    key: const Key('interruptorSilencio'),
                    contentPadding: EdgeInsets.zero,
                    activeThumbColor: Paleta.doradoPrincipal,
                    title: Text(
                      'Silenciar avisos',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Paleta.textoPrincipal,
                      ),
                    ),
                    subtitle: Text(
                      'Los recordatorios no te avisarán, pero se conservan.',
                      style: GoogleFonts.nunito(
                        fontSize: 12.5,
                        color: Paleta.textoSecundario,
                      ),
                    ),
                    value: _silenciadas,
                    onChanged: (valor) => unawaited(_alternarSilencio(valor)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TituloSeccion extends StatelessWidget {
  const _TituloSeccion(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        texto,
        style: GoogleFonts.nunito(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: Paleta.textoSecundario,
        ),
      ),
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Material (no DecoratedBox) para que el SwitchListTile pinte sobre ella.
    return Material(
      color: Paleta.tarjeta,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Paleta.bordeTarjeta),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}

class _OpcionEscala extends StatelessWidget {
  const _OpcionEscala({
    required this.escala,
    required this.activa,
    required this.alPulsar,
  });

  final EscalaTexto escala;
  final bool activa;
  final VoidCallback alPulsar;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: Key('escala_${escala.name}'),
      onTap: alPulsar,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: activa ? Paleta.doradoPrincipal : Paleta.doradoClaro,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          escala.etiqueta,
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: activa ? Colors.white : Paleta.doradoOscuro,
          ),
        ),
      ),
    );
  }
}
