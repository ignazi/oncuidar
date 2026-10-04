import 'package:flutter/material.dart';
import 'package:oncuidar/app/tema/paleta.dart';
import 'package:oncuidar/app/tema/tipografia.dart';

/// Pie con el logo, nombre y versión de la app.
class PieVersion extends StatelessWidget {
  const PieVersion({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 40,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                // El logo conserva el aro del modo claro también en oscuro.
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: coloresClaros.doradoClaro),
                boxShadow: [
                  BoxShadow(
                    color: coloresClaros.doradoOscuro.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Image.asset('assets/images/OnCuidar.png'),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'OnCuidar',
              style: Tipografia.estilo(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Paleta.textoTerciario,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Center(
            child: Text(
              'versión 1.0.0',
              style: Tipografia.estilo(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Paleta.textoAyuda,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
