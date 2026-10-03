# OnCuidar — Historias de Usuario (guía definitiva)

Documento de requisitos funcionales de la aplicación móvil OnCuidar, redactado como historias de usuario según la práctica ágil reconocida en la literatura, organizado en épicas y sprints, y verificado criterio por criterio contra el código y las pruebas al 3 de octubre de 2026.

**Contenido:** 9 épicas · 21 historias · 88 criterios de aceptación · 99 puntos de historia (referenciales) · 3 sprints.

Este documento reemplaza a las versiones anteriores de las historias (`HISTORIAS_USUARIO.md`, V2 y V3) y al diagnóstico de pendientes. Es la única referencia vigente de los requisitos.

---

## 1. Fundamento metodológico

### 1.1 Qué es una historia de usuario

Una historia de usuario describe una funcionalidad desde la perspectiva de quien la usa y del valor que obtiene. Su plantilla canónica, popularizada por Cohn (2004), tiene tres partes: *rol*, *medio* y *fin*:

> **Como** ⟨rol⟩, **quiero** ⟨medio⟩, **para** ⟨fin⟩.

Jeffries (2001) resume su ciclo de vida en las «tres C»: la **tarjeta** (*card*) que da forma duradera a la historia, la **conversación** (*conversation*) donde se detalla con los interesados y la **confirmación** (*confirmation*), es decir, las pruebas que demuestran que se cumplió. En este documento la tarjeta es el enunciado y la confirmación son los criterios de aceptación.

### 1.2 Criterios de calidad aplicados

**Calidad de cada historia.** Se usó el marco *Quality User Story* (QUS) de Lucassen et al. (2016), que define 13 criterios (Tabla 1 del artículo). Cada historia de este documento se revisó contra ellos:

| Tipo | Criterio | Definición (Lucassen et al., 2016) | Cómo se aplicó aquí |
| ---- | -------- | ---------------------------------- | ------------------- |
| Sintáctico | *Well-formed* (bien formada) | Incluye al menos un rol y un medio | Todas usan «Como… quiero… para…» |
| Sintáctico | *Atomic* (atómica) | Expresa un requisito de exactamente una funcionalidad | Cada historia cubre una sola **meta del usuario**; las variantes de esa meta (crear, editar, eliminar) son criterios de aceptación, no historias aparte |
| Sintáctico | *Minimal* (mínima) | Solo contiene rol, medio y fin | Las notas técnicas van en «Evidencia», fuera del enunciado |
| Semántico | *Conceptually sound* (conceptualmente sólida) | El medio expresa una funcionalidad y el fin una justificación | El «para» siempre da la razón, no repite el «quiero» |
| Semántico | *Problem-oriented* (orientada al problema) | Especifica el problema, no la solución | No se nombran pantallas ni tecnologías en el enunciado |
| Semántico | *Unambiguous* (sin ambigüedad) | Evita términos que admitan varias interpretaciones | Se fijó un glosario (sección 1.4) |
| Semántico | *Conflict-free* (sin conflictos) | No contradice a otra historia | Revisión cruzada entre historias que tocan un mismo dato |
| Pragmático | *Full sentence* (oración completa) | Se lee como una oración completa | Redacción en oraciones completas |
| Pragmático | *Estimable* | No es un requisito demasiado grande para planificar | Ninguna supera 8 puntos, lo que cabe en un sprint |
| Pragmático | *Unique* (única) | Sin duplicados | Cada funcionalidad aparece una sola vez |
| Pragmático | *Uniform* (uniforme) | Todas usan la misma plantilla | Misma plantilla y misma estructura de ficha |
| Pragmático | *Independent* (independiente) | Sin dependencias inherentes de otras | Las dependencias se declaran en la ficha |
| Pragmático | *Complete* (completa) | El conjunto forma una aplicación completa, sin pasos faltantes | Toda historia que edita o elimina datos incluye también cómo se crean |

**Calidad en el conjunto de la épica.** Se aplicó INVEST (Wake, 2003): *Independent, Negotiable, Valuable, Estimable, Small, Testable*.

> **Decisión de granularidad.** Lucassen et al. (2016) piden que una historia exprese «exactamente una funcionalidad». Aquí se interpreta «funcionalidad» como una meta completa del usuario (por ejemplo, «gestionar mis pacientes») y no como cada operación suelta. Con ello se evitan decenas de historias diminutas. A cambio, algunas historias superan los 5 puntos; por eso el tope se fijó en 8, lo que todavía cabe en un sprint (criterios *Small* y *Estimable*).

> La revisión contra QUS se hizo de forma manual. No se ejecutó la herramienta AQUSA descrita en el artículo.

### 1.3 Criterios de aceptación: dos versiones

Cada criterio se presenta en dos redacciones equivalentes:

- **En palabras simples:** una oración directa, pensada para leer rápido y para conversar con la contraparte de Enfermería.
- **Formal (Dado / Cuando / Entonces):** el escenario verificable que propone North (2006), pensado para derivar pruebas automáticas.

> **Dado** un contexto inicial, **cuando** ocurre un evento, **entonces** se obtiene un resultado observable.

Cada criterio lleva un identificador (por ejemplo `CA-08.3` es el tercer criterio de la HU-08) que sirve para citarlo en pruebas, informes y revisiones.

### 1.4 Glosario y convenciones

- **Rol único.** La aplicación tiene un solo tipo de usuario: el **cuidador**, persona que atiende a uno o más pacientes. El paciente no usa la aplicación: es el sujeto de los datos. Las tareas internas (cifrar, sincronizar) se expresan siempre como un beneficio observable para el cuidador, no como un rol «sistema».
- **Paciente activo:** el paciente seleccionado en ese momento; la información clínica se muestra y se guarda siempre para él.
- **Registro clínico:** anotación de signos vitales, síntomas y observaciones. Puede ser *programado* (cuenta para un máximo diario) o *extra*.
- **Intensidad de un síntoma:** valor de 0 a 10 con cinco categorías: 0 sin síntoma, 1 a 3 leve, 4 a 6 moderado, 7 a 9 severo y 10 insoportable.
- **Nivel de alerta:** resultado de evaluar un registro clínico: normal, alerta o crítico.
- **Sin conexión:** el teléfono no tiene acceso a internet.
- **Estados de una historia:**
  - ✅ **Hecha:** el código cumple todos sus criterios y cada criterio tiene al menos una prueba automática.
  - 🟡 **Implementada, con pruebas pendientes:** el código cumple, pero algún criterio no tiene prueba automática o depende del teléfono real. La ficha indica cuáles.
  - 🔴 **Con defecto conocido:** algún criterio no se cumple hoy. La ficha indica cuál.
- **Prioridad:** Crítica, Alta, Media o Baja, según su impacto en el uso clínico diario.
- **Puntos:** estimación relativa del esfuerzo. Son referenciales.

### 1.5 Definición de hecho

Una historia se considera hecha solo si cumple todo lo siguiente:

1. Cada criterio de aceptación está implementado, no parcialmente.
2. Tiene pruebas automáticas que pasan; la evidencia se cita en la ficha.
3. El análisis estático no reporta errores y la suite de pruebas completa pasa.
4. Todo dato sensible nuevo se guarda cifrado y toda escritura clínica declara su paciente.

**Verificación al 3-oct-2026 (tras el refactor por capas):** `flutter analyze` sin errores ni avisos · `flutter test` **400/400** · reglas de Firestore **19/19** contra el emulador. Además, cada criterio de este documento se contrastó con el código y las pruebas; los resultados están en las fichas y en la sección 8.

---

## 2. Sprints y calendario

El desarrollo se organiza en tres sprints. Cada uno termina con una versión instalable (APK) que se revisa con la contraparte de Enfermería. El calendario es el del informe de título.

| Sprint | Periodo | Foco | Historias | Puntos | Estado al 3-oct-2026 |
| ------ | ------- | ---- | --------- | ------ | -------------------- |
| 1 | 26 ago – 15 sep 2026 | Flujo principal: acceso, cifrado, pacientes, registro clínico e historial | HU-01 a HU-10 | 43 | ✅ Terminado |
| 2 | 16 sep – 20 oct 2026 | Rutina del cuidador: informes, panel, orientación, recordatorios y biblioteca | HU-11 a HU-19 | 43 | ▶ En curso (semana 3 de 5) |
| 3 | 21 oct – 13 nov 2026 | Integración: datos por paciente y funcionamiento sin conexión | HU-20 y HU-21 | 13 | ⏳ Planificado; su alcance ya está implementado |
| **Total** | 26 ago – 13 nov 2026 | | **21 historias** | **99** | |

**Avance real.** El alcance de las cinco semanas del sprint 2 quedó implementado por adelantado (commits del 20 y 22 de septiembre) y el alcance del sprint 3 se adelantó el 30 de septiembre. Los defectos conocidos se corrigieron y las pruebas pendientes se escribieron el 3 de octubre (sección 8). Lo que resta antes de cerrar el sprint 2 es validar en dispositivo el modo sin conexión (HU-21) y ejecutar el plan de certificación (sección 5).

### 2.1 Semanas del sprint 2

El informe fija las fechas de cada sprint y reparte el trabajo del sprint 2 en cinco semanas. Las fechas de cada semana se calcularon contando siete días desde el inicio del sprint.

| Semana | Fechas | Funcionalidad | Historias |
| ------ | ------ | ------------- | --------- |
| 1 | 16 – 22 sep | Panel principal y exportación del historial a PDF y Excel | HU-12, HU-11 |
| 2 | 23 – 29 sep | Biblioteca educativa con materiales descargables | HU-17, HU-18 |
| 3 | 30 sep – 6 oct | Videos, guías, infografías y contenido sin conexión | HU-19 |
| 4 | 7 – 13 oct | Asistente de orientación, preguntas frecuentes y conversaciones | HU-13, HU-14 |
| 5 | 14 – 20 oct | Recordatorios, notificaciones locales y conexión final de rutas | HU-15, HU-16 |

---

## 3. Organización

