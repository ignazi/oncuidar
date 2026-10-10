# DevOps de OnCuidar: ideas, arquitectura objetivo y plan

Documento de diseño para implementar después. **Lo que hay hoy** está marcado con ✅, **lo que falta** con ⬜ y lo que depende del servidor de la universidad con 🔒. En el informe solo debe declararse como implementado lo que tenga ✅.

## 1. Idea central

DevOps es un ciclo que se repite: planificar → codificar → construir → probar → publicar → desplegar → operar → monitorear → volver a planificar. El objetivo es que **nada importante dependa de acordarse de hacerlo a mano**: las pruebas corren solas, el empaquetado es repetible, el despliegue es un comando y los problemas se detectan antes de que los note el usuario.

## 2. Estado actual frente al ciclo

| Paso | Qué debería existir | Hoy |
|---|---|---|
| Planificar | Backlog, sprints, evidencia de ceremonias | ✅ historias de usuario (`docs/HU.md`), Scrum y Gantt en el informe · ⬜ tablero y registro de ceremonias |
| Codificar | Git, commits claros, versiones etiquetadas | ✅ commits convencionales · ⬜ etiquetas de versión y `CHANGELOG` |
| Construir | Build repetible | ✅ `Dockerfile`, `docker-compose.yml`, `flutter build apk` · ⬜ un script único |
| Probar | Pruebas automáticas en cada cambio | ✅ 54 del backend, 294 de la app, script de humo · ⬜ ejecución automática (CI) |
| Publicar | Artefactos versionados (imagen, APK) | ⬜ hoy el APK se genera a mano |
| Desplegar | Un comando, con vuelta atrás | 🔒 pendiente de la cuenta #1813 |
| Operar | Reinicio automático, respaldos, HTTPS | ✅ `restart: unless-stopped` · ⬜ respaldos · 🔒 HTTPS y reinicio tras reinicio del servidor |
| Monitorear | Salud, métricas y alertas | ✅ `/api/salud` · ⬜ todo lo demás |

## 3. Arquitectura objetivo

```
 PC de desarrollo                                  Servidor Parra (UBB) · Podman Tesistas
 ┌──────────────────────────┐                      ┌────────────────────────────────────────┐
 │ código + pruebas         │                      │  usuario rootless "<usuario>"           │
 │ scripts/verificar        │   SFTP/SSH :22       │                                        │
 │ scripts/publicar  ───────┼─────────────────────▶│  contenedor api  (Node 22 / Express)   │◀── celulares (HTTP/JSON + JWT)
 │ scripts/desplegar        │   imagen + .env      │      puerto público asignado           │      <puerto API>
 └───────────┬──────────────┘                      │            │ red interna               │
             │ git (solo local)                    │  contenedor db   (PostgreSQL 15)       │
             ▼                                     │      volumen de datos · sin puerto     │
   CI opcional (GitHub Actions)                    │                                        │
   mismas pasos que `verificar`                    │  contenedor monitor (Uptime Kuma, opc.)│◀── navegador del equipo
                                                   │      puerto asignado (panel)           │      <puerto panel>
                                                   │                                        │
                                                   │  cron/systemd: respaldo diario pg_dump │
                                                   └──────────────────┬─────────────────────┘
                                                                      │ SMTP saliente (465/587)
                                                                      ▼
                                                            Gmail (correos de enlace)
```

Principios: la base **nunca** publica puerto; los secretos viven solo en el `.env` del servidor; los archivos de la biblioteca van dentro de la imagen o en un volumen; todo se puede reconstruir desde el repositorio.

## 4. Entornos

| Entorno | Para qué | Cómo se levanta |
|---|---|---|
| Local | Desarrollo y prueba en el teléfono | `docker compose up -d` (ya existe) |
| Pruebas | Pruebas del backend con base efímera | `docker-compose.pruebas.yml` (ya existe) |
| Producción UBB | Entrega y demo | `podman compose` o Quadlet con el `.env` del servidor 🔒 |

## 5. Canalización (CI/CD) propuesta

