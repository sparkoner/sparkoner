"""Genera ConstruirMapas.luau: un único script para pegar en la barra de comandos de Studio.

Crea ServerStorage.MapBuilder (ModuleScript con sus mapas), construye los mapas en
ServerStorage.MapasDuelo y coloca uno en Workspace para verlo.
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