| Épica | Historias | Puntos | Sprint |
| ----- | --------- | ------ | ------ |
| E1. Cuenta y acceso | HU-01 a HU-04 | 17 | 1 |
| E2. Seguridad y privacidad | HU-05 | 5 | 1 |
| E3. Pacientes | HU-06 y HU-07 | 8 | 1 |
| E4. Registro y seguimiento clínico | HU-08 a HU-10 | 13 | 1 |
| E5. Informes | HU-11 | 6 | 2 |
| E6. Panel y orientación | HU-12 a HU-14 | 15 | 2 |
| E7. Recordatorios | HU-15 y HU-16 | 8 | 2 |
| E8. Biblioteca educativa | HU-17 a HU-19 | 14 | 2 |
| E9. Integridad y continuidad de los datos | HU-20 y HU-21 | 13 | 3 |
| **Total** | **21** | **99** | |

### 3.1 Estado de las historias

| Estado | Historias |
| ------ | --------- |
| ✅ Hecha | HU-01 a HU-20 |
| 🟡 Implementada, falta validar en dispositivo | HU-21 |
| 🔴 Con defecto conocido | — |

### 3.2 Equivalencia con la numeración anterior

El informe de título usa la numeración de la primera versión de las historias (30 historias en tres sprints), que no coincide con la de este documento. Las pruebas ya no siguen ninguna numeración: están ordenadas igual que el código (`test/caracteristicas/<funcionalidad>/…`), y cada ficha las cita en su campo «Evidencia». Para cruzar con el informe, use esta tabla.

| Este documento | Numeración anterior (informe) |
| -------------- | -------------------------------------------------- |
| HU-01 Conocer la aplicación | HU-01 |
| HU-02 Crear mi cuenta | HU-02 |
| HU-03 Iniciar sesión y recuperar el acceso | HU-03 |
| HU-04 Gestionar mi perfil y mis correos | HU-05 |
| HU-05 Proteger mis datos con cifrado | HU-04 |
| HU-06 Gestionar mis pacientes | HU-06 |
| HU-07 Elegir el paciente activo | HU-07 |
| HU-08 Registrar signos vitales y síntomas | HU-09 |
| HU-09 Consultar el historial | HU-10 |
| HU-10 Corregir o eliminar registros del día | HU-11 |
| HU-11 Exportar a PDF o Excel | HU-12 y HU-13 |
| HU-12 Ver el resumen y moverme por la aplicación | HU-08 y HU-26 |
| HU-13 Conversar con el asistente | HU-14 y HU-15 |
| HU-14 Consultar las preguntas frecuentes | HU-16 |
| HU-15 Gestionar mis recordatorios | HU-17 |
| HU-16 Recibir un aviso en el teléfono | HU-18 |
| HU-17 Explorar la biblioteca educativa | HU-19 |
| HU-18 Tener el contenido sin conexión | HU-20 |
| HU-19 Ver videos, guías e infografías | HU-21 y HU-22 |
| HU-20 Mantener separados los datos de cada paciente | HU-24 y HU-25 |
| HU-21 Usar la aplicación sin conexión | HU-27 |
| *(eliminada)* Gestionar mis listas de verificación | HU-23 |
| *(plan de certificación, no es historia)* | HU-28, HU-29 y HU-30 |

---

# 4. Historias de usuario

## E1. Cuenta y acceso

### HU-01 · Conocer la aplicación al abrirla
**Sprint:** 1 · **Estado:** ✅ Hecha · **Prioridad:** Crítica · **Puntos:** 3 · **Depende de:** —

**Como** cuidador, **quiero** ver una pantalla de bienvenida con la propuesta de valor al abrir la aplicación, **para** entender qué hace antes de entrar.

| ID | En palabras simples | Formal (Dado / Cuando / Entonces) |
| -- | ------------------- | --------------------------------- |
| CA-01.1 | Si abro la aplicación sin haber iniciado sesión, después de una breve carga veo la bienvenida con el logo, lo que ofrece la aplicación y los botones «Iniciar Sesión» y «Crear Cuenta». | **Dado** que abro la aplicación sin sesión, **cuando** termina la carga animada, **entonces** veo la bienvenida con el logo, la propuesta de valor y los botones «Iniciar Sesión» y «Crear Cuenta». |
| CA-01.2 | Si ya tenía la sesión iniciada, la aplicación me lleva directo al panel principal. | **Dado** que tengo una sesión activa, **cuando** abro la aplicación, **entonces** llego directamente al panel principal. |

*Evidencia: `lib/caracteristicas/autenticacion/presentacion/pantalla_carga.dart`, `lib/caracteristicas/autenticacion/presentacion/pantalla_bienvenida.dart`; `test/app/arranque_test.dart`, `test/caracteristicas/autenticacion/presentacion/pantalla_carga_test.dart`, `test/caracteristicas/autenticacion/presentacion/pantalla_iniciar_sesion_test.dart`.*
*Cobertura: la prueba de la bienvenida solo comprueba el texto de saludo; no verifica el logo ni los botones.*

### HU-02 · Crear mi cuenta
**Sprint:** 1 · **Estado:** ✅ Hecha · **Prioridad:** Crítica · **Puntos:** 5 · **Depende de:** —

**Como** cuidador, **quiero** crear mi cuenta completando un formulario por secciones, **para** registrar mis datos y los de mi paciente en un solo proceso.

| ID | En palabras simples | Formal (Dado / Cuando / Entonces) |
| -- | ------------------- | --------------------------------- |
| CA-02.1 | Puedo crear mi cuenta llenando los datos del cuidador, del paciente, del centro de salud y del contacto de emergencia; al guardar entro al panel principal. | **Dado** que completo con datos válidos las secciones de cuidador, paciente, centro de salud y contacto de emergencia, **cuando** confirmo, **entonces** se crea mi cuenta y entro al panel principal. |
| CA-02.2 | Si dejo un campo obligatorio vacío, o escribo un correo o un RUT con formato inválido, veo el error y no puedo continuar. | **Dado** que un campo obligatorio está vacío o el correo o el RUT tienen un formato inválido, **cuando** intento guardar, **entonces** veo el error y la cuenta no se crea. |
| CA-02.3 | Si algo falla al guardar mis datos, la cuenta no queda creada a medias. | **Dado** que falla el guardado de mis datos, **cuando** se está creando la cuenta, **entonces** se deshace el alta y la cuenta no queda creada a medias. |

*Evidencia: `lib/caracteristicas/autenticacion/presentacion/pantalla_crear_cuenta.dart`, `lib/caracteristicas/autenticacion/presentacion/formulario_registro.dart`, `lib/caracteristicas/autenticacion/dominio/validaciones_registro.dart`, `lib/caracteristicas/autenticacion/datos/servicio_alta_cuenta.dart`; `test/caracteristicas/autenticacion/presentacion/pantalla_crear_cuenta_test.dart`, `test/caracteristicas/autenticacion/dominio/validaciones_registro_test.dart`.*
*Cobertura: CA-02.3 se prueba con el orden del deshacer (primero los datos, después la cuenta de acceso).*
*Nota: el teléfono solo se valida como obligatorio, sin comprobar su formato. El deshacer del alta es completo para la cuenta de acceso y de mejor esfuerzo para los datos guardados.*

### HU-03 · Iniciar sesión, cerrar sesión y recuperar el acceso
**Sprint:** 1 · **Estado:** ✅ Hecha · **Prioridad:** Alta · **Puntos:** 4 · **Depende de:** HU-02

**Como** cuidador, **quiero** entrar y salir de mi cuenta y recuperar el acceso si olvido mi contraseña, **para** proteger mi información sin quedar fuera de ella.

| ID | En palabras simples | Formal (Dado / Cuando / Entonces) |
| -- | ------------------- | --------------------------------- |
| CA-03.1 | Con mi correo y mi contraseña correctos entro al panel; si me equivoco, veo un mensaje de error claro. | **Dado** que ingreso credenciales válidas, **cuando** confirmo, **entonces** llego al panel principal; si son inválidas, veo un mensaje de error claro. |
| CA-03.2 | Si cierro la aplicación sin cerrar sesión, al volver a abrirla sigo dentro. | **Dado** que cierro la aplicación sin cerrar sesión, **cuando** la vuelvo a abrir, **entonces** mi sesión sigue activa. |
| CA-03.3 | Puedo cerrar sesión (la aplicación me pide confirmar) y vuelvo a la bienvenida. | **Dado** que cierro sesión, **cuando** confirmo, **entonces** vuelvo a la bienvenida. |
| CA-03.4 | Si olvido mi contraseña, puedo pedir un correo para restablecerla, a mi correo principal o al de respaldo. | **Dado** que olvidé mi contraseña, **cuando** solicito la recuperación, **entonces** recibo un correo para restablecerla, en el correo principal o en el de respaldo. |

*Evidencia: `lib/caracteristicas/autenticacion/presentacion/pantalla_iniciar_sesion.dart`, `lib/caracteristicas/autenticacion/presentacion/pantalla_recuperar_acceso.dart`, `lib/caracteristicas/perfil/presentacion/perfil_cuidador.dart`; `test/caracteristicas/autenticacion/presentacion/pantalla_iniciar_sesion_test.dart`, `test/caracteristicas/autenticacion/presentacion/pantalla_recuperar_acceso_test.dart`, `test/caracteristicas/perfil/presentacion/pantalla_perfil_test.dart`.*
*Corregido el 3-oct-2026: el error `invalid-credential` de `firebase_auth` 6.x muestra «Correo o contraseña incorrectos.» (CA-03.1) y la recuperación por correo de respaldo acepta la respuesta `{ ok: true }` del servidor (CA-03.4). Ambos casos tienen prueba.*

### HU-04 · Gestionar mi perfil y mis correos
**Sprint:** 1 · **Estado:** ✅ Hecha · **Prioridad:** Alta · **Puntos:** 5 · **Depende de:** HU-03

**Como** cuidador, **quiero** ver y editar mis datos personales y cambiar mis correos confirmando mi contraseña, **para** mantener mi cuenta actualizada sin que nadie más pueda alterarla desde mi sesión.

