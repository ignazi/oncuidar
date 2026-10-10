# Bitácora de la migración de OnCuidar (Firebase → servidor propio)

Documento para retomar el trabajo en cualquier momento. Última actualización: 10-oct-2026.

## 1. Qué se hizo y por qué

El profesor pidió que la app no use Firebase y que se conecte al servidor de la universidad. Se creó una **copia independiente** del proyecto en `C:\Users\marig\Desktop\OnCuidar-Docker` (rama `docker/servidor-propio`, sin remoto: nunca se hace push). El proyecto original (`Universidad\PROYECTOTITULO\OnCuidar`, rama `refactor/arquitectura-por-capas`) quedó intacto con Firebase.

**Arquitectura nueva:** app Flutter → API REST (Node 22 + Express 5, JWT) → PostgreSQL 15, todo en Docker Compose. Los datos sensibles se cifran en el teléfono (AES-GCM) y el servidor solo guarda texto cifrado (columna `cifrados`, jsonb).

## 2. Qué incluye hoy

- **Backend** (`backend/`): registro, login, recuperar contraseña (correo principal y de respaldo), clave de datos por usuario, cuidador, pacientes, registros clínicos, recordatorios, chat, biblioteca y favoritos. **54 pruebas** (Jest + Postgres real).
- **App**: sin Firebase; cliente HTTP, sesión propia, cola sin conexión adaptada, caché local. **294 pruebas** de Flutter (se conservaron solo las relevantes).
- **Biblioteca (Aprende)**: 4 videos, 15 infografías y 1 guía. Archivos por carpeta en `backend/archivos/` (`videos/`, `infografias/`, `guias/`). Miniaturas de video automáticas con `ffmpeg`. Filtros: tipo (Todos/Videos/Guías/Infografías) + chip desplegable **Temas ▾** (10 temas, cada uno con su color; etiqueta arriba a la derecha de cada tarjeta).
- **Verificación de correos por enlace**: cambio de correo principal, correo de respaldo y registro (no bloquea el acceso). Insignias en el perfil.
- **Correos y páginas web con la identidad de OnCuidar**: plantilla con logo incrustado, modo oscuro y texto plano; páginas de restablecer contraseña y de confirmación.
- **Correo saliente**: Gmail (`oncuidar1@gmail.com`) con contraseña de aplicación, configurada en `.env`.
- **Documentación**: `README.md` (cómo levantar todo), `backend/README.md` (API y despliegue en Podman), `docs/HU.md` (historias de usuario actualizadas).

## 3. Cómo retomar (si se apagó el PC)

```bash
cd C:\Users\marig\Desktop\OnCuidar-Docker
# 1. Abrir Docker Desktop y esperar a que diga "running"
docker compose up -d
curl http://localhost:8080/api/salud        # debe responder {"ok":true}
git log --oneline -5                        # ver el último commit
```

- App en el celular: instalar el APK de `Desktop\OnCuidar.apk` (apunta a la IP del PC, `192.168.1.86:8080`; si cambió la IP hay que recompilar) o correr `flutter run` (ver README).
- Ver la base de datos: DBeaver, conexión `localhost:5432`, usuario y base `oncuidar`, contraseña = `POSTGRES_PASSWORD` del `.env`. Requiere `docker-compose.override.yml` (copia del `.ejemplo`).
- Compilar el APK: `flutter build apk --release --dart-define=API_URL=http://<IP>:8080/api`.

## 4. Secretos (dónde viven; no están en git)

- `.env` en la raíz (ignorado por git): contraseña de Postgres, JWT, clave maestra, HMAC y datos SMTP.
- La contraseña de aplicación de Gmail se pegó en el chat de trabajo: **conviene revocarla y crear otra** al terminar la demo (https://myaccount.google.com/apppasswords) y actualizar `SMTP_CLAVE` en `.env`.
- Nunca se guardan contraseñas de la cuenta de la universidad en este repositorio.

## 5. Servidor de la universidad (pendiente)

- Solicitud de cuenta **#1813**, servicio *Podman Tesistas*, servidor Parra (`parra.chillan.ubiobio.cl`, IP pública `146.83.196.166`, IP privada `10.10.6.22`). Estado al 10-oct: **Deshabilitada**; falta la activación y el correo con los **puertos asignados** (usar solo esos).
- Subida de archivos por SFTP al puerto 22 (clave SSH ya registrada). La app quedará en `http://parra.chillan.ubiobio.cl:<puerto>`.
- También existe un servicio PostgreSQL de la U (puerto 5432); hoy se usa Postgres propio en contenedor.

## 6. Pendientes

1. Esperar la activación y los puertos; desplegar con Podman (pasos en `backend/README.md`); subir también los `.mp4` (no van en git).
2. Probar desde el servidor que pueda **enviar correos** (puerto 465/587 hacia Gmail). Si está bloqueado: SMTP de la U o un servicio por HTTPS.
3. Compilar el APK definitivo con `API_URL` del servidor de la U y habilitar HTTP o conseguir HTTPS.
4. Web de descarga del APK (si dan un segundo puerto) o servirla desde la API.
5. Revisar en un celular real: filtros y colores de Aprende, insignias de correos, correos en Outlook/iPhone, modo sin conexión de punta a punta.
6. Pruebas nuevas para el cliente HTTP y la sesión; limitar la frecuencia de `/auth/cambiar-correo` y `/correo-respaldo`.
7. Revocar la contraseña de aplicación de Gmail y cambiar los secretos de producción.

## 7. Decisiones y cuidados

- Un commit local por cambio, en español y sin atribución a IA; **nunca push ni PR**.
- Los tests de Flutter se redujeron a los que no dependían de Firebase; se rehacen los de datos más adelante si hace falta.
- Un `.mp4` nuevo: copiarlo a `backend/archivos/videos/`, agregar su entrada a `backend/scripts/material_educativo.json` y ejecutar `docker compose up -d --build api && docker compose exec api node scripts/cargar_material.js`.
- La respuesta de recuperar contraseña siempre es `ok` aunque el correo no exista (evita revelar qué cuentas hay). Si no llega correo, revisa `docker compose logs api` y la bandeja de spam.
- Algunos servicios de correo abren los enlaces antes que el usuario y podrían gastar el token (riesgo conocido, sin resolver).

## 8. Historial de commits (rama `docker/servidor-propio`)

| Commit | Qué |
|---|---|
| 7d5e957 | Backend propio: API REST + PostgreSQL en Docker |
| 8c6bbcc | La app usa la API (sesión, cifrado, base segura, cola, repositorios) |
| 34f31bd | Se quita Firebase por completo; la biblioteca se sirve desde el backend |
| a9b682b | Se dejan solo las pruebas relevantes sin Firebase |
| ac1f375 | Se permite HTTP en la app para el servidor de pruebas |
| 76de92a | Se ignora el override local de compose |
| 027e4c5 | Material educativo real (4 videos, 15 infografías, 1 guía) |
| 092913d, 3e65074 | Filtro por tema; chip desplegable «Temas» |
| 1fa99a2 | Temas con nombres cortos y descripciones claras |
| 95cb59b | Archivos por carpetas y miniaturas de video automáticas |
| a84d254, ddea9c6 | Limpieza de archivos sin uso y documentación sin Firebase |
| c748ff6, cc9542f | Color por tema; etiqueta arriba a la derecha |
| 4c9e9b8, 9d00e77 | README (uso, DBeaver) |
| 1852103 | Verificación de correos por enlace |
| f02fafe | Correos y páginas web con la identidad de OnCuidar |
