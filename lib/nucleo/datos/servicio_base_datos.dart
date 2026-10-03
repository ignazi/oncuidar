import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:oncuidar/nucleo/cifrado/servicio_cifrado.dart';
import 'package:oncuidar/nucleo/conectividad/servicio_conectividad.dart';
import 'package:oncuidar/nucleo/datos/base_datos_segura.dart';
import 'package:oncuidar/nucleo/sincronizacion/cola_escrituras.dart';

class ServicioBaseDatos {
  ServicioBaseDatos({
    FirebaseFirestore? base,
    FirebaseAuth? auth,
    String? uidPrueba,
    required ServicioCifrado cifrado,
    ColaEscrituras? cola,
    ServicioConectividad? conectividad,
  }) : bd = BaseDatosSegura(
         base: base,
         auth: auth,
         uidPrueba: uidPrueba,
         cifrado: cifrado,
         cola: cola,
         conectividad: conectividad,
       );

  /// Usa una base ya creada (la del proveedor de infraestructura).
  ServicioBaseDatos.sobre(this.bd);

  final BaseDatosSegura bd;

  Future<void> verificarEscrituraDisponible() =>
      bd.verificarEscrituraDisponible();

  Future<void> aplicarEscrituraPendiente(EscrituraPendiente escritura) =>
      bd.aplicarEscrituraPendiente(escritura);
}
