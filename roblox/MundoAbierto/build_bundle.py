"""Genera ConstruirMundo.luau: un único script para pegar en la barra de comandos de Roblox Studio.

Instala el mundo abierto (ServerStorage.MundoAbierto) y el clima (ReplicatedStorage.ClimaConfig,
ServerScriptService.ClimaServidor y StarterPlayerScripts.ClimaCliente), pone las piezas en
Workspace.Mundo y genera el terreno.
Uso: python3 build_bundle.py
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, 'src')


def read(*p):
    return open(os.path.join(SRC, *p), encoding='utf-8').read()


def long_string(text):
    level = 1
    while ('[' + '=' * level + '[') in text or (']' + '=' * level + ']') in text:
        level += 1
    eq = '=' * level
    return f'[{eq}[\n{text}]{eq}]'


MODULES = ['Motor', 'Piezas', 'Datos', 'Terreno', 'Vegetacion']
zones = sorted(f[:-5] for f in os.listdir(os.path.join(SRC, 'MundoAbierto', 'Zonas')) if f.endswith('.luau'))
L = [
    '-- Pega TODO este texto en la barra de comandos de Roblox Studio (Ver > Barra de comandos) y pulsa Enter.',
    '-- Instala el mundo abierto y su clima y genera el terreno. Tarda un par de minutos.',
    '-- OJO: borra el terreno y la Baseplate de este lugar. Úsalo en un lugar nuevo.',
    '-- Archivo generado por build_bundle.py a partir de src/.',
    '',
    'local ServerStorage = game:GetService("ServerStorage")',
    'local ReplicatedStorage = game:GetService("ReplicatedStorage")',
    'local ServerScriptService = game:GetService("ServerScriptService")',
    'local StarterPlayer = game:GetService("StarterPlayer")',
    'local FUENTE_MUNDO = ' + long_string(read('MundoAbierto', 'init.luau')),
    'local FUENTES = {}',
]
for m in MODULES:
    L.append(f'FUENTES["{m}"] = ' + long_string(read('MundoAbierto', m + '.luau')))
L.append('local ZONAS = {}')
for z in zones:
    L.append(f'ZONAS["{z}"] = ' + long_string(read('MundoAbierto', 'Zonas', z + '.luau')))
L += [
    'local CLIMA_CONFIG = ' + long_string(read('Clima', 'ClimaConfig.luau')),
    'local CLIMA_SERVIDOR = ' + long_string(read('Clima', 'ClimaServidor.server.luau')),
    'local CLIMA_CLIENTE = ' + long_string(read('Clima', 'ClimaCliente.client.luau')),
    '',
    'local function crear(padre, clase, nombre, fuente)',
    '\tlocal viejo = padre:FindFirstChild(nombre)',
    '\tif viejo then viejo:Destroy() end',
    '\tlocal s = Instance.new(clase)',
    '\ts.Name = nombre',
    '\ts.Source = fuente',
    '\ts.Parent = padre',
    '\treturn s',
    'end',
    '',
    '-- Módulo del mundo con sus partes y sus zonas',
    'local mundo = crear(ServerStorage, "ModuleScript", "MundoAbierto", FUENTE_MUNDO)',
    'for nombre, fuente in pairs(FUENTES) do',
    '\tcrear(mundo, "ModuleScript", nombre, fuente)',
    'end',
    'local carpeta = Instance.new("Folder")',
    'carpeta.Name = "Zonas"',
    'carpeta.Parent = mundo',
    'for nombre, fuente in pairs(ZONAS) do',
    '\tcrear(carpeta, "ModuleScript", nombre, fuente)',
    'end',
    '',
    '-- Clima',
    'local config = crear(ReplicatedStorage, "ModuleScript", "ClimaConfig", CLIMA_CONFIG)',
    'crear(ServerScriptService, "Script", "ClimaServidor", CLIMA_SERVIDOR)',
    'local jugadorScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts") or Instance.new("StarterPlayerScripts", StarterPlayer)',
    'crear(jugadorScripts, "LocalScript", "ClimaCliente", CLIMA_CLIENTE)',
    '',
    '-- Carpeta para tus propios modelos 3D (árboles de la Toolbox...). Si ya existe no se toca',
    'local modelos = ServerStorage:FindFirstChild("ModelosMundo")',
    'if not modelos then',
    '\tmodelos = Instance.new("Folder")',
    '\tmodelos.Name = "ModelosMundo"',
    '\tmodelos.Parent = ServerStorage',
    'end',
    'for _, tipo in ipairs({ "Pino", "Roble", "Abedul", "Muerto", "Arbusto" }) do',
    '\tif not modelos:FindFirstChild(tipo) then',
    '\t\tlocal f = Instance.new("Folder")',
    '\t\tf.Name = tipo',
    '\t\tf.Parent = modelos',
    '\tend',
    'end',
    '',
    '-- Ajustes para que se vea y vaya bien',
    'pcall(function() game:GetService("Lighting").Technology = Enum.Technology.Future end)',
    'pcall(function() game:GetService("MaterialService").Use2022Materials = true end)',
    'pcall(function() workspace.StreamingEnabled = true end)',
    'for _, nombre in ipairs({ "Baseplate", "SpawnLocation" }) do',
    '\tlocal obj = workspace:FindFirstChild(nombre)',
    '\tif obj and obj:IsA("BasePart") then obj:Destroy() end',
    'end',
    '',
    'local Mundo = require(mundo)',
    'local inicio = os.clock()',
    'print("[Mundo] 1/3 Construyendo las piezas...")',
    'local viejo = workspace:FindFirstChild("Mundo")',
    'if viejo then viejo:Destroy() end',
    'local modelo = Mundo.construir()',
    'modelo.Parent = workspace',
    'print("[Mundo] 2/3 Generando el terreno...")',
    'Mundo.generarTerreno(function(hechos, total)',
    '\tif hechos % 32 == 0 then',
    '\t\tprint(string.format("[Mundo]     terreno %d%%", math.floor(hechos / total * 100)))',
    '\tend',
    'end)',
    'print("[Mundo] 3/3 Aplicando el clima inicial...")',
    'local Clima = require(config)',
    'Clima.aplicar(Clima.ClimaInicial or "Nublado")',
    'game:GetService("Lighting").ClockTime = Clima.HoraFija',
    'print(string.format("[Mundo] Listo en %.0f segundos. Guarda el lugar para conservarlo.", os.clock() - inicio))',
    '',
]
out = os.path.join(HERE, 'ConstruirMundo.luau')
open(out, 'w', encoding='utf-8').write('\n'.join(L))
print('Generado', out, '-', len(zones), 'zonas,', os.path.getsize(out) // 1024, 'KB')