| ID | En palabras simples | Formal (Dado / Cuando / Entonces) |
| -- | ------------------- | --------------------------------- |
| CA-04.1 | En mi perfil veo mi nombre, correos, teléfono y parentesco, y puedo editar mis datos personales. | **Dado** que abro mi perfil, **cuando** carga, **entonces** veo mi nombre, correo principal, correo de respaldo, teléfono y parentesco, y puedo editar mis datos personales. |
| CA-04.2 | Para cambiar un correo tengo que escribir mi contraseña actual. | **Dado** que quiero cambiar un correo, **cuando** confirmo, **entonces** la aplicación me pide la contraseña actual antes de aplicar el cambio. |
| CA-04.3 | Mientras un cambio de correo (principal o de respaldo) espera confirmación, veo «Pendiente de confirmar» junto al correo nuevo. | **Dado** que hay un cambio de correo pendiente de confirmar, **cuando** veo mi perfil, **entonces** aparece «Pendiente de confirmar» junto al correo nuevo. |
| CA-04.4 | Si el servidor no registró mi correo de respaldo, la aplicación lo vuelve a intentar al abrir mi perfil. | **Dado** que el servidor no confirmó mi correo de respaldo, **cuando** abro el perfil, **entonces** la aplicación reintenta registrarlo. |

*Evidencia: `lib/caracteristicas/perfil/presentacion/perfil_cuidador.dart`, `lib/caracteristicas/perfil/presentacion/widgets/tarjeta_perfil_cuidador.dart`, `lib/caracteristicas/perfil/presentacion/widgets/dialogo_correos.dart`, `lib/caracteristicas/perfil/datos/repositorio_cuidador.dart`; `test/caracteristicas/perfil/presentacion/pantalla_perfil_test.dart`, `test/caracteristicas/perfil/datos/repositorio_cuidador_test.dart`.*
*Cobertura: CA-04.2 solo verifica que aparece el campo «Contraseña actual», no que una contraseña errónea bloquee el cambio. CA-04.4 se prueba en el repositorio, no al abrir la pantalla.*

---

## E2. Seguridad y privacidad

### HU-05 · Proteger mis datos sensibles con cifrado
**Sprint:** 1 · **Estado:** ✅ Hecha · **Prioridad:** Crítica · **Puntos:** 5 · **Depende de:** HU-02

**Como** cuidador, **quiero** que los datos sensibles míos y de mis pacientes se cifren automáticamente, **para** que nadie ajeno pueda leer información médica ni personal.

| ID | En palabras simples | Formal (Dado / Cuando / Entonces) |
| -- | ------------------- | --------------------------------- |
| CA-05.1 | Los datos sensibles (nombre, RUT, diagnóstico, registros clínicos y recordatorios) salen del teléfono ya cifrados con AES-GCM de 256 bits. | **Dado** que guardo datos sensibles (nombre, RUT, diagnóstico, registros clínicos o recordatorios), **cuando** se envían a la base de datos, **entonces** salen cifrados desde el teléfono con AES-GCM de 256 bits. |
| CA-05.2 | Si alguien mira la base de datos desde su consola, no puede leer el contenido clínico ni personal; solo quedan a la vista datos como la fecha, el tipo y el nivel de alerta del registro. | **Dado** que reviso la base de datos desde su consola, **cuando** abro un documento sensible, **entonces** el contenido clínico y personal (nombre, RUT, diagnóstico, signos vitales, síntomas, observaciones, título y descripción del recordatorio) es ilegible; solo quedan en claro metadatos como la fecha, el tipo y el nivel de alerta del registro. |
| CA-05.3 | Al cerrar sesión la clave se bloquea y nadie puede descifrar hasta que yo vuelva a entrar; la clave se conserva en el almacenamiento seguro del teléfono para poder guardar datos sin conexión. | **Dado** que cierro sesión, **cuando** termina el cierre, **entonces** la clave se bloquea en memoria y no se puede descifrar hasta volver a entrar; se conserva en el almacenamiento seguro del dispositivo para poder guardar datos sin conexión. |

*Evidencia: `lib/nucleo/cifrado/servicio_cifrado.dart`, `lib/nucleo/datos/base_datos_segura.dart`; `test/nucleo/cifrado/servicio_cifrado_test.dart`, `test/integracion/sin_conexion/clave_sin_red_test.dart`.*
*Cobertura: la prueba de bloqueo comprueba que no se puede cifrar tras bloquear; no hay prueba de la conservación en el almacenamiento seguro ni del flujo completo de cierre de sesión.*

---

## E3. Pacientes

### HU-06 · Gestionar mis pacientes
**Sprint:** 1 · **Estado:** ✅ Hecha · **Prioridad:** Crítica · **Puntos:** 6 · **Depende de:** HU-03

**Como** cuidador, **quiero** registrar, editar, archivar, restaurar y eliminar a mis pacientes, **para** que mi lista solo muestre a quienes atiendo y sus expedientes estén al día.

| ID | En palabras simples | Formal (Dado / Cuando / Entonces) |
| -- | ------------------- | --------------------------------- |
| CA-06.1 | Al guardar los datos básicos de un paciente queda creado con un identificador único; si lo edito, el cambio se ve de inmediato. | **Dado** que completo los datos básicos de un paciente, **cuando** guardo, **entonces** queda creado con un identificador único; si lo edito, el cambio se refleja de inmediato. |
| CA-06.2 | La lista solo muestra a mis pacientes activos. | **Dado** que veo la lista de pacientes, **cuando** carga, **entonces** aparecen solo los pacientes activos que me pertenecen. |
| CA-06.3 | Puedo archivar a un paciente (confirmando) para sacarlo de la lista, y restaurarlo después. | **Dado** que archivo un paciente, **cuando** confirmo el aviso, **entonces** deja de aparecer entre los activos y puedo restaurarlo después. |
| CA-06.4 | Al eliminar a un paciente (confirmando) también se borran sus registros clínicos y recordatorios. | **Dado** que elimino un paciente, **cuando** confirmo el aviso, **entonces** se borran también sus registros clínicos y recordatorios. |
| CA-06.5 | Si archivo o elimino a un paciente, sus avisos de recordatorio dejan de sonar; si lo restauro, vuelven a programarse. | **Dado** que archivo o elimino un paciente, **cuando** termina la acción, **entonces** sus avisos de recordatorio dejan de sonar; al restaurarlo se programan de nuevo. |

*Evidencia: `lib/caracteristicas/pacientes/presentacion/gestion_pacientes.dart`, `lib/caracteristicas/pacientes/presentacion/widgets/dialogo_paciente.dart`, `lib/caracteristicas/pacientes/datos/repositorio_pacientes.dart`, `lib/caracteristicas/pacientes/dominio/ciclo_de_vida_paciente.dart`; `test/caracteristicas/pacientes/presentacion/gestion_pacientes_test.dart`, `test/caracteristicas/pacientes/datos/repositorio_pacientes_test.dart`, `test/caracteristicas/recordatorios/dominio/recordatorio_test.dart`, `test/nucleo/cifrado/servicio_cifrado_test.dart`.*
*Cobertura: CA-06.1 prueba la creación en el repositorio, pero no el diálogo ni la edición de los campos.*

### HU-07 · Elegir el paciente activo
**Sprint:** 1 · **Estado:** ✅ Hecha · **Prioridad:** Crítica · **Puntos:** 2 · **Depende de:** HU-06

**Como** cuidador, **quiero** elegir con qué paciente trabajo en cada momento, **para** ver y registrar la información del paciente correcto.

| ID | En palabras simples | Formal (Dado / Cuando / Entonces) |
| -- | ------------------- | --------------------------------- |
| CA-07.1 | Si tengo varios pacientes, puedo elegir uno y su nombre aparece en el panel principal. | **Dado** que tengo varios pacientes, **cuando** elijo uno, **entonces** pasa a ser el paciente activo y su nombre se ve en el panel principal. |
| CA-07.2 | Al cerrar y volver a abrir la aplicación, sigue elegido el mismo paciente. | **Dado** que elegí un paciente, **cuando** cierro y vuelvo a abrir la aplicación, **entonces** sigue seleccionado. |
| CA-07.3 | Si no tengo pacientes, el panel me invita a registrar uno. | **Dado** que no tengo pacientes, **cuando** abro el panel principal, **entonces** veo una invitación a registrar uno. |

*Evidencia: `lib/caracteristicas/pacientes/presentacion/proveedores_pacientes.dart`, `lib/caracteristicas/pacientes/presentacion/widgets/tarjeta_paciente_activo.dart`, `lib/caracteristicas/pacientes/presentacion/widgets/dialogo_cambiar_paciente.dart`; `test/caracteristicas/pacientes/presentacion/proveedores_pacientes_test.dart`, `test/integracion/cambio_de_paciente_test.dart`, `test/caracteristicas/panel_principal/presentacion/pantalla_panel_principal_test.dart`.*
*Nota: si no hay selección guardada, o el paciente guardado ya no existe, se activa el primero de la lista.*

---

## E4. Registro y seguimiento clínico

### HU-08 · Registrar signos vitales y síntomas con alerta automática
**Sprint:** 1 · **Estado:** ✅ Hecha · **Prioridad:** Crítica · **Puntos:** 5 · **Depende de:** HU-07

**Como** cuidador, **quiero** registrar los signos vitales, síntomas y observaciones del paciente activo y que la aplicación evalúe su gravedad, **para** documentar su evolución y detectar con rapidez una situación preocupante.

