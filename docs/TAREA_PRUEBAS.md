# Tarea: ordenar y documentar las pruebas de OnCuidar

Documento para un agente (OpenCode u otro). Lee primero `AGENTS.md` en la raíz: sus reglas duras mandan sobre este texto.

## 0. Objetivo

Que las pruebas se puedan **explicar en el informe de título** sin parecer «demasiadas»: pocas, sin duplicados, ordenadas por nivel y ligadas a las historias de usuario de `docs/HU.md`. **Solo se tocan `test/` y `docs/`**; no se cambia nada de `lib/`.

## 1. Reglas duras (resumen de `AGENTS.md`)

- Nunca `git push`, PR ni ramas remotas. Solo commits locales, uno por paso.
- Commits en español, estilo convencional (`test:`, `docs:`, `refactor:`). **Prohibido** `Co-Authored-By` o cualquier atribución a IA.
- Todo en español: nombres, comentarios (una línea), nombres de pruebas y de archivos.
- Imports internos con `package:oncuidar/...` (en `test/`, las ayudas se importan con ruta relativa a `test/ayudas/`).
- No tocar `firestore.rules` ni `lib/`.
- Antes de dar un paso por hecho, correr la verificación (sección 4).

## 2. Estado actual (5-oct-2026, rama `refactor/arquitectura-por-capas`)

- 595 pruebas ejecutadas, 531 escritas (la diferencia son pruebas repetidas por parámetros: matriz de desbordes, contraste, burbujas del chat).
- Cobertura de líneas de referencia: **85,89 % (8.710 de 10.141 líneas)**.
- `flutter analyze` sin problemas y `dart format` sin cambios.

Por nivel (escritas): unitarias `test(...)` 287, de widget `testWidgets(...)` 244. Por carpeta: `nucleo` 39, `app` 25, `compartido` 24, `integracion` 75, y el resto en `caracteristicas/<área>/{dominio,datos,presentacion}`. Aparte, 19 pruebas de reglas de Firestore en `test/reglas_firestore/` (emulador, ver `AGENTS.md` §3).

### Ya hecho (no repetir)

- Se quitaron duplicados confirmados leyendo los cuerpos de las pruebas.
- Se separaron por nivel archivos que mezclaban datos, dominio y pantalla:
  `recordatorios/datos/repositorio_recordatorios_test.dart`, `chat/datos/repositorio_conversaciones_test.dart`, `biblioteca/dominio/material_educativo_test.dart`, `biblioteca/presentacion/avance_video_test.dart`, `biblioteca/presentacion/widgets/tarjeta_material_test.dart`; los avisos al archivar/restaurar/eliminar pasaron a `pacientes/dominio/ciclo_de_vida_paciente_test.dart`.
- Se unificaron las ayudas de recordatorios en `test/ayudas/recordatorios.dart`.

## 3. Trabajo pendiente

### 3.1 Más orden por nivel (sin perder pruebas)

Mover pruebas que están en el archivo equivocado. Cada archivo debe probar **un solo archivo de `lib/`** (test espejo):

| Archivo actual | Problema | Destino sugerido |
| --- | --- | --- |
| `autenticacion/presentacion/pantalla_iniciar_sesion_test.dart` | contiene pruebas del Splash y del Perfil | Splash → `pantalla_carga_test.dart`; Perfil → `perfil/presentacion/pantalla_perfil_test.dart` |
| `historial/datos/orden_y_rango_exportacion_test.dart` | prueba exportadores y consultas | exportadores → `exportadores_test.dart`; consulta por rango → `registro_clinico/datos/repositorio_registros_clinicos_test.dart` |
| `historial/datos/diseno_exportacion_test.dart` | mezcla `formato_exportacion` con PDF y Excel | separar por archivo de `lib/` |
| `integracion/sin_desbordes_test.dart` y `integracion/sin_desbordes_texto_test.dart` | dos archivos para lo mismo | dejar uno solo, `sin_desbordes_test.dart` |
| `historial/presentacion/botones_exportar_test.dart` | tiene 1 sola prueba | moverla a `pantalla_historial_test.dart` |

Al mover pruebas que usan ayudas privadas (`_algo`), preferir las ayudas de `test/ayudas/` en vez de copiarlas.

### 3.2 Posibles duplicados que **no** se verificaron

Solo quitar una prueba si (a) sus aserciones están contenidas en otra y (b) la cobertura no baja (ver §4). Candidatas:

- `pantalla_iniciar_sesion_test.dart`: «perfil muestra cuidador y cierra sesion» (la sesión ya se cierra en `pantalla_perfil_test.dart`).
- `integracion/avisos_al_entrar_test.dart` frente a `app/enrutador/destino_aviso_test.dart`: casos de «sin sesión conserva el destino».
- `registro_clinico/dominio/motor_reglas_clinicas_test.dart` (40) y `autenticacion/dominio/validaciones_registro_test.dart` (12): son tablas de valores límite; se pueden expresar con un bucle sobre una lista de casos (misma cobertura, menos código). **No bajar los valores límite.**

