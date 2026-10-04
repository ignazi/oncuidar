import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:oncuidar/app/tema/paleta.dart';
import 'package:oncuidar/caracteristicas/configuracion/dominio/escala_texto.dart';
import 'package:oncuidar/caracteristicas/configuracion/dominio/modo_tema.dart';
import 'package:oncuidar/caracteristicas/configuracion/presentacion/proveedores_configuracion.dart';
import 'package:oncuidar/caracteristicas/recordatorios/presentacion/controlador_recordatorios.dart';

/// Ajustes de la app dentro de «Mi perfil»: apariencia, texto y avisos.
class SeccionConfiguracion extends ConsumerStatefulWidget {
  const SeccionConfiguracion({super.key});

  @override
  ConsumerState<SeccionConfiguracion> createState() =>
      _SeccionConfiguracionState();
}

class _SeccionConfiguracionState extends ConsumerState<SeccionConfiguracion> {
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
    final modo = ref.watch(modoTemaProvider);
    return Column(
      key: const Key('seccionConfiguracion'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Configuración de la app',
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Paleta.textoPrincipal,
            ),
          ),
        ),
        const _TituloSeccion('Apariencia'),
        _Tarjeta(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final opcion in ModoTema.values)
                    _Opcion(
                      clave: Key('modo_${opcion.name}'),
                      etiqueta: opcion.etiqueta,
                      activa: opcion == modo,
                      alPulsar: () => unawaited(
                        ref.read(modoTemaProvider.notifier).fijar(opcion),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Automático sigue el modo claro u oscuro del teléfono.',
                style: GoogleFonts.nunito(
                  fontSize: 12.5,
                  color: Paleta.textoSecundario,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
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
                    _Opcion(
                      clave: Key('escala_${opcion.name}'),
                      etiqueta: opcion.etiqueta,
                      activa: opcion == escala,
                      alPulsar: () => unawaited(
                        ref.read(escalaTextoProvider.notifier).fijar(opcion),
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
        side: BorderSide(color: Paleta.bordeTarjeta),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}

class _Opcion extends StatelessWidget {
  const _Opcion({
    required this.clave,
    required this.etiqueta,
    required this.activa,
    required this.alPulsar,
  });

  final Key clave;
  final String etiqueta;
  final bool activa;
  final VoidCallback alPulsar;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: clave,
      onTap: alPulsar,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: activa ? Paleta.doradoPrincipal : Paleta.doradoClaro,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          etiqueta,
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