| ID | En palabras simples | Formal (Dado / Cuando / Entonces) |
| -- | ------------------- | --------------------------------- |
| CA-08.1 | En el formulario puedo anotar hasta cuatro signos vitales (todos opcionales) y síntomas con una intensidad visual, aunque la información esté incompleta. | **Dado** que abro el formulario, **cuando** lo completo, **entonces** puedo ingresar hasta cuatro signos vitales opcionales (temperatura, frecuencia cardíaca, saturación y frecuencia respiratoria) y síntomas con una intensidad visual, aunque la información sea parcial. |
| CA-08.2 | Si escribo un valor imposible, por ejemplo una saturación sobre 100 %, la aplicación no lo guarda y me indica el rango válido. | **Dado** que escribo un signo vital fuera del rango físico posible, **cuando** intento guardar, **entonces** el registro no se guarda y veo el rango válido de ese signo. |
| CA-08.3 | Al mover la intensidad de un síntoma de 0 a 10 veo su categoría: 0 sin síntoma, 1 a 3 leve, 4 a 6 moderado, 7 a 9 severo y 10 insoportable. | **Dado** que indico la intensidad de un síntoma de 0 a 10, **cuando** muevo el indicador, **entonces** veo su categoría: 0 sin síntoma, 1 a 3 leve, 4 a 6 moderado, 7 a 9 severo y 10 insoportable. |
| CA-08.4 | Cada paciente tiene un máximo de registros programados por día (3 por defecto); al pasarlo, el registro se guarda como extra y los extra no cuentan para ese máximo. | **Dado** que elijo un registro programado, **cuando** el paciente ya alcanzó su máximo de programados del día, **entonces** el registro se guarda como extra; los registros extra no cuentan para ese máximo. |
| CA-08.5 | Al guardar veo una confirmación y el registro queda con nivel normal, alerta o crítico; su contenido queda cifrado. | **Dado** que guardo un registro, **cuando** la aplicación lo evalúa, **entonces** queda con nivel normal, alerta o crítico, veo una confirmación y el contenido queda cifrado. |
| CA-08.6 | El nivel del registro es el más alto que resulte de sus signos vitales y de sus síntomas, según las reglas de la tabla de abajo. | **Dado** que un registro tiene signos vitales o síntomas, **cuando** se evalúa, **entonces** su nivel es el más alto que resulte de aplicar las reglas de signos vitales y de síntomas. |
| CA-08.7 | En el panel principal veo el estado de alerta del último registro. | **Dado** que reviso el panel principal, **cuando** hay registros, **entonces** veo el estado global de alerta del último registro. |

**Reglas de evaluación (CA-08.6).** Los síntomas con intensidad 0 se ignoran.

| Origen | Crítico | Alerta |
| ------ | ------- | ------ |
| Síntomas | Un síntoma insoportable (10) o dos o más severos (7 a 9) | Un síntoma severo (7 a 9) o tres o más moderados (4 a 6) |
| Temperatura | Mayor que 39,5 °C o menor que 35 °C | Mayor que 38,5 °C o menor que 36,5 °C |
| Frecuencia cardíaca | Mayor que 130 o menor que 40 lpm | Mayor que 100 o menor que 50 lpm |
| Saturación de oxígeno | Menor que 90 % | Menor que 92 % |
| Frecuencia respiratoria | Mayor que 28 o menor que 8 rpm | Mayor que 20 o menor que 12 rpm |

Rangos físicos válidos (CA-08.2): temperatura 30 a 45 °C, frecuencia cardíaca 20 a 250 lpm, saturación 50 a 100 % y frecuencia respiratoria 4 a 60 rpm. El máximo diario de registros programados es configurable por paciente entre 1 y 10.

*Evidencia: `lib/caracteristicas/registro_clinico/presentacion/pantalla_registro_clinico.dart`, `lib/caracteristicas/registro_clinico/dominio/registro_clinico.dart`, `lib/caracteristicas/registro_clinico/dominio/motor_reglas_clinicas.dart`, `lib/caracteristicas/registro_clinico/dominio/rangos_signos.dart`, `lib/caracteristicas/registro_clinico/dominio/conteo_registros.dart`, `lib/caracteristicas/panel_principal/presentacion/widgets/tarjeta_signos_vitales.dart`; `test/caracteristicas/registro_clinico/presentacion/pantalla_registro_clinico_test.dart`, `test/caracteristicas/registro_clinico/dominio/motor_reglas_clinicas_test.dart`, `test/caracteristicas/registro_clinico/dominio/registro_clinico_test.dart`, `test/caracteristicas/panel_principal/presentacion/pantalla_panel_principal_test.dart`.*
*Cobertura: CA-08.5 prueba el nivel crítico, no el normal ni el de alerta. Los valores exactamente en el límite de varios umbrales (35,0 °C, 130, 100, 40, 50, 90, 28, 20, 8 y 12) no tienen prueba.*
*Nota: el nivel de alerta, el tipo de registro y las fechas se guardan en claro; el resto del contenido, cifrado.*

### HU-09 · Consultar el historial de registros
**Sprint:** 1 · **Estado:** ✅ Hecha · **Prioridad:** Alta · **Puntos:** 5 · **Depende de:** HU-08

**Como** cuidador, **quiero** consultar y filtrar el historial del paciente activo, **para** revisar cómo ha evolucionado su salud y encontrar un episodio concreto.

| ID | En palabras simples | Formal (Dado / Cuando / Entonces) |
| -- | ------------------- | --------------------------------- |
| CA-09.1 | El historial muestra los registros del paciente activo, del más reciente al más antiguo. | **Dado** que abro el historial, **cuando** carga, **entonces** veo los registros del paciente activo ordenados del más reciente al más antiguo. |
| CA-09.2 | Al abrir un registro veo sus signos vitales, síntomas y observaciones ya descifrados. | **Dado** que selecciono un registro, **cuando** se abre, **entonces** veo sus signos vitales, síntomas y observaciones ya descifrados. |
| CA-09.3 | Puedo filtrar por nivel de alerta o por fecha y la lista muestra solo lo que coincide. | **Dado** que aplico un filtro por nivel de alerta o por fecha, **cuando** hay coincidencias, **entonces** la lista muestra solo esos registros. |
| CA-09.4 | Si hay más registros que los cargados, «Cargar más» trae los 50 siguientes, aunque el filtro no tenga coincidencias entre los ya cargados. | **Dado** que existen más registros que los cargados, **cuando** pulso «Cargar más», **entonces** se cargan los siguientes 50, aunque el filtro no tenga coincidencias entre los ya cargados. |

*Evidencia: `lib/caracteristicas/historial/presentacion/pantalla_historial.dart`, `lib/caracteristicas/historial/presentacion/controlador_historial.dart`, `lib/caracteristicas/historial/dominio/filtro_historial.dart`, `lib/caracteristicas/registro_clinico/datos/repositorio_registros_clinicos.dart`; `test/caracteristicas/historial/presentacion/pantalla_historial_test.dart`.*
*Cobertura: CA-09.4 se prueba con una página inyectada; el Firestore simulado no pagina, así que la consulta real de la página siguiente no está comprobada.*
*Nota: el filtro de fecha se aplica sobre la fecha del registro; el orden y la paginación, sobre el momento en que se creó.*

### HU-10 · Corregir o eliminar los registros del día
**Sprint:** 1 · **Estado:** ✅ Hecha · **Prioridad:** Media · **Puntos:** 3 · **Depende de:** HU-09

**Como** cuidador, **quiero** editar o eliminar los registros que hice hoy, **para** corregir un error sin alterar el historial anterior.

| ID | En palabras simples | Formal (Dado / Cuando / Entonces) |
| -- | ------------------- | --------------------------------- |
| CA-10.1 | En un registro de hoy puedo editarlo o eliminarlo desde su menú. | **Dado** que veo un registro de hoy, **cuando** abro su menú, **entonces** puedo editarlo o eliminarlo. |
| CA-10.2 | En un registro de un día anterior esas opciones no aparecen. | **Dado** que veo un registro de un día anterior, **cuando** abro su menú, **entonces** no se ofrecen esas opciones. |
| CA-10.3 | Al eliminar un registro (confirmando) desaparece al instante del historial y del panel principal. | **Dado** que elimino un registro, **cuando** confirmo el aviso, **entonces** desaparece de inmediato del historial y del panel principal. |

*Evidencia: `lib/caracteristicas/historial/presentacion/widgets/cabecera_tarjeta_registro.dart`, `lib/caracteristicas/historial/presentacion/pantalla_historial.dart`; `test/caracteristicas/historial/presentacion/pantalla_historial_test.dart`, `test/integracion/sin_conexion/integridad_datos_test.dart`.*
*Cobertura: CA-10.3 comprueba que el registro desaparece del historial; el panel principal lee la misma fuente de datos, pero no tiene una prueba propia de este caso.*
*Nota: «de hoy» se mide por el día calendario del registro. Al editar se conservan la fecha, la hora y el tipo, y se recalcula el nivel de alerta.*

---

## E5. Informes

### HU-11 · Exportar el historial a PDF o Excel
**Sprint:** 2 · **Estado:** ✅ Hecha · **Prioridad:** Alta · **Puntos:** 6 · **Depende de:** HU-09

**Como** cuidador, **quiero** exportar el historial del paciente a un informe PDF o a una planilla Excel, **para** compartirlo con médicos o familiares o analizarlo en otro formato.

| ID | En palabras simples | Formal (Dado / Cuando / Entonces) |
| -- | ------------------- | --------------------------------- |
| CA-11.1 | Al exportar un rango de fechas, el archivo trae todos los registros de ese rango, de los más antiguos a los más nuevos y ya descifrados, aunque no estuvieran cargados en pantalla. | **Dado** que elijo un rango de fechas, **cuando** exporto, **entonces** el archivo incluye todos los registros del rango, incluso los que aún no estaban cargados en pantalla, en orden cronológico y con los datos ya descifrados. |
| CA-11.2 | El PDF contiene los datos del paciente y sus registros clínicos. | **Dado** que se genera el PDF, **cuando** lo abro, **entonces** contiene los datos del paciente y sus registros clínicos. |
| CA-11.3 | El Excel tiene una hoja «Historial» con columnas legibles: fecha, hora, tipo, estado, temperatura, frecuencia cardíaca, saturación, frecuencia respiratoria, síntomas y observaciones. | **Dado** que se genera el Excel, **cuando** reviso la hoja «Historial», **entonces** veo una tabla con las columnas Fecha, Hora, Tipo, Estado, Temp., F.C., Sat. O₂, F.R., Síntomas y Observaciones. |
| CA-11.4 | Cuando el archivo está listo puedo abrirlo o compartirlo. | **Dado** que el archivo está listo, **cuando** lo recibo, **entonces** puedo abrirlo o compartirlo directamente. |

