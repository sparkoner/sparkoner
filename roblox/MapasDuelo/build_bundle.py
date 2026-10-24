"""Genera los scripts para pegar en la barra de comandos de Studio:

- ConstruirMapas.luau: crea ServerStorage.MapBuilder (ModuleScript con sus mapas), construye los
  mapas de duelo en ServerStorage.MapasDuelo y coloca uno en Workspace para verlo.
- ConstruirMundoAbierto.luau: crea ServerStorage.MapBuilder y ServerStorage.MundoAbierto y pone el
  mundo abierto (con su terreno) en Workspace.
Uso: python3 build_bundle.py
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, 'MapBuilder')


def long_string(text):
    level = 1
    while ('[' + '=' * level + '[') in text or (']' + '=' * level + ']') in text:
        level += 1
    eq = '=' * level
    return f'[{eq}[\n{text}]{eq}]'


maps = sorted(f[:-5] for f in os.listdir(os.path.join(SRC, 'Mapas')) if f.endswith('.luau'))
init = open(os.path.join(SRC, 'init.luau'), encoding='utf-8').read()
parts = [
    '-- Pega TODO este texto en la barra de comandos de Roblox Studio (Ver > Barra de comandos) y pulsa Enter.',
    '-- Crea ServerStorage.MapBuilder y los mapas en ServerStorage.MapasDuelo.',
    '-- Archivo generado por build_bundle.py: edita los .luau de MapBuilder/ y vuelve a generarlo.',
    '',
    f'local VER_MAPA = "{"Gasolinera" if "Gasolinera" in maps else maps[0]}" -- mapa que se coloca en Workspace para verlo (pon nil para ninguno)',
    '',
    'local ServerStorage = game:GetService("ServerStorage")',
    'local FUENTE_MAPBUILDER = ' + long_string(init),
    'local FUENTE_PROPS = ' + long_string(open(os.path.join(SRC, 'Props.luau'), encoding='utf-8').read()),
    'local FUENTES_MAPAS = {}',
]
for name in maps:
    code = open(os.path.join(SRC, 'Mapas', name + '.luau'), encoding='utf-8').read()
    parts.append(f'FUENTES_MAPAS["{name}"] = ' + long_string(code))
parts += [
    '',
    'local anterior = ServerStorage:FindFirstChild("MapBuilder")',
    'if anterior then anterior:Destroy() end',
    'local modulo = Instance.new("ModuleScript")',
    'modulo.Name = "MapBuilder"',
    'modulo.Source = FUENTE_MAPBUILDER',
    'local props = Instance.new("ModuleScript")',
    'props.Name = "Props"',
    'props.Source = FUENTE_PROPS',
    'props.Parent = modulo',
    'local carpeta = Instance.new("Folder")',
    'carpeta.Name = "Mapas"',
    'carpeta.Parent = modulo',
    'for nombre, fuente in pairs(FUENTES_MAPAS) do',
    '\tlocal mapa = Instance.new("ModuleScript")',
    '\tmapa.Name = nombre',
    '\tmapa.Source = fuente',
    '\tmapa.Parent = carpeta',
    'end',
    'modulo.Parent = ServerStorage',
    '',
    'local MapBuilder = require(modulo)',
    '-- La iluminación Future da sombras a las luces y brillo al neón',
    'pcall(function() game:GetService("Lighting").Technology = Enum.Technology.Future end)',
    'MapBuilder.buildAll()',
    'if VER_MAPA then',
    '\tMapBuilder.load(VER_MAPA)',
    'end',
    'print("Mapas de duelo creados en ServerStorage.MapasDuelo. Mapa en Workspace: " .. tostring(VER_MAPA))',
    '',
]
out = os.path.join(HERE, 'ConstruirMapas.luau')
open(out, 'w', encoding='utf-8').write('\n'.join(parts))
print('Generado', out, '-', len(maps), 'mapas:', ', '.join(maps))

# ---------------------------------------------------------------------
#  Mundo abierto
# ---------------------------------------------------------------------
WORLD = os.path.join(HERE, 'MundoAbierto')
zones = sorted(f[:-5] for f in os.listdir(os.path.join(WORLD, 'Zonas')) if f.endswith('.luau'))
parts = [
    '-- Pega TODO este texto en la barra de comandos de Roblox Studio (Ver > Barra de comandos) y pulsa Enter.',
    '-- Crea ServerStorage.MapBuilder y ServerStorage.MundoAbierto y pone el mundo abierto en Workspace.',
    '-- OJO: borra el terreno que haya en este lugar. Úsalo mejor en un lugar nuevo.',
    '-- Archivo generado por build_bundle.py: edita los .luau de MapBuilder/ y MundoAbierto/ y vuelve a generarlo.',
    '',
    'local ServerStorage = game:GetService("ServerStorage")',
    'local FUENTE_MAPBUILDER = ' + long_string(init),
    'local FUENTE_PROPS = ' + long_string(open(os.path.join(SRC, 'Props.luau'), encoding='utf-8').read()),
    'local FUENTE_MUNDO = ' + long_string(open(os.path.join(WORLD, 'init.luau'), encoding='utf-8').read()),
    'local FUENTE_DATOS = ' + long_string(open(os.path.join(WORLD, 'Mundo.luau'), encoding='utf-8').read()),
    'local FUENTES_ZONAS = {}',
]
for name in zones:
    parts.append(f'FUENTES_ZONAS["{name}"] = ' + long_string(open(os.path.join(WORLD, 'Zonas', name + '.luau'), encoding='utf-8').read()))
parts += [
    '',
    'local function modulo(nombre, fuente, padre)',
    '\tlocal m = Instance.new("ModuleScript")',
    '\tm.Name = nombre',
    '\tm.Source = fuente',
    '\tm.Parent = padre',
    '\treturn m',
    'end',
    '',
    '-- MapBuilder (si ya existía, conserva sus mapas de duelo)',
    'local mapBuilder = modulo("MapBuilder", FUENTE_MAPBUILDER)',
    'modulo("Props", FUENTE_PROPS, mapBuilder)',
    'local anterior = ServerStorage:FindFirstChild("MapBuilder")',
    'if anterior then',
    '\tlocal mapas = anterior:FindFirstChild("Mapas")',
    '\tif mapas then mapas.Parent = mapBuilder end',
    '\tanterior:Destroy()',
    'end',
    'mapBuilder.Parent = ServerStorage',
    '',
    '-- MundoAbierto con sus datos y una carpeta de zonas',
    'local viejo = ServerStorage:FindFirstChild("MundoAbierto")',
    'if viejo then viejo:Destroy() end',
    'local mundo = modulo("MundoAbierto", FUENTE_MUNDO)',
    'modulo("Mundo", FUENTE_DATOS, mundo)',
    'local carpeta = Instance.new("Folder")',
    'carpeta.Name = "Zonas"',
    'carpeta.Parent = mundo',
    'for nombre, fuente in pairs(FUENTES_ZONAS) do',
    '\tmodulo(nombre, fuente, carpeta)',
    'end',
    'mundo.Parent = ServerStorage',
    '',
    'local MapBuilder = require(mapBuilder)',
    'pcall(function() game:GetService("Lighting").Technology = Enum.Technology.Future end)',
    '-- Con un mapa tan grande, cada jugador carga solo lo que tiene cerca',
    'pcall(function() workspace.StreamingEnabled = true end)',
    'print("Construyendo el mundo abierto... puede tardar un minuto.")',
    'local inicio = os.clock()',
    'local modelo = MapBuilder.build("MundoAbierto", require(mundo))',
    'MapBuilder.show(modelo, "MundoAbierto")',
    'print(string.format("Mundo abierto listo en %.0f segundos. Guarda el lugar para conservarlo.", os.clock() - inicio))',
    '',
]
out = os.path.join(HERE, 'ConstruirMundoAbierto.luau')
open(out, 'w', encoding='utf-8').write('\n'.join(parts))
print('Generado', out, '-', len(zones), 'zonas:', ', '.join(zones))
