# -*- coding: utf-8 -*-
"""Genera drawio/mer/mer.drawio (MER de Chen, escala de grises) y verifica choques.
Uso: python generar_mer.py
Luego exportar: draw.io -x -f png -s 3 -b 12 -o figures/mer/mer.png drawio/mer/mer.drawio
"""
import os
import sys
from xml.sax.saxutils import escape

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
SALIDA = os.path.join(RAIZ, 'drawio', 'mer', 'mer.drawio')
TINTA = '#262626'
FUENTE = 12
celdas = []
cajas = []
cont = [10]


def nid(p='n'):
    cont[0] += 1
    return f'{p}{cont[0]}'


def vert(txt, cx, cy, w, h, estilo, tipo, nombre):
    i = nid()
    v = txt.replace('&', '&amp;').replace('"', '&quot;').replace('\n', '&lt;br&gt;') if '<' not in txt else escape(txt, {'"': '&quot;'})
    celdas.append(f'<mxCell id="{i}" value="{v}" style="{estilo}" vertex="1" parent="1">'
                  f'<mxGeometry x="{cx - w / 2:.0f}" y="{cy - h / 2:.0f}" width="{w}" height="{h}" as="geometry"/></mxCell>')
    cajas.append((tipo, nombre, cx - w / 2, cy - h / 2, w, h))
    return i


def arista(a, b):
    i = nid('e')
    celdas.append(f'<mxCell id="{i}" style="endArrow=none;html=1;strokeColor={TINTA};strokeWidth=1.5;rounded=0;" '
                  f'edge="1" parent="1" source="{a}" target="{b}"><mxGeometry relative="1" as="geometry"/></mxCell>')
    return i


def etiqueta(ar, txt, pos):
    i = nid('l')
    celdas.append(f'<mxCell id="{i}" value="{txt}" style="edgeLabel;html=1;align=center;verticalAlign=middle;fontSize=14;'
                  f'fontStyle=1;labelBackgroundColor=#FFFFFF;fontColor=#1A1A1A;" vertex="1" connectable="0" parent="{ar}">'
                  f'<mxGeometry relative="1" x="{pos}" as="geometry"><mxPoint as="offset"/></mxGeometry></mxCell>')


ENT = {}


def entidad(k, txt, cx, cy, debil=False):
    w, h = 150, 54
    est = (f'html=1;whiteSpace=wrap;strokeColor={TINTA};fontColor=#1A1A1A;fillColor=#F1F1F1;fontStyle=1;'
           f'fontSize=14;strokeWidth=2;' + ('shape=ext;double=1;margin=4;' if debil else ''))
    ENT[k] = (vert(txt, cx, cy, w, h, est, 'ent', txt), cx, cy)


def relacion(txt, cx, cy, w=140, h=72, debil=False):
    est = (f'html=1;whiteSpace=wrap;strokeColor={TINTA};fontColor=#1A1A1A;fillColor=#FFFFFF;fontSize=13;strokeWidth=1.5;'
           + ('shape=rhombus;double=1;' if debil else 'rhombus;'))
    return vert(txt, cx, cy, w, h, est, 'rel', txt)


def rel(txt, a, b, ca, cb, cx=None, cy=None, **kw):
    cx = (ENT[a][1] + ENT[b][1]) / 2 if cx is None else cx
    cy = (ENT[a][2] + ENT[b][2]) / 2 if cy is None else cy
    r = relacion(txt, cx, cy, **kw)
    e1, e2 = arista(ENT[a][0], r), arista(r, ENT[b][0])
    etiqueta(e1, ca, 0.5)
    etiqueta(e2, cb, 0.5)
    return r, cx, cy


def atr(txt, cx, cy, clave=False, parcial=False, multi=False, derivado=False):
    w = max(52, int(len(txt) * 7.4 + 26)) + (12 if multi else 0)
    v = escape(txt)
    if clave:
        v = f'<u>{v}</u>'
    if parcial:
        v = f'<span style="text-decoration: underline dashed;">{v}</span>'
    est = (f'html=1;whiteSpace=wrap;strokeColor={TINTA};fontColor=#1A1A1A;fillColor=#FFFFFF;fontSize={FUENTE};strokeWidth=1;'
           + ('shape=doubleEllipse;' if multi else 'ellipse;') + ('dashed=1;' if derivado else ''))
    return vert(v, cx, cy, w, 26, est, 'atr', txt)


def atributos(k, lista, destino=None):
    """lista: (texto, dx, dy, opciones); destino: id al que se une (por defecto la entidad)."""
    eid, cx, cy = ENT[k] if destino is None else destino
    for t, dx, dy, op in lista:
        a = atr(t, cx + dx, cy + dy, **op)
        arista(a, eid)


def choques():
    n = 0
    for i in range(len(cajas)):
        for j in range(i + 1, len(cajas)):
            a, b = cajas[i], cajas[j]
            if a[2] < b[2] + b[4] + 8 and b[2] < a[2] + a[4] + 8 and a[3] < b[3] + b[5] + 6 and b[3] < a[3] + a[5] + 6:
                print('CHOQUE:', a[1], '<->', b[1])
                n += 1
    return n


