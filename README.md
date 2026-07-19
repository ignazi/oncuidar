# Oncuidar

Apoyo al cuidado oncológico pediátrico — aplicación móvil para cuidadores de pacientes pediátricos con cáncer.

## Descripción

Oncuidar ayuda a los cuidadores a registrar y monitorear la salud diaria de sus pacientes, manteniendo una bitácora completa con alertas inteligentes y acceso rápido a información educativa.

### Funcionalidades principales

- **Dashboard** — resumen de signos vitales, acceso rápido a módulos
- **Registro Diario** — captura de temperatura, presión arterial, peso, y nivel de síntomas (1-10)
- **Motor de Alertas** — semáforo clínico (verde/amarillo/rojo) basado en reglas predefinidas
- **Historial** — consulta de registros pasados con filtros por nivel de alerta
- **Orientación Guiada** — chat con sugerencias inteligentes para cuidados básicos
- **Biblioteca Educativa** — artículos, videos, guías y PDFs sobre cuidados oncológicos
- **Preguntas Frecuentes** — 8 preguntas comunes con respuestas detalladas
- **Recordatorios** — alarmas para medicamentos, mediciones y citas médicas
- **Perfil** — datos del cuidador, paciente, centro de salud y contacto de emergencia

## Requisitos

- Flutter SDK `^3.12.2`
- Dart SDK `^3.12.2`
- Firebase project con Auth, Firestore, Messaging y Storage habilitados
- Android Studio o VS Code con plugins de Flutter

## Instalación

### 1. Clonar el repositorio

```bash
git clone https://github.com/tu-usuario/oncuidar.git
cd oncuidar
```

### 2. Instalar dependencias

```bash
flutter pub get
```

### 3. Configurar Firebase

El proyecto usa FlutterFire CLI. Si necesitas regenerar la configuración:

```bash
flutterfire configure
```

Esto genera `lib/firebase_options.dart` con las credenciales de tu proyecto Firebase.

### 4. Configurar iconos de la app

```bash
dart run flutter_launcher_icons
```

### 5. Ejecutar

```bash
flutter run
```

## Estructura del proyecto

```
lib/
├── main.dart                      # Punto de entrada
├── firebase_options.dart          # Configuración Firebase (generado)
│
├── core/
│   ├── theme/
│   │   ├── app_colors.dart        # Design tokens de colores
│   │   ├── app_spacing.dart       # Espaciado consistente
│   │   └── app_theme.dart         # Tema Material Design 3
│   ├── services/
│   │   ├── clinical_rules_engine.dart  # Motor de alertas clínicas
│   │   └── firestore_test.dart    # Test de conexión Firestore
│   ├── widgets/
│   │   ├── alert_badge.dart       # Badge de nivel de alerta
│   │   ├── chat_bubble.dart       # Burbuja de chat
│   │   ├── disclaimer_text.dart   # Texto de descargo
│   │   ├── empty_state.dart       # Estado vacío reutilizable
│   │   ├── gradient_header.dart   # Header con gradiente dorado
│   │   └── vital_sign_card.dart   # Card de signo vital
│   └── constants/
│
├── features/
│   ├── onboarding/
│   │   ├── splash_screen.dart     # Pantalla de carga
│   │   ├── welcome_screen.dart    # Bienvenida
│   │   ├── login_screen.dart      # Inicio de sesión
│   │   └── registration_screen.dart # Registro de usuario
│   ├── dashboard/
│   │   └── dashboard_screen.dart  # Panel principal
│   ├── daily_record/
│   │   └── daily_record_screen.dart # Registro diario
│   ├── history/
│   │   └── history_screen.dart    # Historial de registros
│   ├── orientation/
│   │   └── orientation_screen.dart # Chat de orientación
│   ├── library/
│   │   ├── library_screen.dart    # Biblioteca educativa
│   │   └── article_detail_screen.dart # Detalle de artículo
│   ├── faq/
│   │   └── faq_screen.dart        # Preguntas frecuentes
│   ├── reminders/
│   │   └── reminders_screen.dart  # Recordatorios
│   └── profile/
│       └── profile_screen.dart    # Perfil de usuario
│
├── models/
│   ├── alert_level.dart           # Niveles de alerta (normal, alert, critical)
│   ├── app_user.dart              # Modelo de usuario
│   ├── daily_record.dart          # Registro diario
│   ├── educational_content.dart   # Contenido educativo
│   ├── orientation_rule.dart      # Reglas de orientación
│   ├── patient.dart               # Modelo de paciente
│   ├── reminder.dart              # Recordatorio
│   ├── symptom_entry.dart         # Entrada de síntomas
│   └── vital_signs.dart           # Signos vitales
│
└── router/
    └── app_router.dart            # GoRouter con ShellRoute
```

## Design System

### Paleta de colores

| Token | Color | Uso |
|-------|-------|-----|
| `goldPrimary` | `#C9A84C` | Acentos principales, botones |
| `goldLight` | `#F5E6B8` | Fondos sutiles, badges |
| `goldDark` | `#A67C2E` | Gradientes, texto en fondos claros |
| `creamBg` | `#FDF8EE` | Fondo principal de la app |
| `cardBg` | `#F5EFE6` | Fondos de cards |
| `cardBgWarm` | `#FBF5E8` | Cards alternados |
| `textPrimary` | `#2D2D2D` | Texto principal |
| `textSecondary` | `#6B6B6B` | Texto secundario |
| `alertGreen` | `#4CAF50` | Estado normal |
| `alertYellow` | `#FFA726` | Estado de alerta |
| `alertRed` | `#D32F2F` | Estado crítico |

### Tipografía

- **Poppins** — títulos de marca (splash, welcome)
- **Nunito** — todo el resto de la interfaz

### Componentes reutilizables

- `GradientHeader` — header con gradiente dorado y ola decorativa
- `VitalSignCard` — card para mostrar signos vitales
- `AlertBadge` — badge con color según nivel de alerta
- `ChatBubble` — burbujas de chat para orientación
- `EmptyState` — estado vacío con ícono y mensaje
- `DisclaimerText` — texto de descargo de responsabilidad

## Navegación

La app usa **GoRouter** con **ShellRoute** para la navegación principal:

- **Onboarding** — stack independiente (splash → welcome → login/registro)
- **Dashboard** — BottomAppBar con 4 tabs + FAB central para registro diario
- **Pantallas internas** — navegación tipo stack con back button

### Tabs principales

1. 🏠 Inicio (Dashboard)
2. 📊 Historial
3. 📚 Biblioteca (centro del FAB)
4. ❓ FAQ
5. 👤 Perfil

## Firebase

### Servicios utilizados

| Servicio | Versión | Uso |
|----------|---------|-----|
| `firebase_core` | 4.12.0 | Inicialización |
| `firebase_auth` | 6.5.4 | Autenticación (email/password) |
| `cloud_firestore` | 6.6.0 | Base de datos |
| `firebase_messaging` | 16.4.1 | Notificaciones push |
| `firebase_storage` | 13.4.4 | Almacenamiento de archivos |

### Reglas de Firestore

Las reglas están configuradas para permitir:
- Lectura/escritura de registros diarios por usuario autenticado
- Lectura de contenido educativo y FAQs
- Escritura de recordatorios por usuario

## Build

### APK (desarrollo/distribución directa)

```bash
flutter build apk --release
```

El archivo se genera en: `build/app/outputs/flutter-apk/app-release.apk`

### App Bundle (Google Play)

```bash
flutter build appbundle --release
```

## Versión

- **1.0.0** — Versión inicial con todas las funcionalidades UI completas

## Licencia

Proyecto privado — Todos los derechos reservados.
