# Oncuidar — Guía de Setup del Entorno

> **Instrucciones para el yo del futuro (y para cualquier agente de IA que trabaje en este repo):**
> si esta máquina fue formateada o estás en una máquina nueva, esta guía te dice EXACTAMENTE
> qué instalar y cómo verificar que todo funciona. No improvises versiones: usá las de abajo.

---

## 1. Contexto del proyecto

| Dato | Valor |
|------|-------|
| Tipo | App **Flutter** + **Firebase** (apoyo al cuidado oncológico pediátrico) |
| Repo | `https://github.com/ignazi/oncuidar` |
| Rama de trabajo | **`Changes`** (no `main`) — acá viven todos los cambios recientes |
| CI | `.github/workflows/flutter-ci.yml` — corre `flutter analyze` + tests (422 tests) |
| Package name | `cl.zapataramirez.oncuidar` |
| Estado del release | Usa **debug signing** (hay TODO pendiente en `android/app/build.gradle.kts`) — no existe keystore de release que respaldar |

---

## 2. ⚠️ ANTES DE FORMATEAR (si todavía estás a tiempo)

1. **`android/app/google-services.json`** — es el único archivo crítico que NO está en GitHub.
   - Respaldarlo (USB, nube, lo que sea).
   - Si se pierde: regenerar en [Firebase Console](https://console.firebase.google.com)
     → Configuración del proyecto → tu app Android → descargar `google-services.json`.
   - Sin este archivo, la app **NO compila** (el plugin `com.google.gms.google-services` falla).
2. Verificar que el repo esté 100% pusheado a la rama `Changes` (nada local sin subir).
3. No hay keystores que respaldar (ver punto 1 de la tabla).

---

## 3. Stack y versiones exactas

| Componente | Versión | ¿Se instala a mano? |
|------------|---------|---------------------|
| Flutter | canal **stable** (cualquier versión reciente) | ✅ Sí |
| Dart SDK | `^3.12.2` (viene con Flutter) | ✅ Sí (incluido) |
| Java / JDK | **17** (`sourceCompatibility = VERSION_17`) | ✅ Sí |
| Android Studio | Última estable | ✅ Sí |
| Android SDK Platform | La más reciente (`flutter.compileSdkVersion`) | ✅ Sí (vía Studio) |
| Android SDK Build-Tools | Incluido | ✅ Sí (vía Studio) |
| Android SDK Command-line Tools | Incluido | ✅ Sí (vía Studio) |
| NDK | `flutter.ndkVersion` (la que pida Flutter) | ✅ Sí (vía Studio) |
| Gradle | 9.1.0 | ❌ No — auto-descarga (wrapper) |
| Android Gradle Plugin | 9.0.1 | ❌ No — se baja solo |
| Kotlin | 2.3.20 | ❌ No — se baja solo |
| Git | Última | ✅ Sí |

**Regla de oro:** Gradle, AGP y Kotlin los resuelve el proyecto solo. Lo único manual es:
**Git, JDK 17, Flutter, Android Studio + SDK, y el `google-services.json`.**

---

## 4. Instalación paso a paso (Windows)

### Paso 1 — Git
- [git-scm.com/downloads](https://git-scm.com/downloads)
- Opciones por defecto, activar **"Add to PATH"** (Git Bash option, etc.).

### Paso 2 — JDK 17
- [Temurin 17 (Adoptium)](https://adoptium.net/temurin/releases/?version=17) — elegir Windows x64.
- Configurar variable de entorno:
  - `JAVA_HOME` → `C:\Program Files\Eclipse Adoptium\jdk-17.x.x.x-hotspot` (o donde se instale)
  - Agregar `%JAVA_HOME%\bin` al `PATH`.
- **OJO:** no usar el JBR (JetBrains Runtime) de Android Studio como `JAVA_HOME` — usar el JDK 17 explícito.

### Paso 3 — Flutter SDK
- Descargar del [sitio oficial de Flutter](https://docs.flutter.dev/get-started/install/windows/mobile) — canal **stable**.
- Extraer en una ruta **sin espacios ni caracteres raros** (recomendado: `C:\src\flutter`).
- Agregar `flutter\bin` al `PATH`.
- La versión exacta da igual mientras sea stable reciente: el proyecto exige `sdk: ^3.12.2`
  (lo cumple cualquier stable actual).

### Paso 4 — Android Studio
- [developer.android.com/studio](https://developer.android.com/studio) — última estable.
- En **SDK Manager** (Settings → Languages & Frameworks → Android SDK) instalar:
  - Android SDK Platform (la más reciente)
  - Android SDK Build-Tools
  - Android SDK Command-line Tools
  - NDK (la versión que pida Flutter)
- Aceptar licencias:
  ```powershell
  flutter doctor --android-licenses
  ```

### Paso 5 — Editor
- **VS Code** + extensiones **Flutter** y **Dart** (recomendado para trabajar con agentes de IA),
  o directamente **Android Studio**. A gusto del usuario.

---

## 5. Post-instalación — levantar la app

```powershell
# 1. Clonar (y usar la rama de trabajo)
git clone https://github.com/ignazi/oncuidar.git
cd oncuidar
git checkout Changes

# 2. Restaurar la configuración de Firebase
#    → pegar google-services.json en: android\app\google-services.json

# 3. Dependencias
flutter pub get

# 4. Verificar entorno
flutter doctor

# 5. Correr la app (con un emulador/device conectado)
flutter run
```

---

## 6. Verificación — ¿está todo bien?

```powershell
flutter doctor          # debe salir todo ✅ (o al menos Android toolchain ✅)
flutter analyze         # 0 errores, 0 warnings
flutter test            # 422 tests, todos pasando
```

Si `flutter analyze` o `flutter test` dan problemas en una máquina nueva, **NO es por la máquina** —
primero descartar: `flutter clean` + `flutter pub get` y reintentar.

---

## 7. Troubleshooting / Gotchas

| Problema | Causa probable | Solución |
|----------|----------------|----------|
| `flutter doctor` muestra Android toolchain con ✗ | Licencias sin aceptar / SDK incompleto | `flutter doctor --android-licenses`, instalar SDK Platform en SDK Manager |
| Error de Firebase / `google-services.json` no encontrado | Archivo no restaurado | Respaldarlo o regenerarlo en Firebase Console (sección 2) |
| Error de Java version / `Unsupported class file major version` | `JAVA_HOME` apunta a JDK equivocado (ej: 21 en vez de 17) | Revisar `JAVA_HOME` → JDK 17, reiniciar terminal |
| Primer `flutter run` tarda MUCHO | Gradle 9.1.0 se está descargando (primera vez) | Paciencia — es normal, las siguientes builds son más rápidas |
| `flutter: command not found` | PATH mal configurado | Agregar `flutter\bin` al PATH y reiniciar terminal |
| App compila pero Firebase da errores en runtime | `google-services.json` de otra app / package mismatch | Verificar que el package sea `cl.zapataramirez.oncuidar` |
| Tests fallan solo en máquina nueva | Dependencias corruptas / caché | `flutter clean` + `flutter pub get` |

---

## 8. Comandos de referencia rápida

```powershell
flutter doctor            # diagnóstico del entorno
flutter pub get           # instalar dependencias
flutter clean             # limpiar build
flutter analyze           # análisis estático (debe dar 0 issues)
flutter test              # suite completa de tests
flutter run               # correr en device/emulador
flutter build apk         # build de debug/release APK
dart run flutter_launcher_icons  # regenerar íconos si cambia el logo
```

---

*Última actualización: 2026-07-31 — basada en el análisis real del repo (pubspec.yaml, android/settings.gradle.kts, android/app/build.gradle.kts, gradle-wrapper.properties).*
