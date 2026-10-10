# OnCuidar

App móvil de apoyo a cuidadores de niños, niñas y adolescentes con cáncer. El cuidador registra síntomas y signos vitales, recibe alertas y recordatorios, consulta material educativo y conversa con un asistente. Los datos sensibles se cifran en el teléfono (AES-GCM) y el servidor solo guarda texto cifrado.

**Piezas:** app Flutter (`lib/`) → API REST Node.js + Express (`backend/`) → PostgreSQL. Todo el servidor corre con Docker Compose.

## Requisitos

- [Docker](https://www.docker.com/) con Compose
- [Flutter](https://docs.flutter.dev/get-started/install) 3.44 (canal estable) y el SDK de Android
- Un teléfono Android (con depuración USB) o un emulador
- Node.js 22 (solo si vas a correr las pruebas del backend)

## 1. Levantar el servidor

```bash
cp .env.ejemplo .env     # y cambia los valores "cambiar_…" (secretos con: openssl rand -base64 32)
docker compose up -d --build
curl http://localhost:8080/api/salud     # debe responder {"ok":true}
```

En `.env`, `CLAVE_MAESTRA` va vacía en el ejemplo: complétala con 32 bytes en base64. Si cambias `POSTGRES_PASSWORD`, actualiza también `DATABASE_URL`. Sin `SMTP_HOST` los enlaces de recuperación de contraseña y de confirmación de correos se imprimen en el log de la API (`docker compose logs api`).

## 2. Correr la app

```bash
flutter pub get
```

La app lee la dirección de la API con `--dart-define=API_URL=…` (por defecto `http://10.0.2.2:8080/api`, el PC visto desde el emulador de Android).

| Dónde la pruebas | Comando |
|---|---|
| Emulador Android | `flutter run` |
| Teléfono por USB | `adb reverse tcp:8080 tcp:8080` y luego `flutter run --dart-define=API_URL=http://localhost:8080/api` |
| Teléfono por Wi-Fi | `flutter run --dart-define=API_URL=http://<IP-del-PC>:8080/api` (mismo Wi-Fi y puerto 8080 abierto en el firewall) |

Para que los enlaces de la biblioteca funcionen desde el teléfono, pon la misma IP en `URL_PUBLICA` del `.env` y reinicia con `docker compose up -d api`.

## 3. Generar el APK

```bash
flutter build apk --release --dart-define=API_URL=http://<host>:<puerto>/api
```

Queda en `build/app/outputs/flutter-apk/app-release.apk`. Hoy el APK permite tráfico HTTP sin cifrar (`usesCleartextTraffic`); con HTTPS conviene quitarlo.

## Día a día

```bash
docker compose up -d          # encender (Docker Desktop abierto)
docker compose logs -f api    # ver qué pasa en la API
docker compose down           # apagar (los datos se conservan en el volumen)
```

Si cambias código del backend: `docker compose up -d --build api`.

## Ver la base de datos con DBeaver

Sirve para comprobar que los datos sensibles están cifrados.

1. Publica Postgres solo en tu PC: `cp docker-compose.override.yml.ejemplo docker-compose.override.yml` y luego `docker compose up -d`.
2. Instala [DBeaver Community](https://dbeaver.io/download/) → **Nueva conexión → PostgreSQL**.
3. Completa: Host `localhost`, Puerto `5432`, Base de datos y Usuario `oncuidar`, Contraseña la `POSTGRES_PASSWORD` de tu `.env`. Pulsa **Probar conexión** (acepta descargar el driver) y **Finalizar**.
4. Abre `oncuidar → Esquemas → public → Tablas`, doble clic en `pacientes` → pestaña **Datos**. Las columnas del objeto `cifrados` se ven como texto ilegible; el servidor nunca ve el nombre, el RUT ni el diagnóstico reales.

Tablas principales: `usuarios`, `pacientes`, `registros_clinicos`, `recordatorios`, `conversaciones`, `material_educativo`.

## Material educativo

Los archivos están en `backend/archivos/` (`videos/`, `infografias/`, `guias/`) y el catálogo en `backend/scripts/material_educativo.json`. Las miniaturas de los videos se generan solas con `ffmpeg`. Para agregar material: copia el archivo, añade su entrada al JSON y ejecuta:

```bash
docker compose up -d --build api && docker compose exec api node scripts/cargar_material.js
```

Los `.mp4` no se versionan en git por su peso: en un clon nuevo hay que copiarlos a `backend/archivos/videos/`.

## Pruebas

```bash
flutter analyze && flutter test                                   # app
docker compose -f docker-compose.pruebas.yml up -d                # Postgres de pruebas (puerto 5433)
cd backend && npm install && npm test                             # API
```

## Estructura

```
lib/        app Flutter (por funcionalidad: dominio / datos / presentación)
backend/    API REST, archivos y catálogo de la biblioteca
database/   esquema SQL de PostgreSQL
docs/       historias de usuario (HU.md)
tool/       script de humo contra la API (dart run tool/humo_api.dart)
```

Detalles de la API, variables y despliegue con Podman: [`backend/README.md`](backend/README.md).
