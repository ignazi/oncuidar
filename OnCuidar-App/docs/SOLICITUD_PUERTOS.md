# Solicitud de puertos y condiciones del servidor para OnCuidar

Mensaje para enviar al profesor guía y/o a la administración del servidor. Completar los datos entre corchetes antes de enviarlo.

---

**Asunto:** Solicitud de puertos y confirmación de condiciones del servidor Parra · Proyecto de título OnCuidar · Cuenta #1813

Estimados:

Junto con saludar, les escribo por mi proyecto de título **OnCuidar**, una aplicación móvil de apoyo a cuidadores de niños, niñas y adolescentes con cáncer. Cuento con la solicitud de cuenta **#1813** del servicio *Podman Tesistas* (servidor Parra, `parra.chillan.ubiobio.cl`), que aparece como *Deshabilitada*. Les agradecería que la activen y que me indiquen los **puertos asignados**, ya que el servicio indica que solo se pueden usar los puertos entregados.

**Datos de la solicitud**
- Estudiante: [Nombre completo] · Correo institucional: [correo@alumnos.ubiobio.cl]
- Profesor responsable: Gastón Márquez Ortega
- Servicio: Podman Tesistas · Cuenta de usuario: [login asignado]

## 1. Puertos que necesito

| # | Uso | Obligatorio | Detalle |
|---|---|---|---|
| 1 | **API REST de la aplicación** | Sí | Un puerto TCP público. La app móvil se conecta a `http://parra.chillan.ubiobio.cl:<puerto>` |
| 2 | Panel de monitoreo (Uptime Kuma) | No | Un segundo puerto para revisar la disponibilidad del servicio. Si no es posible, el monitoreo se hace sin panel |
| 3 | Página de descarga del APK | No | Se puede servir desde el mismo puerto de la API; solo pediría un puerto adicional si prefieren separarlo |

La base de datos (PostgreSQL 15) corre en un contenedor dentro de la red interna de Podman, **sin puerto público**.

## 2. Preguntas sobre el entorno

1. **Contenedores:** ¿está instalado `podman compose` (o `podman-compose`)? ¿Qué versión de Podman hay?
2. **Servicios permanentes:** ¿puedo activar `loginctl enable-linger` para que los contenedores sigan corriendo al cerrar la sesión y se reinicien con el servidor? ¿Se permite Quadlet/systemd de usuario?
3. **Correo saliente:** la aplicación envía correos (verificación y recuperación de contraseña) por SMTP hacia `smtp.gmail.com`, puertos **465 o 587**. ¿Están permitidos desde el servidor? Si no, ¿existe un servidor SMTP de la universidad que pueda usar?
4. **HTTPS:** ¿es posible contar con un subdominio y certificado, o con un proxy inverso de la universidad? Hoy la aplicación se conecta por HTTP.
5. **Recursos:** ¿hay límites de memoria, CPU o espacio en disco por usuario? Necesito del orden de 1 GB de disco para imágenes, material educativo (videos) y respaldos.
6. **Respaldos:** ¿la universidad respalda el volumen de mi cuenta o debo respaldar yo la base de datos por mi cuenta?
7. **Base de datos:** el servicio *PostgreSQL* (puerto 5432) también aparece habilitado. Mi plan es usar PostgreSQL en un contenedor propio; ¿hay alguna objeción o preferencia?
8. **Acceso:** ¿la subida de archivos por SFTP al puerto 22 con mi clave pública ya registrada es suficiente para el despliegue, incluyendo ejecutar `podman` por SSH?

## 3. Resumen técnico del servicio

- **API:** Node.js 22 + Express 5, autenticación con JWT, un único contenedor.
- **Base de datos:** PostgreSQL 15 en contenedor, volumen persistente.
- **Seguridad:** los datos clínicos se cifran en el teléfono (AES-GCM) y el servidor solo guarda texto cifrado.
- **Tráfico esperado:** bajo (demostración y pruebas con pocos usuarios).
- **Contenedores:** 2 (API y base de datos), más 1 opcional de monitoreo.
- **Memoria estimada:** API ~256 MB, PostgreSQL ~256 MB, monitoreo ~100 MB.

Quedo a la espera de su respuesta. Muchas gracias por su ayuda.

Saludos cordiales,
[Nombre] · [Correo institucional] · [Teléfono]

---

### Notas internas (no incluir en el correo)

- La contraseña de la cuenta de la universidad **no** debe escribirse en este documento ni enviarse por correo.
- Cuando lleguen los puertos, anotarlos en `docs/BITACORA.md` y fijar `PUERTO_API` y `URL_PUBLICA` en el `.env` del servidor.
- Puertos de ejemplo del proyecto en local: API `8080`; PostgreSQL de pruebas `5433`; PostgreSQL de desarrollo `5432` (solo en `127.0.0.1`).