Una sola secuencia, ejecutable **localmente** con `scripts/verificar` y, si algún día se sube el repositorio, también como archivo de GitHub Actions (no se sube nada sin decidirlo).

1. **Verificar:** `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test`; `npm ci` y `npm test` del backend contra PostgreSQL efímero; script de humo.
2. **Seguridad básica:** `npm audit --omit=dev` y revisión de que no haya secretos en git.
3. **Construir:** imagen del backend con etiqueta de versión (`oncuidar-api:1.0.0`) y APK release (`--dart-define=API_URL=…`).
4. **Publicar:** etiqueta git `v1.0.0`, entrada en `CHANGELOG.md` y artefactos en `dist/`.
5. **Desplegar** 🔒: subir imagen y `.env` por SFTP, `podman load`, reiniciar, esperar `/api/salud`; si no responde, volver a la imagen anterior.
6. **Verificar el despliegue:** el script de humo contra la URL pública.

Versionado semántico (`MAYOR.MENOR.PARCHE`), con el número en `pubspec.yaml`, `backend/package.json` y la etiqueta de la imagen.

## 6. Despliegue en Podman

- **Rootless:** sin permisos de administrador, por lo que solo se pueden usar puertos sobre 1024 (los asignados).
- **Dos formas de describir los servicios:** `podman compose`/`podman-compose` (reutiliza `docker-compose.yml`, más rápido de adoptar) o **Quadlet** (un archivo `.container` por servicio, systemd los reinicia y arranca solos tras reiniciar el servidor; es la forma que Podman recomienda para servicios permanentes). Para el proyecto: empezar con compose y pasar a Quadlet si el servidor lo permite.
- Para que los servicios sobrevivan al cierre de la sesión SSH hace falta `loginctl enable-linger` (preguntar si está permitido).
- **Healthchecks** en la API (`/api/salud`) y en PostgreSQL (`pg_isready`); con Quadlet, un contenedor «unhealthy» puede reiniciarse solo.
- **Límites de recursos** (`mem_limit`) razonables: el servidor es compartido.
- **Vuelta atrás:** conservar la imagen de la versión anterior (`oncuidar-api:1.0.0`) para reactivarla si la nueva falla.

## 7. Operación

- **Respaldos:** `pg_dump` diario comprimido, retención de 7 días, **y una prueba de restauración** (un respaldo no probado no cuenta). Guardar una copia fuera del servidor.
- **HTTPS:** pedir subdominio o proxy inverso. Mientras tanto la app permite HTTP (`usesCleartextTraffic`); los datos clínicos igual viajan cifrados, pero la contraseña y el token no, y esa es la razón principal para pedir HTTPS.
- **Correo:** comprobar desde el servidor que sale al puerto SMTP (`465`/`587`); si está bloqueado, alternativa por HTTPS (servicio transaccional) o SMTP de la universidad.
- **Secretos:** rotar `SMTP_CLAVE`, `JWT_SECRETO` y la clave de Postgres antes de entregar; respaldar `CLAVE_MAESTRA` aparte (sin ella no se pueden abrir las claves de datos de los usuarios).

## 8. Monitoreo: investigación y recomendación

**Qué preguntas hay que poder responder:** ¿está arriba? ¿responde rápido? ¿se está quedando sin disco o memoria? ¿falló un correo o una consulta? ¿quién se enterará?

| Herramienta | Responde a | Recursos | Encaja aquí |
|---|---|---|---|
| **Healthchecks de contenedor + `/api/salud`** | «¿vive el proceso?» | nulos | ✅ base, ya casi está |
| **Uptime Kuma** | «¿puede el usuario abrir la API?»; avisa por correo/Telegram; página de estado | ~50–100 MB de RAM; trae imágenes sin root desde la v2 | ✅ **recomendada** |
| **`/metrics` con `prom-client`** | cuántas peticiones, errores y latencia de la API | casi nulos (una librería) | ✅ barata y muy útil para el informe |
| **Netdata** | «¿cómo está el servidor?» (CPU, RAM, disco, por proceso) | moderado | 🔶 opcional, si dan permisos |
| **Prometheus + Grafana** | histórico y paneles | pesado para un servidor compartido | ⬜ trabajo futuro |
| **Logs estructurados (JSON) + `podman logs`/journald** | «¿qué pasó a las 14:03?» | nulos | ✅ recomendada |

