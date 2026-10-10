import 'package:oncuidar/nucleo/datos/base_datos_segura.dart';
import 'package:oncuidar/nucleo/datos/rutas_api.dart';
import 'package:oncuidar/nucleo/sesion/servicio_sesion.dart';
import 'package:oncuidar/nucleo/sincronizacion/cola_escrituras.dart';

/// Datos personales del cuidador y cambios de sus correos.
class RepositorioCuidador {
  RepositorioCuidador(this.bd);

  final BaseDatosSegura bd;

  ServicioSesion get _sesion =>
      bd.sesion ?? (throw StateError('No user authenticated'));

  /// Guarda al cuidador cifrando los datos personales.
  Future<void> crearCuidador(Map<String, dynamic> datos) async {
    final cuerpo = <String, dynamic>{};
    final correoRespaldo = datos['correo_respaldo'] as String?;
    if (correoRespaldo != null && correoRespaldo.isNotEmpty) {
      bd.ponerCifrado(
        cuerpo,
        'correo_respaldo_cifrado',
        await bd.cifrado.cifrar(bd.uid, correoRespaldo.trim().toLowerCase()),
      );
    }
    await bd.reemplazarPorCifrado(
      cuerpo,
      plano: datos['nombre'] as String?,
      cifrado: 'nombre_cifrado',
    );
    await bd.reemplazarPorCifrado(
      cuerpo,
      plano: datos['telefono'] as String?,
      cifrado: 'telefono_cifrado',
    );
    await bd.reemplazarPorCifrado(
      cuerpo,
      plano: datos['relacion'] as String?,
      cifrado: 'relacion_cifrada',
    );
    await bd.reemplazarPorCifrado(
      cuerpo,
      plano: datos['direccion'] as String?,
      cifrado: 'direccion_cifrada',
    );
    cuerpo['versionEncriptacion'] = 2;
    await bd.escribir(
      RutasApi.cuidador,
      cuerpo,
      operacion: OperacionPendiente.guardar,
    );
  }

  /// Devuelve los datos visibles del cuidador con sus campos personales ya
  /// descifrados. El correo se devuelve en texto plano por ser el
  /// identificador de acceso.
  ///
  /// `correoRespaldo` es el correo de respaldo descifrado (solo existe si se
  /// registró vía la app; el servidor solo guarda el hash del confirmado).
  Future<Map<String, dynamic>> obtenerCuidador() async {
    final json = await bd.leerConCache(RutasApi.cuidador);
    return _mapearCuidador((json as Map).cast<String, dynamic>());
  }

  Stream<Map<String, dynamic>?> cuidadorEnTiempoReal() {
    if (!bd.tieneIdentidad()) return Stream.value(null);
    return bd.flujo<Map<String, dynamic>?>(
      RutasApi.cuidador,
      vacio: <String, dynamic>{},
      convertir: (json) async {
        final datos = (json as Map).cast<String, dynamic>();
        if (datos.isEmpty) return null;
        try {
          return await _mapearCuidador(datos);
        } catch (_) {
          return null;
        }
      },
    );
  }

  Future<Map<String, dynamic>> _mapearCuidador(
    Map<String, dynamic> datos,
  ) async {
    return {
      'correo': datos['correo'] as String?,
      'nombre': await bd.descifrarCampo(datos, 'nombre_cifrado'),
      'telefono': await bd.descifrarCampo(datos, 'telefono_cifrado'),
      'relacion': await bd.descifrarCampo(datos, 'relacion_cifrada'),
      'direccion': await bd.descifrarCampo(datos, 'direccion_cifrada'),
      'correoRespaldo': await bd.descifrarCampo(
        datos,
        'correo_respaldo_cifrado',
      ),
      'respaldoPendiente': datos['respaldoPendiente'] == true,
      'correoVerificado': datos['correoVerificado'] == true,
      'correoRespaldoVerificado': datos['correoRespaldoVerificado'] == true,
      'pendienteCorreo': datos['pendienteCorreo'] as String?,
    };
  }

  /// Actualiza los datos personales del cuidador cifrando solo los campos
  /// no nulos. Un campo vacío (teléfono/parentesco) se borra; el nombre se
  /// trata igual que el resto para mantener el contrato simple.
  Future<void> actualizarCuidador({
    String? nombre,
    String? telefono,
    String? relacion,
    String? direccion,
  }) async {
    final cuerpo = <String, dynamic>{};
    if (nombre != null) {
      await bd.reemplazarPorCifrado(
        cuerpo,
        plano: nombre,
        cifrado: 'nombre_cifrado',
      );
    }
    if (telefono != null) {
      await bd.reemplazarPorCifrado(
        cuerpo,
        plano: telefono,
        cifrado: 'telefono_cifrado',
      );
    }
    if (relacion != null) {
      await bd.reemplazarPorCifrado(
        cuerpo,
        plano: relacion,
        cifrado: 'relacion_cifrada',
      );
    }
    if (direccion != null) {
      await bd.reemplazarPorCifrado(
        cuerpo,
        plano: direccion,
        cifrado: 'direccion_cifrada',
      );
    }
    if (cuerpo.isEmpty) return;
    await bd.escribir(
      RutasApi.cuidador,
      cuerpo,
      operacion: OperacionPendiente.guardar,
    );
  }

  // ── Cambio de correo ──

  /// El servidor envía un enlace al correo nuevo; el cambio se aplica al confirmarlo.
  Future<void> cambiarCorreoPrincipal({
    required String contrasena,
    required String nuevoCorreo,
  }) async {
    await _sesion.cambiarCorreo(contrasena, nuevoCorreo);
    bd.notificarCambio();
  }

  /// Pide el respaldo nuevo (queda pendiente hasta confirmar el enlace) y guarda su copia cifrada.
  Future<void> cambiarCorreoRespaldo({
    required String contrasena,
    required String nuevoCorreo,
  }) async {
    await _sesion.verificarContrasena(contrasena);
    final normalizado = nuevoCorreo.trim().toLowerCase();
    await _sesion.pedirCorreoRespaldo(normalizado);
    final cuerpo = <String, dynamic>{};
    bd.ponerCifrado(
      cuerpo,
      'correo_respaldo_cifrado',
      await bd.cifrado.cifrar(bd.uid, normalizado),
    );
    await bd.escribir(
      RutasApi.cuidador,
      cuerpo,
      operacion: OperacionPendiente.guardar,
    );
    bd.notificarCambio();
  }

  /// Reenvía el enlace para verificar el correo principal.
  Future<void> reenviarVerificacion() => _sesion.reenviarVerificacion();
}