**Lección ya aprendida:** una prueba que parecía duplicada («sin asignación guardada va dirigido al paciente») era la única que ejercitaba `Recordatorio.fromMap`. Se detectó porque la cobertura bajó 16 líneas. Siempre medir antes de borrar.

### 3.3 Convención académica de las pruebas

Aplicar a todos los archivos de `test/`:

1. Primera línea del archivo: comentario con la historia que respalda, por ejemplo `// HU-09 Consultar el historial: CA-09.1 a CA-09.4.`
2. Un `group` por criterio o por comportamiento, nombrado como el criterio de `docs/HU.md` (por ejemplo `CA-09.4 Cargar más`).
3. Nombre de cada prueba: frase en español que diga el comportamiento («filtro por estado muestra solo los registros coincidentes»), sin números ni nombres de variables.
4. Lo que no pertenece a una historia (cifrado, cola sin conexión, tema, accesibilidad) se agrupa como requisito no funcional y se cita así en el comentario inicial.

### 3.4 Entregable principal: `docs/PRUEBAS.md`

Documento para copiar al informe. Debe incluir:

1. **Estrategia**: pirámide de pruebas de la guía de Flutter (unitarias, de widget, de integración) más las reglas de Firestore en el emulador. Una tabla con qué verifica cada nivel y cuántas pruebas hay.
2. **Estructura de `test/`**: espejo de `lib/` (`caracteristicas/<área>/{dominio,datos,presentacion}`, `nucleo`, `app`, `compartido`, `integracion`, `ayudas`).
3. **Matriz de trazabilidad**: una fila por historia (HU-01 a HU-21) con sus criterios y los archivos de prueba que los verifican. Se arma leyendo los comentarios iniciales del punto 3.3 y las notas «Cobertura» de `docs/HU.md`. Señalar honestamente los criterios con cobertura parcial.
4. **Pruebas de regresión**: 3 o 4 ejemplos reales de defectos hallados en el teléfono que quedaron con prueba (hora del chat que chocaba con el texto, degradado de la barra que medía 0 de alto, zoom que saltaba con contenido bajo, «Programado» partido en dos líneas).
5. **Calidad no funcional**: contraste WCAG (`app/tema/contraste_paleta_test.dart`), sin desbordes de texto en distintos tamaños (`integracion/sin_desbordes_test.dart`), modo oscuro, modo sin conexión.
6. **Métricas**: total de pruebas, cobertura de líneas, tiempo de la suite (unos 2 minutos), y que se corre antes de cada commit.
7. **Limitaciones**: lo que no se puede probar sin teléfono (zoom táctil real, visor de PDF de `pdfx`, selector «Guardar como») y el plan de certificación de `docs/HU.md` §5.

## 4. Verificación obligatoria después de cada paso

```powershell
flutter analyze                                            # "No issues found!"
dart format --output=none --set-exit-if-changed lib test   # 0 cambios
flutter test                                               # todo en verde
flutter test --coverage                                    # genera coverage/lcov.info
```

La cobertura **no puede bajar** de 8.710 líneas cubiertas. Para comparar contra la referencia, guardar una copia del `lcov.info` actual antes de empezar (`copy coverage\lcov.info lcov_antes.info`) y usar este script (`python cobertura.py lcov_antes.info coverage/lcov.info`); imprime las líneas que dejaron de cubrirse por archivo, y la meta es **0**:

```python
import sys

def leer(ruta):
    datos, actual, lf, lh, cub = {}, None, 0, 0, set()
    for linea in open(ruta, encoding="utf-8"):
        linea = linea.strip()
        if linea.startswith("SF:"):
            actual, lf, lh, cub = linea[3:].replace("\\", "/"), 0, 0, set()
        elif linea.startswith("DA:"):
            n, veces = linea[3:].split(",")[:2]
            lf += 1
            if int(veces) > 0:
                lh += 1
                cub.add(int(n))
        elif linea == "end_of_record" and actual:
            datos[actual] = (lf, lh, cub)
    return datos

antes, despues = leer(sys.argv[1]), leer(sys.argv[2])
print("antes  :", sum(v[1] for v in antes.values()), "/", sum(v[0] for v in antes.values()))
print("después:", sum(v[1] for v in despues.values()), "/", sum(v[0] for v in despues.values()))
perdidas = 0
for archivo, (_, _, cub) in sorted(antes.items()):
    otro = despues.get(archivo)
    if otro and cub - otro[2]:
        perdidas += len(cub - otro[2])
        print("  pierde", len(cub - otro[2]), "líneas en", archivo, sorted(cub - otro[2])[:10])
print("líneas que dejaron de cubrirse:", perdidas)
```

Si un paso hace perder líneas, devolver la prueba o reemplazarla por una que cubra esas líneas.

## 5. Cierre

- Un commit local por paso (`test:` para mover o quitar pruebas, `docs:` para `docs/PRUEBAS.md`).
- Actualizar el conteo de referencia de `flutter test` en `AGENTS.md` §3 con el número final y la fecha.
- Informar al final: pruebas antes y después, cobertura antes y después, archivos movidos y pruebas quitadas con el motivo de cada una.
