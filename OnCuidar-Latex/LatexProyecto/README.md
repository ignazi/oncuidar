# Informe Final de Proyecto de Título — OnCuidar (LaTeX)

Plantilla y estructura LaTeX del **Informe Final de Proyecto de Título**
_OnCuidar: Aplicación móvil de apoyo educativo para cuidadores de niños, niñas y
adolescentes con cáncer_, desarrollada para el Departamento de Ciencias de la
Computación y Tecnología de la Información de la Universidad del Bío-Bío.

## Requisitos para compilar

- Distribución LaTeX actualizada (TeX Live 2021+ o MiKTeX).
- Paquetes usados: babel (spanish), geometry, setspace, graphicx, float, caption,
  subcaption, booktabs, longtable, tabularx, array, ragged2e, makecell,
  adjustbox, mathptmx, microtype, xcolor, amsmath, titlesec, fancyhdr, enumitem,
  needspace, listings, hyperref, tikz, natbib.
- Motores: `pdflatex` (compilación principal) + `bibtex` (bibliografía).

## Estructura de carpetas

```
LatexProyecto/
├── main.tex                  → documento principal (portada, resumen, índices, capítulos, bibliografía, anexos)
├── main.pdf                  → informe compilado
├── references.bib            → referencias BibTeX (estilo APA-like con natbib)
├── README.md
├── config/                   → paquetes, formato y comandos reutilizables
├── chapters/                 → capítulos 01-14 y anexos A-H (solo .tex)
├── figures/                  → imágenes que usa el informe (solo PNG)
│   ├── bpmn/                 → proceso de negocio futuro
│   ├── casos-uso/            → diagrama general y CU-06, 08, 09, 11, 12
│   ├── diseno/               → arquitectura y navegación
│   ├── mer/                  → modelo entidad-relación (y modelo lógico de referencia)
│   ├── mockups/              → capturas de la aplicación
│   └── logos, organigrama y proceso actual
└── drawio/                   → fuentes editables de los diagramas (abrir con draw.io)
    ├── bpmn/                 → bpmn-futuro.drawio
    ├── casos-uso/            → cu-general.drawio y cu-06 … cu-12
    ├── diseno/               → arquitectura.drawio, navegacion.drawio
    └── mer/                  → mer.drawio
```

## Cómo actualizar un diagrama

1. Abrir el `.drawio` correspondiente en `drawio/` y editarlo.
2. Exportar con *Archivo → Exportar como → PNG* (zoom 300-400 %, borde 12, fondo
   blanco) y reemplazar el PNG del mismo nombre en `figures/<carpeta>/`.
3. Recompilar el informe. El LaTeX solo lee los PNG; los `.drawio` no se
   incluyen en la compilación.

## Cómo compilar

En Windows PowerShell, desde `LatexProyecto/`:

```powershell
pdflatex main.tex
bibtex main
pdflatex main.tex
pdflatex main.tex
```

Con `latexmk` (recomendado):

```powershell
latexmk -pdf -interaction=nonstopmode main.tex
```

El PDF resultante es `main.pdf`. Para borrar los archivos temporales de
compilación (`.aux`, `.log`, `.toc`, …) se usa `latexmk -c` y se eliminan a mano
los `.aux` de `chapters/`.

## Cómo agregar contenido

### Capítulos
Crear el archivo en `chapters/` y agregar la línea `\include{chapters/XX-...}`
en `main.tex`, entre los `\include` existentes.

### Figuras
- Copiar la imagen (PNG) a la subcarpeta que corresponda de `figures/` (todas las rutas son relativas a `main.tex`).
- Insertar con:

```latex
\begin{figure}[H]
    \centering
    \safeincludegraphics[width=0.85\textwidth]{figures/mi-figura.png}
    \caption{Descripción de la figura.}
    \label{fig:mi-figura}
\end{figure}
```

- `\safeincludegraphics` muestra una caja "Imagen pendiente" si el archivo no
  existe, por lo que el documento siempre compila.

### Tablas
- Tablas normales: `tabularx` con columnas `Y` (flexible), `L{ancho}` o
  `R{ancho}` (definidas en `config/formatting.tex`) + `booktabs`.
- Tablas largas: `longtable` (ver capítulos 3, 6, 8, 9 y anexo E como ejemplo).
- Toda tabla debe llevar `\caption{}` y `\label{}`.

### Referencias
Agregar la entrada en `references.bib` y citar con:

```latex
\citep{clave}     % (Autor, año)
\citet{clave}     % Autor (año)
```

Luego compilar con `bibtex` (ver pasos anteriores).

## Cómo convertir a Word

- **Pandoc:** `pandoc main.tex -o informe.docx` (resultado razonable; revisar
  tablas `longtable` y los listados de código).
- El documento usa títulos reales LaTeX, tablas reales y figuras con
  `figure`/`caption`, lo que minimiza pérdidas en la conversión.
- La bibliografía (natbib) suele requerir ajuste manual tras la conversión.

## Errores comunes

| Error | Causa probable | Solución |
|---|---|---|
| `File not found` al incluir un capítulo | Ruta incorrecta en `\include` | Verificar nombre y ruta en `main.tex`. |
| `! LaTeX Error: File 'figures/...' not found` | Figura inexistente | El documento compila igual gracias a `\safeincludegraphics`; agregar la imagen en `figures/`. |
| Citas vacías `(?)` | Falta ejecutar `bibtex` | Correr `bibtex main` y recompilar. |
| Overfull hbox | Texto largo sin división | Revisar columnas (usar `Y` en lugar de columnas rígidas). |
| Longtable cortada | Encabezados repetidos sin `\endhead` | Verificar la estructura `\endfirsthead/\endhead`. |

## Contenido pendiente

El documento contiene marcadores explícitos que deben revisarse/completarse:

- `[COMPLETAR: ...]` — texto o dato pendiente.
- `[INSERTAR FIGURA: ...]` / `[INSERTAR TABLA: ...]` — figura o tabla pendiente
  (diagramas BPMN, casos de uso, mapa de navegación, carta Gantt, capturas).
- `% REVISAR` — comentarios LaTeX de fuentes bibliográficas o datos por
  verificar (títulos de artículos, productividad UCP, plazos del piloto).