**Recomendación por capas (de menos a más esfuerzo):**
1. **Capa 1 (imprescindible):** healthchecks, `/api/salud` y logs en JSON con nivel y una identificación de petición.
2. **Capa 2 (recomendada):** Uptime Kuma vigilando `/api/salud`, con alerta por correo cuando falle; y `/metrics` con `prom-client` (peticiones, errores 4xx/5xx, latencia, uso de memoria del proceso).
3. **Capa 3 (opcional):** Netdata o Prometheus + Grafana, solo si el servidor y el tiempo lo permiten. Para la tesis alcanza con describirlos como mejora futura.

Alertas mínimas que valen la pena: API caída más de 2 minutos, disco sobre 85 %, respaldo diario fallido, ráfaga de errores 5xx.

Fuentes consultadas: [Uptime Kuma: uso de recursos y alternativas ligeras](https://fosshost.com/guides/foss-monitoring-tools-for-your-vps/), [novedades de Uptime Kuma 2.0 (imágenes sin root)](https://oneuptime.com/blog/post/2026-02-08-how-to-run-uptime-kuma-in-docker-for-status-monitoring/markdown), [Uptime Kuma frente a Netdata](https://selfhosting.sh/compare/uptime-kuma-vs-netdata/), [Podman Quadlet y systemd](https://computingforgeeks.com/podman-quadlet-systemd-fedora/), [documentación de unidades de Podman](https://docs.podman.io/en/v4.6.0/markdown/podman-systemd.unit.5.html), [métricas de Node.js con Prometheus y Grafana](https://stackabuse.com/nodejs-application-monitoring-with-prometheus-and-grafana/). Las cifras de memoria son de esas fuentes y conviene medirlas en el servidor real.

## 9. Plan de implementación

| Fase | Entrega | Depende de | Criterio de «hecho» |
|---|---|---|---|
| 1 | `scripts/verificar` (formato, análisis, pruebas, humo) y archivo de GitHub Actions equivalente | nada | Un comando deja todo en verde o falla con el motivo |
| 2 | Versionado, `CHANGELOG.md`, `scripts/publicar` (imagen + APK en `dist/`) | fase 1 | Un APK `v1.0.0` y una imagen con esa misma etiqueta |
| 3 | Logs JSON, `/metrics`, healthchecks en compose | nada | `/metrics` responde; los contenedores muestran «healthy» |
| 4 | `scripts/desplegar` (SFTP + Podman + comprobación + vuelta atrás) | 🔒 cuenta activa y puertos | Despliegue en un comando y `HUMO OK` contra la URL pública |
| 5 | Respaldo diario con restauración probada; Uptime Kuma con alerta | 🔒 servidor | Un respaldo restaurado en una base de prueba; una alerta recibida |
| 6 | Informe: sección DevOps con lo realmente implementado y trabajo futuro | fases previas | Cada afirmación del informe tiene su evidencia |

**Riesgos:** puerto SMTP bloqueado en el servidor, falta de `linger` (los contenedores se detienen al cerrar sesión), cuota de disco para los videos y los respaldos, HTTPS no disponible, y que el despliegue tarde por la activación de la cuenta.

## 10. Decisiones pendientes

1. ¿Base en contenedor propio o en el servicio PostgreSQL de la universidad (puerto 5432)? Hoy el plan usa contenedor propio, porque da control del esquema y de los respaldos.
2. ¿Se sube el repositorio a GitHub para usar Actions, o la canalización queda solo local?
3. ¿Uptime Kuma necesita un puerto propio? (ver `docs/SOLICITUD_PUERTOS.md`).
4. ¿Compose o Quadlet, según lo que permita el servidor?