*Evidencia: `lib/caracteristicas/historial/datos/exportador_pdf.dart`, `lib/caracteristicas/historial/datos/exportador_excel.dart`, `lib/caracteristicas/historial/datos/formato_exportacion.dart`, `lib/caracteristicas/historial/datos/archivo_exportacion.dart`, `lib/caracteristicas/historial/dominio/orden_registros.dart`, `lib/caracteristicas/historial/presentacion/controlador_historial.dart`; `test/caracteristicas/historial/datos/exportadores_test.dart`, `test/caracteristicas/historial/datos/orden_y_rango_exportacion_test.dart`, `test/caracteristicas/historial/presentacion/exportar_desde_historial_test.dart`.*
*Cobertura: de CA-11.2 solo se prueba que el PDF es un documento válido con los registros en orden. Abrir y compartir reales no están probados (se usan canales simulados).*
*Nota: la exportación respeta el filtro de nivel de alerta activo. Si la consulta por rango falla, exporta solo lo que está cargado en pantalla.*

---

## E6. Panel y orientación

### HU-12 · Ver el resumen del paciente y moverme por la aplicación
**Sprint:** 2 · **Estado:** ✅ Hecha · **Prioridad:** Alta · **Puntos:** 5 · **Depende de:** HU-07

**Como** cuidador, **quiero** ver un resumen del paciente activo apenas entro y una barra para moverme entre las secciones, **para** conocer su estado sin buscarlo y llegar rápido a cada función.

| ID | En palabras simples | Formal (Dado / Cuando / Entonces) |
| -- | ------------------- | --------------------------------- |
| CA-12.1 | El panel me saluda, muestra el paciente activo, la fecha y hora de su último registro, los signos vitales de ese registro y cuántos registros se hicieron hoy sobre su meta diaria. | **Dado** que abro el panel principal, **cuando** carga, **entonces** veo el saludo, el nombre del paciente activo, la fecha y hora del registro más reciente, los signos vitales de ese registro (o «--» si no los tiene) y cuántos registros programados se hicieron hoy sobre el máximo diario del paciente (3 por defecto); los extra se informan aparte. |
| CA-12.2 | Desde el panel puedo ir directo a orientación, recordatorios, biblioteca, registro, historial y preguntas frecuentes. | **Dado** que estoy en el panel principal, **cuando** miro los accesos directos, **entonces** puedo ir a orientación, recordatorios, biblioteca, registros, historial y preguntas frecuentes. |
| CA-12.3 | Desde cualquier sección principal la barra inferior me lleva a Inicio, Chat, Registro, Aprende o Perfil. | **Dado** que estoy en cualquier sección principal, **cuando** toco un destino de la barra inferior (Inicio, Chat, Registro, Aprende o Perfil), **entonces** llego a esa sección. |

*Evidencia: `lib/caracteristicas/panel_principal/presentacion/pantalla_panel_principal.dart`, `lib/caracteristicas/panel_principal/presentacion/widgets/saludo_paciente.dart`, `lib/caracteristicas/panel_principal/presentacion/widgets/accesos_rapidos.dart`, `lib/app/navegacion_principal.dart`, `lib/app/enrutador/enrutador.dart`; `test/caracteristicas/panel_principal/presentacion/pantalla_panel_principal_test.dart`, `test/app/navegacion_principal_test.dart`.*
*Cobertura: de CA-12.2 solo se prueban los títulos y el acceso al historial.*
*Nota: la meta es el máximo diario configurado para el paciente (corregido el 3-oct-2026). Los signos vitales son los del último registro, no el último valor de cada signo.*

### HU-13 · Conversar con el asistente de orientación
**Sprint:** 2 · **Estado:** ✅ Hecha · **Prioridad:** Media · **Puntos:** 8 · **Depende de:** —

**Como** cuidador, **quiero** conversar con un asistente que responda mis dudas sobre el cuidado y conservar mis conversaciones, **para** resolverlas en el momento y recordar orientaciones previas.

| ID | En palabras simples | Formal (Dado / Cuando / Entonces) |
| -- | ------------------- | --------------------------------- |
| CA-13.1 | Al escribir una pregunta, el asistente responde con una orientación de las preguntas frecuentes de la aplicación, con reglas locales y sin inteligencia artificial externa. | **Dado** que escribo una pregunta, **cuando** la envío, **entonces** el asistente responde con una orientación del catálogo de preguntas frecuentes de la aplicación, mediante reglas locales y sin inteligencia artificial externa. |
| CA-13.2 | En un chat nuevo veo preguntas sugeridas que puedo tocar. | **Dado** que abro un chat nuevo, **cuando** carga, **entonces** veo preguntas sugeridas. |
| CA-13.3 | Dentro de una conversación puedo buscar una palabra y ver solo los mensajes que la contienen, sin importar las tildes. | **Dado** que estoy en una conversación, **cuando** abro la búsqueda y escribo una palabra, **entonces** veo solo los mensajes que la contienen (sin distinguir tildes) y, si ninguno la contiene, el aviso «Sin resultados para tu búsqueda». |
| CA-13.4 | Las conversaciones se guardan cifradas. | **Dado** que se guarda una conversación, **cuando** se almacena, **entonces** su contenido queda cifrado. |
| CA-13.5 | Mis conversaciones aparecen ordenadas por su última actividad, con un título tomado de mi primera pregunta, salvo que yo les haya puesto un nombre. | **Dado** que abro la lista de conversaciones, **cuando** carga, **entonces** aparecen por su última actividad, con un título tomado de la primera pregunta recortada, salvo que yo les haya puesto un nombre. |
| CA-13.6 | Puedo retomar una conversación anterior, cambiarle el nombre o eliminarla; al eliminar me pide confirmar. | **Dado** que abro una conversación anterior, **cuando** escribo, **entonces** puedo continuarla, y también renombrarla o eliminarla, pidiéndome confirmación al eliminar («Esta acción no se puede deshacer»). |
| CA-13.7 | Mis conversaciones son las mismas aunque cambie de paciente, porque pertenecen a mi cuenta. | **Dado** que cambio de paciente activo, **cuando** abro mis conversaciones, **entonces** siguen siendo las mismas, porque pertenecen al cuidador. |

*Evidencia: `lib/caracteristicas/chat/presentacion/pantalla_chat.dart`, `lib/caracteristicas/chat/presentacion/controlador_chat.dart`, `lib/caracteristicas/chat/presentacion/proveedor_chat_activo.dart`, `lib/caracteristicas/chat/presentacion/widgets/hoja_conversaciones.dart`, `lib/caracteristicas/chat/dominio/respuestas_chat.dart`, `lib/caracteristicas/chat/datos/repositorio_conversaciones.dart`, `lib/caracteristicas/preguntas_frecuentes/dominio/catalogo_preguntas.dart`; `test/caracteristicas/chat/presentacion/pantalla_chat_test.dart`, `test/caracteristicas/chat/presentacion/widgets/hoja_conversaciones_test.dart`, `test/integracion/cambio_de_paciente_test.dart`.*
*Nota: el título se recorta a 40 caracteres. El mensaje de respaldo cuando no hay coincidencia («Aún no tengo una respuesta exacta…») no tiene prueba. El chat activo se vacía al cambiar de cuenta (corregido el 3-oct-2026, con prueba).*

### HU-14 · Consultar las preguntas frecuentes
**Sprint:** 2 · **Estado:** ✅ Hecha · **Prioridad:** Baja · **Puntos:** 2 · **Depende de:** —

**Como** cuidador, **quiero** buscar respuestas rápidas a las dudas más comunes, **para** no depender de búsquedas externas.

| ID | En palabras simples | Formal (Dado / Cuando / Entonces) |
| -- | ------------------- | --------------------------------- |
| CA-14.1 | Veo las preguntas en un acordeón y puedo abrir cada respuesta. | **Dado** que abro las preguntas frecuentes, **cuando** carga, **entonces** veo las preguntas en un acordeón con su respuesta expandible. |
| CA-14.2 | Al escribir en el buscador la lista se filtra al instante, sin importar las tildes, y también puedo filtrar por categoría. | **Dado** que escribo una palabra en el buscador, **cuando** hay coincidencias, **entonces** la lista se filtra al instante, sin distinguir tildes; también puedo filtrar por categoría. |
| CA-14.3 | Si una respuesta tiene material relacionado en la biblioteca, veo un enlace a él; si el material no existe, el enlace no aparece. | **Dado** que una respuesta tiene material relacionado en la biblioteca, **cuando** la expando, **entonces** veo un enlace a ese material; si el material no existe, el enlace no aparece. |

*Evidencia: `lib/caracteristicas/preguntas_frecuentes/presentacion/pantalla_preguntas_frecuentes.dart`, `lib/caracteristicas/preguntas_frecuentes/dominio/catalogo_preguntas.dart`; `test/caracteristicas/preguntas_frecuentes/presentacion/pantalla_preguntas_frecuentes_test.dart`.*
*Nota: la búsqueda compara con la pregunta, la respuesta y la categoría. El catálogo actual tiene tres preguntas y solo dos enlazan material. El enlace tampoco aparece mientras el catálogo de la biblioteca no ha cargado.*

---

## E7. Recordatorios

### HU-15 · Gestionar mis recordatorios
**Sprint:** 2 · **Estado:** ✅ Hecha · **Prioridad:** Alta · **Puntos:** 5 · **Depende de:** HU-07

**Como** cuidador, **quiero** programar, editar y eliminar recordatorios de medicamentos, controles y actividades, **para** no olvidar ninguna tarea del paciente.

