# Backend de OnCuidar

API REST (Node 22, Express 5, PostgreSQL 15) de OnCuidar. El cliente cifra los datos sensibles con AES-GCM; el servidor **nunca descifra**: solo guarda texto cifrado en la columna `cifrados` (jsonb) y rechaza con 400 los campos clínicos en claro.

## Levantar

```bash
cp .env.ejemplo .env        # en la raíz; completar secretos (ver abajo)
docker compose up -d --build
curl http://localhost:8080/api/salud   # {"ok":true}
```

Solo se publica la API (`PUERTO_API`, por defecto 8080, hacia el 3000 del contenedor). Postgres queda en la red interna; para desarrollo copiar `docker-compose.override.yml.ejemplo` a `docker-compose.override.yml`. El esquema (`database/init.sql`) se carga solo al crear el volumen por primera vez. Al arrancar, la API carga el material educativo si la tabla está vacía.

## Variables del `.env`

| Variable | Uso |
| --- | --- |
| `PUERTO_API` | Puerto del host para la API (8080) |
| `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` | Credenciales de Postgres |
| `DATABASE_URL` | Conexión de la API (`postgres://usuario:clave@db:5432/base`) |
| `JWT_SECRETO` | Firma HS256 de los tokens (30 días), mínimo 16 caracteres |
| `CLAVE_MAESTRA` | 32 bytes en base64; sella las claves de datos (`openssl rand -base64 32`). **Si se pierde, las claves de datos no se pueden abrir** |
| `HMAC_CORREO` | Secreto del HMAC del correo de respaldo |
| `URL_PUBLICA` | Base pública del servidor (default `http://localhost:8080`): enlaces de restablecer contraseña y de confirmación de correos, y URLs absolutas de `/archivos/...` en la biblioteca |
| `SMTP_HOST`, `SMTP_PUERTO`, `SMTP_USUARIO`, `SMTP_CLAVE`, `SMTP_REMITENTE` | Correo; sin `SMTP_HOST` el enlace se imprime en el log de la API |
| `LIMITE_AUTH`, `VENTANA_AUTH_MS` | Límite de intentos por IP en `/auth/*` (30 cada 15 min) |

## Endpoints (prefijo `/api`, JSON, errores `{"error":"..."}`)

Sin token: `GET /salud`, `POST /auth/registro`, `/auth/login`, `/auth/recuperar-contrasena`, `/auth/restablecer-contrasena`, `/auth/recuperar-por-respaldo`, `GET /auth/restablecer?token=` (página HTML), `GET /auth/confirmar-correo?token=` (página HTML; el token del correo es la credencial).
Con `Authorization: Bearer <token>`:

- Cuenta: `POST /auth/verificar-contrasena`, `POST /auth/cambiar-correo`, `POST /auth/reenviar-verificacion`, `DELETE /cuenta`, `POST /clave-datos`, `POST /correo-respaldo`
- Verificación de correos por enlace (vence en 1 h, un solo uso; solo se guarda el sha256 del token en `tokens_correo`):
  - `POST /auth/cambiar-correo {contrasena, nuevoCorreo}` envía el enlace al correo nuevo y responde `{ok, pendiente:true}`; el correo principal no cambia hasta confirmar (409 si otro usuario ya lo usa). Una solicitud nueva invalida la anterior.
  - `POST /correo-respaldo {correo}` también queda pendiente: el token guarda solo el HMAC del correo y `correo_respaldo_hash` se escribe al confirmar. El respaldo anterior sigue vigente hasta entonces y `recuperar-por-respaldo` solo usa respaldos confirmados.
  - `GET /auth/confirmar-correo?token=` aplica el cambio en una transacción y muestra una página («Correo confirmado» o «Enlace inválido o vencido»).
  - El registro envía un enlace de verificación sin bloquear (si el envío falla, la cuenta se crea igual). `POST /auth/reenviar-verificacion` lo reenvía (máximo uno cada 60 s por usuario). Los usuarios existentes quedan sin verificar y no se bloquea nada.
  - `GET /cuidador` incluye `correoVerificado`, `correoRespaldoVerificado`, `respaldoPendiente`, `pendienteCorreo`, `pendienteCorreoTipo` y `pendienteCorreoSolicitadoEn`; el `PUT` ignora los campos de pendientes (los maneja el servidor).
- `GET|PUT /cuidador` (merge; `null` dentro de `cifrados` borra esa clave)
- `GET /pacientes?archivados=`, `PUT|DELETE /pacientes/:id`
- `GET /pacientes/:pid/registros?limite=&antesDeCreadoEn=` o `?desde=&hasta=`; `PUT|DELETE /pacientes/:pid/registros/:rid`
- `GET /pacientes/:pid/recordatorios?limite=`; `PUT|DELETE /pacientes/:pid/recordatorios/:rid`
- `GET /conversaciones?limite=`; `PUT|DELETE /conversaciones/:id`
- `GET /biblioteca`, `GET /biblioteca/:id`, `GET /favoritos`, `PUT|DELETE /favoritos/:id`

Todo se filtra por el usuario del token; un recurso ajeno responde 404. Los `PUT` son upserts con fusión. Fechas en ISO-8601 UTC.

## Migrar una base ya creada (verificación de correos)

`database/init.sql` solo corre al crear el volumen. Para una base existente (idempotente):

```bash
docker compose exec -T db sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"' <<'SQL'
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS correo_verificado boolean DEFAULT false;
CREATE TABLE IF NOT EXISTS tokens_correo (
  token_hash text PRIMARY KEY,
  usuario_id uuid NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
  tipo text NOT NULL,
  correo_nuevo text,
  respaldo_hash text,
  creado_en timestamptz DEFAULT now(),
  expira_en timestamptz NOT NULL,
  usado boolean DEFAULT false
);
CREATE INDEX IF NOT EXISTS idx_tokens_correo_usuario ON tokens_correo (usuario_id, tipo);
SQL
```

## Pruebas

Usan Postgres real (base `oncuidar_pruebas`, efímera, puerto 5433):

```bash
docker compose -f docker-compose.pruebas.yml up -d --wait   # en la raíz
cd backend && npm install && npm test
docker compose -f docker-compose.pruebas.yml down
```

Las pruebas borran los usuarios `*@prueba.cl` que crean. Con `DATABASE_URL_PRUEBAS` se apunta a otra base.

## Archivos de la biblioteca

Los archivos viven en `backend/archivos/` (van dentro de la imagen) y se sirven en `GET /archivos/<nombre>` con cache de 7 días y sin listado. El seed guarda rutas relativas (`/archivos/x.pdf`) y la API las devuelve absolutas con `URL_PUBLICA`. El seed solo carga si la tabla está vacía; para recargarlo: `docker compose exec api node scripts/cargar_material.js`.

## Despliegue en Podman (servidor de la universidad)

A confirmar cuando la universidad entregue los puertos y el host definitivos.

1. Copiar `.env.ejemplo` a `.env` y completar secretos. `PUERTO_API` debe ser mayor a 1024 (sin root no se puede enlazar puertos bajos). `URL_PUBLICA=http://<host>:<puerto>`.
2. Levantar con `podman compose up -d --build` (o `podman-compose up -d --build`). Si el volumen de `database/init.sql` falla por SELinux, agregar `:Z` al montaje.
3. Comprobar con `curl http://<host>:<puerto>/api/salud`.
4. Compilar el APK apuntando al servidor: `flutter build apk --release --dart-define=API_URL=http://<host>:<puerto>/api`.
5. Si el acceso es por HTTP (sin TLS), Android release solo lo permite con `usesCleartextTraffic`; usar HTTPS si la universidad lo ofrece.