K = dict(clave=True)
YT, YB = 380, 980
entidad('men', 'MENSAJE', 150, YT, debil=True)
entidad('con', 'CONVERSACIÓN', 520, YT)
entidad('cui', 'CUIDADOR', 960, YT)
entidad('mat', 'MATERIAL EDUCATIVO', 1400, YT)
entidad('rec', 'RECORDATORIO', 430, YB)
entidad('pac', 'PACIENTE', 960, YB)
entidad('reg', 'REGISTRO CLÍNICO', 1440, YB)
entidad('sin', 'SÍNTOMA', 1830, YB)

rel('Contiene', 'men', 'con', 'N', '1', debil=True)
rel('Inicia', 'con', 'cui', 'N', '1')
rel('Marca como\nfavorito', 'cui', 'mat', 'N', 'M', h=84, w=150)
rel('Programa', 'cui', 'rec', '1', 'N', cx=700, cy=680)
rel('Atiende', 'cui', 'pac', '1', 'N')
rel('Posee', 'pac', 'reg', '1', 'N')
inc = rel('Incluye', 'reg', 'sin', 'N', 'M', w=130)

atributos('men', [('Orden', -75, -85, dict(parcial=True)), ('Texto', 0, -150, {}), ('Emisor', 75, -85, {})])
atributos('con', [('ID conversación', -140, -85, K), ('Título', 0, -155, {}), ('Última actividad', 85, -85, {})])
atributos('cui', [('ID cuidador', -215, -75, K), ('Nombre completo', -105, -150, {}), ('Correo electrónico', 0, -225, {}),
                  ('Teléfono', 105, -150, {}), ('Parentesco', 215, -75, {}),
                  ('Correo verificado', 255, 75, {}), ('Correo de respaldo', 115, 115, {})])
atributos('mat', [('ID material', -105, -80, K), ('Título', 0, -150, {}), ('Categoría', 120, -80, {}),
                  ('Tipo de archivo', 260, 0, {})])
atributos('rec', [('ID recordatorio', -190, -80, K), ('Fecha y hora', -250, 10, {}), ('Título', -135, 75, {}),
                  ('Días de repetición', 0, 140, dict(multi=True)), ('Tipo', 135, 75, {}),
                  ('Dirigido a', 205, -75, {}), ('Activo', 240, 10, {})])
atributos('pac', [('ID paciente', -140, -85, K), ('Edad', 140, -85, {}),
                  ('Nombre completo', -200, 70, {}), ('Fase de tratamiento', 185, 70, {}),
                  ('RUT', -105, 140, {}), ('Diagnóstico', 105, 140, {}),
                  ('Centro de salud', 0, 210, {}), ('Contacto de emergencia', -250, 210, {})])
atributos('reg', [('ID registro', -130, -85, K),
                  ('Fecha', -150, 70, {}), ('Nivel de alerta', 150, 70, dict(derivado=True)),
                  ('Tipo de registro', -80, 140, {}), ('Observaciones', 80, 140, {})])
# atributo compuesto: Signos vitales (se une a Registro clínico)
sv = atr('Signos vitales', 1440, 830)
arista(sv, ENT['reg'][0])
atributos('reg', [('Temperatura', -190, -40, {}), ('Frecuencia cardíaca', -80, -130, {}),
                  ('Saturación de oxígeno', 120, -130, {}), ('Frecuencia respiratoria', 250, -40, {})],
          destino=(sv, 1440, 830))
# relación Incluye: atributos de la relación
atributos('reg', [('Intensidad', 1630 - 1440, 900 - 980, {}), ('Nota', 1745 - 1440, 900 - 980, {})],
          destino=(inc[0], inc[1], inc[2]))
atributos('sin', [('ID síntoma', -60, 80, K), ('Nombre', 60, 80, {})])

# leyenda
leyenda = ('<b>Simbología</b><br>Rectángulo: entidad<br>Rectángulo doble: entidad débil<br>Rombo: relación<br>'
           '<u>Atributo</u>: clave primaria<br>Subrayado discontinuo: clave parcial<br>Elipse doble: multivaluado<br>'
           'Elipse discontinua: derivado<br>1, N, M: cardinalidad de la relación')
li = nid('leyenda')
celdas.append(f'<mxCell id="{li}" value="{escape(leyenda, {chr(34): "&quot;"})}" style="html=1;whiteSpace=wrap;align=left;'
              f'verticalAlign=top;strokeColor=#BBBBBB;fontSize=12;spacing=8;fillColor=#FFFFFF;" vertex="1" parent="1">'
              f'<mxGeometry x="40" y="560" width="250" height="200" as="geometry"/></mxCell>')

n = choques()
xml = ('<mxfile host="Electron"><diagram name="MER OnCuidar" id="mer-oncuidar"><mxGraphModel dx="1088" dy="724" grid="1" '
       'gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="2200" '
       'pageHeight="1400" math="0" shadow="0"><root><mxCell id="0"/><mxCell id="1" parent="0"/>'
       + ''.join(celdas) + '</root></mxGraphModel></diagram></mxfile>')
with open(SALIDA, 'w', encoding='utf-8') as f:
    f.write(xml)
print('escrito', SALIDA, 'choques:', n)
sys.exit(1 if n else 0)