| ID | En palabras simples | Formal (Dado / Cuando / Entonces) |
| -- | ------------------- | --------------------------------- |
| CA-15.1 | Puedo programar un recordatorio una sola vez, desde hoy y hasta cinco años adelante. | **Dado** que creo un recordatorio, **cuando** elijo «Una vez», **entonces** puedo programarlo desde hoy y hasta cinco años adelante; si elijo hoy con una hora ya pasada, el aviso suena mañana a esa hora. |
| CA-15.2 | Puedo programarlo cada semana, en los días que yo elija. | **Dado** que creo un recordatorio, **cuando** elijo repetición semanal, **entonces** se programa en los días de la semana que elija. |
| CA-15.3 | Puedo programarlo cada mes, en el día del mes que yo elija. | **Dado** que creo un recordatorio, **cuando** elijo repetición mensual, **entonces** se programa en el día del mes que elija. |
| CA-15.4 | Puedo dejar el recordatorio dirigido al paciente o a mí. | **Dado** que creo un recordatorio, **cuando** lo asigno, **entonces** puedo dejarlo para el paciente o para mí. |
| CA-15.5 | El título, la descripción y la programación se guardan cifrados. | **Dado** que se guarda el recordatorio, **cuando** se almacena, **entonces** su título, descripción y programación quedan cifrados. |
| CA-15.6 | Al editar un recordatorio conserva su fecha original, salvo que yo la cambie; si lo elimino (confirmando) desaparece de la lista. | **Dado** que edito un recordatorio, **cuando** guardo, **entonces** conserva su fecha original salvo que yo la cambie; y si lo elimino, desaparece de la lista tras confirmar. |
| CA-15.7 | Con el interruptor de cada recordatorio puedo apagarlo sin borrarlo y volver a encenderlo. | **Dado** que tengo un recordatorio, **cuando** apago su interruptor, **entonces** deja de avisar sin borrarse, y **cuando** lo vuelvo a encender, se programa otra vez. |

*Evidencia: `lib/caracteristicas/recordatorios/presentacion/pantalla_recordatorios.dart`, `lib/caracteristicas/recordatorios/presentacion/controlador_recordatorios.dart`, `lib/caracteristicas/recordatorios/presentacion/widgets/dialogo_recordatorio.dart`, `lib/caracteristicas/recordatorios/datos/repositorio_recordatorios.dart`; `test/caracteristicas/recordatorios/presentacion/pantalla_recordatorios_test.dart`, `test/caracteristicas/recordatorios/presentacion/widgets/dialogo_recordatorio_test.dart`, `test/caracteristicas/recordatorios/presentacion/reglas_recordatorio_test.dart`, `test/caracteristicas/recordatorios/dominio/recordatorio_test.dart`.*
*Nota: el título es obligatorio. Una repetición semanal sin ningún día elegido se guarda como «una vez» con la fecha de hoy, sin avisar. No existe la acción «completar recordatorio»: solo se activa o se desactiva.*

### HU-16 · Recibir un aviso en el teléfono a la hora indicada
**Sprint:** 2 · **Estado:** ✅ Hecha (probada en dispositivo) · **Prioridad:** Media · **Puntos:** 3 · **Depende de:** HU-15

**Como** cuidador, **quiero** recibir una notificación en mi teléfono cuando llega la hora de un recordatorio, **para** actuar a tiempo aunque no tenga la aplicación abierta.

| ID | En palabras simples | Formal (Dado / Cuando / Entonces) |
| -- | ------------------- | --------------------------------- |
| CA-16.1 | Al guardar un recordatorio nuevo, o al reactivar uno, la aplicación pide el permiso de notificaciones (el sistema solo muestra el diálogo la primera vez). | **Dado** que guardo un recordatorio nuevo o reactivo uno, **cuando** termina el guardado, **entonces** la aplicación solicita el permiso de notificaciones; el sistema solo muestra el diálogo la primera vez. |
| CA-16.2 | Cuando llega la fecha y hora de un recordatorio activo, el teléfono muestra una notificación. | **Dado** que un recordatorio activo llega a su fecha y hora, **cuando** se cumple, **entonces** el teléfono muestra una notificación. |
| CA-16.3 | Al tocar la notificación, la aplicación se abre en Recordatorios. | **Dado** que toco la notificación, **cuando** se abre la aplicación, **entonces** llego a Recordatorios. |
| CA-16.4 | Al cerrar sesión se cancelan los avisos. | **Dado** que cierro sesión, **cuando** termina el cierre, **entonces** se cancelan los avisos. |
| CA-16.5 | Al volver a iniciar sesión, los avisos se programan otra vez sin que yo edite nada. | **Dado** que inicio sesión de nuevo, **cuando** entro a la aplicación, **entonces** los avisos se programan otra vez sin que yo edite nada. |

*Evidencia: `lib/nucleo/notificaciones/servicio_notificaciones.dart`, `lib/nucleo/notificaciones/calendario_avisos.dart`, `lib/caracteristicas/pacientes/dominio/ciclo_de_vida_paciente.dart`, `lib/app/enrutador/destino_aviso.dart`, `lib/main.dart`, `lib/caracteristicas/autenticacion/presentacion/pantalla_carga.dart`, `lib/caracteristicas/autenticacion/presentacion/pantalla_iniciar_sesion.dart`, `lib/caracteristicas/perfil/presentacion/perfil_cuidador.dart`; `test/nucleo/notificaciones/calendario_avisos_test.dart`, `test/integracion/avisos_al_entrar_test.dart`, `test/app/enrutador/destino_aviso_test.dart`, `test/caracteristicas/pacientes/dominio/ciclo_de_vida_paciente_test.dart`, `test/caracteristicas/perfil/presentacion/pantalla_perfil_test.dart`.*
*Cobertura: CA-16.2 se prueba en el cálculo de la próxima fecha del aviso; que el teléfono muestre la notificación se validó en un teléfono real.*
*Nota: el reagendado omite los recordatorios apagados, los de una sola vez ya vencidos y los de pacientes archivados. Si el usuario silenció las notificaciones, no se programa ninguna. La cancelación al cerrar sesión ocurre solo por el botón «Cerrar sesión».*

---

## E8. Biblioteca educativa

### HU-17 · Explorar la biblioteca educativa
**Sprint:** 2 · **Estado:** ✅ Hecha · **Prioridad:** Media · **Puntos:** 3 · **Depende de:** —

**Como** cuidador, **quiero** explorar un catálogo de contenido educativo sobre el cuidado, **para** aprender y aplicar mejores prácticas.

| ID | En palabras simples | Formal (Dado / Cuando / Entonces) |
| -- | ------------------- | --------------------------------- |
| CA-17.1 | Veo el catálogo de materiales y los que tienen archivo y ya están descargados muestran una marca. | **Dado** que abro la biblioteca, **cuando** carga, **entonces** veo el catálogo de materiales y cada material con archivo adjunto que ya está descargado muestra una marca de verificación. |
| CA-17.2 | Puedo buscar por título, elegir una categoría o ver solo mis favoritos, y la lista se filtra. | **Dado** que escribo en el buscador, elijo una categoría o activo los favoritos, **cuando** hay coincidencias, **entonces** la lista se filtra. |
| CA-17.3 | Si marco un material como favorito, sigue marcado cuando vuelva. | **Dado** que marco un material como favorito, **cuando** vuelvo más tarde, **entonces** sigue marcado. |

*Evidencia: `lib/caracteristicas/biblioteca/presentacion/pantalla_biblioteca.dart`, `lib/caracteristicas/biblioteca/presentacion/widgets/tarjeta_material.dart`, `lib/caracteristicas/biblioteca/dominio/categorias.dart`, `lib/caracteristicas/biblioteca/datos/repositorio_biblioteca.dart`; `test/caracteristicas/biblioteca/presentacion/pantalla_biblioteca_test.dart`, `test/caracteristicas/biblioteca/presentacion/pantalla_video_y_tarjeta_material_test.dart`.*
*Nota: el buscador filtra solo por título. El catálogo se guarda 24 horas y se sirve desde esa copia si Firestore falla. La tarjeta no muestra un estado «pendiente» mientras se descarga.*

### HU-18 · Tener el contenido disponible sin conexión
**Sprint:** 2 · **Estado:** ✅ Hecha · **Prioridad:** Alta · **Puntos:** 5 · **Depende de:** HU-17

**Como** cuidador, **quiero** que el contenido educativo se descargue solo la primera vez, **para** consultarlo después sin conexión y sin gastar datos.

| ID | En palabras simples | Formal (Dado / Cuando / Entonces) |
| -- | ------------------- | --------------------------------- |
| CA-18.1 | La primera vez que inicio sesión, el contenido se descarga en segundo plano sin impedirme usar la aplicación. | **Dado** que inicio sesión por primera vez, **cuando** entro a la aplicación, **entonces** el contenido se descarga en segundo plano sin bloquear el uso del resto de la aplicación. |
| CA-18.2 | Lo que ya se descargó no se vuelve a descargar al reabrir o actualizar la aplicación. | **Dado** que un archivo ya está descargado en el teléfono, **cuando** reabro o actualizo la aplicación, **entonces** no se vuelve a descargar. |
| CA-18.3 | Si la red falla durante la descarga, la aplicación reintenta lo que faltó al abrirla de nuevo o al iniciar sesión. | **Dado** que la red falla durante la descarga, **cuando** vuelvo a abrir la aplicación o inicio sesión, **entonces** la aplicación reintenta lo que faltó. |

*Evidencia: `lib/caracteristicas/biblioteca/presentacion/proveedores_biblioteca.dart`, `lib/caracteristicas/biblioteca/datos/servicio_cache_contenido.dart`, `lib/caracteristicas/biblioteca/datos/servicio_cache_metadata.dart`; `test/caracteristicas/biblioteca/presentacion/proveedores_biblioteca_test.dart`, `test/caracteristicas/biblioteca/datos/servicio_cache_contenido_test.dart`.*
*Cobertura: «sin bloquear» (CA-18.1) no se verifica.*
*Nota: se descargan también las miniaturas e imágenes, de tres en tres. La copia local guarda como máximo 200 archivos y 365 días. El reintento ocurre en un arranque en frío y al iniciar sesión, no al volver del fondo.*

### HU-19 · Ver videos, guías e infografías
**Sprint:** 2 · **Estado:** ✅ Hecha · **Prioridad:** Media · **Puntos:** 6 · **Depende de:** HU-17

**Como** cuidador, **quiero** ver videos, leer guías y consultar infografías dentro de la aplicación, **para** aprender de forma visual y tener recomendaciones prácticas a la mano.

