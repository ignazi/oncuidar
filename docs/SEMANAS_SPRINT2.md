# Estructura de ramas — Sprint 2 (Semanas)

Este repositorio organiza el avance del **Sprint 2** de OnCuidar en ramas
por semana, agrupadas bajo la rama paraguas `Semanas`:

| Rama | Contenido |
| --- | --- |
| `Semanas` | Rama paraguas con este documento y la base del sprint 2. |
| `Semanas/semana-3` | Estado real del respaldo de las semanas 1 a 3 (dashboard, exportación PDF/Excel, biblioteca, videos, guías, checklists y offline). |
| `Semanas/semana-4` | Chat de orientación, preguntas frecuentes (FAQ) y mejoras de interfaz (favoritos de biblioteca, header). |
| `Semanas/semana-5` | Recordatorios, notificaciones locales y conexión final de rutas (chat, FAQ y recordatorios accesibles desde la navegación). |

## Semanas 1 y 2

El avance de las semanas 1 y 2 quedó guardado en un único commit de
respaldo (`feat: respaldo estado actual sprint 2`), por lo que no es
posible separarlo sin inventar estados intermedios. Su contenido se
documenta aquí y vive en `Semanas/semana-3`:

- **Semana 1** — Dashboard (panel del cuidador) y exportación de
  historial clínico a PDF y Excel.
- **Semana 2** — Biblioteca educativa con materiales descargables.

## Cómo ver el avance por semana

El avance real de cada semana es el *diff* entre ramas consecutivas:

```bash
# Semana 4 (todo lo agregado sobre la semana 3)
git diff Semanas/semana-3 Semanas/semana-4

# Semana 5 (todo lo agregado sobre la semana 4)
git diff Semanas/semana-4 Semanas/semana-5
```

## Convenciones

- Commits en español con prefijo conventional (`feat:`, `docs:`).
- El contenido sensible (datos clínicos cifrados, reglas de Firestore,
  notificaciones) respeta el esquema de cifrado del proyecto.