| ID | En palabras simples | Formal (Dado / Cuando / Entonces) |
| -- | ------------------- | --------------------------------- |
| CA-19.1 | El video se reproduce en horizontal, a pantalla inmersiva, con controles para reproducir, pausar, avanzar y retroceder 10 segundos y una barra de progreso que puedo arrastrar. | **Dado** que abro un video, **cuando** se reproduce, **entonces** se muestra en horizontal y a pantalla inmersiva, con controles de reproducir, pausar, avanzar y retroceder 10 segundos, y una barra de progreso que puedo arrastrar. |
| CA-19.2 | Si dejé un video a medias, al volver a abrirlo continúa donde quedó. | **Dado** que dejé un video a medias, **cuando** lo vuelvo a abrir, **entonces** continúa desde donde quedó. |
| CA-19.3 | Una infografía sin archivo adjunto se ve ampliada sobre la pantalla; puedo acercarla hasta 5 veces con zoom y cerrarla con la X. | **Dado** que abro una infografía sin archivo adjunto, **cuando** se muestra, **entonces** la veo ampliada sobre la pantalla y puedo acercarla hasta 5 veces con zoom y cerrarla con la X. |
| CA-19.4 | El detalle de una guía muestra sus recomendaciones en secciones con título y, si tiene archivo adjunto, un botón para abrirlo. | **Dado** que abro el detalle de una guía (desde la biblioteca si no tiene archivo adjunto, o desde las preguntas frecuentes), **cuando** carga, **entonces** veo sus recomendaciones en secciones tituladas y un botón para abrir el archivo adjunto si lo tiene. |
| CA-19.5 | Una imagen que ya vi sigue disponible sin conexión porque quedó guardada en el teléfono. | **Dado** que ya vi una imagen, **cuando** no tengo conexión, **entonces** la sigo viendo porque quedó guardada en el teléfono. |

*Evidencia: `lib/caracteristicas/biblioteca/presentacion/pantalla_video.dart`, `lib/caracteristicas/biblioteca/presentacion/pantalla_detalle_material.dart`, `lib/caracteristicas/biblioteca/presentacion/pantalla_biblioteca.dart`, `lib/caracteristicas/biblioteca/presentacion/widgets/dialogo_imagen_ampliable.dart`, `lib/caracteristicas/biblioteca/presentacion/widgets/imagen_cacheada.dart`; `test/caracteristicas/biblioteca/presentacion/pantalla_video_test.dart`, `test/caracteristicas/biblioteca/presentacion/pantalla_video_y_tarjeta_material_test.dart`, `test/caracteristicas/biblioteca/presentacion/pantalla_detalle_material_test.dart`, `test/caracteristicas/biblioteca/presentacion/pantalla_biblioteca_test.dart`.*
*Cobertura: el reproductor se prueba con una plataforma de video simulada. CA-19.5 usa una caché simulada, no una prueba sin red real.*
*Nota: no hay botón de pantalla completa; el video siempre se abre en horizontal e inmersivo. Si el material trae archivo adjunto (por ejemplo un PDF), la lista lo abre en otra aplicación en lugar del detalle o del visor. Los controles del video se ocultan a los 4 segundos. El material de categoría «Checklist» se abre como lista con marcas que valen solo durante la sesión.*

---

## E9. Integridad y continuidad de los datos

### HU-20 · Mantener separados los datos de cada paciente
**Sprint:** 3 (implementada por adelantado) · **Estado:** ✅ Hecha · **Prioridad:** Alta · **Puntos:** 8 · **Depende de:** HU-07

**Como** cuidador, **quiero** que los registros y recordatorios de un paciente nunca se mezclen con los de otro, **para** evitar errores médicos graves.

| ID | En palabras simples | Formal (Dado / Cuando / Entonces) |
| -- | ------------------- | --------------------------------- |
| CA-20.1 | Al cambiar de paciente, mis registros y recordatorios son solo los del nuevo paciente. | **Dado** que cambio de paciente activo, **cuando** vuelvo a abrir los registros y recordatorios, **entonces** veo únicamente los del nuevo paciente. |
| CA-20.2 | El chat y la biblioteca no cambian ni se duplican al cambiar de paciente, porque pertenecen a mi cuenta. | **Dado** que cambio de paciente activo, **cuando** abro el chat y la biblioteca, **entonces** son los mismos de siempre, sin duplicarse, porque pertenecen al cuidador. |
| CA-20.3 | El servidor rechaza un registro o recordatorio que declare un paciente distinto al de su ubicación, y no deja cambiarlo si ya existe. | **Dado** que se guarda un registro clínico o un recordatorio, **cuando** el documento declara un paciente distinto al de su ubicación, **entonces** el servidor lo rechaza; y si ya existe, tampoco se puede cambiar el paciente que declara. |
| CA-20.4 | Otro cuidador no puede acceder a mis pacientes. | **Dado** que otro cuidador intenta acceder a mis pacientes, **cuando** lo intenta, **entonces** el servidor lo rechaza. |
| CA-20.5 | Yo siempre puedo borrar mis propios documentos. | **Dado** que quiero borrar uno de mis documentos, **cuando** lo borro, **entonces** el servidor lo permite. |

*Evidencia: `firestore.rules`, `lib/nucleo/datos/base_datos_segura.dart`, `lib/caracteristicas/registro_clinico/datos/repositorio_registros_clinicos.dart`, `lib/caracteristicas/recordatorios/datos/repositorio_recordatorios.dart`; `test/reglas_firestore/reglas_firestore.test.js` (19 casos contra el emulador), `test/integracion/aislamiento_paciente_test.dart`, `test/integracion/cambio_de_paciente_test.dart`.*
*Cobertura: CA-20.4 prueba solo la escritura de otro cuidador, no la lectura ni otras colecciones. La biblioteca es contenido común; solo los favoritos pertenecen al cuidador.*
*Nota: las reglas exigen el paciente declarado en cada actualización, también en documentos antiguos, y prohíben escribir en claro el título, la descripción, los síntomas y las observaciones.*

### HU-21 · Usar la aplicación sin conexión
**Sprint:** 3 (implementada por adelantado) · **Estado:** 🟡 Falta validar en dispositivo · **Prioridad:** Alta · **Puntos:** 5 · **Depende de:** HU-08, HU-15

**Como** cuidador, **quiero** seguir registrando información cuando no hay internet y saber si ya quedó guardada, **para** no perder datos y que se envíen solos cuando vuelva la red.

| ID | En palabras simples | Formal (Dado / Cuando / Entonces) |
| -- | ------------------- | --------------------------------- |
| CA-21.1 | Sin internet puedo crear, cambiar o borrar registros y recordatorios; la lista lo muestra al instante y queda guardado en el teléfono aunque cierre la aplicación. | **Dado** que no tengo conexión, **cuando** creo, cambio o borro un registro clínico o un recordatorio, **entonces** la lista lo muestra de inmediato y la acción queda guardada en el teléfono aunque cierre la aplicación. |
| CA-21.2 | Cuando vuelve la red, lo pendiente se envía solo y en el mismo orden en que lo hice; un borrado no se deshace con cambios antiguos. | **Dado** que recupero la conexión, **cuando** la aplicación detecta la red, **entonces** envía lo pendiente automáticamente y en el mismo orden en que lo hice; un borrado no se deshace con cambios antiguos. |
| CA-21.3 | Si no hay internet y la clave de cifrado no está en el teléfono, la aplicación me avisa que no puede guardar el registro en vez de fallar en silencio. | **Dado** que no tengo conexión y la clave de cifrado no está guardada en el teléfono, **cuando** intento guardar un registro clínico, **entonces** la aplicación me avisa que no puede hacerlo, en lugar de fallar en silencio. |
| CA-21.4 | Sin internet puedo ver mis registros más recientes que ya estaban guardados en el teléfono. | **Dado** que no tengo conexión, **cuando** consulto los últimos registros, **entonces** veo los 50 más recientes que ya estaban guardados en el teléfono. |
| CA-21.5 | Si pierdo la conexión, o abro o retomo la aplicación sin ella, aparece «Sin conexión» abajo durante 3 segundos, sin más detalles y sin repetirse al cambiar de pantalla. | **Dado** que no tengo conexión, **cuando** la pierdo, o abro o retomo la aplicación, **entonces** aparece durante 3 segundos el aviso «Sin conexión» en la parte inferior, sin más detalles y sin repetirse al cambiar de pantalla. |

*Evidencia: `lib/nucleo/sincronizacion/cola_escrituras.dart`, `lib/nucleo/sincronizacion/orquestador_sincronizacion.dart`, `lib/nucleo/conectividad/servicio_conectividad.dart`, `lib/nucleo/datos/base_datos_segura.dart`, `lib/nucleo/cifrado/servicio_cifrado.dart`, `lib/compartido/widgets/banner_conexion.dart`, `lib/caracteristicas/registro_clinico/presentacion/pantalla_registro_clinico.dart`; `test/integracion/sin_conexion/`, `test/nucleo/sincronizacion/cola_escrituras_test.dart`, `test/nucleo/conectividad/servicio_conectividad_test.dart`, `test/compartido/widgets/banner_conexion_test.dart`, `test/caracteristicas/registro_clinico/datos/repositorio_registros_clinicos_test.dart`.*
*Cobertura: CA-21.1 prueba «se ve de inmediato» solo con recordatorios. CA-21.3 se prueba en el servicio, no el aviso de pantalla. CA-21.5 prueba los 3 segundos con una duración explícita, no con la constante por defecto, y no hay prueba de navegación entre pantallas.*
*Pendiente de dispositivo: caída y vuelta real de la red y el comportamiento de la conectividad en Android e iOS.*
*Nota: «hay red» significa que existe una interfaz de red activa, no que haya internet. Cada escritura espera hasta 8 segundos; si vence, se encola. Los reintentos esperan de 2 a 60 segundos, hasta 8 veces; después pasan a «fallidas», igual que los errores permanentes. La cola es por cuidador y sobrevive al cierre de sesión.*

---

# 5. Plan de certificación (no son historias de usuario)

Son pautas de prueba que se ejecutan a mano sobre la APK de lanzamiento, con evidencia de cada paso. No forman parte del conteo de historias ni de puntos.

| Pauta | Cubre | Estado |
| ----- | ----- | ------ |
| Flujo core | Instalación → onboarding → registro → creación de paciente → registro clínico | Pendiente de ejecutar |
| Biblioteca y navegación | Biblioteca → contenido → reproducción → navegación | Pendiente de ejecutar |
| Evaluación completa | Guía completa de uso, caída y recuperación de red, recordatorios con la aplicación cerrada | Pendiente de ejecutar |

# 6. Decisiones de diseño vigentes

Estas decisiones ya están tomadas y condicionan varias historias. Cambiarlas exige revisar las historias afectadas.

- **Cola de escrituras sin conexión.** Los borrados también pasan por la cola y se encolan detrás de los pendientes del mismo documento. La cola se conserva por usuario al cerrar sesión (HU-21).
- **Reconciliación.** Al sincronizar gana la última escritura campo a campo, en el orden en que se encolaron; un borrado hecho en el servidor gana sobre las actualizaciones pendientes (HU-21).
- **Clave de cifrado.** Al cerrar sesión se bloquea en memoria, pero se conserva en el almacenamiento seguro del dispositivo para poder guardar datos sin conexión (HU-05, HU-21).
- **Recuperación por correo de respaldo.** El servidor siempre responde `{ ok: true }` y espera 60 segundos entre envíos al mismo correo, para no revelar si una cuenta existe (HU-03).
- **Colecciones existentes.** `clinicalRecords` y `patients` no se renombran, porque exigiría migrar datos; lo nuevo se nombra en español. Los recordatorios usan `recordatorios`.
- **Navegación.** Barra inferior de cinco destinos (Inicio, Chat, Registro, Aprende y Perfil), sin botón flotante ni enlaces directos externos (HU-12). No se reimplementa sin pedido explícito.
- **Listas de verificación del cuidador.** Se eliminaron del producto el 3 de octubre de 2026 por decisión de alcance. La biblioteca conserva los materiales educativos de categoría «Checklist», que son contenido compartido y no datos del cuidador.

# 7. Cómo verificar

Desde la raíz del proyecto:

```powershell
flutter analyze
flutter test
flutter test test/caracteristicas/<funcionalidad>      # una sola funcionalidad
```

Reglas de Firestore (solo si se modifica `firestore.rules` o lo que se escribe en las subcolecciones clínicas). Necesitan JDK 21 o superior; sirve el de Android Studio:

```bash
export JAVA_HOME="/c/Program Files/Android/Android Studio/jbr"; export PATH="$JAVA_HOME/bin:$PATH"
firebase emulators:exec --only firestore --project oncuidar-reglas-test "npm --prefix test/reglas_firestore test"
```

Resultado esperado al 3-oct-2026: análisis sin errores ni avisos, `flutter test` 400/400 y reglas 19/19.

# 8. Defectos conocidos y pruebas pendientes

## 8.1 Defectos corregidos

No quedan defectos conocidos abiertos. Los cinco detectados al contrastar los criterios con el código se corrigieron el 3 de octubre de 2026 y cada uno tiene prueba:

| Dónde | Defecto | Corrección y prueba |
| ----- | ------- | ------------------- |
| HU-03 · inicio de sesión | El error `invalid-credential` de `firebase_auth` 6.x caía en un mensaje genérico | Muestra «Correo o contraseña incorrectos.» · `pantalla_iniciar_sesion_test.dart` |
| HU-03 · recuperar acceso | La pantalla esperaba `found == true` y el servidor responde `{ ok: true }` | Acepta `{ ok: true }` como envío correcto · `pantalla_recuperar_acceso_test.dart` |
| HU-13 · chat activo | El chat activo no se vaciaba al cambiar de cuenta | Se reinicia cuando cambia el usuario de la sesión · `pantalla_chat_test.dart` |
| HU-12 · panel principal | La meta de registros del día estaba fija en 3 | Usa el máximo diario del paciente · `pantalla_panel_principal_test.dart` |
| HU-02 · alta de cuenta | Al fallar el alta podía quedar el documento del usuario sin cuenta de acceso | Se borran primero los datos (con la sesión aún activa) y después la cuenta · `pantalla_crear_cuenta_test.dart` |

## 8.2 Pruebas agregadas

Las pruebas que faltaban se escribieron el 3 de octubre de 2026 (`test/` replica la estructura de `lib/`):

| Criterio | Prueba |
| -------- | ------ |
| CA-02.2 | `autenticacion/dominio/validaciones_registro_test.dart`, `autenticacion/presentacion/pantalla_crear_cuenta_test.dart` |
| CA-04.3 | `perfil/presentacion/pantalla_perfil_test.dart` |
| CA-06.4 | `pacientes/datos/repositorio_pacientes_test.dart` |
| CA-07.2 | `pacientes/presentacion/proveedores_pacientes_test.dart` |
| CA-08.3 | `registro_clinico/dominio/registro_clinico_test.dart` |
| CA-09.4 y CA-10.1 a CA-10.3 | `historial/presentacion/pantalla_historial_test.dart` |
| CA-11.3 | `historial/datos/exportadores_test.dart` |
| CA-12.3 | `test/app/navegacion_principal_test.dart` |
| CA-14.3 | `preguntas_frecuentes/presentacion/pantalla_preguntas_frecuentes_test.dart` |
| CA-15.2 | `recordatorios/presentacion/widgets/dialogo_recordatorio_test.dart` |
| CA-16.2 | `test/nucleo/notificaciones/calendario_avisos_test.dart` |
| CA-16.4 | `perfil/presentacion/pantalla_perfil_test.dart` |
| CA-17.1 y CA-19.3 | `biblioteca/presentacion/pantalla_biblioteca_test.dart` |
| CA-18.3 | `biblioteca/presentacion/proveedores_biblioteca_test.dart` |
| CA-19.1 | `biblioteca/presentacion/pantalla_video_test.dart` |
| CA-19.4 | `biblioteca/presentacion/pantalla_detalle_material_test.dart` |
| CA-21.4 | `registro_clinico/datos/repositorio_registros_clinicos_test.dart` |

Las rutas sin prefijo están dentro de `test/caracteristicas/`.

## 8.3 Otros pendientes

- **Validación en dispositivo.** HU-16 (avisos) se probó en un teléfono real. HU-21 (modo sin conexión) depende de la red real y sigue validada solo con pruebas automáticas; tampoco se simula el tiempo de espera de 8 s al enviar desde la cola.
- **Paginación.** «Cargar más» (HU-09) se prueba con una página inyectada; la consulta real de la página siguiente no pudo verificarse, porque el Firestore simulado devuelve una lista vacía.
- **Estado «pendiente» en la biblioteca.** La tarjeta de un material indica si está descargado, pero no muestra un estado «pendiente» mientras se descarga (HU-17).
- **Material educativo tipo checklist.** Se abre como una lista con marcas y avance; las marcas valen solo durante la sesión y no hay pruebas automáticas dedicadas. No forma parte de ninguna historia.
- **Datos antiguos en Firebase.** Los documentos que existieran en la subcolección `userChecklists` quedan sin uso y ya no se pueden leer ni borrar desde la aplicación; se limpian desde la consola de Firebase o con un script.

# 9. Limitaciones

- **Granularidad.** Algunas historias agrupan varias operaciones de una misma meta (HU-06, HU-13, HU-20). Si un docente exige una funcionalidad por historia, deberían dividirse; los criterios de aceptación ya están separados para facilitarlo.
- **Evaluación con usuarios.** La evaluación con cuidadores reales queda fuera del alcance del proyecto.
- **Certificación.** Las pautas del plan de la sección 5 siguen pendientes de ejecutar.

# 10. Historial de cambios

| Fecha | Cambio |
| ----- | ------ |
| 3-oct-2026 | Refactor por capas. Las rutas de «Evidencia» apuntan a la estructura nueva (`lib/caracteristicas/<funcionalidad>/{dominio,datos,presentacion}` y `test/` como espejo de `lib/`). Se corrigieron los cinco defectos conocidos y se agregaron las pruebas pendientes: HU-01 a HU-20 quedan hechas y HU-21 solo espera la validación en dispositivo. CA-12.1 pasa a usar el máximo diario del paciente. |
| 3-oct-2026 | Se agregaron los sprints con su calendario y su estado, los identificadores de criterios y la doble redacción (palabras simples y formal). Cada criterio se contrastó con el código y las pruebas: se corrigieron los criterios que no coincidían con la aplicación (historial del más reciente al más antiguo, video e infografía, meta del panel, reglas de alerta, formato de teléfono, columnas del Excel y otros), se quitó «completar recordatorio» (no existe) y se documentaron los defectos y las pruebas pendientes. |
| 3-oct-2026 | Versión definitiva. Se eliminó la historia de listas de verificación del cuidador (de 22 a 21 historias y de 102 a 99 puntos) y se renumeraron las dos últimas. HU-08 incorpora la escala de intensidad de 0 a 10 y sus reglas de alerta. Reemplaza a V2, V3 y al diagnóstico de pendientes. |
| 30-sep-2026 | V3: 22 historias en 9 épicas, plantilla «Como… quiero… para…», criterios Dado/Cuando/Entonces y fundamento metodológico. |
| 30-sep-2026 | V2: consolidación de la primera versión en 20 historias. |
| Inicial | Primera versión: 30 historias en tres sprints. |

# 11. Referencias

Cohn, M. (2004). *User stories applied: For agile software development*. Addison-Wesley.

Jeffries, R. (2001). *Essential XP: Card, Conversation, Confirmation*. XP Magazine. (Descripción consultada en Agile Alliance, *What are the Three Cs?*, https://agilealliance.org/glossary/three-cs/).

Lucassen, G., Dalpiaz, F., van der Werf, J. M. E. M., & Brinkkemper, S. (2016). Improving agile requirements: The Quality User Story framework and tool. *Requirements Engineering, 21*(3), 383–403. https://doi.org/10.1007/s00766-016-0250-x

North, D. (2006). Introducing BDD. *Better Software*. https://dannorth.net/introducing-bdd/

Wake, B. (2003). *INVEST in good stories, and SMART tasks*. XP123. https://xp123.com/articles/invest-in-good-stories-and-smart-tasks
