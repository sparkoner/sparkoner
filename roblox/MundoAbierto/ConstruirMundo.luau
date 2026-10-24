-- Pega TODO este texto en la barra de comandos de Roblox Studio (Ver > Barra de comandos) y pulsa Enter.
-- Instala el mundo abierto, su clima y la caza y la pesca, y genera el terreno. Tarda un par de minutos.
-- OJO: borra el terreno y la Baseplate de este lugar. Úsalo en un lugar nuevo.
-- Archivo generado por build_bundle.py a partir de src/.

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local FUENTE_MUNDO = [=[
--[[
	Mundo abierto postapocalíptico (al estilo The Last of Us): unos 4 x 4 km con relieve realista,
	ríos, lagos, playas, montañas nevadas, bosques y 16 zonas abandonadas unidas por carreteras.

	Va en ServerStorage como ModuleScript "MundoAbierto" con estos hijos:
	  Motor       construye piezas y zonas
	  Piezas      objetos prefabricados (casas, coches, vallas...)
	  Datos       costa, ríos, carreteras, zonas y utilidades
	  Terreno     relieve y suelo (se escribe con WriteVoxels)
	  Vegetacion  abetos, robles, abedules, sotobosque, hierba alta, juncos, troncos y rocas
	  Zonas       un ModuleScript por zona

	Uso:
		local Mundo = require(game.ServerStorage.MundoAbierto)
		Mundo.instalar()   -- pone las piezas en Workspace.Mundo y genera el terreno
]]
local Mundo = {}

-- Construye todas las piezas y devuelve el Model (sin terreno todavía)
function Mundo.construir()
	local Motor = require(script:WaitForChild("Motor"))
	return Motor.build("Mundo", function(b, MB)
		local W = require(script:WaitForChild("Datos"))(b, MB)
		local T = require(script:WaitForChild("Terreno"))(W)
		local V = require(script:WaitForChild("Vegetacion"))(b, MB, W, T)
		Mundo.W, Mundo.T, Mundo.V = W, T, V
		-- Las zonas pueden plantar árboles sueltos
		local KINDS = { roble = V.oak, pino = V.pine, abeto = V.pine, muerto = V.dead, abedul = V.birch }
		function W.tree(x, z, kind, s)
			(KINDS[kind] or V.oak)(x, z, s or 1)
		end

		b.model:SetAttribute("Nombre", "Mundo Abierto")

		b:zone("Carreteras")
		W.buildRoads()
		W.buildBridges()
		W.buildCars()

		local zones = script:WaitForChild("Zonas"):GetChildren()
		table.sort(zones, function(a, c)
			return a.Name < c.Name
		end)
		for _, module in ipairs(zones) do
			if module:IsA("ModuleScript") then
				b:zone(module.Name)
				require(module)(b, MB, W)
			end
		end

		b:zone("Bosque")
		Mundo.vegetacion = V.buildAll({ trees = 2600, bushes = 1100, tufts = 4500, reeds = 450, riverRocks = 160, logs = 140, stumps = 160, rocks = 320 })
		b:zone(nil)
		W.buildBounds()
	end)
end

-- Escribe el terreno (tarda un poco). progress(hechos, total) es opcional.
function Mundo.generarTerreno(progress)
	local terrain = workspace.Terrain
	terrain:Clear()
	Mundo.T.generate(terrain, progress)
end

-- Todo en uno: piezas en Workspace.Mundo y terreno
function Mundo.instalar(progress)
	local viejo = workspace:FindFirstChild("Mundo")
	if viejo then
		viejo:Destroy()
	end
	local modelo = Mundo.construir()
	modelo.Parent = workspace
	Mundo.generarTerreno(progress)
	return modelo
end

return Mundo
]=]
local FUENTES = {}
FUENTES["Motor"] = [=[
--[[
	Motor del mundo abierto: construye el mundo con piezas (Parts) agrupadas por zonas.
	Es independiente de cualquier otro proyecto: solo lo usa ServerStorage.MundoAbierto.
]]

local Motor = {}
Motor.Props = {}

-- =====================================================================
--  Utilidades
-- =====================================================================
local function copy(t)
	local out = {}
	for k, v in pairs(t) do
		out[k] = v
	end
	return out
end

local function rotateY(x, z, degrees)
	local a = math.rad(degrees)
	local c, s = math.cos(a), math.sin(a)
	return x * c + z * s, -x * s + z * c
end

local function rgb(c)
	return Color3.fromRGB(c[1], c[2], c[3])
end
Motor.rgb = rgb

-- =====================================================================
--  Constructor
-- =====================================================================
local Builder = {}
Builder.__index = Builder

local Group = {}
Group.__index = Group

function Motor.new(name)
	local model = Instance.new("Model")
	model.Name = name
	local self = setmetatable({ model = model, folders = {} }, Builder)
	self:folder("Mapa")
	self:folder("Decoracion")
	self:folder("Spawns")
	return self
end

local TOP_LEVEL = { Spawns = true, Limites = true }

function Builder:folder(name)
	-- Con zone() las piezas van a Zonas/<zona>/<carpeta>; los spawns y los límites siempre arriba
	local key = (self.zoneName and not TOP_LEVEL[name]) and (self.zoneName .. "/" .. name) or name
	local folder = self.folders[key]
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = (key ~= name) and self.zoneFolder or self.model
		self.folders[key] = folder
	end
	return folder
end

-- Agrupa lo que se construye a continuación en Zonas/<name> (nil para volver a la raíz)
function Builder:zone(name)
	if not name then
		self.zoneName, self.zoneFolder = nil, nil
		return
	end
	local zones = self.folders.Zonas
	if not zones then
		zones = Instance.new("Folder")
		zones.Name = "Zonas"
		zones.Parent = self.model
		self.folders.Zonas = zones
	end
	local folder = zones:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Model")
		folder.Name = name
		folder.Parent = zones
	end
	self.zoneName, self.zoneFolder = name, folder
end

-- Posición en studs y giro en grados
function Builder:cframe(pos, rot)
	local rx, ry, rz = 0, 0, 0
	if rot then
		rx, ry, rz = rot[1] or 0, rot[2] or 0, rot[3] or 0
	end
	return CFrame.new(pos[1], pos[2], pos[3]) * CFrame.fromEulerAnglesYXZ(math.rad(rx), math.rad(ry), math.rad(rz))
end

function Builder:part(className, p)
	local part = Instance.new(className)
	part.Name = p.name or className
	part.Anchored = true
	part.Size = Vector3.new(p.size[1], p.size[2], p.size[3])
	part.CFrame = self:cframe(p.pos, p.rot)
	part.Color = rgb(p.color or { 200, 200, 200 })
	part.Material = Enum.Material[p.mat or "SmoothPlastic"]
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if p.shape then
		part.Shape = Enum.PartType[p.shape]
	end
	if p.transparency then
		part.Transparency = p.transparency
	end
	if p.reflectance then
		part.Reflectance = p.reflectance
	end
	local folder = p.folder or "Mapa"
	if p.collide == false or folder == "Decoracion" then
		part.CanCollide = false
	end
	if p.shadow == false then
		part.CastShadow = false
	end
	if p.query == false then
		part.CanQuery = false
		part.CanTouch = false
	end
	part.Parent = self:folder(folder)
	return part
end

function Builder:box(p)
	return self:part("Part", p)
end

-- Rampa: sube desde -Z (borde fino) hacia +Z (cara alta), como el WedgePart de Roblox
function Builder:wedge(p)
	return self:part("WedgePart", p)
end

-- Escalera trepable (Size en múltiplos de 2)
function Builder:truss(p)
	return self:part("TrussPart", p)
end

function Builder:ball(p)
	local q = copy(p)
	q.size = { p.diameter, p.diameter, p.diameter }
	q.shape = "Ball"
	return self:part("Part", q)
end

-- Elipsoide (bola estirada en cada eje): un bloque con SpecialMesh de esfera.
-- Sirve para copas de árbol, arbustos y matas con formas irregulares en vez de bolas perfectas
function Builder:blob(p)
	local part = self:part("Part", p)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

-- Cilindro: axis = "y" (vertical, por defecto), "x" o "z"
function Builder:cylinder(p)
	local q = copy(p)
	q.size = { p.length, p.diameter, p.diameter }
	q.shape = "Cylinder"
	local r = p.rot or { 0, 0, 0 }
	local axis = p.axis or "y"
	if axis == "y" then
		q.rot = { r[1] or 0, r[2] or 0, 90 }
	elseif axis == "z" then
		q.rot = { r[1] or 0, (r[2] or 0) + 90, 0 }
	else
		q.rot = { r[1] or 0, r[2] or 0, r[3] or 0 }
	end
	return self:part("Part", q)
end

-- Ejecuta fn dos veces: normal y reflejado en X, para que ambos lados del duelo sean iguales
-- Grupo con origen y giro propios (para muebles, coches, contenedores...)
function Builder:at(origin, rotY)
	return setmetatable({ b = self, origin = origin, rotY = rotY or 0 }, Group)
end

function Group:transform(p)
	local q = copy(p)
	local lp = p.pos or { 0, 0, 0 }
	local x, z = rotateY(lp[1], lp[3], self.rotY)
	q.pos = { self.origin[1] + x, self.origin[2] + lp[2], self.origin[3] + z }
	local r = p.rot or { 0, 0, 0 }
	q.rot = { r[1] or 0, (r[2] or 0) + self.rotY, r[3] or 0 }
	return q
end

function Group:at(localPos, rotY)
	local x, z = rotateY(localPos[1], localPos[3], self.rotY)
	return self.b:at({ self.origin[1] + x, self.origin[2] + localPos[2], self.origin[3] + z }, self.rotY + (rotY or 0))
end

for _, method in ipairs({ "box", "wedge", "truss", "ball", "cylinder", "blob" }) do
	Group[method] = function(self, p)
		return self.b[method](self.b, self:transform(p))
	end
end

-- =====================================================================
--  Puntos de aparición, carteles y luces
-- =====================================================================
-- Punto de aparición real (SpawnLocation neutral) para mundos abiertos: Roblox lo usa al reaparecer
function Builder:spawnLocation(pos, yaw)
	local part = self:part("SpawnLocation", {
		name = "Aparicion",
		size = { 6, 1, 6 },
		pos = pos,
		rot = { 0, yaw or 0, 0 },
		transparency = 1,
		collide = false,
		shadow = false,
		folder = "Spawns",
	})
	part.Neutral = true
	part.Duration = 5
	part.CanQuery = false
	part.CanTouch = false
	part:SetAttribute("Team", "Mundo")
	return part
end

-- Cartel con texto en una cara de la pieza (SurfaceGui)
function Motor.sign(part, text, opts)
	opts = opts or {}
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Cartel"
	gui.Face = Enum.NormalId[opts.face or "Front"]
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = opts.pps or 40
	gui.LightInfluence = opts.glow and 0 or 1
	gui.Parent = part

	if opts.bg then
		local bg = Instance.new("Frame")
		bg.Name = "Fondo"
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundColor3 = rgb(opts.bg)
		bg.BorderSizePixel = 0
		bg.Parent = gui
	end
	-- Círculos decorativos { x, y, tamaño (relativo a la altura), color }
	for i, dot in ipairs(opts.dots or {}) do
		local circle = Instance.new("Frame")
		circle.Name = "Circulo" .. i
		circle.AnchorPoint = Vector2.new(0.5, 0.5)
		circle.Position = UDim2.fromScale(dot[1], dot[2])
		circle.SizeConstraint = Enum.SizeConstraint.RelativeYY
		circle.Size = UDim2.fromScale(dot[3], dot[3])
		circle.BackgroundColor3 = rgb(dot[4])
		circle.BorderSizePixel = 0
		circle.ZIndex = 2
		circle.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = circle
	end

	local label = Instance.new("TextLabel")
	label.Name = "Texto"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(opts.width or 0.92, opts.height or 0.8)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font[opts.font or "FredokaOne"]
	label.TextColor3 = rgb(opts.color or { 255, 255, 255 })
	if opts.stroke then
		label.TextStrokeColor3 = rgb(opts.stroke)
		label.TextStrokeTransparency = 0
	end
	label.ZIndex = 3
	label.Parent = gui
	return gui
end

-- kind: "Point", "Surface" o "Spot"
function Motor.light(part, kind, opts)
	opts = opts or {}
	local light = Instance.new(kind .. "Light")
	light.Color = rgb(opts.color or { 255, 240, 220 })
	light.Brightness = opts.brightness or 1
	light.Range = opts.range or 16
	light.Shadows = opts.shadows or false
	if kind ~= "Point" then
		light.Face = Enum.NormalId[opts.face or "Bottom"]
		light.Angle = opts.angle or 90
	end
	light.Parent = part
	return light
end

-- Fuego realista sobre una pieza (la pieza es la base de las llamas):
-- llamas (Fire), humo (Smoke), chispas (ParticleEmitter) y una luz que parpadea en el cliente.
-- opts: size (2 a 30), smoke (false = sin humo), light (false = sin luz), range, brightness
local CollectionService = game:GetService("CollectionService")
function Motor.fire(part, opts)
	opts = opts or {}
	local size = opts.size or 4
	local fire = Instance.new("Fire")
	fire.Size = size
	fire.Heat = opts.heat or 9
	fire.Color = rgb(opts.color or { 255, 138, 52 })
	fire.SecondaryColor = rgb(opts.secondary or { 255, 62, 18 })
	fire.Parent = part
	if opts.smoke ~= false then
		local smoke = Instance.new("Smoke")
		smoke.Color = rgb(opts.smokeColor or { 74, 70, 66 })
		smoke.Opacity = opts.smokeOpacity or 0.12
		smoke.RiseVelocity = opts.rise or 5
		smoke.Size = opts.smokeSize or size * 0.9
		smoke.Parent = part
	end
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Chispas"
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 176, 80), Color3.fromRGB(255, 74, 20))
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.16, 0)
	sparks.Lifetime = NumberRange.new(0.8, 1.8)
	sparks.Rate = math.floor(2 + size * 1.2)
	sparks.Speed = NumberRange.new(3, 7)
	sparks.SpreadAngle = Vector2.new(25, 25)
	sparks.Acceleration = Vector3.new(0, 3, 0)
	sparks.Drag = 1.5
	sparks.EmissionDirection = Enum.NormalId.Top
	sparks.Parent = part
	if opts.light ~= false then
		local light = Motor.light(part, "Point", { color = { 255, 150, 70 }, brightness = opts.brightness or 2, range = opts.range or 20, shadows = true })
		light:SetAttribute("Base", light.Brightness)
		CollectionService:AddTag(light, "LuzFuego")
	end
	CollectionService:AddTag(part, "Fuego")
	return fire
end

-- =====================================================================
--  Piezas reutilizables (Piezas.luau)
-- =====================================================================
require(script.Parent:WaitForChild("Piezas"))(Motor)

-- Construye el mundo y devuelve su Model (sin ponerlo en Workspace)
function Motor.build(name, buildFn)
	local b = Motor.new(name)
	buildFn(b, Motor)
	b.model.WorldPivot = CFrame.new(0, 0, 0)
	return b.model
end

return Motor
]=]
FUENTES["Piezas"] = [=[
-- Biblioteca de piezas detalladas. Cada función recibe g (constructor o grupo) y crea el objeto.
return function(MB)
	local P = MB.Props

	local function darker(c, k)
		k = k or 40
		return { math.max(c[1] - k, 0), math.max(c[2] - k, 0), math.max(c[3] - k, 0) }
	end
	local function lighter(c, k)
		k = k or 40
		return { math.min(c[1] + k, 255), math.min(c[2] + k, 255), math.min(c[3] + k, 255) }
	end
	P.darker, P.lighter = darker, lighter

	-- Barra (caja) entre dos puntos locales
	function P.segment(g, a, b, thickness, color, mat, folder)
		local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
		local len = math.sqrt(dx * dx + dy * dy + dz * dz)
		local pitch = -math.deg(math.asin(dy / len))
		local yaw = math.deg(math.atan2(dx, dz))
		return g:box({ name = "Barra", size = { thickness, thickness, len }, pos = { (a[1] + b[1]) / 2, (a[2] + b[2]) / 2, (a[3] + b[3]) / 2 }, rot = { pitch, yaw, 0 }, color = color, mat = mat or "Metal", folder = folder })
	end

	-- Tubo (cilindro) entre dos puntos locales
	function P.rod(g, a, b, diameter, color, mat, folder)
		local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
		local len = math.sqrt(dx * dx + dy * dy + dz * dz)
		local roll = math.deg(math.asin(dy / len))
		local yaw = math.deg(math.atan2(-dz, dx))
		return g:cylinder({ name = "Tubo", axis = "x", length = len, diameter = diameter, pos = { (a[1] + b[1]) / 2, (a[2] + b[2]) / 2, (a[3] + b[3]) / 2 }, rot = { 0, yaw, roll }, color = color, mat = mat or "Metal", folder = folder })
	end

	-- =================================================================
	--  Mobiliario urbano
	-- =================================================================
	function P.crate(g, pos, size, rotY, color)
		local c = g:at(pos, rotY)
		local s = size or 5
		local wood = color or { 206, 160, 104 }
		local frame = darker(wood, 45)
		c:box({ name = "Caja", size = { s - 0.3, s - 0.3, s - 0.3 }, pos = { 0, s / 2, 0 }, color = wood, mat = "WoodPlanks" })
		local e = 0.45
		for _, x in ipairs({ -1, 1 }) do
			for _, z in ipairs({ -1, 1 }) do
				c:box({ name = "Canto", size = { e, s, e }, pos = { x * (s - e) / 2, s / 2, z * (s - e) / 2 }, color = frame, mat = "Wood" })
			end
		end
		for _, y in ipairs({ e / 2, s - e / 2 }) do
			for _, z in ipairs({ -1, 1 }) do
				c:box({ name = "Marco", size = { s, e, e }, pos = { 0, y, z * (s - e) / 2 }, color = frame, mat = "Wood" })
				c:box({ name = "Marco", size = { e, e, s }, pos = { z * (s - e) / 2, y, 0 }, color = frame, mat = "Wood" })
			end
		end
		local diag = math.sqrt(2) * (s - 2 * e)
		for _, z in ipairs({ -1, 1 }) do
			c:box({ name = "Riostra", size = { diag, e * 0.8, 0.2 }, pos = { 0, s / 2, z * (s / 2 - 0.05) }, rot = { 0, 0, 45 }, color = frame, mat = "Wood", folder = "Decoracion" })
		end
	end

	function P.cardboard(g, pos, size, rotY)
		local c = g:at(pos, rotY)
		local s = size or { 3, 2.4, 2.6 }
		c:box({ name = "Carton", size = s, pos = { 0, s[2] / 2, 0 }, color = { 186, 146, 98 }, mat = "Cardboard" })
		c:box({ name = "Cinta", size = { 0.6, 0.05, s[3] + 0.02 }, pos = { 0, s[2] + 0.02, 0 }, color = { 214, 190, 140 }, folder = "Decoracion" })
	end

	function P.tree(g, pos, scale, palette)
		local t = g:at(pos, 0)
		local s = scale or 1
		local leaves = palette or { { 196, 120, 58 }, { 168, 108, 50 }, { 134, 128, 62 } }
		local bark = { 92, 66, 48 }
		t:cylinder({ name = "Tronco", length = 5 * s, diameter = 1.8 * s, pos = { 0, 2.5 * s, 0 }, color = bark, mat = "Wood" })
		t:cylinder({ name = "Tronco", length = 5 * s, diameter = 1.3 * s, pos = { 0, 7 * s, 0 }, color = bark, mat = "Wood", folder = "Decoracion" })
		P.rod(t, { 0, 6 * s, 0 }, { 2.6 * s, 9 * s, 0.6 * s }, 0.7 * s, bark, "Wood", "Decoracion")
		P.rod(t, { 0, 6.5 * s, 0 }, { -2.4 * s, 9.4 * s, -0.8 * s }, 0.6 * s, bark, "Wood", "Decoracion")
		local blobs = {
			{ 0, 11 * s, 0, 8.5, 1 }, { 3 * s, 9.6 * s, 0.8 * s, 6.5, 2 }, { -2.8 * s, 10 * s, -1 * s, 6.8, 3 },
			{ 0.6 * s, 13.6 * s, -0.6 * s, 6, 2 }, { -1.2 * s, 9 * s, 2.6 * s, 6, 1 }, { 1.6 * s, 9.4 * s, -2.6 * s, 5.6, 3 },
			{ -2.2 * s, 12.6 * s, 1.4 * s, 4.8, 1 }, { 2.6 * s, 12.4 * s, 1.8 * s, 4.4, 3 },
		}
		for _, b in ipairs(blobs) do
			t:ball({ name = "Copa", diameter = b[4] * s, pos = { b[1], b[2], b[3] }, color = leaves[b[5]], mat = "LeafyGrass", folder = "Decoracion" })
		end
	end

	function P.bush(g, pos, scale, color)
		local b = g:at(pos, 0)
		local s = scale or 1
		local c = color or { 88, 122, 62 }
		for _, o in ipairs({ { 0, 1.4, 0, 3.4 }, { 1.4, 1.1, 0.6, 2.6 }, { -1.3, 1.0, -0.5, 2.6 }, { 0.3, 1.0, 1.4, 2.2 } }) do
			b:ball({ name = "Arbusto", diameter = o[4] * s, pos = { o[1] * s, o[2] * s, o[3] * s }, color = (o[4] > 3) and c or lighter(c, 14), mat = "LeafyGrass" })
		end
	end

	function P.pottedPlant(g, pos, scale)
		local p = g:at(pos, 0)
		local s = scale or 1
		p:cylinder({ name = "Maceta", length = 1.8 * s, diameter = 2 * s, pos = { 0, 0.9 * s, 0 }, color = { 182, 96, 64 }, mat = "Plaster" })
		p:cylinder({ name = "Tierra", length = 0.1, diameter = 1.8 * s, pos = { 0, 1.82 * s, 0 }, color = { 70, 50, 40 }, mat = "Ground", folder = "Decoracion" })
		for _, o in ipairs({ { 0, 3, 0, 2.2 }, { 0.6, 2.6, 0.4, 1.6 }, { -0.6, 2.5, -0.3, 1.6 }, { 0, 3.8, 0.2, 1.4 } }) do
			p:ball({ name = "Hojas", diameter = o[4] * s, pos = { o[1] * s, o[2] * s, o[3] * s }, color = { 76, 128, 66 }, mat = "LeafyGrass", folder = "Decoracion" })
		end
	end

	function P.planter(g, pos, size, rotY)
		local p = g:at(pos, rotY)
		local w, d = size[1], size[2]
		p:box({ name = "Jardinera", size = { w, 2.4, d }, pos = { 0, 1.2, 0 }, color = { 158, 152, 146 }, mat = "Concrete" })
		p:box({ name = "Borde", size = { w + 0.4, 0.3, d + 0.4 }, pos = { 0, 2.55, 0 }, color = { 184, 178, 170 }, mat = "Concrete" })
		p:box({ name = "Tierra", size = { w - 0.6, 0.2, d - 0.6 }, pos = { 0, 2.5, 0 }, color = { 74, 56, 44 }, mat = "Ground", folder = "Decoracion" })
		local n = math.max(1, math.floor(w / 3.5))
		for i = 1, n do
			local x = -w / 2 + (i - 0.5) * w / n
			P.bush(p, { x, 2.2, 0 }, math.min(d / 4, 0.9))
		end
	end

	function P.bench(g, pos, rotY, color)
		local b = g:at(pos, rotY)
		local wood = color or { 150, 100, 60 }
		for i = 0, 2 do
			b:box({ name = "Listón", size = { 6, 0.25, 0.45 }, pos = { 0, 1.7, -0.55 + i * 0.55 }, color = wood, mat = "WoodPlanks" })
		end
		for i = 0, 1 do
			b:box({ name = "Respaldo", size = { 6, 0.45, 0.2 }, pos = { 0, 2.4 + i * 0.6, 0.85 }, rot = { -10, 0, 0 }, color = wood, mat = "WoodPlanks" })
		end
		for _, x in ipairs({ -2.6, 2.6 }) do
			b:box({ name = "Pata", size = { 0.3, 1.6, 1.6 }, pos = { x, 0.8, 0 }, color = { 50, 50, 56 }, mat = "Metal" })
			b:box({ name = "Pata", size = { 0.3, 1.6, 0.3 }, pos = { x, 2.4, 0.95 }, color = { 50, 50, 56 }, mat = "Metal" })
		end
	end

	function P.trashCan(g, pos, color)
		local t = g:at(pos, 0)
		local c = color or { 52, 98, 70 }
		t:cylinder({ name = "Papelera", length = 3, diameter = 2.2, pos = { 0, 1.5, 0 }, color = c, mat = "Metal" })
		t:cylinder({ name = "Aro", length = 0.3, diameter = 2.4, pos = { 0, 2.9, 0 }, color = darker(c, 30), mat = "Metal", folder = "Decoracion" })
		t:cylinder({ name = "Tapa", length = 0.4, diameter = 2.3, pos = { 0, 3.2, 0 }, color = darker(c, 15), mat = "Metal", folder = "Decoracion" })
		t:cylinder({ name = "Base", length = 0.3, diameter = 2.4, pos = { 0, 0.15, 0 }, color = darker(c, 30), mat = "Metal", folder = "Decoracion" })
	end

	function P.dumpster(g, pos, rotY, color)
		local d = g:at(pos, rotY)
		local c = color or { 58, 108, 72 }
		d:box({ name = "Contenedor", size = { 7, 4, 4 }, pos = { 0, 2.4, 0 }, color = c, mat = "Metal" })
		d:wedge({ name = "Tapa", size = { 7.1, 0.8, 4.1 }, pos = { 0, 4.8, 0 }, rot = { 0, 180, 0 }, color = darker(c, 20), mat = "Rubber" })
		for _, x in ipairs({ -2.8, 2.8 }) do
			for _, z in ipairs({ -1.4, 1.4 }) do
				d:cylinder({ name = "Rueda", axis = "x", length = 0.4, diameter = 0.9, pos = { x, 0.45, z }, color = { 30, 30, 32 }, mat = "Rubber", folder = "Decoracion" })
			end
		end
		d:box({ name = "Asa", size = { 6, 0.25, 0.25 }, pos = { 0, 3.6, -2.15 }, color = darker(c, 40), mat = "Metal", folder = "Decoracion" })
	end

	function P.cone(g, pos)
		local c = g:at(pos, 0)
		c:box({ name = "Base", size = { 1.6, 0.25, 1.6 }, pos = { 0, 0.12, 0 }, color = { 30, 30, 32 }, mat = "Rubber" })
		local sizes = { { 1.2, 0.6 }, { 0.95, 1.1 }, { 0.7, 1.6 }, { 0.45, 2.1 } }
		for i, s in ipairs(sizes) do
			c:cylinder({ name = "Cono", length = 0.55, diameter = s[1], pos = { 0, s[2] - 0.05, 0 }, color = (i == 3) and { 240, 240, 240 } or { 245, 110, 30 }, mat = "Rubber" })
		end
	end

	function P.tires(g, pos, count)
		local t = g:at(pos, 0)
		for i = 1, count or 3 do
			t:cylinder({ name = "Neumatico", length = 1, diameter = 3, pos = { (i % 2) * 0.2, 0.5 + (i - 1) * 1, 0 }, color = { 32, 32, 34 }, mat = "Rubber" })
			t:cylinder({ name = "Llanta", length = 1.02, diameter = 1.6, pos = { (i % 2) * 0.2, 0.5 + (i - 1) * 1, 0 }, color = { 60, 60, 64 }, mat = "Rubber", folder = "Decoracion" })
		end
	end

	function P.hydrant(g, pos)
		local h = g:at(pos, 0)
		h:cylinder({ name = "Hidrante", length = 2.2, diameter = 1, pos = { 0, 1.1, 0 }, color = { 200, 40, 36 }, mat = "Metal" })
		h:ball({ name = "Cabeza", diameter = 1.05, pos = { 0, 2.25, 0 }, color = { 200, 40, 36 }, mat = "Metal", folder = "Decoracion" })
		h:cylinder({ name = "Boca", axis = "x", length = 1.6, diameter = 0.45, pos = { 0, 1.5, 0 }, color = { 220, 200, 60 }, mat = "Metal", folder = "Decoracion" })
	end

	function P.streetLight(g, pos, rotY, height, color)
		local s = g:at(pos, rotY)
		local h = height or 18
		s:cylinder({ name = "Base", length = 1.2, diameter = 1.4, pos = { 0, 0.6, 0 }, color = { 60, 62, 70 }, mat = "Metal" })
		s:cylinder({ name = "Farola", length = h, diameter = 0.7, pos = { 0, h / 2, 0 }, color = { 74, 76, 84 }, mat = "Metal" })
		s:box({ name = "Brazo", size = { 0.4, 0.4, 5 }, pos = { 0, h - 0.4, -2.3 }, color = { 74, 76, 84 }, mat = "Metal", folder = "Decoracion" })
		s:box({ name = "Cabeza", size = { 1.6, 0.6, 3 }, pos = { 0, h - 0.6, -4.6 }, color = { 60, 62, 70 }, mat = "Metal", folder = "Decoracion" })
		local lamp = s:box({ name = "Bombilla", size = { 1.2, 0.15, 2.4 }, pos = { 0, h - 0.95, -4.6 }, color = color or { 255, 226, 170 }, mat = "Neon", folder = "Decoracion" })
		MB.light(lamp, "Spot", { face = "Bottom", color = color or { 255, 220, 160 }, brightness = 2, range = 40, angle = 100 })
	end

	function P.vending(g, pos, rotY, color, text)
		local v = g:at(pos, rotY)
		local c = color or { 200, 40, 50 }
		v:box({ name = "Maquina", size = { 4, 7, 3 }, pos = { 0, 3.5, 0 }, color = c })
		local front = v:box({ name = "Escaparate", size = { 2.6, 4.4, 0.1 }, pos = { -0.5, 4, -1.55 }, color = { 220, 236, 250 }, mat = "Neon", transparency = 0.15, folder = "Decoracion" })
		MB.light(front, "Surface", { face = "Front", color = { 210, 230, 255 }, brightness = 0.6, range = 8 })
		for i = 0, 3 do
			v:box({ name = "Latas", size = { 2.2, 0.5, 0.2 }, pos = { -0.5, 2.5 + i * 1, -1.5 }, color = ({ { 220, 60, 60 }, { 60, 140, 220 }, { 250, 200, 60 }, { 90, 190, 110 } })[i + 1], folder = "Decoracion" })
		end
		v:box({ name = "Botones", size = { 0.8, 3, 0.15 }, pos = { 1.45, 4.2, -1.55 }, color = { 40, 40, 46 }, folder = "Decoracion" })
		local top = v:box({ name = "Marca", size = { 4, 1.2, 0.1 }, pos = { 0, 6.6, -1.55 }, color = c, folder = "Decoracion" })
		MB.sign(top, text or "COLA", { font = "GothamBlack", color = { 255, 255, 255 }, glow = true })
	end

	function P.atm(g, pos, rotY)
		local a = g:at(pos, rotY)
		a:box({ name = "Cajero", size = { 3, 6, 2.4 }, pos = { 0, 3, 0 }, color = { 70, 80, 96 }, mat = "Metal" })
		local screen = a:box({ name = "Pantalla", size = { 1.6, 1.2, 0.1 }, pos = { 0, 4.4, -1.25 }, color = { 90, 200, 255 }, mat = "Neon", folder = "Decoracion" })
		MB.sign(screen, "ATM", { font = "GothamBlack", color = { 20, 40, 80 } })
		a:box({ name = "Teclado", size = { 1.6, 0.6, 0.6 }, pos = { 0, 3.2, -1.4 }, rot = { 20, 0, 0 }, color = { 40, 40, 46 }, folder = "Decoracion" })
	end

	function P.newspaperBox(g, pos, rotY, color)
		local n = g:at(pos, rotY)
		local c = color or { 40, 90, 170 }
		n:box({ name = "Periodicos", size = { 2, 3.4, 1.8 }, pos = { 0, 1.9, 0 }, color = c, mat = "Metal" })
		n:box({ name = "Ventana", size = { 1.4, 1, 0.1 }, pos = { 0, 2.6, -0.92 }, color = { 220, 230, 235 }, mat = "Glass", transparency = 0.2, folder = "Decoracion" })
		n:box({ name = "Pata", size = { 0.3, 0.2, 1.8 }, pos = { 0, 0.1, 0 }, color = { 40, 40, 44 }, folder = "Decoracion" })
	end

	-- Cartel plano (póster o señal) con fondo y texto
	function P.poster(g, pos, rotY, size, bg, text, textColor, font)
		local p = g:at(pos, rotY)
		local part = p:box({ name = "Poster", size = { size[1], size[2], 0.1 }, pos = { 0, 0, 0 }, color = bg, folder = "Decoracion" })
		MB.sign(part, text, { bg = bg, color = textColor or { 255, 255, 255 }, font = font or "FredokaOne" })
		return part
	end

	-- Letrero de neón: texto brillante sobre un panel oscuro con borde luminoso
	function P.neonSign(g, pos, rotY, size, text, color, font)
		local n = g:at(pos, rotY)
		local panel = n:box({ name = "Letrero", size = { size[1], size[2], 0.4 }, pos = { 0, 0, 0 }, color = { 24, 22, 30 }, folder = "Decoracion" })
		MB.sign(panel, text, { font = font or "FredokaOne", color = color, glow = true, width = 0.86, height = 0.72 })
		for _, y in ipairs({ -1, 1 }) do
			n:box({ name = "Borde", size = { size[1] + 0.3, 0.2, 0.5 }, pos = { 0, y * size[2] / 2, 0 }, color = color, mat = "Neon", folder = "Decoracion" })
		end
		for _, x in ipairs({ -1, 1 }) do
			n:box({ name = "Borde", size = { 0.2, size[2], 0.5 }, pos = { x * size[1] / 2, 0, 0 }, color = color, mat = "Neon", folder = "Decoracion" })
		end
		MB.light(panel, "Point", { color = color, brightness = 1.6, range = math.max(size[1], 10) })
		return panel
	end

	-- Guirnalda de bombillas colgando entre dos puntos
	function P.stringLights(g, a, b, count, sag, colors)
		local prev = nil
		for i = 0, count do
			local t = i / count
			local x = a[1] + (b[1] - a[1]) * t
			local z = a[3] + (b[3] - a[3]) * t
			local y = a[2] + (b[2] - a[2]) * t - sag * 4 * t * (1 - t)
			local point = { x, y, z }
			if prev then
				P.segment(g, prev, point, 0.08, { 30, 30, 30 }, "Plastic", "Decoracion")
			end
			if i > 0 and i < count then
				local c = colors[(i % #colors) + 1]
				g:ball({ name = "Bombilla", diameter = 0.45, pos = { x, y - 0.25, z }, color = c, mat = "Neon", folder = "Decoracion" })
			end
			prev = point
		end
	end

	function P.chainFence(g, a, b, height)
		local dx, dz = b[1] - a[1], b[3] - a[3]
		local len = math.sqrt(dx * dx + dz * dz)
		local posts = math.max(2, math.floor(len / 8) + 1)
		local metal = { 140, 144, 150 }
		for i = 0, posts - 1 do
			local t = i / (posts - 1)
			g:cylinder({ name = "Poste", length = height, diameter = 0.35, pos = { a[1] + dx * t, height / 2, a[3] + dz * t }, color = metal, mat = "Metal" })
		end
		P.rod(g, { a[1], height, a[3] }, { b[1], height, b[3] }, 0.25, metal, "Metal")
		local yaw = math.deg(math.atan2(-dz, dx))
		g:box({ name = "Malla", size = { len, height - 0.4, 0.05 }, pos = { (a[1] + b[1]) / 2, height / 2, (a[3] + b[3]) / 2 }, rot = { 0, yaw, 0 }, color = { 120, 124, 130 }, mat = "DiamondPlate", transparency = 0.55 })
	end

	function P.woodFence(g, a, b, height, color)
		local dx, dz = b[1] - a[1], b[3] - a[3]
		local len = math.sqrt(dx * dx + dz * dz)
		local wood = color or { 168, 128, 88 }
		local yaw = math.deg(math.atan2(-dz, dx))
		local mid = { (a[1] + b[1]) / 2, 0, (a[3] + b[3]) / 2 }
		local f = g:at(mid, yaw)
		local n = math.floor(len / 1.1)
		for i = 0, n do
			local x = -len / 2 + i * len / n
			f:box({ name = "Tabla", size = { 0.8, height, 0.25 }, pos = { x, height / 2, 0 }, color = (i % 3 == 0) and darker(wood, 15) or wood, mat = "WoodPlanks" })
		end
		for _, y in ipairs({ height * 0.3, height * 0.8 }) do
			f:box({ name = "Travesano", size = { len, 0.4, 0.3 }, pos = { 0, y, 0.25 }, color = darker(wood, 25), mat = "Wood", folder = "Decoracion" })
		end
	end

	-- Muro con zócalo y remate superior
	function P.wall(g, pos, rotY, size, color, baseColor, capColor, mat)
		local w = g:at(pos, rotY)
		w:box({ name = "Muro", size = size, pos = { 0, size[2] / 2, 0 }, color = color, mat = mat or "Plaster" })
		w:box({ name = "Zocalo", size = { size[1] + 0.1, 1.2, size[3] + 0.3 }, pos = { 0, 0.6, 0 }, color = baseColor or darker(color, 50), mat = "Concrete" })
		w:box({ name = "Remate", size = { size[1] + 0.3, 0.6, size[3] + 0.5 }, pos = { 0, size[2] - 0.3, 0 }, color = capColor or lighter(color, 20), mat = "Concrete" })
	end

	-- Ventana con marco, travesaños, cristal y alféizar (centrada en pos, mirando a -Z)
	function P.window(g, pos, rotY, w, h, frameColor, glassColor)
		local v = g:at(pos, rotY)
		local f = frameColor or { 60, 60, 70 }
		v:box({ name = "Cristal", size = { w, h, 0.2 }, pos = { 0, 0, 0 }, color = glassColor or { 168, 198, 214 }, mat = "Glass", transparency = 0.45 })
		for _, x in ipairs({ -w / 2, w / 2 }) do
			v:box({ name = "Marco", size = { 0.5, h + 0.5, 0.6 }, pos = { x, 0, 0 }, color = f, mat = "Metal" })
		end
		for _, y in ipairs({ -h / 2, h / 2 }) do
			v:box({ name = "Marco", size = { w + 0.5, 0.5, 0.6 }, pos = { 0, y, 0 }, color = f, mat = "Metal" })
		end
		v:box({ name = "Travesano", size = { 0.25, h, 0.4 }, pos = { 0, 0, 0 }, color = f, mat = "Metal", folder = "Decoracion" })
		v:box({ name = "Travesano", size = { w, 0.25, 0.4 }, pos = { 0, h * 0.15, 0 }, color = f, mat = "Metal", folder = "Decoracion" })
		v:box({ name = "Alfeizar", size = { w + 1, 0.35, 1.2 }, pos = { 0, -h / 2 - 0.4, -0.4 }, color = { 210, 206, 200 }, mat = "Concrete", folder = "Decoracion" })
	end

	-- Acera con bordillo (pos = centro, size = { largo X, ancho Z })
	function P.sidewalk(g, pos, size, rotY)
		local s = g:at(pos, rotY)
		s:box({ name = "Acera", size = { size[1], 0.6, size[2] }, pos = { 0, 0.3, 0 }, color = { 176, 172, 166 }, mat = "Pavement" })
		s:box({ name = "Bordillo", size = { size[1], 0.7, 0.6 }, pos = { 0, 0.35, -size[2] / 2 + 0.3 }, color = { 206, 202, 196 }, mat = "Concrete" })
		local n = math.floor(size[1] / 6)
		for i = 1, n - 1 do
			s:box({ name = "Junta", size = { 0.12, 0.62, size[2] - 0.8 }, pos = { -size[1] / 2 + i * size[1] / n, 0.3, 0.3 }, color = { 140, 136, 130 }, mat = "Concrete", folder = "Decoracion" })
		end
	end

	function P.puddle(g, pos, diameter)
		g:cylinder({ name = "Charco", length = 0.06, diameter = diameter, pos = { pos[1], pos[2] + 0.03, pos[3] }, color = { 60, 66, 78 }, mat = "Glass", transparency = 0.25, reflectance = 0.3, folder = "Decoracion" })
	end

	function P.stain(g, pos, diameter)
		g:cylinder({ name = "Mancha", length = 0.04, diameter = diameter, pos = { pos[1], pos[2] + 0.02, pos[3] }, color = { 40, 36, 38 }, transparency = 0.5, folder = "Decoracion" })
	end

	function P.manhole(g, pos)
		g:cylinder({ name = "Alcantarilla", length = 0.08, diameter = 3, pos = { pos[1], pos[2] + 0.04, pos[3] }, color = { 64, 62, 60 }, mat = "DiamondPlate", folder = "Decoracion" })
	end

	-- =================================================================
	--  Vehículos
	-- =================================================================
	-- wrecked = true: coche abandonado (oxidado, con musgo, cristales sucios y luces apagadas)
	function P.car(g, pos, rotY, color, wrecked)
		local c = g:at(pos, rotY)
		local paint = color or { 190, 50, 50 }
		local trim = { 34, 34, 38 }
		c:box({ name = "Chasis", size = { 5.4, 1.4, 11.2 }, pos = { 0, 1.5, 0 }, color = paint, reflectance = 0.06 })
		c:box({ name = "Paragolpes", size = { 5.6, 0.9, 0.6 }, pos = { 0, 1.1, -5.7 }, color = trim })
		c:box({ name = "Paragolpes", size = { 5.6, 0.9, 0.6 }, pos = { 0, 1.1, 5.7 }, color = trim })
		c:box({ name = "Capo", size = { 5.2, 0.8, 3.4 }, pos = { 0, 2.6, -3.7 }, color = paint, reflectance = 0.06 })
		c:box({ name = "Maletero", size = { 5.2, 0.8, 2.2 }, pos = { 0, 2.6, 4.3 }, color = paint, reflectance = 0.06 })
		c:wedge({ name = "Parabrisas", size = { 4.9, 2, 1.8 }, pos = { 0, 4, -1.1 }, color = { 40, 48, 60 }, mat = "Glass", transparency = 0.1 })
		c:box({ name = "Habitaculo", size = { 4.9, 2, 3.2 }, pos = { 0, 4, 1.4 }, color = { 40, 48, 60 }, mat = "Glass", transparency = 0.1 })
		c:wedge({ name = "Luneta", size = { 4.9, 2, 1.2 }, pos = { 0, 4, 3.6 }, rot = { 0, 180, 0 }, color = { 40, 48, 60 }, mat = "Glass", transparency = 0.1 })
		c:box({ name = "Techo", size = { 4.9, 0.3, 3.4 }, pos = { 0, 5.1, 1.3 }, color = paint, reflectance = 0.06 })
		for _, x in ipairs({ -2.5, 2.5 }) do
			c:box({ name = "Pilar", size = { 0.2, 2, 0.3 }, pos = { x, 4, 0.2 }, color = paint, folder = "Decoracion" })
			c:box({ name = "Retrovisor", size = { 0.5, 0.4, 0.3 }, pos = { x * 1.12, 3.3, -1.6 }, color = paint, folder = "Decoracion" })
			for _, z in ipairs({ -3.6, 3.6 }) do
				c:box({ name = "Paso", size = { 0.3, 1.9, 3.3 }, pos = { x * 1.02, 1.6, z }, color = trim, folder = "Decoracion" })
				c:cylinder({ name = "Rueda", axis = "x", length = 1, diameter = 2.6, pos = { x * 0.98, 1.3, z }, color = { 28, 28, 30 }, mat = "Rubber" })
				c:cylinder({ name = "Llanta", axis = "x", length = 1.04, diameter = 1.4, pos = { x * 0.98, 1.3, z }, color = { 180, 182, 188 }, mat = "Metal", folder = "Decoracion" })
			end
		end
		for _, x in ipairs({ -1.9, 1.9 }) do
			c:box({ name = "Faro", size = { 1.2, 0.5, 0.15 }, pos = { x, 2.2, -5.62 }, color = wrecked and { 120, 120, 110 } or { 255, 244, 214 }, mat = wrecked and "Glass" or "Neon", folder = "Decoracion" })
			c:box({ name = "Piloto", size = { 1.2, 0.5, 0.15 }, pos = { x, 2.2, 5.62 }, color = wrecked and { 90, 30, 30 } or { 210, 30, 30 }, mat = wrecked and "Glass" or "Neon", folder = "Decoracion" })
		end
		if wrecked then
			c:box({ name = "Musgo", size = { 4.4, 0.25, 2.6 }, pos = { 0.3, 5.3, 1.6 }, color = { 74, 104, 56 }, mat = "LeafyGrass", folder = "Decoracion" })
			c:box({ name = "Musgo", size = { 3.6, 0.25, 2 }, pos = { -0.4, 3.05, -3.8 }, color = { 84, 110, 60 }, mat = "LeafyGrass", folder = "Decoracion" })
			c:box({ name = "Oxido", size = { 5.45, 0.8, 4 }, pos = { 0, 1.2, 2 }, color = { 120, 70, 44 }, mat = "CorrodedMetal", folder = "Decoracion" })
		end
		c:box({ name = "Matricula", size = { 1.8, 0.6, 0.1 }, pos = { 0, 1.2, 6.03 }, color = { 240, 240, 236 }, folder = "Decoracion" })
	end

	function P.truck(g, pos, rotY, color)
		local t = g:at(pos, rotY)
		local paint = color or { 236, 236, 232 }
		t:box({ name = "Chasis", size = { 7, 1.2, 22 }, pos = { 0, 1.6, 2 }, color = { 46, 46, 52 }, mat = "Metal" })
		local cargo = t:box({ name = "Caja", size = { 8, 8.5, 15 }, pos = { 0, 6.45, 5.5 }, color = paint })
		for i = 0, 4 do
			t:box({ name = "Nervio", size = { 8.1, 0.25, 0.25 }, pos = { 0, 2.6 + i * 2, -2.05 }, color = darker(paint, 30), folder = "Decoracion" })
		end
		t:box({ name = "Cabina", size = { 7.6, 4.2, 5.5 }, pos = { 0, 4.3, -5.3 }, color = { 200, 60, 50 } })
		t:wedge({ name = "Parabrisas", size = { 7.4, 2.2, 2.2 }, pos = { 0, 7.5, -6.95 }, color = { 40, 48, 60 }, mat = "Glass", transparency = 0.1 })
		t:box({ name = "TechoCabina", size = { 7.6, 2.2, 3.3 }, pos = { 0, 7.5, -4.2 }, color = { 200, 60, 50 } })
		t:box({ name = "Rejilla", size = { 5, 1.6, 0.15 }, pos = { 0, 3.4, -8.1 }, color = { 50, 50, 56 }, mat = "DiamondPlate", folder = "Decoracion" })
		for _, x in ipairs({ -2.9, 2.9 }) do
			t:box({ name = "Faro", size = { 1.2, 0.7, 0.15 }, pos = { x, 3.4, -8.12 }, color = { 255, 244, 214 }, mat = "Neon", folder = "Decoracion" })
		end
		for _, w in ipairs({ { -3.6, -5.5 }, { 3.6, -5.5 }, { -3.6, 4 }, { 3.6, 4 }, { -3.6, 9 }, { 3.6, 9 } }) do
			t:cylinder({ name = "Rueda", axis = "x", length = 1, diameter = 3, pos = { w[1], 1.5, w[2] }, color = { 28, 28, 30 }, mat = "Rubber" })
			t:cylinder({ name = "Llanta", axis = "x", length = 1.04, diameter = 1.5, pos = { w[1], 1.5, w[2] }, color = { 170, 172, 178 }, mat = "Metal", folder = "Decoracion" })
		end
		return cargo
	end

	function P.forklift(g, pos, rotY, color)
		local f = g:at(pos, rotY)
		local c = color or { 230, 160, 30 }
		f:box({ name = "Carretilla", size = { 4.4, 2.6, 6 }, pos = { 0, 2, 0.4 }, color = c })
		f:box({ name = "Contrapeso", size = { 4.4, 2.2, 1.4 }, pos = { 0, 2.6, 3.4 }, color = darker(c, 40) })
		f:box({ name = "Asiento", size = { 1.8, 1.2, 1.6 }, pos = { 0, 3.9, 1.4 }, color = { 30, 30, 32 }, mat = "Leather", folder = "Decoracion" })
		for _, x in ipairs({ -1.9, 1.9 }) do
			for _, z in ipairs({ -1.4, 2.4 }) do
				f:box({ name = "Pilar", size = { 0.25, 4, 0.25 }, pos = { x, 5.3, z }, color = { 40, 40, 44 }, mat = "Metal", folder = "Decoracion" })
			end
			f:box({ name = "Mastil", size = { 0.4, 9, 0.6 }, pos = { x * 0.8, 4.8, -2.9 }, color = { 50, 50, 56 }, mat = "Metal" })
			f:box({ name = "Horquilla", size = { 0.5, 0.25, 4 }, pos = { x * 0.5, 0.5, -4.9 }, color = { 50, 50, 56 }, mat = "Metal" })
		end
		f:box({ name = "Techo", size = { 4.2, 0.25, 4.2 }, pos = { 0, 7.4, 0.5 }, color = { 40, 40, 44 }, mat = "Metal", folder = "Decoracion" })
		for _, w in ipairs({ { -2.2, -1.6 }, { 2.2, -1.6 }, { -2.2, 2.6 }, { 2.2, 2.6 } }) do
			f:cylinder({ name = "Rueda", axis = "x", length = 0.9, diameter = 1.9, pos = { w[1], 0.95, w[2] }, color = { 28, 28, 30 }, mat = "Rubber" })
		end
	end

	-- =================================================================
	--  Industrial y tejados
	-- =================================================================
	function P.container(g, pos, rotY, color, open, label)
		local c = g:at(pos, rotY)
		local L, H, W = 21, 9, 8.5
		local dark = darker(color, 45)
		if open then
			c:box({ name = "Suelo", size = { L, 0.6, W }, pos = { 0, 0.3, 0 }, color = { 70, 64, 58 }, mat = "WoodPlanks" })
			c:box({ name = "Techo", size = { L, 0.6, W }, pos = { 0, H - 0.3, 0 }, color = color, mat = "Metal" })
			c:box({ name = "Pared", size = { L, H, 0.6 }, pos = { 0, H / 2, -W / 2 + 0.3 }, color = color, mat = "Metal" })
			c:box({ name = "Pared", size = { L, H, 0.6 }, pos = { 0, H / 2, W / 2 - 0.3 }, color = color, mat = "Metal" })
			local lamp = c:box({ name = "Lampara", size = { 4, 0.2, 0.6 }, pos = { 0, H - 0.7, 0 }, color = { 255, 236, 200 }, mat = "Neon", folder = "Decoracion" })
			MB.light(lamp, "Point", { color = { 255, 226, 180 }, brightness = 1.2, range = 14 })
		else
			c:box({ name = "Contenedor", size = { L, H, W }, pos = { 0, H / 2, 0 }, color = color, mat = "Metal" })
			for _, z in ipairs({ -W / 4, W / 4 }) do
				c:box({ name = "Puerta", size = { 0.3, H - 0.8, W / 2 - 0.3 }, pos = { L / 2 + 0.12, H / 2, z }, color = dark, mat = "Metal", folder = "Decoracion" })
				for _, dz in ipairs({ -0.9, 0.9 }) do
					c:box({ name = "Cierre", size = { 0.25, H - 1.4, 0.2 }, pos = { L / 2 + 0.3, H / 2, z + dz }, color = { 150, 150, 156 }, mat = "Metal", folder = "Decoracion" })
				end
			end
		end
		-- Esquinas reforzadas
		for _, x in ipairs({ -1, 1 }) do
			for _, z in ipairs({ -1, 1 }) do
				for _, y in ipairs({ 0.35, H - 0.35 }) do
					c:box({ name = "Esquina", size = { 0.8, 0.7, 0.8 }, pos = { x * (L / 2 - 0.3), y, z * (W / 2 - 0.3) }, color = darker(color, 60), mat = "Metal", folder = "Decoracion" })
				end
			end
		end
		for i = 0, 8 do
			local x = -L / 2 + 1.5 + i * 2.25
			for _, side in ipairs({ -1, 1 }) do
				c:box({ name = "Nervio", size = { 0.6, H - 0.9, 0.25 }, pos = { x, H / 2, side * (W / 2 + 0.1) }, color = dark, mat = "Metal", folder = "Decoracion" })
			end
		end
		if label then
			for _, side in ipairs({ -1, 1 }) do
				local panel = c:box({ name = "Rotulo", size = { 9, 1.8, 0.1 }, pos = { 0, H - 1.6, side * (W / 2 + 0.3) }, rot = { 0, side > 0 and 180 or 0, 0 }, color = color, transparency = 1, folder = "Decoracion" })
				MB.sign(panel, label, { font = "GothamBlack", color = { 240, 240, 236 } })
			end
		end
	end

	function P.acUnit(g, pos, rotY)
		local a = g:at(pos, rotY)
		local body = { 186, 190, 196 }
		a:box({ name = "AireAcondicionado", size = { 7, 4.5, 5 }, pos = { 0, 2.55, 0 }, color = body, mat = "Metal" })
		a:box({ name = "Patas", size = { 6.6, 0.3, 4.6 }, pos = { 0, 0.15, 0 }, color = { 80, 82, 88 }, mat = "Metal" })
		for i = 0, 7 do
			a:box({ name = "Aleta", size = { 0.12, 3, 0.25 }, pos = { -2.4 + i * 0.7, 2.6, -2.55 }, color = { 120, 124, 132 }, mat = "Metal", folder = "Decoracion" })
		end
		a:cylinder({ name = "Ventilador", length = 0.3, diameter = 3.6, pos = { 0, 4.95, 0.4 }, color = { 60, 62, 70 }, mat = "DiamondPlate", folder = "Decoracion" })
		a:cylinder({ name = "Rejilla", length = 0.32, diameter = 1, pos = { 0, 4.97, 0.4 }, color = { 140, 144, 150 }, mat = "Metal", folder = "Decoracion" })
		P.rod(a, { 3.5, 1.2, 1 }, { 4.6, 1.2, 1 }, 0.5, { 120, 124, 132 }, "Metal", "Decoracion")
	end

	function P.vent(g, pos)
		local v = g:at(pos, 0)
		v:cylinder({ name = "Chimenea", length = 2.6, diameter = 1.2, pos = { 0, 1.3, 0 }, color = { 150, 154, 160 }, mat = "Metal" })
		v:cylinder({ name = "Sombrero", length = 0.4, diameter = 2, pos = { 0, 3, 0 }, color = { 120, 124, 130 }, mat = "Metal", folder = "Decoracion" })
	end

	function P.waterTank(g, pos)
		local w = g:at(pos, 0)
		local metal = { 90, 92, 100 }
		for _, o in ipairs({ { -3.2, -3.2 }, { 3.2, -3.2 }, { -3.2, 3.2 }, { 3.2, 3.2 } }) do
			w:box({ name = "Pata", size = { 0.8, 6.5, 0.8 }, pos = { o[1], 3.25, o[2] }, color = metal, mat = "Metal" })
		end
		P.segment(w, { -3.2, 0.5, -3.2 }, { 3.2, 6, -3.2 }, 0.3, metal, "Metal", "Decoracion")
		P.segment(w, { 3.2, 0.5, 3.2 }, { -3.2, 6, 3.2 }, 0.3, metal, "Metal", "Decoracion")
		w:box({ name = "Base", size = { 8, 0.5, 8 }, pos = { 0, 6.75, 0 }, color = metal, mat = "DiamondPlate" })
		w:cylinder({ name = "Deposito", length = 8, diameter = 8.5, pos = { 0, 11, 0 }, color = { 122, 94, 72 }, mat = "WoodPlanks" })
		for _, y in ipairs({ 8, 10.6, 13.2 }) do
			w:cylinder({ name = "Aro", length = 0.3, diameter = 8.7, pos = { 0, y, 0 }, color = { 56, 56, 62 }, mat = "Metal", folder = "Decoracion" })
		end
		for i, d in ipairs({ 8.8, 6.6, 4.2, 1.8 }) do
			w:cylinder({ name = "Tejadillo", length = 0.7, diameter = d, pos = { 0, 15 + i * 0.6, 0 }, color = { 70, 66, 70 }, mat = "RoofShingles", folder = "Decoracion" })
		end
		w:truss({ name = "Escalera", size = { 2, 10, 2 }, pos = { 0, 11, 5.3 }, color = metal })
	end

	function P.satelliteDish(g, pos, rotY)
		local s = g:at(pos, rotY)
		s:cylinder({ name = "Mastil", length = 3, diameter = 0.5, pos = { 0, 1.5, 0 }, color = { 140, 144, 150 }, mat = "Metal" })
		s:cylinder({ name = "Plato", axis = "z", length = 0.4, diameter = 5, pos = { 0, 3.6, -0.4 }, rot = { 25, 0, 0 }, color = { 220, 222, 226 }, folder = "Decoracion" })
		P.rod(s, { 0, 3.6, -0.6 }, { 0, 3.2, -2.6 }, 0.15, { 120, 124, 130 }, "Metal", "Decoracion")
	end

	function P.floodLight(g, pos, rotY, height)
		local f = g:at(pos, rotY)
		f:box({ name = "Torre", size = { 1.4, height, 1.4 }, pos = { 0, height / 2, 0 }, color = { 150, 154, 160 }, mat = "Metal" })
		for _, x in ipairs({ -1, 1 }) do
			P.segment(f, { x * 2.5, 0, 0 }, { 0, height * 0.45, 0 }, 0.4, { 150, 154, 160 }, "Metal")
		end
		f:box({ name = "Soporte", size = { 6, 0.4, 0.6 }, pos = { 0, height + 0.2, 0 }, color = { 70, 72, 80 }, mat = "Metal" })
		for _, x in ipairs({ -2, 0, 2 }) do
			local lamp = f:box({ name = "Foco", size = { 1.6, 1.2, 0.5 }, pos = { x, height + 0.9, -0.3 }, rot = { -20, 0, 0 }, color = { 255, 248, 230 }, mat = "Neon", folder = "Decoracion" })
			if x == 0 then
				MB.light(lamp, "Spot", { face = "Front", brightness = 2, range = 60, angle = 70, color = { 255, 246, 226 } })
			end
		end
	end

	function P.pallet(g, pos, rotY)
		local p = g:at(pos, rotY)
		for _, z in ipairs({ -1.6, 0, 1.6 }) do
			p:box({ name = "Taco", size = { 4.4, 0.5, 0.6 }, pos = { 0, 0.25, z }, color = { 150, 110, 70 }, mat = "Wood" })
		end
		for i = 0, 4 do
			p:box({ name = "Tabla", size = { 0.7, 0.25, 4 }, pos = { -1.8 + i * 0.9, 0.62, 0 }, color = { 182, 136, 88 }, mat = "WoodPlanks" })
		end
	end

	function P.drum(g, pos, color)
		local d = g:at(pos, 0)
		local c = color or { 48, 92, 150 }
		d:cylinder({ name = "Bidon", length = 3.4, diameter = 2.4, pos = { 0, 1.7, 0 }, color = c, mat = "Metal" })
		for _, y in ipairs({ 1.1, 2.3 }) do
			d:cylinder({ name = "Aro", length = 0.15, diameter = 2.5, pos = { 0, y, 0 }, color = darker(c, 30), mat = "Metal", folder = "Decoracion" })
		end
		d:cylinder({ name = "Tapon", length = 0.1, diameter = 0.4, pos = { 0.6, 3.45, 0 }, color = { 200, 200, 200 }, folder = "Decoracion" })
	end

	function P.cableReel(g, pos, rotY)
		local r = g:at(pos, rotY)
		for _, x in ipairs({ -1.6, 1.6 }) do
			r:cylinder({ name = "Bobina", axis = "x", length = 0.5, diameter = 6, pos = { x, 3, 0 }, color = { 176, 132, 86 }, mat = "WoodPlanks" })
		end
		r:cylinder({ name = "Cable", axis = "x", length = 2.8, diameter = 4.2, pos = { 0, 3, 0 }, color = { 30, 30, 34 }, mat = "Rubber" })
	end

	function P.railing(g, from, to, height, color)
		local dx, dz = to[1] - from[1], to[3] - from[3]
		local length = math.sqrt(dx * dx + dz * dz)
		local yaw = math.deg(math.atan2(-dz, dx))
		local r = g:at({ (from[1] + to[1]) / 2, from[2], (from[3] + to[3]) / 2 }, yaw)
		local metal = color or { 186, 188, 196 }
		local posts = math.max(2, math.floor(length / 4) + 1)
		for i = 0, posts - 1 do
			local x = -length / 2 + i * length / (posts - 1)
			r:cylinder({ name = "Poste", length = height, diameter = 0.3, pos = { x, height / 2, 0 }, color = metal, mat = "Metal" })
		end
		r:cylinder({ name = "Pasamanos", axis = "x", length = length, diameter = 0.35, pos = { 0, height, 0 }, color = metal, mat = "Metal" })
		r:cylinder({ name = "Barra", axis = "x", length = length, diameter = 0.18, pos = { 0, height / 2, 0 }, color = metal, mat = "Metal", folder = "Decoracion" })
	end

	-- Barandilla de skate (rail) sobre postes
	function P.skateRail(g, from, to, height)
		local metal = { 200, 202, 210 }
		P.rod(g, { from[1], from[2] + height, from[3] }, { to[1], to[2] + height, to[3] }, 0.45, metal, "Metal")
		for _, p in ipairs({ from, to }) do
			g:cylinder({ name = "Poste", length = height, diameter = 0.35, pos = { p[1], p[2] + height / 2, p[3] }, color = { 60, 62, 70 }, mat = "Metal" })
		end
	end

	function P.stairs(g, pos, rotY, steps, stepHeight, stepDepth, width, color, nosing)
		local s = g:at(pos, rotY)
		for i = 1, steps do
			local h = i * stepHeight
			s:box({ name = "Escalon", size = { width, h, stepDepth }, pos = { 0, h / 2, (i - 0.5) * stepDepth }, color = color, mat = "Concrete" })
			if nosing then
				s:box({ name = "Canto", size = { width, 0.12, 0.35 }, pos = { 0, h + 0.03, (i - 1) * stepDepth + 0.2 }, color = nosing, folder = "Decoracion" })
			end
		end
	end

	function P.quarterPipe(g, pos, rotY, width, radius, surface, side)
		local q = g:at(pos, rotY)
		local segments = 10
		local prevZ, prevY = 0, 0
		for i = 1, segments do
			local phi = math.rad(90 * i / segments)
			local z, y = radius * math.sin(phi), radius - radius * math.cos(phi)
			local dz, dy = z - prevZ, y - prevY
			local len = math.sqrt(dz * dz + dy * dy)
			local angle = math.deg(math.atan2(dy, dz))
			q:box({ name = "Curva", size = { width, 0.6, len + 0.15 }, pos = { 0, (y + prevY) / 2, (z + prevZ) / 2 }, rot = { -angle, 0, 0 }, color = surface, mat = "WoodPlanks" })
			local fill = math.min(y, prevY) - 0.3
			if fill > 0.2 then
				q:box({ name = "Relleno", size = { width - 0.2, fill, dz }, pos = { 0, fill / 2, (z + prevZ) / 2 }, color = side })
			end
			prevZ, prevY = z, y
		end
		q:cylinder({ name = "Coping", axis = "x", length = width, diameter = 0.7, pos = { 0, radius, radius }, color = { 200, 202, 210 }, mat = "Metal" })
	end

	-- Gradas para el público
	function P.bleachers(g, pos, rotY, rows, width, colors)
		local b = g:at(pos, rotY)
		for i = 1, rows do
			local h = i * 1.6
			b:box({ name = "Grada", size = { width, h, 2.4 }, pos = { 0, h / 2, (i - 0.5) * 2.4 }, color = { 70, 70, 82 }, mat = "Concrete" })
			b:box({ name = "Asiento", size = { width - 0.4, 0.3, 1.2 }, pos = { 0, h + 0.15, (i - 0.5) * 2.4 - 0.4 }, color = colors[(i % #colors) + 1], folder = "Decoracion" })
		end
	end

	function P.skateboardRack(g, pos, rotY)
		local r = g:at(pos, rotY)
		r:box({ name = "Panel", size = { 12, 6, 0.4 }, pos = { 0, 4, 0 }, color = { 60, 58, 70 }, mat = "WoodPlanks" })
		local colors = { { 245, 122, 192 }, { 112, 206, 186 }, { 242, 202, 66 }, { 120, 140, 240 }, { 240, 110, 80 } }
		for i = 1, 5 do
			local x = -5 + (i - 1) * 2.5
			r:box({ name = "Tabla", size = { 1.6, 5, 0.2 }, pos = { x, 4, -0.35 }, color = colors[i], folder = "Decoracion" })
			for _, y in ipairs({ 2.2, 5.8 }) do
				r:cylinder({ name = "Rueda", axis = "x", length = 1.2, diameter = 0.45, pos = { x, y, -0.6 }, color = { 240, 240, 236 }, folder = "Decoracion" })
			end
		end
	end

	function P.speaker(g, pos, rotY)
		local s = g:at(pos, rotY)
		s:box({ name = "Altavoz", size = { 3, 5, 2.6 }, pos = { 0, 2.5, 0 }, color = { 30, 30, 34 }, mat = "Fabric" })
		for _, y in ipairs({ 1.6, 3.6 }) do
			s:cylinder({ name = "Cono", axis = "z", length = 0.2, diameter = (y > 2) and 1.4 or 2.2, pos = { 0, y, -1.32 }, color = { 60, 60, 66 }, mat = "Rubber", folder = "Decoracion" })
		end
	end

	function P.lockers(g, pos, rotY, count, color)
		local l = g:at(pos, rotY)
		local c = color or { 112, 206, 186 }
		for i = 1, count do
			local x = (i - (count + 1) / 2) * 2.1
			l:box({ name = "Taquilla", size = { 2, 7, 2.4 }, pos = { x, 3.5, 0 }, color = (i % 2 == 0) and c or darker(c, 18), mat = "Metal" })
			for j = 0, 2 do
				l:box({ name = "Rejilla", size = { 1.2, 0.15, 0.1 }, pos = { x, 5.8 + j * 0.35, -1.22 }, color = darker(c, 60), folder = "Decoracion" })
			end
			l:box({ name = "Tirador", size = { 0.15, 0.8, 0.15 }, pos = { x + 0.6, 3.6, -1.25 }, color = { 200, 200, 206 }, mat = "Metal", folder = "Decoracion" })
		end
	end

	function P.umbrellaTable(g, pos, color)
		local u = g:at(pos, 0)
		u:cylinder({ name = "Mesa", length = 0.3, diameter = 4, pos = { 0, 2.6, 0 }, color = { 236, 236, 232 } })
		u:cylinder({ name = "Pie", length = 2.6, diameter = 0.4, pos = { 0, 1.3, 0 }, color = { 60, 60, 66 }, mat = "Metal" })
		u:cylinder({ name = "Palo", length = 5, diameter = 0.25, pos = { 0, 5.1, 0 }, color = { 200, 200, 206 }, mat = "Metal", folder = "Decoracion" })
		for i, d in ipairs({ 8, 6, 3.6 }) do
			u:cylinder({ name = "Sombrilla", length = 0.4, diameter = d, pos = { 0, 7.2 + i * 0.35, 0 }, color = (i % 2 == 1) and color or { 245, 245, 240 }, mat = "Fabric", folder = "Decoracion" })
		end
		for _, a in ipairs({ 0, 120, 240 }) do
			local r = math.rad(a)
			u:box({ name = "Silla", size = { 1.6, 1.8, 1.6 }, pos = { math.cos(r) * 3, 0.9, math.sin(r) * 3 }, color = { 240, 240, 236 }, folder = "Decoracion" })
		end
	end

	function P.propaneCage(g, pos, rotY)
		local c = g:at(pos, rotY)
		c:box({ name = "Jaula", size = { 6, 5, 2.6 }, pos = { 0, 2.5, 0 }, color = { 150, 154, 160 }, mat = "DiamondPlate", transparency = 0.55 })
		c:box({ name = "Techo", size = { 6.2, 0.3, 2.8 }, pos = { 0, 5.15, 0 }, color = { 60, 110, 170 }, mat = "Metal" })
		for i = 0, 3 do
			c:cylinder({ name = "Bombona", length = 2.4, diameter = 1.2, pos = { -2.1 + i * 1.4, 1.3, 0 }, color = { 236, 236, 232 }, mat = "Metal", folder = "Decoracion" })
		end
		local sign = c:box({ name = "Cartel", size = { 3, 0.8, 0.1 }, pos = { 0, 4.2, -1.36 }, color = { 60, 110, 170 }, folder = "Decoracion" })
		MB.sign(sign, "PROPANO", { bg = { 60, 110, 170 }, font = "GothamBlack" })
	end

	-- Poste con cartel de precios
	function P.pricePylon(g, pos, rotY, brand, color)
		local p = g:at(pos, rotY)
		p:box({ name = "Peana", size = { 6, 1.4, 3 }, pos = { 0, 0.7, 0 }, color = { 180, 176, 170 }, mat = "Concrete" })
		for _, x in ipairs({ -2, 2 }) do
			p:box({ name = "Pilar", size = { 0.8, 14, 0.8 }, pos = { x, 7, 0 }, color = { 60, 62, 70 }, mat = "Metal" })
		end
		local top = p:box({ name = "Marca", size = { 7, 3.4, 1.2 }, pos = { 0, 15.5, 0 }, color = color })
		for _, face in ipairs({ "Front", "Back" }) do
			MB.sign(top, brand, { face = face, font = "GothamBlack", color = { 255, 255, 255 } })
		end
		local prices = p:box({ name = "Precios", size = { 6, 5.4, 1 }, pos = { 0, 11, 0 }, color = { 30, 30, 34 } })
		for _, face in ipairs({ "Front", "Back" }) do
			MB.sign(prices, "95  1.89\nDIESEL  1.74", { face = face, font = "Arcade", color = { 255, 210, 60 }, glow = true, height = 0.9 })
		end
	end

	function P.guardrail(g, a, b)
		local dx, dz = b[1] - a[1], b[3] - a[3]
		local len = math.sqrt(dx * dx + dz * dz)
		local yaw = math.deg(math.atan2(-dz, dx))
		local r = g:at({ (a[1] + b[1]) / 2, 0, (a[3] + b[3]) / 2 }, yaw)
		r:box({ name = "Bionda", size = { len, 1, 0.3 }, pos = { 0, 2, 0 }, color = { 190, 194, 200 }, mat = "Metal" })
		for i = 0, math.floor(len / 6) do
			r:box({ name = "Poste", size = { 0.4, 2.4, 0.4 }, pos = { -len / 2 + i * 6, 1.2, 0.3 }, color = { 120, 124, 130 }, mat = "Metal" })
		end
	end

	-- Barrera de hormigón tipo New Jersey (a lo largo de X local)
	function P.barrier(g, pos, rotY)
		local b = g:at(pos, rotY)
		local concrete = { 226, 224, 218 }
		b:box({ name = "Barrera", size = { 8, 1.4, 2.6 }, pos = { 0, 0.7, 0 }, color = concrete, mat = "Concrete" })
		b:wedge({ name = "Barrera", size = { 8, 1.2, 0.7 }, pos = { 0, 2, -0.95 }, color = concrete, mat = "Concrete" })
		b:wedge({ name = "Barrera", size = { 8, 1.2, 0.7 }, pos = { 0, 2, 0.95 }, rot = { 0, 180, 0 }, color = concrete, mat = "Concrete" })
		b:box({ name = "Barrera", size = { 8, 2.2, 1.2 }, pos = { 0, 2.5, 0 }, color = concrete, mat = "Concrete" })
		for _, x in ipairs({ -2.6, 2.6 }) do
			b:box({ name = "Franja", size = { 1.6, 0.9, 2.7 }, pos = { x, 0.75, 0 }, color = { 205, 45, 45 }, folder = "Decoracion" })
		end
	end

	-- Poste eléctrico de ladrillo con travesaño (devuelve la altura de los cables)
	function P.pole(g, pos, height)
		local p = g:at(pos, 0)
		p:box({ name = "Poste", size = { 1.8, height, 1.8 }, pos = { 0, height / 2, 0 }, color = { 150, 82, 66 }, mat = "Brick" })
		p:box({ name = "Remate", size = { 2.2, 0.6, 2.2 }, pos = { 0, height + 0.3, 0 }, color = { 120, 70, 58 }, mat = "Concrete", folder = "Decoracion" })
		p:box({ name = "Travesano", size = { 9, 0.6, 0.6 }, pos = { 0, height - 1.5, 0 }, color = { 90, 70, 55 }, mat = "Wood", folder = "Decoracion" })
		for _, x in ipairs({ -3.5, 0, 3.5 }) do
			p:cylinder({ name = "Aislante", length = 0.8, diameter = 0.4, pos = { x, height - 0.8, 0 }, color = { 200, 200, 190 }, folder = "Decoracion" })
		end
		p:box({ name = "Transformador", size = { 1.6, 2.6, 1.6 }, pos = { 0, height - 5, -1.6 }, color = { 120, 124, 130 }, mat = "Metal", folder = "Decoracion" })
		return height - 0.6
	end

	-- Lámpara de techo con panel de neón y luz hacia abajo
	function P.ceilingLight(g, pos, withLight, color)
		local l = g:at(pos, 0)
		l:box({ name = "Carcasa", size = { 10, 0.6, 3 }, pos = { 0, 0, 0 }, color = { 50, 48, 60 }, folder = "Decoracion" })
		local panel = l:box({ name = "Panel", size = { 9, 0.2, 2.4 }, pos = { 0, -0.4, 0 }, color = color or { 255, 238, 214 }, mat = "Neon", folder = "Decoracion" })
		for _, x in ipairs({ -4, 4 }) do
			l:box({ name = "Cable", size = { 0.1, 2.2, 0.1 }, pos = { x, 1.4, 0 }, color = { 30, 30, 30 }, folder = "Decoracion" })
		end
		if withLight then
			MB.light(panel, "Surface", { face = "Bottom", brightness = 1.5, range = 40, angle = 120, color = color or { 255, 236, 210 } })
		end
	end

	-- Surtidor de gasolina
	function P.pump(g, pos, rotY)
		local p = g:at(pos, rotY)
		p:box({ name = "Surtidor", size = { 2.6, 5.4, 1.8 }, pos = { 0, 2.7, 0 }, color = { 236, 232, 228 } })
		p:box({ name = "Base", size = { 2.8, 0.6, 2 }, pos = { 0, 0.3, 0 }, color = { 60, 62, 70 }, mat = "Metal" })
		p:box({ name = "Cabezal", size = { 2.8, 1.2, 2 }, pos = { 0, 5.9, 0 }, color = { 205, 45, 45 } })
		for _, z in ipairs({ -0.95, 0.95 }) do
			p:box({ name = "Pantalla", size = { 1.8, 1, 0.1 }, pos = { 0, 4, z }, color = { 120, 230, 140 }, mat = "Neon", folder = "Decoracion" })
			p:box({ name = "Teclado", size = { 1.2, 0.8, 0.1 }, pos = { 0, 2.8, z }, color = { 40, 40, 46 }, folder = "Decoracion" })
		end
		for _, x in ipairs({ -1.45, 1.45 }) do
			p:box({ name = "Pistola", size = { 0.3, 1, 0.5 }, pos = { x, 3.4, 0 }, color = ({ { 40, 160, 60 }, { 30, 30, 30 } })[x < 0 and 1 or 2], folder = "Decoracion" })
			P.rod(p, { x, 3, 0 }, { x * 1.1, 0.6, 0.6 }, 0.2, { 30, 30, 30 }, "Rubber", "Decoracion")
		end
	end


	-- =================================================================
	--  Edificios configurables por país
	-- =================================================================
	local function copyTable(t)
		local out = {}
		for k, v in pairs(t) do
			out[k] = v
		end
		return out
	end

	-- Casa con la fachada hacia -Z local. o: w, h, d, color, mat, trim, floors, cols, roof ("flat", "gable", "pagoda"),
	-- roofColor, roofMat, door, doorColor, shutters, balcony, flowers, shop (texto), shopColor, logs, fireEscape, lit
	function P.house(g, pos, rotY, o)
		local h = g:at(pos, rotY)
		local w, H, d = o.w or 12, o.h or 14, o.d or 10
		local wall = o.color or { 240, 236, 228 }
		local trim = o.trim or darker(wall, 60)
		h:box({ name = "Casa", size = { w, H, d }, pos = { 0, H / 2, 0 }, color = wall, mat = o.mat or "Plaster" })
		h:box({ name = "Zocalo", size = { w + 0.1, 1.4, d + 0.3 }, pos = { 0, 0.7, 0 }, color = o.base or darker(wall, 70), mat = "Concrete" })
		if o.roof == "gable" or o.roof == "pagoda" then
			local rh = o.roofHeight or 4
			local over = o.roof == "pagoda" and 2.6 or 0.9
			local rc = o.roofColor or { 176, 82, 56 }
			local rmat = o.roofMat or "ClayRoofTiles"
			h:wedge({ name = "Tejado", size = { w + over * 2, rh, d / 2 + over }, pos = { 0, H + rh / 2, -d / 4 - over / 2 }, color = rc, mat = rmat })
			h:wedge({ name = "Tejado", size = { w + over * 2, rh, d / 2 + over }, pos = { 0, H + rh / 2, d / 4 + over / 2 }, rot = { 0, 180, 0 }, color = rc, mat = rmat })
			h:box({ name = "Alero", size = { w + over * 2, 0.5, 0.5 }, pos = { 0, H + 0.1, -d / 2 - over + 0.25 }, color = o.eaveColor or darker(rc, 40), folder = "Decoracion" })
		else
			h:box({ name = "Cornisa", size = { w + 0.6, 0.8, d + 0.6 }, pos = { 0, H + 0.4, 0 }, color = trim, mat = "Concrete" })
		end
		local floors = o.floors or math.max(1, math.floor(H / 6.5))
		local fh = H / floors
		local cols = o.cols or math.max(1, math.floor(w / 5))
		local front = -d / 2
		local doorCol = math.ceil(cols / 2)
		for f = 1, floors do
			local y = (f - 1) * fh + fh * 0.55
			for c = 1, cols do
				local x = -w / 2 + (c - 0.5) * w / cols
				if f == 1 and o.shop and c == doorCol then
					-- Tienda: escaparate ancho, toldo y rótulo
					h:box({ name = "Escaparate", size = { math.min(w - 2, 8), 4.6, 0.3 }, pos = { 0, 3.3, front - 0.1 }, color = o.lit and { 255, 214, 150 } or { 70, 90, 110 }, mat = o.lit and "Neon" or "Glass", transparency = o.lit and 0.35 or 0.1, folder = "Decoracion" })
					h:wedge({ name = "Toldo", size = { math.min(w - 1, 9), 1.2, 2.4 }, pos = { 0, 6.4, front - 1.2 }, color = o.shopColor or { 200, 50, 50 }, mat = "Fabric", folder = "Decoracion" })
					local sign = h:box({ name = "Rotulo", size = { math.min(w - 2, 9), 1.6, 0.3 }, pos = { 0, 7.9, front - 0.2 }, color = o.shopColor or { 200, 50, 50 }, folder = "Decoracion" })
					MB.sign(sign, o.shop, { font = o.shopFont or "GothamBlack", color = { 255, 255, 255 }, glow = o.lit })
				elseif f == 1 and o.door ~= false and c == doorCol then
					h:box({ name = "Puerta", size = { 3, 6, 0.3 }, pos = { x, 3, front - 0.1 }, color = o.doorColor or { 120, 72, 42 }, mat = "WoodPlanks", folder = "Decoracion" })
					h:box({ name = "Dintel", size = { 3.8, 0.5, 0.45 }, pos = { x, 6.25, front - 0.15 }, color = trim, folder = "Decoracion" })
				else
					h:box({ name = "Marco", size = { 2.8, 3.4, 0.3 }, pos = { x, y, front - 0.1 }, color = trim, folder = "Decoracion" })
					h:box({ name = "Ventana", size = { 2.2, 2.8, 0.34 }, pos = { x, y, front - 0.12 }, color = o.ruined and { 28, 32, 30 } or o.lit and ((f + c) % 3 == 0 and { 50, 56, 70 } or { 255, 206, 140 }) or (o.glass or { 66, 86, 108 }), mat = (o.lit and not o.ruined and (f + c) % 3 ~= 0) and "Neon" or "Glass", transparency = (o.lit and not o.ruined) and 0.3 or 0.1, folder = "Decoracion" })
					if o.ruined and (f * 5 + c * 3) % 4 == 0 then
						for _, r in ipairs({ 35, -35 }) do
							h:box({ name = "Tablon", size = { 3.4, 0.5, 0.15 }, pos = { x, y, front - 0.35 }, rot = { 0, 0, r }, color = { 120, 96, 70 }, mat = "WoodPlanks", folder = "Decoracion" })
						end
					end
					if o.shutters then
						for _, sx in ipairs({ -1.85, 1.85 }) do
							h:box({ name = "Contraventana", size = { 0.9, 3.2, 0.2 }, pos = { x + sx, y, front - 0.15 }, color = o.shutters, mat = "WoodPlanks", folder = "Decoracion" })
						end
					end
					if o.balcony and f > 1 then
						h:box({ name = "Balcon", size = { 3.6, 0.3, 1.4 }, pos = { x, y - 1.8, front - 0.7 }, color = trim, folder = "Decoracion" })
						h:box({ name = "Baranda", size = { 3.6, 0.15, 0.15 }, pos = { x, y - 0.7, front - 1.35 }, color = { 40, 40, 44 }, mat = "Metal", folder = "Decoracion" })
						for _, bx in ipairs({ -1.7, 0, 1.7 }) do
							h:box({ name = "Barrote", size = { 0.12, 1.1, 0.12 }, pos = { x + bx, y - 1.2, front - 1.35 }, color = { 40, 40, 44 }, mat = "Metal", folder = "Decoracion" })
						end
						if o.flowers then
							h:ball({ name = "Flores", diameter = 0.9, pos = { x - 1, y - 1.3, front - 0.8 }, color = o.flowers, mat = "LeafyGrass", folder = "Decoracion" })
						end
					end
				end
			end
		end
		if o.logs then
			for y = 1.8, H - 0.6, 1.25 do
				h:cylinder({ name = "Tronco", axis = "x", length = w + 0.6, diameter = 0.9, pos = { 0, y, front + 0.3 }, color = darker(wall, 10), mat = "Wood", folder = "Decoracion" })
			end
		end
		if o.ruined then
			P.overgrowth(h, w, H, front - 0.2)
		end
		if o.fireEscape and floors > 1 then
			for f = 2, floors do
				local y = (f - 1) * fh
				h:box({ name = "Escape", size = { w * 0.55, 0.25, 2.2 }, pos = { 0, y, front - 1.1 }, color = { 40, 40, 44 }, mat = "DiamondPlate", folder = "Decoracion" })
				h:box({ name = "Baranda", size = { w * 0.55, 0.15, 0.15 }, pos = { 0, y + 2.4, front - 2.15 }, color = { 40, 40, 44 }, mat = "Metal", folder = "Decoracion" })
				if f < floors then
					P.segment(h, { -w * 0.2, y + 0.2, front - 1.1 }, { w * 0.2, y + fh, front - 1.1 }, 0.5, { 40, 40, 44 }, "Metal", "Decoracion")
				end
			end
		end
	end

	-- Fila de casas a lo largo de X (de x0 a x1) con estilos que se van alternando
	function P.houseRow(g, z, rotY, x0, x1, styles, depth)
		local x, i = x0, 0
		while x < x1 - 3 do
			i = i + 1
			local o = copyTable(styles[(i - 1) % #styles + 1])
			o.w = math.min(o.w or 12, x1 - x)
			o.d = depth or o.d
			P.house(g, { x + o.w / 2, 0, z }, rotY, o)
			x = x + o.w
		end
	end

	-- =================================================================
	--  Vegetación y naturaleza
	-- =================================================================
	function P.pineTree(g, pos, scale, snowy)
		local t = g:at(pos, 0)
		local s = scale or 1
		t:cylinder({ name = "Tronco", length = 4 * s, diameter = 1.2 * s, pos = { 0, 2 * s, 0 }, color = { 90, 64, 46 }, mat = "Wood" })
		local tiers = { { 9, 4 }, { 7.4, 6.6 }, { 5.8, 9 }, { 4, 11.2 }, { 2.2, 13.2 } }
		for _, tier in ipairs(tiers) do
			t:cylinder({ name = "Ramas", length = 2.6 * s, diameter = tier[1] * s, pos = { 0, tier[2] * s, 0 }, color = { 46, 92, 62 }, mat = "LeafyGrass", folder = "Decoracion" })
			if snowy then
				t:cylinder({ name = "Nieve", length = 0.5 * s, diameter = tier[1] * 0.85 * s, pos = { 0, (tier[2] + 1.4) * s, 0 }, color = { 244, 248, 252 }, mat = "Snow", folder = "Decoracion" })
			end
		end
	end

	function P.palmTree(g, pos, scale)
		local t = g:at(pos, 0)
		local s = scale or 1
		local prev = { 0, 0, 0 }
		for i = 1, 6 do
			local nextPoint = { math.sin(i * 0.35) * 1.4 * s, i * 2.6 * s, 0 }
			P.rod(t, prev, nextPoint, (1.5 - i * 0.08) * s, { 150, 116, 78 }, "Wood")
			prev = nextPoint
		end
		local top = prev
		for k = 0, 7 do
			local a = k * 45
			local leaf = t:at(top, a)
			leaf:box({ name = "Hoja", size = { 1.6 * s, 0.25 * s, 7 * s }, pos = { 0, -0.6 * s, -3.2 * s }, rot = { -22, 0, 0 }, color = (k % 2 == 0) and { 76, 140, 62 } or { 96, 156, 70 }, mat = "LeafyGrass", folder = "Decoracion" })
		end
		for k = 0, 2 do
			t:ball({ name = "Coco", diameter = 0.9 * s, pos = { top[1] + math.cos(k * 2.1) * 0.7 * s, top[2] - 0.6 * s, math.sin(k * 2.1) * 0.7 * s }, color = { 110, 80, 50 }, folder = "Decoracion" })
		end
	end

	function P.cactus(g, pos, scale)
		local c = g:at(pos, 0)
		local s = scale or 1
		local green = { 70, 130, 72 }
		c:cylinder({ name = "Cactus", length = 7 * s, diameter = 1.4 * s, pos = { 0, 3.5 * s, 0 }, color = green, mat = "Grass" })
		c:ball({ name = "Punta", diameter = 1.4 * s, pos = { 0, 7 * s, 0 }, color = green, mat = "Grass", folder = "Decoracion" })
		for _, side in ipairs({ -1, 1 }) do
			local y = (side > 0 and 3.2 or 4.2) * s
			c:cylinder({ name = "Brazo", axis = "x", length = 1.6 * s, diameter = 0.9 * s, pos = { side * 1.2 * s, y, 0 }, color = green, mat = "Grass", folder = "Decoracion" })
			c:cylinder({ name = "Brazo", length = 2.4 * s, diameter = 0.9 * s, pos = { side * 1.9 * s, y + 1.1 * s, 0 }, color = green, mat = "Grass", folder = "Decoracion" })
			c:ball({ name = "Punta", diameter = 0.9 * s, pos = { side * 1.9 * s, y + 2.3 * s, 0 }, color = green, mat = "Grass", folder = "Decoracion" })
		end
	end

	function P.snowPile(g, pos, scale)
		local s = scale or 1
		for _, o in ipairs({ { 0, 0, 0, 5 }, { 1.8, 0, 0.8, 3.6 }, { -1.6, 0, -0.6, 3.4 } }) do
			g:ball({ name = "Nieve", diameter = o[4] * s, pos = { pos[1] + o[1] * s, pos[2] - o[4] * s * 0.25, pos[3] + o[3] * s }, color = { 242, 246, 252 }, mat = "Snow" })
		end
	end

	-- =================================================================
	--  Monumentos y estructuras
	-- =================================================================
	-- Puerta torii (se atraviesa a lo largo de X local)
	function P.torii(g, pos, rotY, width, height)
		local t = g:at(pos, rotY)
		local red = { 200, 46, 36 }
		for _, z in ipairs({ -width / 2, width / 2 }) do
			t:cylinder({ name = "Pilar", length = height, diameter = 1.4, pos = { 0, height / 2, z }, color = red, mat = "WoodPlanks" })
			t:cylinder({ name = "Base", length = 1, diameter = 1.9, pos = { 0, 0.5, z }, color = { 30, 30, 32 }, folder = "Decoracion" })
		end
		t:box({ name = "Nuki", size = { 1, 1, width + 2 }, pos = { 0, height * 0.72, 0 }, color = red, mat = "WoodPlanks" })
		t:box({ name = "Kasagi", size = { 1.6, 1.2, width + 6 }, pos = { 0, height + 0.6, 0 }, color = { 30, 30, 32 }, mat = "WoodPlanks" })
		t:box({ name = "Shimaki", size = { 1.3, 0.9, width + 4.6 }, pos = { 0, height - 0.3, 0 }, color = red, mat = "WoodPlanks" })
		for _, z in ipairs({ -1, 1 }) do
			t:wedge({ name = "Punta", size = { 1.6, 1, 1.6 }, pos = { 0, height + 1.7, z * (width / 2 + 2.2) }, rot = { 0, z > 0 and 0 or 180, 0 }, color = { 30, 30, 32 }, folder = "Decoracion" })
		end
		local plaque = t:box({ name = "Placa", size = { 0.4, 2.2, 1.8 }, pos = { 0, height * 0.86, 0 }, color = { 30, 30, 32 }, folder = "Decoracion" })
		MB.sign(plaque, "神社", { face = "Left", color = { 240, 200, 90 } })
		MB.sign(plaque, "神社", { face = "Right", color = { 240, 200, 90 } })
	end

	function P.lantern(g, pos, color, withLight)
		local l = g:at(pos, 0)
		local c = color or { 230, 60, 40 }
		local body = l:ball({ name = "Farolillo", diameter = 1.6, pos = { 0, 0, 0 }, color = c, mat = "Neon", transparency = 0.15, folder = "Decoracion" })
		l:cylinder({ name = "Tapa", length = 0.25, diameter = 0.9, pos = { 0, 0.8, 0 }, color = { 30, 30, 32 }, folder = "Decoracion" })
		l:cylinder({ name = "Tapa", length = 0.25, diameter = 0.9, pos = { 0, -0.8, 0 }, color = { 30, 30, 32 }, folder = "Decoracion" })
		if withLight then
			MB.light(body, "Point", { color = c, brightness = 1.2, range = 14 })
		end
	end

	-- Farolillo de piedra japonés (tōrō)
	function P.stoneLantern(g, pos)
		local t = g:at(pos, 0)
		local stone = { 150, 148, 140 }
		t:box({ name = "Base", size = { 2.4, 0.8, 2.4 }, pos = { 0, 0.4, 0 }, color = stone, mat = "Slate" })
		t:cylinder({ name = "Fuste", length = 2.6, diameter = 0.9, pos = { 0, 2.1, 0 }, color = stone, mat = "Slate" })
		t:box({ name = "Plataforma", size = { 2.2, 0.5, 2.2 }, pos = { 0, 3.6, 0 }, color = stone, mat = "Slate" })
		local light = t:box({ name = "Fuego", size = { 1.4, 1.3, 1.4 }, pos = { 0, 4.5, 0 }, color = { 255, 200, 120 }, mat = "Neon", folder = "Decoracion" })
		t:box({ name = "Techo", size = { 2.8, 0.6, 2.8 }, pos = { 0, 5.45, 0 }, color = stone, mat = "Slate" })
		t:ball({ name = "Remate", diameter = 0.8, pos = { 0, 6, 0 }, color = stone, mat = "Slate", folder = "Decoracion" })
		MB.light(light, "Point", { color = { 255, 196, 120 }, brightness = 1, range = 12 })
	end

	-- Guirnalda de banderines (papel picado)
	function P.bunting(g, a, b, count, sag, colors)
		local prev = nil
		for i = 0, count do
			local t = i / count
			local point = { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t - sag * 4 * t * (1 - t), a[3] + (b[3] - a[3]) * t }
			if prev then
				P.segment(g, prev, point, 0.08, { 40, 40, 40 }, "Plastic", "Decoracion")
			end
			if i > 0 and i < count then
				local yaw = math.deg(math.atan2(-(b[3] - a[3]), b[1] - a[1]))
				g:box({ name = "Banderin", size = { 1.1, 1.3, 0.05 }, pos = { point[1], point[2] - 0.7, point[3] }, rot = { 0, yaw, 0 }, color = colors[(i % #colors) + 1], mat = "Fabric", folder = "Decoracion", shadow = false })
			end
			prev = point
		end
	end

	function P.fountain(g, pos, radius, waterColor)
		local f = g:at(pos, 0)
		local stone = { 206, 200, 186 }
		local water = waterColor or { 90, 160, 200 }
		f:cylinder({ name = "Pileta", length = 2.4, diameter = radius * 2, pos = { 0, 1.2, 0 }, color = stone, mat = "Limestone" })
		f:cylinder({ name = "Agua", length = 0.2, diameter = radius * 2 - 1.2, pos = { 0, 2.35, 0 }, color = water, mat = "Glass", transparency = 0.3, reflectance = 0.2, folder = "Decoracion" })
		f:cylinder({ name = "Columna", length = 5, diameter = 1.6, pos = { 0, 4.5, 0 }, color = stone, mat = "Limestone" })
		f:cylinder({ name = "Taza", length = 0.8, diameter = radius, pos = { 0, 6.8, 0 }, color = stone, mat = "Limestone" })
		f:cylinder({ name = "Agua", length = 0.15, diameter = radius - 0.6, pos = { 0, 7.25, 0 }, color = water, mat = "Glass", transparency = 0.3, folder = "Decoracion" })
		f:ball({ name = "Remate", diameter = 1.2, pos = { 0, 7.9, 0 }, color = stone, mat = "Limestone", folder = "Decoracion" })
	end

	-- Quiosco abierto con columnas y tejado cónico
	function P.kiosk(g, pos, radius, color, roofColor)
		local k = g:at(pos, 0)
		k:cylinder({ name = "Plataforma", length = 1.4, diameter = radius * 2, pos = { 0, 0.7, 0 }, color = { 210, 204, 192 }, mat = "Limestone" })
		for i = 0, 7 do
			local a = math.rad(i * 45 + 22.5)
			k:cylinder({ name = "Columna", length = 8, diameter = 0.7, pos = { math.cos(a) * (radius - 1), 5.4, math.sin(a) * (radius - 1) }, color = color, mat = "Metal" })
		end
		for i, d in ipairs({ radius * 2 + 1.5, radius * 1.6, radius * 1.1, radius * 0.6 }) do
			k:cylinder({ name = "Tejado", length = 1, diameter = d, pos = { 0, 9.4 + i * 0.95, 0 }, color = (i % 2 == 1) and roofColor or { 245, 245, 240 }, mat = "Metal" })
		end
		k:ball({ name = "Remate", diameter = 1.2, pos = { 0, 14.6, 0 }, color = { 220, 180, 60 }, mat = "Metal", folder = "Decoracion" })
		-- Barandilla entre columnas, con entradas en los lados +X y -X
		for i = 0, 7 do
			if i ~= 3 and i ~= 7 then
				local a1, a2 = math.rad(i * 45 + 22.5), math.rad(i * 45 + 67.5)
				local r = radius - 1
				for _, y in ipairs({ 2.2, 3.6 }) do
					P.segment(k, { math.cos(a1) * r, y, math.sin(a1) * r }, { math.cos(a2) * r, y, math.sin(a2) * r }, 0.3, color, "Metal")
				end
			end
		end
		for _, side in ipairs({ -1, 1 }) do
			k:box({ name = "Escalon", size = { 2, 0.7, 5 }, pos = { side * (radius + 0.9), 0.35, 0 }, color = { 190, 184, 172 }, mat = "Limestone" })
		end
	end

	-- Puesto de mercado con toldo de tela (frente hacia -Z local)
	function P.marketStall(g, pos, rotY, color, text, goods)
		local m = g:at(pos, rotY)
		local wood = { 150, 108, 70 }
		m:box({ name = "Mostrador", size = { 8, 3.4, 3 }, pos = { 0, 1.7, 0 }, color = wood, mat = "WoodPlanks" })
		for _, x in ipairs({ -3.8, 3.8 }) do
			for _, z in ipairs({ -1.4, 1.4 }) do
				m:box({ name = "Poste", size = { 0.4, 7.4, 0.4 }, pos = { x, 3.7, z }, color = darker(wood, 30), mat = "Wood" })
			end
		end
		for i = 0, 3 do
			m:box({ name = "Toldo", size = { 2.1, 0.25, 4.4 }, pos = { -3.15 + i * 2.1, 7.6, -0.3 }, rot = { 12, 0, 0 }, color = (i % 2 == 0) and color or { 245, 240, 230 }, mat = "Fabric" })
		end
		local palette = goods or { { 230, 60, 50 }, { 250, 190, 60 }, { 110, 180, 80 }, { 240, 130, 40 } }
		for i = 0, 5 do
			m:ball({ name = "Producto", diameter = 0.9, pos = { -3 + i * 1.2, 3.75, -0.6 }, color = palette[(i % #palette) + 1], folder = "Decoracion" })
		end
		if text then
			local sign = m:box({ name = "Rotulo", size = { 6, 1.2, 0.2 }, pos = { 0, 6.6, -1.6 }, color = color, folder = "Decoracion" })
			MB.sign(sign, text, { font = "LuckiestGuy", color = { 255, 255, 255 }, bg = color })
		end
	end

	function P.trafficLight(g, pos, rotY)
		local t = g:at(pos, rotY)
		t:cylinder({ name = "Poste", length = 12, diameter = 0.6, pos = { 0, 6, 0 }, color = { 40, 42, 46 }, mat = "Metal" })
		t:box({ name = "Brazo", size = { 0.4, 0.4, 6 }, pos = { 0, 11.6, -3 }, color = { 40, 42, 46 }, mat = "Metal", folder = "Decoracion" })
		t:box({ name = "Semaforo", size = { 1.4, 3.8, 1.2 }, pos = { 0, 10.2, -5.6 }, color = { 30, 30, 34 }, mat = "Metal", folder = "Decoracion" })
		local colors = { { 230, 40, 40 }, { 245, 190, 40 }, { 60, 220, 90 } }
		for i, c in ipairs(colors) do
			t:cylinder({ name = "Luz", axis = "z", length = 0.15, diameter = 0.8, pos = { 0, 11.4 - i * 1.15, -6.25 }, color = c, mat = (i == 3) and "Neon" or "SmoothPlastic", folder = "Decoracion" })
		end
	end

	-- Columna clásica (rota = más baja y sin capitel)
	function P.column(g, pos, height, diameter, color, mat, broken)
		local c = g:at(pos, 0)
		local m = mat or "Sandstone"
		c:box({ name = "Basa", size = { diameter + 1, 1, diameter + 1 }, pos = { 0, 0.5, 0 }, color = color, mat = m })
		c:cylinder({ name = "Fuste", length = height, diameter = diameter, pos = { 0, 1 + height / 2, 0 }, color = color, mat = m })
		if not broken then
			c:box({ name = "Capitel", size = { diameter + 1.2, 1.2, diameter + 1.2 }, pos = { 0, 1.6 + height, 0 }, color = color, mat = m })
		end
	end

	function P.obelisk(g, pos, height, width, color)
		local o = g:at(pos, 0)
		local c = color or { 214, 186, 132 }
		o:box({ name = "Pedestal", size = { width + 3, 2, width + 3 }, pos = { 0, 1, 0 }, color = darker(c, 20), mat = "Sandstone" })
		local segments = 4
		for i = 1, segments do
			local w = width * (1 - (i - 1) * 0.08)
			o:box({ name = "Obelisco", size = { w, height / segments, w }, pos = { 0, 2 + (i - 0.5) * height / segments, 0 }, color = c, mat = "Sandstone" })
		end
		for _, r in ipairs({ 0, 90, 180, 270 }) do
			o:wedge({ name = "Piramidion", size = { width * 0.68, 2.4, width * 0.34 }, pos = { 0, 3.2 + height, 0 }, rot = { 0, r, 0 }, color = { 230, 196, 90 }, mat = "Metal", folder = "Decoracion" })
		end
	end

	-- Pirámide escalonada (decoración de fondo)
	function P.pyramid(g, pos, base, height, steps, color)
		local p = g:at(pos, 0)
		for i = 1, steps do
			local size = base * (1 - (i - 1) / steps)
			local h = height / steps
			p:box({ name = "Piramide", size = { size, h, size }, pos = { 0, (i - 0.5) * h, 0 }, color = color, mat = "Sandstone", folder = "Decoracion" })
		end
	end

	function P.onionDome(g, pos, diameter, color)
		local o = g:at(pos, 0)
		o:cylinder({ name = "Tambor", length = diameter * 0.6, diameter = diameter * 0.8, pos = { 0, diameter * 0.3, 0 }, color = { 240, 236, 228 }, mat = "Plaster" })
		o:ball({ name = "Cupula", diameter = diameter, pos = { 0, diameter * 0.95, 0 }, color = color, mat = "Metal", reflectance = 0.15 })
		o:ball({ name = "Punta", diameter = diameter * 0.45, pos = { 0, diameter * 1.5, 0 }, color = color, mat = "Metal" })
		o:cylinder({ name = "Aguja", length = diameter * 0.7, diameter = 0.3, pos = { 0, diameter * 1.95, 0 }, color = { 230, 190, 70 }, mat = "Metal", folder = "Decoracion" })
		o:box({ name = "Cruz", size = { 0.25, 1.6, 0.25 }, pos = { 0, diameter * 2.4, 0 }, color = { 230, 190, 70 }, mat = "Metal", folder = "Decoracion" })
		o:box({ name = "Cruz", size = { 1, 0.25, 0.25 }, pos = { 0, diameter * 2.5, 0 }, color = { 230, 190, 70 }, mat = "Metal", folder = "Decoracion" })
	end

	-- Campanario (frente hacia -Z local)
	function P.bellTower(g, pos, rotY, height, color, roofColor)
		local t = g:at(pos, rotY)
		t:box({ name = "Torre", size = { 7, height, 7 }, pos = { 0, height / 2, 0 }, color = color, mat = "Plaster" })
		t:box({ name = "Cornisa", size = { 7.8, 0.8, 7.8 }, pos = { 0, height - 4.6, 0 }, color = darker(color, 40), mat = "Concrete" })
		for _, r in ipairs({ 0, 90, 180, 270 }) do
			local face = t:at({ 0, 0, 0 }, r)
			face:box({ name = "Arco", size = { 2.6, 3.4, 0.4 }, pos = { 0, height - 2.4, -3.45 }, color = { 30, 26, 24 }, folder = "Decoracion" })
		end
		t:ball({ name = "Campana", diameter = 1.6, pos = { 0, height - 2.4, -2.6 }, color = { 190, 150, 60 }, mat = "Metal", folder = "Decoracion" })
		for i, w in ipairs({ 7.6, 5.4, 3.2, 1.2 }) do
			t:box({ name = "Chapitel", size = { w, 1.2, w }, pos = { 0, height + (i - 0.5) * 1.2, 0 }, color = roofColor or { 176, 82, 56 }, mat = "ClayRoofTiles" })
		end
		t:box({ name = "Cruz", size = { 0.3, 2.2, 0.3 }, pos = { 0, height + 5.9, 0 }, color = { 60, 56, 52 }, mat = "Metal", folder = "Decoracion" })
		t:box({ name = "Cruz", size = { 1.3, 0.3, 0.3 }, pos = { 0, height + 6.3, 0 }, color = { 60, 56, 52 }, mat = "Metal", folder = "Decoracion" })
	end

	-- Nieve que cae: emisor de partículas en una pieza invisible (size = { X, Z })
	function P.snowfall(g, pos, size, rate)
		local part = g:box({ name = "Nevada", size = { size[1], 1, size[2] }, pos = pos, transparency = 1, folder = "Decoracion", shadow = false })
		part.CanQuery = false
		part.CanTouch = false
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "Nieve"
		emitter.EmissionDirection = Enum.NormalId.Bottom
		emitter.Rate = rate or 120
		emitter.Lifetime = NumberRange.new(9, 12)
		emitter.Speed = NumberRange.new(5, 7)
		emitter.SpreadAngle = Vector2.new(12, 12)
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-40, 40)
		emitter.Size = NumberSequence.new(0.35)
		emitter.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
		emitter.LightEmission = 0.2
		emitter.Parent = part
		return emitter
	end

	function P.snowman(g, pos)
		local s = g:at(pos, 0)
		for _, b in ipairs({ { 0, 2, 4 }, { 0, 5.1, 3 }, { 0, 7.4, 2.1 } }) do
			s:ball({ name = "Nieve", diameter = b[3], pos = { 0, b[2], 0 }, color = { 246, 248, 252 }, mat = "Snow" })
		end
		s:cylinder({ name = "Nariz", axis = "z", length = 1, diameter = 0.3, pos = { 0, 7.4, -1.3 }, color = { 240, 130, 40 }, folder = "Decoracion" })
		s:cylinder({ name = "Sombrero", length = 1.6, diameter = 1.4, pos = { 0, 9.1, 0 }, color = { 30, 30, 34 }, mat = "Fabric", folder = "Decoracion" })
		s:cylinder({ name = "Ala", length = 0.2, diameter = 2.2, pos = { 0, 8.35, 0 }, color = { 30, 30, 34 }, mat = "Fabric", folder = "Decoracion" })
		s:cylinder({ name = "Bufanda", length = 0.6, diameter = 2.3, pos = { 0, 6.4, 0 }, color = { 200, 40, 40 }, mat = "Fabric", folder = "Decoracion" })
	end

	function P.logPile(g, pos, rotY, length)
		local l = g:at(pos, rotY)
		local rows = { { 4, 0.9 }, { 3, 2.5 }, { 2, 4.1 }, { 1, 5.7 } }
		for _, r in ipairs(rows) do
			for i = 1, r[1] do
				local z = (i - (r[1] + 1) / 2) * 1.8
				l:cylinder({ name = "Tronco", axis = "x", length = length, diameter = 1.8, pos = { 0, r[2], z }, color = { 140, 100, 66 }, mat = "Wood" })
			end
		end
	end

	function P.taxi(g, pos, rotY)
		P.car(g, pos, rotY, { 250, 200, 30 })
		local t = g:at(pos, rotY)
		local sign = t:box({ name = "Taxi", size = { 1.8, 0.7, 0.8 }, pos = { 0, 5.6, 1.3 }, color = { 250, 250, 240 }, mat = "Neon", folder = "Decoracion" })
		MB.sign(sign, "TAXI", { face = "Front", font = "GothamBlack", color = { 30, 30, 30 } })
		t:box({ name = "Franja", size = { 5.45, 0.4, 6 }, pos = { 0, 2.3, 0.6 }, color = { 30, 30, 30 }, folder = "Decoracion" })
	end

	function P.hotdogCart(g, pos, rotY)
		local c = g:at(pos, rotY)
		c:box({ name = "Carrito", size = { 6, 3, 3 }, pos = { 0, 2.4, 0 }, color = { 220, 220, 216 }, mat = "Metal" })
		for _, x in ipairs({ -2, 2 }) do
			c:cylinder({ name = "Rueda", axis = "z", length = 0.4, diameter = 1.8, pos = { x, 0.9, -1.6 }, color = { 30, 30, 32 }, mat = "Rubber", folder = "Decoracion" })
		end
		local sign = c:box({ name = "Rotulo", size = { 5, 1, 0.1 }, pos = { 0, 3, -1.56 }, color = { 200, 40, 40 }, folder = "Decoracion" })
		MB.sign(sign, "HOT DOGS", { bg = { 200, 40, 40 }, font = "GothamBlack", color = { 255, 230, 120 } })
		c:cylinder({ name = "Palo", length = 4, diameter = 0.2, pos = { 0, 5.9, 0 }, color = { 180, 180, 186 }, folder = "Decoracion" })
		for i, d in ipairs({ 6.5, 4.4, 2.2 }) do
			c:cylinder({ name = "Sombrilla", length = 0.35, diameter = d, pos = { 0, 7.6 + i * 0.3, 0 }, color = (i % 2 == 1) and { 40, 120, 200 } or { 250, 200, 40 }, mat = "Fabric", folder = "Decoracion" })
		end
	end

	-- Boca de metro con barandilla y farolas verdes
	function P.subwayEntrance(g, pos, rotY)
		local s = g:at(pos, rotY)
		s:box({ name = "Hueco", size = { 6, 0.2, 10 }, pos = { 0, 0.05, 0 }, color = { 20, 20, 24 }, folder = "Decoracion" })
		for i = 1, 5 do
			s:box({ name = "Escalon", size = { 5.6, 0.1, 1.6 }, pos = { 0, 0.2, -4 + i * 1.6 }, color = { 90, 90, 96 }, mat = "Concrete", folder = "Decoracion" })
		end
		for _, x in ipairs({ -3, 3 }) do
			P.railing(s, { x, 0, -5 }, { x, 0, 5 }, 3.2, { 40, 80, 50 })
			s:cylinder({ name = "Farola", length = 4.4, diameter = 0.35, pos = { x, 2.2, -5 }, color = { 40, 80, 50 }, mat = "Metal" })
			local globe = s:ball({ name = "Globo", diameter = 1.1, pos = { x, 4.8, -5 }, color = { 120, 240, 140 }, mat = "Neon", folder = "Decoracion" })
			if x < 0 then
				MB.light(globe, "Point", { color = { 140, 255, 160 }, brightness = 1, range = 10 })
			end
		end
		P.railing(s, { -3, 0, 5 }, { 3, 0, 5 }, 3.2, { 40, 80, 50 })
		local sign = s:box({ name = "Cartel", size = { 5.4, 1, 0.2 }, pos = { 0, 3.8, 5 }, color = { 30, 30, 34 }, folder = "Decoracion" })
		MB.sign(sign, "SUBWAY", { face = "Front", font = "GothamBlack", color = { 255, 255, 255 } })
	end
	-- =================================================================
	--  Edificios en los que se puede entrar
	-- =================================================================
	-- Pared a lo largo de X local (de x0 a x1, centrada en z) con huecos { xa, xb, ya, yb } (y relativa a y0)
	function P.wallWithHoles(g, x0, x1, z, y0, h, t, holes, color, mat)
		local sorted = {}
		for i, hole in ipairs(holes) do
			sorted[i] = hole
		end
		table.sort(sorted, function(a, c)
			return a[1] < c[1]
		end)
		local function piece(xa, xb, ya, yb)
			if xb - xa > 0.01 and yb - ya > 0.01 then
				g:box({ name = "Pared", size = { xb - xa, yb - ya, t }, pos = { (xa + xb) / 2, y0 + (ya + yb) / 2, z }, color = color, mat = mat or "Plaster" })
			end
		end
		local cursor = x0
		for _, hole in ipairs(sorted) do
			piece(cursor, hole[1], 0, h)
			piece(hole[1], hole[2], 0, hole[3])
			piece(hole[1], hole[2], hole[4], h)
			cursor = hole[2]
		end
		piece(cursor, x1, 0, h)
	end

	-- Igual, pero a lo largo de Z local (de z0 a z1, centrada en x); los huecos usan coordenadas Z
	function P.wallWithHolesZ(g, z0, z1, x, y0, h, t, holes, color, mat)
		P.wallWithHoles(g:at({ x, 0, 0 }, -90), z0, z1, 0, y0, h, t, holes, color, mat)
	end

	-- Casa de dos plantas con escalera interior, puertas y ventanas abiertas y balcón (fachada hacia -Z local).
	-- o: w, d, color, trim, roofColor, floor, wallMat, furniture
	function P.openHouse(g, pos, rotY, o)
		local h = g:at(pos, rotY)
		local W, D, FH, T = o.w or 26, o.d or 20, 9, 1
		local wall = o.color or { 200, 200, 200 }
		local trim = o.trim or { 245, 245, 240 }
		local mat = o.wallMat or "Plaster"
		local floorColor = o.floor or { 150, 110, 76 }
		local front, back = -D / 2 + T / 2, D / 2 - T / 2
		local function win(x, y)
			return { x - 2, x + 2, (y or 0) + 3, (y or 0) + 6.5 }
		end
		h:box({ name = "Suelo", size = { W, 0.6, D }, pos = { 0, 0.3, 0 }, color = floorColor, mat = "WoodPlanks" })
		-- Planta baja: puerta delantera, puerta trasera y ventanas
		P.wallWithHoles(h, -W / 2, W / 2, front, 0, FH, T, { { -2, 2, 0, 7 }, win(-7), win(7) }, wall, mat)
		P.wallWithHoles(h, -W / 2, W / 2, back, 0, FH, T, { win(-7), { 6, 10, 0, 7 } }, wall, mat)
		for _, x in ipairs({ -W / 2 + T / 2, W / 2 - T / 2 }) do
			P.wallWithHolesZ(h, -D / 2 + T, D / 2 - T, x, 0, FH, T, { { -3, 3, 3, 6.5 } }, wall, mat)
		end
		-- Escalera junto a la pared derecha (sube hacia +Z) y hueco en el suelo de arriba
		local sx = W / 2 - T - 2.2
		local z0 = -D / 2 + T + 1
		P.stairs(h, { sx, 0.6, z0 }, 0, 9, 1, 1.3, 4, floorColor)
		local hx = W / 2 - T - 4.4
		local hz = z0 + 9 * 1.3
		h:box({ name = "Piso", size = { hx + W / 2, 0.6, D }, pos = { (hx - W / 2) / 2, FH + 0.3, 0 }, color = floorColor, mat = "WoodPlanks" })
		h:box({ name = "Piso", size = { W / 2 - hx, 0.6, D / 2 - hz }, pos = { (hx + W / 2) / 2, FH + 0.3, (hz + D / 2) / 2 }, color = floorColor, mat = "WoodPlanks" })
		P.railing(h, { hx, FH + 0.6, -D / 2 + T }, { hx, FH + 0.6, hz }, 3, trim)
		-- Planta alta: puerta al balcón y ventanas
		P.wallWithHoles(h, -W / 2, W / 2, front, FH + 0.6, FH - 0.6, T, { { -2, 2, 0, 7 }, win(-7), win(7) }, wall, mat)
		P.wallWithHoles(h, -W / 2, W / 2, back, FH + 0.6, FH - 0.6, T, { win(-7), win(7) }, wall, mat)
		for _, x in ipairs({ -W / 2 + T / 2, W / 2 - T / 2 }) do
			P.wallWithHolesZ(h, -D / 2 + T, D / 2 - T, x, FH + 0.6, FH - 0.6, T, { { -3, 3, 3, 6.5 } }, wall, mat)
		end
		-- Techo a dos aguas
		local top = 2 * FH
		h:box({ name = "Techo", size = { W, 0.6, D }, pos = { 0, top + 0.3, 0 }, color = trim, mat = "Concrete" })
		local rc = o.roofColor or { 120, 70, 60 }
		h:wedge({ name = "Tejado", size = { W + 1.6, 4, D / 2 + 1 }, pos = { 0, top + 2.6, -D / 4 - 0.5 }, color = rc, mat = "RoofShingles" })
		if o.ruined then
			-- Media cubierta hundida: escombros en el piso de arriba
			h:wedge({ name = "Tejado", size = { W / 2 + 0.8, 4, D / 2 + 1 }, pos = { -W / 4 - 0.4, top + 2.6, D / 4 + 0.5 }, rot = { 0, 180, 0 }, color = rc, mat = "RoofShingles" })
			P.debris(h, { W / 4, FH + 0.6, D / 4 }, 1.2)
			P.overgrowth(h, W, top, -D / 2 - 0.2)
			P.overgrowth(h:at({ 0, 0, 0 }, 180), W, top, -D / 2 - 0.2)
		else
			h:wedge({ name = "Tejado", size = { W + 1.6, 4, D / 2 + 1 }, pos = { 0, top + 2.6, D / 4 + 0.5 }, rot = { 0, 180, 0 }, color = rc, mat = "RoofShingles" })
		end
		-- Molduras
		for _, z in ipairs({ -D / 2 - 0.1, D / 2 + 0.1 }) do
			h:box({ name = "Moldura", size = { W + 0.4, 0.6, 0.3 }, pos = { 0, FH + 0.3, z }, color = trim, folder = "Decoracion" })
		end
		for _, x in ipairs({ -W / 2, W / 2 }) do
			for _, z in ipairs({ -D / 2, D / 2 }) do
				h:box({ name = "Esquina", size = { 0.8, top, 0.8 }, pos = { x, top / 2, z }, color = trim, folder = "Decoracion" })
			end
		end
		-- Porche con balcón encima
		h:box({ name = "Balcon", size = { 12, 0.6, 4 }, pos = { 0, FH + 0.3, -D / 2 - 2 }, color = floorColor, mat = "WoodPlanks" })
		P.railing(h, { -6, FH + 0.6, -D / 2 - 3.8 }, { 6, FH + 0.6, -D / 2 - 3.8 }, 3, trim)
		for _, x in ipairs({ -5.6, 5.6 }) do
			h:box({ name = "Columna", size = { 0.8, FH, 0.8 }, pos = { x, FH / 2, -D / 2 - 3.6 }, color = trim })
		end
		h:box({ name = "Escalon", size = { 6, 0.6, 2 }, pos = { 0, 0.3, -D / 2 - 1 }, color = { 180, 176, 170 }, mat = "Concrete" })
		if o.furniture ~= false then
			-- Sofá, mesa, cocina y nevera abajo; cama y cómoda arriba
			h:box({ name = "Sofa", size = { 7, 2.2, 2.6 }, pos = { -6, 1.7, -3 }, color = o.sofa or { 170, 70, 60 }, mat = "Fabric" })
			h:box({ name = "Respaldo", size = { 7, 2, 0.8 }, pos = { -6, 2.6, -1.9 }, color = o.sofa or { 170, 70, 60 }, mat = "Fabric" })
			h:box({ name = "Mesa", size = { 4, 0.4, 3 }, pos = { -6, 2.6, 3 }, color = { 120, 80, 50 }, mat = "WoodPlanks" })
			h:box({ name = "Patas", size = { 3.4, 2, 2.4 }, pos = { -6, 1.6, 3 }, color = { 100, 66, 42 }, mat = "WoodPlanks", transparency = 0.6, folder = "Decoracion" })
			h:box({ name = "Cocina", size = { 8, 3.2, 2.4 }, pos = { 0, 2.2, D / 2 - T - 1.2 }, color = { 236, 236, 230 }, mat = "Marble" })
			h:box({ name = "Nevera", size = { 2.6, 6, 2.4 }, pos = { -5.4, 3.6, D / 2 - T - 1.2 }, color = { 230, 230, 226 }, mat = "Metal" })
			h:box({ name = "Cama", size = { 5, 1.6, 7 }, pos = { -7, FH + 1.4, 4 }, color = { 236, 230, 220 }, mat = "Fabric" })
			h:box({ name = "Manta", size = { 5.1, 0.3, 4.4 }, pos = { -7, FH + 2.3, 5 }, color = o.sofa or { 170, 70, 60 }, mat = "Fabric", folder = "Decoracion" })
			h:box({ name = "Comoda", size = { 5, 3.6, 2 }, pos = { 0, FH + 2.4, D / 2 - T - 1 }, color = { 140, 96, 60 }, mat = "WoodPlanks" })
		end
		local lamp = h:box({ name = "Lampara", size = { 2, 0.3, 2 }, pos = { -4, FH - 0.2, 0 }, color = { 255, 240, 214 }, mat = "Neon", folder = "Decoracion" })
		MB.light(lamp, "Point", { color = { 255, 230, 200 }, brightness = 0.8, range = 16 })
	end

	-- =================================================================
	--  Más vehículos, gente y feria
	-- =================================================================
	function P.bus(g, pos, rotY, color, text)
		local u = g:at(pos, rotY)
		local paint = color or { 246, 190, 30 }
		local body = u:box({ name = "Autobus", size = { 8, 7, 30 }, pos = { 0, 5, 1 }, color = paint })
		u:box({ name = "Capo", size = { 7.4, 3.4, 5 }, pos = { 0, 3.2, -16.4 }, color = paint })
		u:box({ name = "Techo", size = { 7.6, 0.6, 29.6 }, pos = { 0, 8.8, 1 }, color = { 240, 240, 236 }, folder = "Decoracion" })
		u:box({ name = "Franja", size = { 8.06, 0.5, 30 }, pos = { 0, 4.2, 1 }, color = { 30, 30, 30 }, folder = "Decoracion" })
		for i = 0, 6 do
			for _, side in ipairs({ -1, 1 }) do
				u:box({ name = "Ventana", size = { 0.2, 2.4, 3 }, pos = { side * 4.02, 6.6, -10 + i * 3.8 }, color = { 50, 60, 76 }, mat = "Glass", folder = "Decoracion" })
			end
		end
		u:box({ name = "Parabrisas", size = { 7, 3, 0.2 }, pos = { 0, 6.4, -14.05 }, color = { 50, 60, 76 }, mat = "Glass", folder = "Decoracion" })
		u:box({ name = "Paragolpes", size = { 8.2, 1, 0.6 }, pos = { 0, 1.8, -19.1 }, color = { 40, 40, 44 }, mat = "Metal" })
		for _, x in ipairs({ -2.6, 2.6 }) do
			u:box({ name = "Faro", size = { 1.2, 0.8, 0.15 }, pos = { x, 3.4, -18.95 }, color = { 255, 244, 214 }, mat = "Neon", folder = "Decoracion" })
		end
		for _, w in ipairs({ { -3.6, -13 }, { 3.6, -13 }, { -3.6, 10 }, { 3.6, 10 } }) do
			u:cylinder({ name = "Rueda", axis = "x", length = 1, diameter = 3, pos = { w[1], 1.5, w[2] }, color = { 28, 28, 30 }, mat = "Rubber" })
		end
		if text then
			for _, face in ipairs({ "Left", "Right" }) do
				MB.sign(body, text, { face = face, font = "GothamBlack", color = { 30, 30, 30 }, height = 0.22, width = 0.6 })
			end
		end
		return body
	end

	-- Maniquí de pie (clothes = color de la ropa)
	function P.mannequin(g, pos, rotY, clothes)
		local m = g:at(pos, rotY)
		local skin = { 236, 214, 190 }
		local c = clothes or { 60, 110, 180 }
		for _, x in ipairs({ -0.5, 0.5 }) do
			m:box({ name = "Pierna", size = { 0.8, 3, 0.8 }, pos = { x, 1.5, 0 }, color = (c[1] + c[2] + c[3] > 400) and { 60, 60, 70 } or c, folder = "Decoracion" })
			m:box({ name = "Brazo", size = { 0.6, 2.8, 0.6 }, pos = { x * 3.2, 4.4, 0 }, rot = { 0, 0, x * 16 }, color = skin, folder = "Decoracion" })
		end
		m:box({ name = "Torso", size = { 2.2, 2.8, 1.1 }, pos = { 0, 4.4, 0 }, color = c, mat = "Fabric" })
		m:cylinder({ name = "Cuello", length = 0.5, diameter = 0.5, pos = { 0, 6, 0 }, color = skin, folder = "Decoracion" })
		m:ball({ name = "Cabeza", diameter = 1.3, pos = { 0, 6.6, 0 }, color = skin, folder = "Decoracion" })
	end

	-- Noria (la rueda está en el plano XY local)
	function P.ferrisWheel(g, pos, rotY, radius, rimColor)
		local f = g:at(pos, rotY)
		local r = radius or 24
		local hub = r + 4
		local steel = { 236, 236, 240 }
		local neon = rimColor or { 255, 80, 160 }
		local cabins = { { 230, 60, 60 }, { 250, 200, 60 }, { 60, 140, 230 }, { 80, 190, 110 } }
		f:box({ name = "Base", size = { r * 1.3, 1.5, 9 }, pos = { 0, 0.75, 0 }, color = { 120, 120, 128 }, mat = "Concrete" })
		for _, z in ipairs({ -3, 3 }) do
			P.segment(f, { -r * 0.55, 1.5, z }, { 0, hub, z }, 1, steel, "Metal")
			P.segment(f, { r * 0.55, 1.5, z }, { 0, hub, z }, 1, steel, "Metal")
		end
		local hubPart = f:cylinder({ name = "Eje", axis = "z", length = 7, diameter = 2.4, pos = { 0, hub, 0 }, color = { 80, 80, 90 }, mat = "Metal" })
		MB.light(hubPart, "Point", { color = neon, brightness = 1.5, range = 30 })
		local n = 24
		for i = 0, n - 1 do
			local a1, a2 = i / n * math.pi * 2, (i + 1) / n * math.pi * 2
			for _, z in ipairs({ -2, 2 }) do
				P.segment(f, { math.cos(a1) * r, hub + math.sin(a1) * r, z }, { math.cos(a2) * r, hub + math.sin(a2) * r, z }, 0.6, neon, "Neon", "Decoracion")
			end
			if i % 2 == 0 then
				local cx, cy = math.cos(a1) * r, hub + math.sin(a1) * r
				P.segment(f, { 0, hub, 0 }, { cx, cy, 0 }, 0.4, steel, "Metal", "Decoracion")
				f:box({ name = "Cabina", size = { 2.6, 2.8, 3.4 }, pos = { cx, cy - 2.4, 0 }, color = cabins[(i / 2 % 4) + 1], folder = "Decoracion" })
				f:box({ name = "Techo", size = { 3, 0.4, 3.8 }, pos = { cx, cy - 0.8, 0 }, color = steel, folder = "Decoracion" })
			end
		end
	end

	-- =================================================================
	--  Oeste y zona militar
	-- =================================================================
	function P.hayBale(g, pos, rotY)
		local h = g:at(pos, rotY)
		h:box({ name = "Paja", size = { 4, 2.6, 2.6 }, pos = { 0, 1.3, 0 }, color = { 222, 190, 104 }, mat = "Grass" })
		for _, x in ipairs({ -1, 1 }) do
			h:box({ name = "Cuerda", size = { 0.2, 2.7, 2.7 }, pos = { x, 1.3, 0 }, color = { 150, 110, 60 }, folder = "Decoracion" })
		end
	end

	-- Carreta con lona (larga a lo largo de Z local)
	function P.wagon(g, pos, rotY, canvas)
		local w = g:at(pos, rotY)
		local wood = { 130, 88, 56 }
		w:box({ name = "Caja", size = { 5.6, 2.4, 11 }, pos = { 0, 2.6, 0 }, color = wood, mat = "WoodPlanks" })
		w:cylinder({ name = "Lona", axis = "z", length = 10, diameter = 5.4, pos = { 0, 4.2, 0 }, color = canvas or { 240, 232, 214 }, mat = "Fabric" })
		for _, z in ipairs({ -3.5, 0, 3.5 }) do
			w:cylinder({ name = "Aro", axis = "z", length = 0.3, diameter = 5.6, pos = { 0, 4.2, z }, color = { 110, 80, 52 }, folder = "Decoracion" })
		end
		for _, x in ipairs({ -3, 3 }) do
			for _, z in ipairs({ -3.6, 3.6 }) do
				w:cylinder({ name = "Rueda", axis = "x", length = 0.5, diameter = 4.2, pos = { x, 2.1, z }, color = { 90, 62, 40 }, mat = "Wood" })
				w:cylinder({ name = "Buje", axis = "x", length = 0.6, diameter = 1, pos = { x, 2.1, z }, color = { 60, 50, 44 }, mat = "Metal", folder = "Decoracion" })
			end
		end
		w:box({ name = "Lanza", size = { 0.5, 0.5, 6 }, pos = { 0, 1.6, -8.4 }, rot = { -8, 0, 0 }, color = wood, mat = "Wood", folder = "Decoracion" })
	end

	-- Muro de sacos terreros (largo a lo largo de X local)
	function P.sandbags(g, pos, rotY, length, rows)
		local s = g:at(pos, rotY)
		local n = math.max(1, math.floor(length / 2.4))
		for r = 0, (rows or 3) - 1 do
			local offset = (r % 2 == 0) and 0 or 1.2
			for i = 0, n - 1 - (r % 2) do
				local x = -length / 2 + 1.2 + i * 2.4 + offset
				s:box({ name = "Saco", size = { 2.3, 1, 1.5 }, pos = { x, 0.5 + r, 0 }, color = (i + r) % 3 == 0 and { 160, 140, 100 } or { 176, 156, 114 }, mat = "Fabric" })
			end
		end
	end

	-- Torre de vigilancia con escalera trepable y plataforma con barandilla
	function P.watchTower(g, pos, rotY, height)
		local t = g:at(pos, rotY)
		local h = height or 16
		local wood = { 120, 92, 64 }
		for _, x in ipairs({ -3, 3 }) do
			for _, z in ipairs({ -3, 3 }) do
				t:box({ name = "Pata", size = { 1, h, 1 }, pos = { x, h / 2, z }, color = wood, mat = "Wood" })
			end
		end
		t:box({ name = "Plataforma", size = { 8, 0.8, 8 }, pos = { 0, h + 0.4, 0 }, color = wood, mat = "WoodPlanks" })
		for _, side in ipairs({ -1, 1 }) do
			t:box({ name = "Peto", size = { 0.5, 3.4, 8 }, pos = { side * 3.75, h + 2.5, 0 }, color = wood, mat = "WoodPlanks" })
			-- Lado de la escalera con hueco para entrar
			t:box({ name = "Peto", size = { 2.6, 3.4, 0.5 }, pos = { side * 2.7, h + 2.5, 3.75 }, color = wood, mat = "WoodPlanks" })
		end
		t:box({ name = "Peto", size = { 8, 3.4, 0.5 }, pos = { 0, h + 2.5, -3.75 }, color = wood, mat = "WoodPlanks" })
		t:box({ name = "Techo", size = { 9, 0.6, 9 }, pos = { 0, h + 7.5, 0 }, color = { 90, 70, 50 }, mat = "WoodPlanks", folder = "Decoracion" })
		for _, x in ipairs({ -3.6, 3.6 }) do
			for _, z in ipairs({ -3.6, 3.6 }) do
				t:box({ name = "Poste", size = { 0.4, 3.6, 0.4 }, pos = { x, h + 5.6, z }, color = wood, mat = "Wood", folder = "Decoracion" })
			end
		end
		local ladderH = math.floor((h + 2) / 2) * 2
		t:truss({ name = "Escalera", size = { 2, ladderH, 2 }, pos = { 0, ladderH / 2, 5.2 }, color = { 100, 80, 60 } })
	end
	-- =================================================================
	--  Mundo abandonado (estilo apocalipsis)
	-- =================================================================
	-- Musgo y enredaderas sobre una fachada de ancho w y alto H (cara mirando a -Z local, en z)
	function P.overgrowth(g, w, H, z)
		local green = { { 70, 98, 54 }, { 84, 112, 60 }, { 62, 88, 50 } }
		for i, m in ipairs({ { -0.35, 0.12, 0.3, 0.2 }, { 0.3, 0.05, 0.25, 0.14 }, { 0.05, 0.6, 0.18, 0.22 } }) do
			g:box({ name = "Musgo", size = { w * m[3], H * m[4], 0.15 }, pos = { w * m[1], H * m[2] + H * m[4] / 2, z }, color = green[i], mat = "LeafyGrass", folder = "Decoracion", shadow = false })
		end
		for i = 0, 3 do
			local x = -w / 2 + (i + 0.5) * w / 4 + ((i % 2 == 0) and 0.8 or -0.6)
			local len = H * (0.25 + (i % 3) * 0.15)
			g:box({ name = "Enredadera", size = { 0.7, len, 0.2 }, pos = { x, H - len / 2, z - 0.05 }, color = green[(i % 3) + 1], mat = "LeafyGrass", folder = "Decoracion", shadow = false })
		end
	end

	-- Montón de escombros
	function P.debris(g, pos, scale)
		local d = g:at(pos, 0)
		local s = scale or 1
		local pieces = { { 0, 0, 0, 4, 1.4, 3, 12 }, { 1.8, 0.6, 1, 2.4, 1, 2, -20 }, { -1.6, 0.4, -0.8, 2.6, 1.2, 1.6, 35 }, { 0.6, 1.2, -1.2, 1.6, 0.8, 1.4, 60 }, { -0.4, 0.2, 1.8, 3, 0.6, 1, -45 } }
		for i, p in ipairs(pieces) do
			d:box({ name = "Escombro", size = { p[4] * s, p[5] * s, p[6] * s }, pos = { p[1] * s, p[2] * s + p[5] * s / 2, p[3] * s }, rot = { (i % 2) * 8, p[7], (i % 3) * 6 }, color = (i % 2 == 0) and { 150, 146, 138 } or { 130, 92, 74 }, mat = (i % 2 == 0) and "Concrete" or "Brick" })
		end
	end

	-- Muro de chapas oxidadas a lo largo de una línea (para comunidades amuralladas)
	function P.metalWall(g, a, b, height, colors)
		local dx, dz = b[1] - a[1], b[3] - a[3]
		local len = math.sqrt(dx * dx + dz * dz)
		local yaw = math.deg(math.atan2(-dz, dx))
		local w = g:at({ (a[1] + b[1]) / 2, a[2] or 0, (a[3] + b[3]) / 2 }, yaw)
		local palette = colors or { { 120, 84, 62 }, { 96, 100, 96 }, { 140, 104, 70 }, { 84, 92, 100 } }
		local n = math.max(1, math.floor(len / 8))
		for i = 0, n - 1 do
			local x = -len / 2 + (i + 0.5) * len / n
			local hh = height - (i % 3) * 0.6
			w:box({ name = "Chapa", size = { len / n + 0.2, hh, 0.4 }, pos = { x, hh / 2, (i % 2) * 0.3 }, color = palette[(i % #palette) + 1], mat = "CorrodedMetal" })
		end
		for i = 0, n do
			local x = -len / 2 + i * len / n
			w:box({ name = "Poste", size = { 0.6, height + 0.6, 0.6 }, pos = { x, (height + 0.6) / 2, -0.4 }, color = { 70, 60, 52 }, mat = "Wood", folder = "Decoracion" })
		end
	end

	-- Empalizada de tablones con puntas
	function P.plankWall(g, a, b, height, color)
		local dx, dz = b[1] - a[1], b[3] - a[3]
		local len = math.sqrt(dx * dx + dz * dz)
		local yaw = math.deg(math.atan2(-dz, dx))
		local w = g:at({ (a[1] + b[1]) / 2, a[2] or 0, (a[3] + b[3]) / 2 }, yaw)
		local wood = color or { 120, 92, 64 }
		local n = math.max(1, math.floor(len / 6))
		for i = 0, n - 1 do
			local x = -len / 2 + (i + 0.5) * len / n
			local hh = height + (i % 2) * 0.8
			w:box({ name = "Tablones", size = { len / n + 0.1, hh, 0.8 }, pos = { x, hh / 2, 0 }, color = (i % 3 == 0) and darker(wood, 20) or wood, mat = "WoodPlanks" })
			w:wedge({ name = "Punta", size = { len / n, 1.6, 0.4 }, pos = { x, hh + 0.8, -0.2 }, color = darker(wood, 10), mat = "WoodPlanks", folder = "Decoracion" })
			w:wedge({ name = "Punta", size = { len / n, 1.6, 0.4 }, pos = { x, hh + 0.8, 0.2 }, rot = { 0, 180, 0 }, color = darker(wood, 10), mat = "WoodPlanks", folder = "Decoracion" })
		end
	end

	-- Tienda de campaña (a lo largo de X local)
	function P.tent(g, pos, rotY, color, w, d, h)
		local t = g:at(pos, rotY)
		w, d, h = w or 10, d or 7, h or 5
		local c = color or { 92, 110, 70 }
		t:wedge({ name = "Tienda", size = { w, h, d / 2 }, pos = { 0, h / 2, -d / 4 }, color = c, mat = "Fabric" })
		t:wedge({ name = "Tienda", size = { w, h, d / 2 }, pos = { 0, h / 2, d / 4 }, rot = { 0, 180, 0 }, color = darker(c, 12), mat = "Fabric" })
	end

	-- Hoguera: anillo de piedras irregulares, ceniza, leña en tipi, brasas y fuego real (llamas, humo y chispas)
	function P.campfire(g, pos, withLight)
		local f = g:at(pos, 0)
		for i = 0, 8 do
			local a = i * 40 + (i * 17) % 13
			local r = math.rad(a)
			local v = (i % 3) * 8
			f:blob({ name = "Piedra", size = { 1.5 + (i % 3) * 0.3, 0.9 + (i % 2) * 0.3, 1.1 + ((i + 1) % 3) * 0.25 }, pos = { math.cos(r) * 2.1, 0.3, math.sin(r) * 2.1 }, rot = { (i * 23) % 20 - 10, -a, (i * 31) % 16 - 8 }, color = { 100 + v, 98 + v, 94 + v }, mat = "Slate", folder = "Decoracion" })
		end
		f:cylinder({ name = "Ceniza", length = 0.2, diameter = 3.4, pos = { 0, 0.05, 0 }, color = { 52, 50, 48 }, mat = "Ground", folder = "Decoracion" })
		for i = 0, 4 do
			local r = math.rad(i * 72 + 10)
			local lena = P.rod(f, { math.cos(r) * 1.5, 0.1, math.sin(r) * 1.5 }, { math.cos(r) * 0.15, 2.2, math.sin(r) * 0.15 }, 0.36, { 74, 54, 38 }, "Wood", "Decoracion")
			lena.Name = "Lena"
		end
		local fire = f:box({ name = "Fuego", size = { 1.6, 0.3, 1.6 }, pos = { 0, 0.3, 0 }, color = { 255, 110, 30 }, mat = "Neon", folder = "Decoracion", shadow = false })
		MB.fire(fire, { size = 5, light = withLight ~= false, range = 22 })
		return fire
	end

	-- Bidón oxidado con fuego dentro (para calentarse en los campamentos)
	function P.fireBarrel(g, pos)
		local f = g:at(pos, 0)
		f:cylinder({ name = "Bidon", length = 3.6, diameter = 2.6, pos = { 0, 1.8, 0 }, color = { 112, 72, 48 }, mat = "CorrodedMetal" })
		for _, y in ipairs({ 0.9, 2.7 }) do
			f:cylinder({ name = "Aro", length = 0.2, diameter = 2.7, pos = { 0, y, 0 }, color = { 86, 58, 42 }, mat = "CorrodedMetal", folder = "Decoracion" })
		end
		local fire = f:box({ name = "Fuego", size = { 2, 0.3, 2 }, pos = { 0, 3.45, 0 }, color = { 255, 110, 30 }, mat = "Neon", folder = "Decoracion", shadow = false })
		MB.fire(fire, { size = 4, range = 20, brightness = 1.8 })
		return fire
	end

	-- Helicóptero militar estrellado
	function P.helicopterWreck(g, pos, rotY)
		local hcp = g:at(pos, rotY)
		local olive = { 74, 82, 60 }
		hcp:box({ name = "Fuselaje", size = { 7, 6, 16 }, pos = { 0, 3.2, 0 }, rot = { 0, 0, 14 }, color = olive, mat = "Metal" })
		hcp:wedge({ name = "Morro", size = { 6.6, 4, 4 }, pos = { 0.6, 2.6, -9.6 }, rot = { 0, 180, 14 }, color = { 40, 48, 44 }, mat = "Glass" })
		hcp:box({ name = "Cola", size = { 2, 2, 16 }, pos = { 1.2, 4, 15 }, rot = { 6, 0, 14 }, color = olive, mat = "Metal" })
		hcp:box({ name = "Aleta", size = { 0.5, 5, 3 }, pos = { 1.6, 6, 22.4 }, color = olive, mat = "Metal", folder = "Decoracion" })
		for i, r in ipairs({ 20, 110 }) do
			hcp:box({ name = "Pala", size = { 26 - i * 6, 0.3, 1.2 }, pos = { -0.8, 6.8 - i * 0.6, 0 }, rot = { 0, r, 12 + i * 6 }, color = { 40, 40, 40 }, mat = "Metal", folder = "Decoracion" })
		end
		P.debris(hcp, { 6, 0, -4 }, 0.8)
		-- El motor todavía arde y echa una columna de humo negro
		local fuego = hcp:box({ name = "Fuego", size = { 3, 0.5, 3 }, pos = { 0, 6.4, -2 }, color = { 60, 40, 30 }, transparency = 1, folder = "Decoracion", shadow = false })
		MB.fire(fuego, { size = 7, range = 26, smokeColor = { 30, 28, 28 }, smokeOpacity = 0.35, smokeSize = 9, rise = 9 })
	end

	-- Vía de tren entre dos puntos: balasto, dos raíles y traviesas opcionales
	function P.rails(g, a, b, sleepers)
		local dx, dz = b[1] - a[1], b[3] - a[3]
		local len = math.sqrt(dx * dx + dz * dz)
		local yaw = math.deg(math.atan2(-dz, dx))
		local r = g:at({ (a[1] + b[1]) / 2, a[2] or 0, (a[3] + b[3]) / 2 }, yaw)
		r:box({ name = "Balasto", size = { len, 0.6, 10 }, pos = { 0, 0.3, 0 }, color = { 110, 104, 96 }, mat = "Pebble" })
		for _, z in ipairs({ -2.4, 2.4 }) do
			r:box({ name = "Rail", size = { len, 0.5, 0.5 }, pos = { 0, 0.95, z }, color = { 120, 96, 80 }, mat = "CorrodedMetal" })
		end
		if sleepers then
			for x = -len / 2 + 2, len / 2 - 2, 4 do
				r:box({ name = "Traviesa", size = { 1.2, 0.3, 7.6 }, pos = { x, 0.7, 0 }, color = { 90, 70, 52 }, mat = "Wood", folder = "Decoracion" })
			end
		end
	end

	-- Vagón de tren sobre la vía (largo a lo largo de X local). kind: "vagon", "cisterna", "plataforma", "locomotora"
	function P.trainCar(g, pos, rotY, kind, color)
		local t = g:at(pos, rotY)
		local c = color or { 130, 70, 50 }
		t:box({ name = "Bastidor", size = { 30, 1, 8 }, pos = { 0, 2.6, 0 }, color = { 40, 40, 42 }, mat = "Metal" })
		for _, x in ipairs({ -11, -8, 8, 11 }) do
			for _, z in ipairs({ -2.4, 2.4 }) do
				t:cylinder({ name = "Rueda", axis = "z", length = 0.6, diameter = 2.4, pos = { x, 1.6, z }, color = { 50, 46, 44 }, mat = "Metal", folder = "Decoracion" })
			end
		end
		if kind == "cisterna" then
			t:cylinder({ name = "Cisterna", axis = "x", length = 28, diameter = 8, pos = { 0, 7.1, 0 }, color = c, mat = "Metal" })
		elseif kind == "plataforma" then
			P.crate(t, { -6, 3.1, 0 }, 5, 10)
			P.crate(t, { 2, 3.1, 0.5 }, 4.5, -5)
			t:box({ name = "Tubos", size = { 10, 2.4, 6 }, pos = { 9, 4.3, 0 }, color = { 140, 136, 130 }, mat = "Metal" })
		elseif kind == "locomotora" then
			t:box({ name = "Motor", size = { 20, 8, 7 }, pos = { 4, 7.1, 0 }, color = c, mat = "Metal" })
			t:box({ name = "Cabina", size = { 8, 11, 8 }, pos = { -10, 8.6, 0 }, color = c, mat = "Metal" })
			t:box({ name = "Ventanas", size = { 8.1, 2.4, 8.1 }, pos = { -10, 11, 0 }, color = { 30, 34, 36 }, mat = "Glass", folder = "Decoracion" })
			t:box({ name = "Franja", size = { 30.2, 1, 8.2 }, pos = { 0, 4.6, 0 }, color = { 230, 190, 50 }, folder = "Decoracion" })
		else
			t:box({ name = "Vagon", size = { 30, 10, 8 }, pos = { 0, 8.1, 0 }, color = c, mat = "CorrodedMetal" })
			t:box({ name = "Puerta", size = { 6, 8, 0.3 }, pos = { 0, 7.6, -4.1 }, color = darker(c, 30), mat = "Metal", folder = "Decoracion" })
			t:box({ name = "Puerta", size = { 6, 8, 0.3 }, pos = { 0, 7.6, 4.1 }, color = darker(c, 30), mat = "Metal", folder = "Decoracion" })
		end
	end

	-- Torre de radio de celosía con balizas
	function P.radioTower(g, pos, height)
		local t = g:at(pos, 0)
		local h = height or 100
		local steel = { 170, 60, 50 }
		local white = { 230, 230, 226 }
		for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
			P.segment(t, { c[1] * 7, 0, c[2] * 7 }, { c[1] * 1.5, h, c[2] * 1.5 }, 0.8, steel, "Metal")
		end
		for k = 1, 8 do
			local y = k * h / 9
			local half = 7 - 5.5 * y / h
			for i, c in ipairs({ { -1, -1, 1, -1 }, { 1, -1, 1, 1 }, { 1, 1, -1, 1 }, { -1, 1, -1, -1 } }) do
				P.segment(t, { c[1] * half, y, c[2] * half }, { c[3] * half, y, c[4] * half }, 0.4, (k % 2 == 0) and white or steel, "Metal", "Decoracion")
			end
		end
		local beacon = t:ball({ name = "Baliza", diameter = 2, pos = { 0, h + 1.5, 0 }, color = { 255, 60, 50 }, mat = "Neon", folder = "Decoracion" })
		MB.light(beacon, "Point", { color = { 255, 60, 50 }, brightness = 2, range = 30 })
		t:box({ name = "Base", size = { 18, 1, 18 }, pos = { 0, 0.5, 0 }, color = { 150, 148, 142 }, mat = "Concrete" })
	end

	function P.solarPanel(g, pos, rotY)
		local s = g:at(pos, rotY)
		s:box({ name = "Soporte", size = { 0.4, 3, 0.4 }, pos = { 0, 1.5, 0 }, color = { 120, 120, 126 }, mat = "Metal" })
		s:box({ name = "Panel", size = { 6, 0.3, 4 }, pos = { 0, 3.2, 0 }, rot = { 25, 0, 0 }, color = { 40, 60, 110 }, mat = "Glass", reflectance = 0.2 })
	end

	-- Bancal de huerto con plantas
	function P.gardenBed(g, pos, rotY, w, d)
		local b = g:at(pos, rotY)
		w, d = w or 10, d or 4
		b:box({ name = "Bancal", size = { w, 1, d }, pos = { 0, 0.5, 0 }, color = { 110, 80, 56 }, mat = "WoodPlanks" })
		b:box({ name = "Tierra", size = { w - 0.6, 0.2, d - 0.6 }, pos = { 0, 1.05, 0 }, color = { 70, 52, 40 }, mat = "Ground", folder = "Decoracion" })
		for i = 0, math.floor(w / 1.6) - 1 do
			b:ball({ name = "Planta", diameter = 1.2, pos = { -w / 2 + 1 + i * 1.6, 1.6, (i % 2 == 0) and -0.7 or 0.7 }, color = (i % 3 == 0) and { 200, 60, 50 } or { 80, 140, 60 }, mat = "LeafyGrass", folder = "Decoracion" })
		end
	end

	function P.silo(g, pos, radius, height, color)
		local s = g:at(pos, 0)
		local c = color or { 176, 178, 180 }
		s:cylinder({ name = "Silo", length = height, diameter = radius * 2, pos = { 0, height / 2, 0 }, color = c, mat = "CorrodedMetal" })
		s:ball({ name = "Cupula", diameter = radius * 2, pos = { 0, height, 0 }, color = darker(c, 20), mat = "Metal" })
		for y = 6, height - 4, 8 do
			s:cylinder({ name = "Aro", length = 0.4, diameter = radius * 2 + 0.3, pos = { 0, y, 0 }, color = darker(c, 40), mat = "Metal", folder = "Decoracion" })
		end
	end

	-- Molino de viento de granja
	function P.windmill(g, pos, rotY)
		local m = g:at(pos, rotY)
		local steel = { 130, 126, 120 }
		for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
			P.segment(m, { c[1] * 3, 0, c[2] * 3 }, { c[1] * 0.6, 30, c[2] * 0.6 }, 0.4, steel, "Metal")
		end
		m:cylinder({ name = "Buje", axis = "z", length = 1.4, diameter = 1.6, pos = { 0, 31, -1 }, color = steel, mat = "Metal" })
		for i = 0, 11 do
			local a = math.rad(i * 30)
			m:box({ name = "Aspa", size = { 0.8, 5, 0.15 }, pos = { math.cos(a) * 3.2, 31 + math.sin(a) * 3.2, -1.8 }, rot = { 0, 0, i * 30 - 90 }, color = { 190, 186, 176 }, mat = "Metal", folder = "Decoracion" })
		end
		m:box({ name = "Cola", size = { 0.3, 3, 5 }, pos = { 0, 31, 3 }, color = steel, mat = "Metal", folder = "Decoracion" })
	end

	-- Campo de cultivo con surcos (rectángulo x0..x1, z0..z1 a la altura y)
	function P.cropField(g, x0, x1, z0, z1, y, color)
		g:box({ name = "Campo", size = { x1 - x0, 0.3, z1 - z0 }, pos = { (x0 + x1) / 2, y + 0.15, (z0 + z1) / 2 }, color = { 104, 84, 60 }, mat = "Ground", folder = "Decoracion" })
		for z = z0 + 3, z1 - 3, 6 do
			g:box({ name = "Surco", size = { x1 - x0 - 4, 1.6, 1.6 }, pos = { (x0 + x1) / 2, y + 1, z }, color = color or { 150, 140, 70 }, mat = "LeafyGrass", folder = "Decoracion", shadow = false })
		end
	end

	-- Avioneta estrellada
	function P.planeWreck(g, pos, rotY)
		local p = g:at(pos, rotY)
		local white = { 220, 220, 214 }
		p:cylinder({ name = "Fuselaje", axis = "z", length = 22, diameter = 5, pos = { 0, 2.6, 0 }, rot = { -4, 0, 0 }, color = white, mat = "Metal" })
		p:box({ name = "Ala", size = { 30, 0.6, 5 }, pos = { 0, 3.4, -2 }, rot = { 0, 0, 6 }, color = white, mat = "Metal" })
		p:box({ name = "Cola", size = { 0.5, 5, 4 }, pos = { 0, 5.6, 10 }, color = { 180, 50, 40 }, mat = "Metal", folder = "Decoracion" })
		p:box({ name = "Estabilizador", size = { 10, 0.4, 3 }, pos = { 0, 3.6, 10 }, color = white, mat = "Metal", folder = "Decoracion" })
		p:box({ name = "Cabina", size = { 4, 1.6, 4 }, pos = { 0, 4.6, -6 }, color = { 40, 50, 56 }, mat = "Glass", folder = "Decoracion" })
		P.debris(p, { 8, 0, 6 }, 0.6)
	end

	function P.tractor(g, pos, rotY, color)
		local t = g:at(pos, rotY)
		local c = color or { 60, 120, 60 }
		t:box({ name = "Chasis", size = { 4, 3, 9 }, pos = { 0, 3, 0 }, color = c, mat = "Metal" })
		t:box({ name = "Cabina", size = { 4.4, 4.4, 4 }, pos = { 0, 6.6, 2 }, color = { 40, 46, 44 }, mat = "Glass", transparency = 0.3 })
		t:box({ name = "Techo", size = { 4.8, 0.4, 4.6 }, pos = { 0, 9, 2 }, color = c, mat = "Metal", folder = "Decoracion" })
		for _, x in ipairs({ -2.6, 2.6 }) do
			t:cylinder({ name = "Rueda", axis = "x", length = 1.6, diameter = 6, pos = { x, 3, 2.6 }, color = { 30, 30, 32 }, mat = "Rubber" })
			t:cylinder({ name = "Rueda", axis = "x", length = 1, diameter = 3.2, pos = { x, 1.6, -3 }, color = { 30, 30, 32 }, mat = "Rubber" })
		end
		t:cylinder({ name = "Escape", length = 3, diameter = 0.4, pos = { 1.2, 6.4, -3 }, color = { 40, 40, 40 }, mat = "Metal", folder = "Decoracion" })
	end

	-- Barca de pesca varada
	function P.boat(g, pos, rotY, color)
		local b = g:at(pos, rotY)
		local c = color or { 220, 220, 210 }
		b:box({ name = "Casco", size = { 8, 3, 18 }, pos = { 0, 1.5, 0 }, color = c, mat = "WoodPlanks" })
		b:wedge({ name = "Proa", size = { 8, 3, 5 }, pos = { 0, 1.5, -11.5 }, rot = { 0, 180, 0 }, color = c, mat = "WoodPlanks" })
		b:box({ name = "Cabina", size = { 5, 4, 5 }, pos = { 0, 5, 3 }, color = { 200, 80, 60 }, mat = "WoodPlanks" })
		b:box({ name = "Franja", size = { 8.1, 0.6, 18.1 }, pos = { 0, 2.6, 0 }, color = { 50, 90, 140 }, folder = "Decoracion" })
	end

	-- Cinta transportadora de cantera entre dos puntos (a la altura del punto b)
	function P.conveyor(g, a, b)
		P.segment(g, a, b, 2.4, { 60, 60, 62 }, "Rubber")
		local n = 4
		for i = 1, n - 1 do
			local t = i / n
			local x, y, z = a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t
			g:box({ name = "Pata", size = { 1, y - 1, 1 }, pos = { x, (y - 1) / 2, z }, color = { 200, 160, 50 }, mat = "Metal" })
		end
	end

	--[[
		Tienda de caza y pesca: cabaña de troncos con mostrador, armero, cañas, trofeos, cámara de cebos
		y un pesadero fuera donde se vende lo cazado. Lleva dos ProximityPrompt con la etiqueta "TiendaCaza"
		(los usa CazaServidor): "Comprar" en el mostrador y "Vender" en el pesadero.
		El frente mira a -Z (local); la cabaña ocupa 22 x 16 studs hacia +Z.
	]]
	function P.tiendaCaza(g, pos, rotY, nombre)
		local t = g:at(pos, rotY)
		local CollectionService = game:GetService("CollectionService")
		local tronco, oscuro, tejado = { 122, 86, 58 }, { 84, 60, 42 }, { 66, 56, 50 }
		t:box({ name = "Suelo", size = { 22, 1, 16 }, pos = { 0, 0.5, 8 }, color = oscuro, mat = "WoodPlanks" })
		-- Paredes de troncos (troncos horizontales apilados)
		for i = 0, 6 do
			local y = 1.6 + i * 1.5
			t:cylinder({ name = "Tronco", axis = "x", length = 22.6, diameter = 1.5, pos = { 0, y, 15.5 }, color = (i % 2 == 0) and tronco or darker(tronco, 10), mat = "Wood" })
			for _, x in ipairs({ -10.6, 10.6 }) do
				t:cylinder({ name = "Tronco", axis = "z", length = 16.6, diameter = 1.5, pos = { x, y, 8 }, color = (i % 2 == 0) and darker(tronco, 8) or tronco, mat = "Wood" })
			end
			if i >= 5 or i <= 1 then
				-- Frente: ventana de mostrador entre medias
				t:cylinder({ name = "Tronco", axis = "x", length = 22.6, diameter = 1.5, pos = { 0, y, 0.5 }, color = (i % 2 == 0) and tronco or darker(tronco, 10), mat = "Wood" })
			else
				for _, x in ipairs({ -8.2, 8.2 }) do
					t:cylinder({ name = "Tronco", axis = "x", length = 6.2, diameter = 1.5, pos = { x, y, 0.5 }, color = tronco, mat = "Wood" })
				end
			end
		end
		-- Tejado a dos aguas con alero
		t:wedge({ name = "Tejado", size = { 24.5, 4.5, 9.5 }, pos = { 0, 13.3, 3.25 }, color = tejado, mat = "WoodPlanks" })
		t:wedge({ name = "Tejado", size = { 24.5, 4.5, 9.5 }, pos = { 0, 13.3, 12.75 }, rot = { 0, 180, 0 }, color = tejado, mat = "WoodPlanks" })
		for _, x in ipairs({ -11.3, 11.3 }) do
			t:wedge({ name = "Hastial", size = { 0.6, 4.5, 8 }, pos = { x, 13.3, 4 }, color = tronco, mat = "WoodPlanks" })
			t:wedge({ name = "Hastial", size = { 0.6, 4.5, 8 }, pos = { x, 13.3, 12 }, rot = { 0, 180, 0 }, color = tronco, mat = "WoodPlanks" })
		end
		-- Porche delante del mostrador
		t:box({ name = "Porche", size = { 14, 0.4, 5.5 }, pos = { 0, 10.4, -2.4 }, rot = { -12, 0, 0 }, color = tejado, mat = "WoodPlanks" })
		for _, x in ipairs({ -6.6, 6.6 }) do
			t:cylinder({ name = "Poste", length = 9.6, diameter = 0.7, pos = { x, 5, -4.6 }, color = oscuro, mat = "Wood" })
		end
		-- Mostrador
		t:box({ name = "Mostrador", size = { 10, 3.6, 1.6 }, pos = { 0, 2.8, 0.8 }, color = oscuro, mat = "WoodPlanks" })
		local encimera = t:box({ name = "Encimera", size = { 10.6, 0.3, 2.4 }, pos = { 0, 4.75, 0.6 }, color = { 150, 112, 76 }, mat = "Wood" })
		local comprar = Instance.new("ProximityPrompt")
		comprar.Name = "Comprar"
		comprar.ActionText = "Comprar"
		comprar.ObjectText = nombre or "Tienda de caza y pesca"
		comprar.MaxActivationDistance = 10
		comprar.RequiresLineOfSight = false
		comprar:SetAttribute("Accion", "Comprar")
		comprar:SetAttribute("Tienda", nombre or "Tienda de caza y pesca")
		comprar.Parent = encimera
		CollectionService:AddTag(comprar, "TiendaCaza")
		-- Caja registradora, balanza y cajas de munición sobre el mostrador
		t:box({ name = "Caja", size = { 1.4, 1, 1.2 }, pos = { 3.4, 5.4, 0.7 }, color = { 60, 60, 64 }, mat = "Metal", folder = "Decoracion" })
		for i, c in ipairs({ { 170, 60, 40 }, { 60, 90, 140 }, { 180, 150, 50 }, { 70, 110, 60 } }) do
			t:box({ name = "CajaMunicion", size = { 0.9, 0.6, 0.6 }, pos = { -4 + i * 1.05, 5.2, 0.4 }, color = c, mat = "SmoothPlastic", folder = "Decoracion" })
		end
		local cartelBase = t:box({ name = "Cartel", size = { 12, 2.2, 0.3 }, pos = { 0, 12.3, -0.5 }, color = { 60, 44, 32 }, mat = "WoodPlanks" })
		MB.sign(cartelBase, "CAZA Y PESCA", { color = { 236, 214, 160 }, font = "SpecialElite", pps = 30 })
		-- Trofeo: cornamenta sobre el cartel
		t:box({ name = "Placa", size = { 1.4, 1.4, 0.3 }, pos = { 0, 14.2, -0.4 }, color = { 92, 66, 46 }, mat = "Wood", folder = "Decoracion" })
		for _, k in ipairs({ 1, -1 }) do
			P.rod(t, { 0.3 * k, 14.5, -0.6 }, { 1.4 * k, 15.6, -0.7 }, 0.18, { 214, 198, 166 }, "Wood", "Decoracion")
			P.rod(t, { 1.4 * k, 15.6, -0.7 }, { 1.9 * k, 16.5, -0.6 }, 0.14, { 214, 198, 166 }, "Wood", "Decoracion")
			P.rod(t, { 1.0 * k, 15.2, -0.7 }, { 1.0 * k, 16.2, -0.9 }, 0.12, { 214, 198, 166 }, "Wood", "Decoracion")
		end
		-- Dentro: armero con rifles, cañas apoyadas, estanterías y un pez disecado
		t:box({ name = "Armero", size = { 8, 6, 0.6 }, pos = { -4, 5, 14.6 }, color = { 92, 66, 46 }, mat = "WoodPlanks", folder = "Decoracion" })
		for i = 0, 3 do
			local x = -6.8 + i * 1.8
			t:box({ name = "Rifle", size = { 0.25, 4.6, 0.35 }, pos = { x, 5, 14.1 }, color = { 40, 40, 42 }, mat = "Metal", folder = "Decoracion" })
			t:box({ name = "Culata", size = { 0.3, 1.6, 0.55 }, pos = { x, 3.1, 14.05 }, color = { 104, 66, 40 }, mat = "Wood", folder = "Decoracion" })
		end
		for i = 0, 4 do
			P.rod(t, { 2 + i * 0.9, 1.1, 14.4 }, { 2.6 + i * 0.9, 10, 14.9 }, 0.12, ({ { 196, 170, 100 }, { 40, 40, 44 }, { 60, 110, 160 } })[i % 3 + 1], "SmoothPlastic", "Decoracion")
		end
		for _, y in ipairs({ 3, 5.5 }) do
			t:box({ name = "Estante", size = { 0.8, 0.2, 10 }, pos = { 9.4, y, 8 }, color = { 150, 112, 76 }, mat = "Wood", folder = "Decoracion" })
			for k = 0, 5 do
				t:box({ name = "Producto", size = { 0.6, 0.8, 0.9 }, pos = { 9.4, y + 0.5, 3.6 + k * 1.7 }, color = ({ { 160, 60, 40 }, { 60, 80, 120 }, { 200, 180, 90 } })[k % 3 + 1], folder = "Decoracion" })
			end
		end
		t:box({ name = "Tabla", size = { 0.3, 1.6, 4 }, pos = { -9.7, 7.5, 8 }, color = { 92, 66, 46 }, mat = "Wood", folder = "Decoracion" })
		t:blob({ name = "PezDisecado", size = { 0.5, 1.1, 3.2 }, pos = { -9.4, 7.5, 8 }, color = { 150, 140, 110 }, mat = "SmoothPlastic", folder = "Decoracion" })
		local lampara = t:ball({ name = "Lampara", diameter = 0.8, pos = { 0, 9.6, 3 }, color = { 255, 220, 160 }, mat = "Neon", folder = "Decoracion" })
		MB.light(lampara, "Point", { color = { 255, 214, 160 }, brightness = 1.4, range = 20, shadows = true })
		-- Cámara de cebos y barriles
		t:box({ name = "Nevera", size = { 2.4, 3.4, 2 }, pos = { 8.2, 2.7, 3.2 }, color = { 220, 224, 226 }, mat = "Metal" })
		P.drum(t, { -13, 0, -2 }, { 90, 70, 50 })
		P.drum(t, { -14.6, 0, 0.6 }, { 70, 90, 60 })
		P.bench(t, { -6, 0, -6 }, 0, { 120, 90, 60 })
		-- Pesadero: dos postes, un travesaño con ganchos y una báscula: aquí se vende lo cazado
		for _, z in ipairs({ -3, 5 }) do
			t:cylinder({ name = "Poste", length = 9, diameter = 0.8, pos = { 14.5, 4.5, z }, color = oscuro, mat = "Wood" })
		end
		local travesano = t:cylinder({ name = "Travesano", axis = "z", length = 9.4, diameter = 0.7, pos = { 14.5, 8.8, 1 }, color = oscuro, mat = "Wood" })
		for _, z in ipairs({ -1, 1.2, 3.2 }) do
			t:cylinder({ name = "Gancho", length = 1.4, diameter = 0.12, pos = { 14.5, 7.8, z }, color = { 120, 120, 124 }, mat = "Metal", folder = "Decoracion" })
		end
		t:box({ name = "Bascula", size = { 2.4, 0.3, 2.4 }, pos = { 14.5, 1.2, 1 }, color = { 110, 110, 114 }, mat = "Metal" })
		t:box({ name = "Bascula", size = { 0.5, 1, 0.5 }, pos = { 14.5, 0.5, 1 }, color = { 80, 80, 84 }, mat = "Metal" })
		local vender = Instance.new("ProximityPrompt")
		vender.Name = "Vender"
		vender.ActionText = "Vender la mochila"
		vender.ObjectText = "Pesadero"
		vender.MaxActivationDistance = 12
		vender.RequiresLineOfSight = false
		vender.KeyboardKeyCode = Enum.KeyCode.F
		vender:SetAttribute("Accion", "Vender")
		vender:SetAttribute("Tienda", nombre or "Tienda de caza y pesca")
		vender.Parent = travesano
		CollectionService:AddTag(vender, "TiendaCaza")
		local cartel = t:box({ name = "Cartel", size = { 0.3, 1.4, 5 }, pos = { 14.1, 6.2, 1 }, color = { 60, 44, 32 }, mat = "WoodPlanks" })
		MB.sign(cartel, "PESADERO", { face = "Left", color = { 236, 214, 160 }, font = "SpecialElite", pps = 30 })
		return encimera
	end

	-- Embarcadero de madera sobre pilotes (para pescar), desde "pos" hacia -Z local
	function P.embarcadero(g, pos, rotY, largo, alturaAgua)
		local e = g:at(pos, rotY)
		local madera = { 120, 92, 64 }
		e:box({ name = "Tablero", size = { 5, 0.5, largo }, pos = { 0, 0.5, -largo / 2 }, color = madera, mat = "WoodPlanks" })
		for z = 0, largo, 6 do
			for _, x in ipairs({ -2.2, 2.2 }) do
				local alto = 0.5 - (alturaAgua or -8) + 4
				e:cylinder({ name = "Pilote", length = alto, diameter = 0.7, pos = { x, 0.5 - alto / 2, -z }, color = darker(madera, 30), mat = "Wood" })
			end
		end
		for _, x in ipairs({ -2.4, 2.4 }) do
			e:box({ name = "Barandilla", size = { 0.25, 0.25, largo * 0.4 }, pos = { x, 3, -largo * 0.2 }, color = madera, mat = "Wood", folder = "Decoracion" })
		end
	end
end
]=]
FUENTES["Datos"] = [=[
-- Datos y utilidades del mundo abierto: costa, ríos, lagos, carreteras, vía del tren, zonas y
-- coches abandonados. X crece hacia el este y Z hacia el sur; el mundo va de -2048 a 2048.
-- El relieve (colinas, montañas, valles y playas) se calcula en Terreno.luau a partir de estos datos.
return function(b, MB)
	local P = MB.Props
	local W = {}
	W.SIZE = 2048

	-- =================================================================
	--  Datos del mapa
	-- =================================================================
	-- Costa de norte a sur por el este y luego hacia el oeste por el sur (el mar queda al este y al sur)
	W.coast = {
		{ 1500, -2048 }, { 1490, -1700 }, { 1460, -1350 }, { 1500, -1000 }, { 1450, -700 }, { 1380, -420 },
		{ 1420, -150 }, { 1380, 150 }, { 1300, 420 }, { 1340, 650 }, { 1200, 880 }, { 1000, 1080 }, { 820, 1300 },
		{ 560, 1390 }, { 300, 1420 }, { 0, 1440 }, { -300, 1420 }, { -560, 1440 }, { -820, 1400 }, { -1080, 1460 },
		{ -1300, 1420 }, { -1500, 1500 }, { -1700, 1480 }, { -2048, 1500 },
	}

	-- Ríos (los puntos van de la fuente a la desembocadura)
	W.rivers = {
		{ name = "RioNorte", width = 44, points = { { -290, -2100 }, { -260, -1800 }, { -200, -1500 }, { -120, -1260 }, { 20, -1150 }, { 240, -1060 }, { 420, -900 }, { 650, -680 }, { 900, -640 }, { 1150, -560 }, { 1300, -520 }, { 1410, -500 } }, mouth = true },
		{ name = "Arroyo", width = 26, points = { { -120, -1260 }, { -140, -1080 }, { -150, -960 } } },
		{ name = "RioOeste", width = 36, points = { { -1700, -2100 }, { -1680, -1700 }, { -1600, -1350 }, { -1520, -1080 }, { -1380, -900 }, { -1240, -700 }, { -1200, -400 }, { -1230, -180 }, { -1200, -30 } } },
		{ name = "Riachuelo", width = 26, points = { { -1200, 40 }, { -1230, 200 }, { -1250, 280 } } },
		{ name = "RioPenal", width = 36, points = { { -1190, 420 }, { -1080, 560 }, { -1000, 620 }, { -900, 860 }, { -950, 1100 }, { -1000, 1300 }, { -1050, 1452 } }, mouth = true },
		{ name = "RioSur", width = 40, points = { { -1000, 620 }, { -720, 740 }, { -480, 560 }, { -250, 380 }, { 0, 420 }, { 180, 560 }, { 330, 800 }, { 420, 1040 }, { 520, 1260 }, { 570, 1386 } }, mouth = true },
	}
	W.lakes = { { -1200, -30, 70 }, { -1250, 340, 90 }, { -150, -900, 100 } }

	-- Meseta de la Colina Alta y cantera
	W.plateau = { x = 1072, z = -228, top = 16, rTop = 120, rBase = 260 }
	W.quarry = { x = 1250, z = -1670 }

	-- Carreteras (ancho 22)
	W.roads = {
		{ { -900, -1640 }, { -940, -1450 }, { -930, -1260 }, { -880, -1150 }, { -800, -950 }, { -700, -760 } },
		{ { -1470, -640 }, { -1300, -640 }, { -1100, -620 }, { -900, -600 }, { -780, -600 } },
		{ { -1470, -640 }, { -1440, -400 }, { -1400, -160 }, { -1390, 40 }, { -1420, 200 }, { -1480, 330 }, { -1540, 410 } },
		{ { -1540, 670 }, { -1500, 880 }, { -1460, 1070 } },
		{ { -1400, -160 }, { -1250, -170 }, { -1100, -140 }, { -960, -110 }, { -800, -60 }, { -640, -60 }, { -480, -120 }, { -330, -100 }, { -180, -180 }, { 0, -260 }, { 200, -380 }, { 300, -420 }, { 500, -420 }, { 700, -380 }, { 820, -280 } },
		{ { -640, -440 }, { -640, -60 }, { -660, 30 } },
		{ { 300, -560 }, { 330, -760 }, { 400, -960 }, { 470, -1100 }, { 520, -1180 } },
		{ { 990, -1500 }, { 1080, -1520 } },
		{ { 1100, 40 }, { 1060, 300 }, { 1020, 530 } },
		{ { -420, -120 }, { -420, 200 }, { -360, 450 }, { -260, 690 } },
		{ { 90, 920 }, { 300, 900 }, { 500, 900 }, { 780, 900 }, { 900, 820 } },
		{ { -680, 150 }, { -720, 420 }, { -640, 640 }, { -560, 900 }, { -430, 920 } },
		{ { -1460, 1070 }, { -1300, 980 }, { -1100, 960 }, { -900, 960 }, { -700, 960 }, { -560, 900 } },
		{ { -1440, -1560 }, { -1560, -1200 }, { -1650, -900 }, { -1700, -780 } },
	}
	W.rail = { { -330, -700 }, { -330, 200 }, { 100, 420 }, { 650, 600 }, { 900, 700 } }

	-- Zonas: rectángulos { x0, x1, z0, z1 } donde no crecen árboles ni se dejan coches
	W.zones = {
		Granjas = { -1500, -700, -1880, -1360 },
		Pista = { -1200, -840, -1220, -860 },
		Villamuro = { -1830, -1470, -780, -500 },
		Comisaria = { -1480, -1300, -160, 20 },
		LagoSereno = { -1120, -800, -100, 220 },
		Penal = { -1700, -1400, 410, 670 },
		ZonaProhibida = { -1610, -1290, 1070, 1330 },
		Motel = { -770, -600, 10, 150 },
		Megatienda = { -780, -480, -740, -440 },
		Estacion = { -440, -200, -720, -120 },
		Antena = { 220, 410, -560, -380 },
		Condado = { 290, 990, -1790, -1170 },
		Cantera = { 1050, 1450, -1870, -1470 },
		ColinaAlta = { 800, 1345, -500, 45 },
		Ciudadela = { -430, 90, 690, 1160 },
		Ladera = { 500, 780, 790, 1070 },
		Refugio = { 870, 1190, 530, 830 },
	}

	-- Suelo de cada zona (material del terreno): Grass = césped corto, LeafyGrass = maleza alta,
	-- Ground = tierra, Mud = barro. Las zonas que no aparecen usan césped corto.
	W.zoneGround = {
		Granjas = "Grass", Penal = "Ground", ZonaProhibida = "Mud", Antena = "Ground", Estacion = "Ground",
		Refugio = "Ground", Cantera = "Rock", Megatienda = "Ground", Motel = "LeafyGrass", Ladera = "LeafyGrass",
		LagoSereno = "LeafyGrass", Comisaria = "Grass",
	}
	-- Zonas que no se aplanan a altura 0 (la meseta y la cantera tienen su propio relieve)
	W.zoneNoFlat = { ColinaAlta = true }

	-- =================================================================
	--  Utilidades
	-- =================================================================
	local seed = 20241
	-- Números pseudoaleatorios repetibles (el mismo mundo cada vez)
	function W.rand()
		seed = (seed * 16807) % 2147483647
		return seed / 2147483647
	end
	function W.range(a, c)
		return a + (c - a) * W.rand()
	end

	local function segDist(px, pz, ax, az, bx, bz)
		local dx, dz = bx - ax, bz - az
		local l2 = dx * dx + dz * dz
		local t = l2 > 0 and math.max(0, math.min(1, ((px - ax) * dx + (pz - az) * dz) / l2)) or 0
		local qx, qz = ax + dx * t - px, az + dz * t - pz
		return math.sqrt(qx * qx + qz * qz)
	end
	W.segDist = segDist
	function W.polylineDist(px, pz, pts)
		local best = math.huge
		for i = 1, #pts - 1 do
			best = math.min(best, segDist(px, pz, pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2]))
		end
		return best
	end

	function W.inZone(x, z, margin)
		margin = margin or 0
		for _, r in pairs(W.zones) do
			if x > r[1] - margin and x < r[2] + margin and z > r[3] - margin and z < r[4] + margin then
				return true
			end
		end
		return false
	end

	function W.nearRoad(x, z, margin)
		for _, road in ipairs(W.roads) do
			if W.polylineDist(x, z, road) < 11 + margin then
				return true
			end
		end
		return W.polylineDist(x, z, W.rail) < 6 + margin
	end

	function W.nearWater(x, z, margin)
		for _, river in ipairs(W.rivers) do
			if W.polylineDist(x, z, river.points) < river.width / 2 + margin then
				return true
			end
		end
		for _, l in ipairs(W.lakes) do
			if math.sqrt((x - l[1]) ^ 2 + (z - l[2]) ^ 2) < l[3] + margin then
				return true
			end
		end
		return false
	end

	-- ¿Está en tierra firme y a más de margin de la costa?
	local landPoly = { { -2048, -2048 } }
	for _, p in ipairs(W.coast) do
		table.insert(landPoly, p)
	end
	-- ¿Está dentro del contorno de tierra (sin contar la distancia a la costa)?
	function W.inLandPoly(x, z)
		local inside = false
		local j = #landPoly
		for i = 1, #landPoly do
			local xi, zi, xj, zj = landPoly[i][1], landPoly[i][2], landPoly[j][1], landPoly[j][2]
			if ((zi > z) ~= (zj > z)) and (x < (xj - xi) * (z - zi) / (zj - zi) + xi) then
				inside = not inside
			end
			j = i
		end
		return inside
	end
	function W.isLand(x, z, margin)
		local inside = false
		local j = #landPoly
		for i = 1, #landPoly do
			local xi, zi, xj, zj = landPoly[i][1], landPoly[i][2], landPoly[j][1], landPoly[j][2]
			if ((zi > z) ~= (zj > z)) and (x < (xj - xi) * (z - zi) / (zj - zi) + xi) then
				inside = not inside
			end
			j = i
		end
		return inside and W.polylineDist(x, z, W.coast) > (margin or 0) and math.abs(x) < W.SIZE - 20 and math.abs(z) < W.SIZE - 20
	end

	local function eachSegment(points, fn)
		for i = 1, #points - 1 do
			local a, c = points[i], points[i + 1]
			local dx, dz = c[1] - a[1], c[2] - a[2]
			local len = math.sqrt(dx * dx + dz * dz)
			fn(a, c, len, math.deg(math.atan2(-dz, dx)), (a[1] + c[1]) / 2, (a[2] + c[2]) / 2, dx / len, dz / len, i)
		end
	end
	W.eachSegment = eachSegment

	-- =================================================================
	--  Carreteras con puentes, vía del tren y límites
	-- =================================================================
	local ROAD = { 66, 66, 68 }
	function W.buildRoads()
		for _, road in ipairs(W.roads) do
			eachSegment(road, function(a, c, len, yaw, mx, mz, ux, uz)
				b:box({ name = "Carretera", size = { len, 0.4, 22 }, pos = { mx, 0, mz }, rot = { 0, yaw, 0 }, color = ROAD, mat = "Asphalt" })
				-- Línea central borrada a trozos y hierba que se come el asfalto
				for d = 12, len - 12, 24 do
					if W.rand() > 0.35 then
						b:box({ name = "Linea", size = { 8, 0.12, 0.5 }, pos = { a[1] + ux * d, 0.22, a[2] + uz * d }, rot = { 0, yaw, 0 }, color = { 170, 150, 92 }, folder = "Decoracion", shadow = false })
					end
				end
				for d = 30, len - 10, 70 do
					if W.rand() > 0.45 then
						local off = W.range(-8, 8)
						b:box({ name = "Hierba", size = { W.range(6, 14), 0.14, W.range(3, 8) }, pos = { a[1] + ux * d - uz * off, 0.23, a[2] + uz * d + ux * off }, rot = { 0, yaw + W.range(-20, 20), 0 }, color = { 78, 104, 58 }, mat = "LeafyGrass", folder = "Decoracion", shadow = false })
					end
				end
			end)
			for _, pt in ipairs(road) do
				b:cylinder({ name = "Cruce", length = 0.4, diameter = 22, pos = { pt[1], 0, pt[2] }, color = ROAD, mat = "Asphalt" })
			end
		end
		eachSegment(W.rail, function(a, c)
			P.rails(b, { a[1], 0, a[2] }, { c[1], 0, c[2] }, false)
		end)
		for _, pt in ipairs(W.rail) do
			b:cylinder({ name = "Balasto", length = 0.6, diameter = 10, pos = { pt[1], 0.3, pt[2] }, color = { 110, 104, 96 }, mat = "Pebble" })
		end
	end

	-- Puentes donde una carretera cruza un río (se calculan solos)
	function W.buildBridges()
		local count = 0
		for _, road in ipairs(W.roads) do
			eachSegment(road, function(a, c, len, yaw, mx, mz, ux, uz)
				for _, river in ipairs(W.rivers) do
					eachSegment(river.points, function(ra, rc, rlen, ryaw, rmx, rmz, rux, ruz)
						local den = ux * ruz - uz * rux
						if math.abs(den) < 1e-6 then
							return
						end
						local wx, wz = ra[1] - a[1], ra[2] - a[2]
						local t = (wx * ruz - wz * rux) / den
						local s = (wx * uz - wz * ux) / den
						if t < 0 or t > len or s < 0 or s > rlen then
							return
						end
						count = count + 1
						local ix, iz = a[1] + ux * t, a[2] + uz * t
						local span = river.width / math.max(0.35, math.abs(den)) + 34
						local g = b:at({ ix, 0, iz }, yaw)
						g:box({ name = "Puente", size = { span, 1.6, 26 }, pos = { 0, -0.6, 0 }, color = { 150, 146, 140 }, mat = "Concrete" })
						for _, side in ipairs({ -1, 1 }) do
							g:box({ name = "Pretil", size = { span, 2.6, 1 }, pos = { 0, 1.2, side * 12.5 }, color = { 160, 156, 150 }, mat = "Concrete" })
							g:box({ name = "Musgo", size = { span * 0.3, 0.8, 1.1 }, pos = { span * (count % 2 == 0 and 0.2 or -0.25), 2, side * 12.5 }, color = { 74, 100, 56 }, mat = "LeafyGrass", folder = "Decoracion", shadow = false })
						end
						for _, off in ipairs({ -river.width / 4, river.width / 4 }) do
							g:cylinder({ name = "Pilar", length = 16, diameter = 3, pos = { off / math.max(0.35, math.abs(den)), -9, 0 }, color = { 130, 128, 122 }, mat = "Concrete", folder = "Decoracion" })
						end
					end)
				end
			end)
		end
		return count
	end

	-- Paredes invisibles alrededor del mundo (en trozos, una pieza no puede medir más de 2048)
	function W.buildBounds()
		local S, H = W.SIZE, 400
		for i = 0, 3 do
			local c = -S + 512 + i * 1024
			for _, wall in ipairs({ { { 1024, H, 4 }, { c, H / 2 - 40, -S - 2 } }, { { 1024, H, 4 }, { c, H / 2 - 40, S + 2 } }, { { 4, H, 1024 }, { -S - 2, H / 2 - 40, c } }, { { 4, H, 1024 }, { S + 2, H / 2 - 40, c } } }) do
				b:part("Part", { name = "Limite", size = wall[1], pos = wall[2], transparency = 1, shadow = false, folder = "Limites" })
			end
		end
	end

	-- =================================================================
	--  Coches abandonados en las carreteras
	-- =================================================================
	local RUST = { { 120, 70, 50 }, { 90, 96, 100 }, { 140, 120, 90 }, { 70, 80, 70 }, { 150, 60, 50 }, { 60, 70, 90 }, { 40, 40, 42 } }
	function W.buildCars()
		local count = 0
		for _, road in ipairs(W.roads) do
			eachSegment(road, function(a, c, len, yaw, mx, mz, ux, uz)
				for d = 40, len - 40, 150 do
					local x, z = a[1] + ux * d, a[2] + uz * d
					if W.rand() < 0.5 and not W.inZone(x, z, 20) and not W.nearWater(x, z, 30) then
						local off = (W.rand() < 0.5) and -5 or 5
						P.car(b, { x - uz * off, 0.2, z + ux * off }, yaw + 90 + W.range(-30, 30), RUST[math.floor(W.rand() * #RUST) + 1], true)
						count = count + 1
					end
				end
			end)
		end
		return count
	end

	-- =================================================================
	--  Utilidades para las zonas
	-- =================================================================
	-- Calle de una zona (por defecto asfalto de 22 de ancho) a la altura y
	function W.road(points, width, color, mat, y)
		width, y = width or 22, y or 0
		eachSegment(points, function(a, c, len, yaw, mx, mz)
			b:box({ name = "Calle", size = { len, 0.4, width }, pos = { mx, y, mz }, rot = { 0, yaw, 0 }, color = color or ROAD, mat = mat or "Asphalt" })
		end)
		for i = 2, #points - 1 do
			b:cylinder({ name = "Cruce", length = 0.4, diameter = width, pos = { points[i][1], y, points[i][2] }, color = color or ROAD, mat = mat or "Asphalt" })
		end
	end

	-- Valla de postes y dos travesaños (barata en piezas)
	function W.fence(a, c, height, color, y)
		local wood = color or { 120, 96, 70 }
		y = y or 0
		local dx, dz = c[1] - a[1], c[2] - a[2]
		local len = math.sqrt(dx * dx + dz * dz)
		local yaw = math.deg(math.atan2(-dz, dx))
		local n = math.max(1, math.floor(len / 10))
		for i = 0, n do
			b:box({ name = "Poste", size = { 0.6, height, 0.6 }, pos = { a[1] + dx * i / n, y + height / 2, a[2] + dz * i / n }, color = wood, mat = "Wood" })
		end
		for _, h in ipairs({ 0.45, 0.85 }) do
			b:box({ name = "Travesano", size = { len, 0.4, 0.3 }, pos = { (a[1] + c[1]) / 2, y + height * h, (a[2] + c[2]) / 2 }, rot = { 0, yaw, 0 }, color = wood, mat = "Wood" })
		end
	end

	-- Recorre el borde de un rectángulo dejando puertas. gates = { { "N" | "S" | "E" | "O", desde, hasta }, ... }
	-- N es el lado z0, S el lado z1, O el lado x0 y E el lado x1. build(a, c) recibe cada tramo { x, z }.
	function W.wallRect(x0, x1, z0, z1, gates, build)
		local sides = { N = { { x0, z0 }, { x1, z0 }, 1 }, E = { { x1, z0 }, { x1, z1 }, 2 }, S = { { x1, z1 }, { x0, z1 }, 1 }, O = { { x0, z1 }, { x0, z0 }, 2 } }
		for _, name in ipairs({ "N", "E", "S", "O" }) do
			local s = sides[name]
			local axis = s[3]
			local from, to = s[1][axis], s[2][axis]
			local cuts = {}
			for _, g in ipairs(gates or {}) do
				if g[1] == name then
					table.insert(cuts, { math.min(g[2], g[3]), math.max(g[2], g[3]) })
				end
			end
			local lo, hi = math.min(from, to), math.max(from, to)
			table.sort(cuts, function(a, c)
				return a[1] < c[1]
			end)
			local cursor = lo
			local function emit(a, c)
				if c - a > 1 then
					local pa, pc = { s[1][1], s[1][2] }, { s[1][1], s[1][2] }
					pa[axis], pc[axis] = a, c
					build(pa, pc)
				end
			end
			for _, cut in ipairs(cuts) do
				emit(cursor, cut[1])
				cursor = cut[2]
			end
			emit(cursor, hi)
		end
	end

	-- Coche de policía abandonado
	function W.policeCar(x, y, z, yaw)
		P.car(b, { x, y, z }, yaw, { 30, 32, 36 }, true)
		local g = b:at({ x, y, z }, yaw)
		g:box({ name = "Puerta", size = { 5.5, 1.6, 4 }, pos = { 0, 2.4, 0.4 }, color = { 230, 230, 226 }, folder = "Decoracion" })
		g:box({ name = "Sirena", size = { 3, 0.5, 0.8 }, pos = { -0.8, 5.55, 1.3 }, color = { 60, 80, 160 }, mat = "Glass", folder = "Decoracion" })
		g:box({ name = "Sirena", size = { 1.5, 0.5, 0.8 }, pos = { 1.4, 5.55, 1.3 }, color = { 160, 50, 50 }, mat = "Glass", folder = "Decoracion" })
	end

	-- Aparcamiento con líneas
	function W.parking(x0, x1, z0, z1, y)
		y = y or 0
		b:box({ name = "Aparcamiento", size = { x1 - x0, 0.4, z1 - z0 }, pos = { (x0 + x1) / 2, y, (z0 + z1) / 2 }, color = { 72, 72, 74 }, mat = "Asphalt" })
		for x = x0 + 8, x1 - 8, 10 do
			for _, z in ipairs({ z0 + 9, z1 - 9 }) do
				b:box({ name = "Linea", size = { 0.4, 0.12, 14 }, pos = { x, y + 0.22, z }, color = { 180, 176, 160 }, folder = "Decoracion", shadow = false })
			end
		end
	end

	-- Punto de aparición sobre el suelo
	function W.spawn(x, z, yaw, y)
		b:spawnLocation({ x, (y or W.groundY(x, z)) + 0.5, z }, yaw)
	end

	return W
end
]=]
FUENTES["Terreno"] = [=[
--[[
	Terreno realista del mundo abierto.
	El relieve se calcula con ruido (colinas suaves, montañas nevadas en los bordes norte y oeste),
	se aplana bajo carreteras y zonas, se excavan los valles de los ríos y los lagos, la cantera
	y la meseta tienen su forma, y la costa baja en playa hasta el mar.
	El suelo cambia según el sitio: césped corto (Grass), maleza alta (LeafyGrass), tierra, barro en
	las orillas, arena en la playa, roca en las pendientes fuertes y nieve en las cumbres.
	Las rocas sueltas también se esculpen en el terreno (Rock, Slate, Basalt) con formas irregulares.
	Se escribe con Terrain:WriteVoxels en bloques de 256 x 256 studs.
]]
return function(W)
	local T = {}
	local S = W.SIZE

	-- =================================================================
	--  Ruido Perlin propio (da el mismo mundo en Studio y en las pruebas)
	-- =================================================================
	local perm = {}
	do
		local p = {}
		for i = 0, 255 do
			p[i] = i
		end
		local seed = 1337
		for i = 255, 1, -1 do
			seed = (seed * 16807) % 2147483647
			local j = seed % (i + 1)
			p[i], p[j] = p[j], p[i]
		end
		for i = 0, 511 do
			perm[i] = p[i % 256]
		end
	end
	local GX = { 1, -1, 1, -1, 1, -1, 0, 0 }
	local GZ = { 1, 1, -1, -1, 0, 0, 1, -1 }
	local function grad(h, x, z)
		local g = h % 8 + 1
		return GX[g] * x + GZ[g] * z
	end
	local function noise(x, z)
		local xi, zi = math.floor(x), math.floor(z)
		local xf, zf = x - xi, z - zi
		xi, zi = xi % 256, zi % 256
		local u = xf * xf * xf * (xf * (xf * 6 - 15) + 10)
		local v = zf * zf * zf * (zf * (zf * 6 - 15) + 10)
		local a, b = perm[xi] + zi, perm[xi + 1] + zi
		local g00 = grad(perm[a], xf, zf)
		local g10 = grad(perm[b], xf - 1, zf)
		local g01 = grad(perm[a + 1], xf, zf - 1)
		local g11 = grad(perm[b + 1], xf - 1, zf - 1)
		local x1 = g00 + u * (g10 - g00)
		local x2 = g01 + u * (g11 - g01)
		return (x1 + v * (x2 - x1)) * 0.75
	end
	local function fbm(x, z, octaves)
		local sum, amp, freq, norm = 0, 1, 1, 0
		for _ = 1, octaves do
			sum = sum + noise(x * freq, z * freq) * amp
			norm = norm + amp
			amp = amp * 0.5
			freq = freq * 2.03
		end
		return sum / norm
	end
	T.noise, T.fbm = noise, fbm

	local function smooth01(t)
		if t <= 0 then
			return 0
		elseif t >= 1 then
			return 1
		end
		return t * t * (3 - 2 * t)
	end
	-- 1 si d <= a, 0 si d >= b, suave en medio
	local function near(d, a, b)
		return 1 - smooth01((d - a) / (b - a))
	end

	-- =================================================================
	--  Campos de distancia en una rejilla de 16 studs (carreteras, ríos, zonas y costa)
	-- =================================================================
	local STEP = 16
	local NG = math.floor(2 * S / STEP) + 1
	local fRoad, fRiver, fZone, fCoast = {}, {}, {}, {}
	local segDist = W.segDist

	local roadSegs, riverSegs = {}, {}
	local function addSegs(list, points, half)
		for i = 1, #points - 1 do
			local a, c = points[i], points[i + 1]
			table.insert(list, { a[1], a[2], c[1], c[2], math.min(a[1], c[1]), math.max(a[1], c[1]), math.min(a[2], c[2]), math.max(a[2], c[2]), half })
		end
	end
	for _, road in ipairs(W.roads) do
		addSegs(roadSegs, road, 0)
	end
	addSegs(roadSegs, W.rail, 0)
	for _, river in ipairs(W.rivers) do
		addSegs(riverSegs, river.points, river.width / 2)
	end
	local zoneRects = {}
	for name, r in pairs(W.zones) do
		if not W.zoneNoFlat[name] then
			table.insert(zoneRects, r)
		end
	end

	local CAP = 200
	for iz = 0, NG - 1 do
		local z = -S + iz * STEP
		for ix = 0, NG - 1 do
			local x = -S + ix * STEP
			local i = iz * NG + ix + 1
			local best = CAP
			for _, s in ipairs(roadSegs) do
				if x > s[5] - best and x < s[6] + best and z > s[7] - best and z < s[8] + best then
					local d = segDist(x, z, s[1], s[2], s[3], s[4])
					if d < best then
						best = d
					end
				end
			end
			fRoad[i] = best
			best = CAP
			for _, s in ipairs(riverSegs) do
				local reach = best + s[9]
				if x > s[5] - reach and x < s[6] + reach and z > s[7] - reach and z < s[8] + reach then
					local d = segDist(x, z, s[1], s[2], s[3], s[4]) - s[9]
					if d < best then
						best = d
					end
				end
			end
			for _, l in ipairs(W.lakes) do
				local d = math.sqrt((x - l[1]) ^ 2 + (z - l[2]) ^ 2) - l[3]
				if d < best then
					best = d
				end
			end
			fRiver[i] = best
			best = CAP
			for _, r in ipairs(zoneRects) do
				local dx = math.max(r[1] - x, 0, x - r[2])
				local dz = math.max(r[3] - z, 0, z - r[4])
				local d = math.sqrt(dx * dx + dz * dz)
				if d < best then
					best = d
				end
			end
			fZone[i] = best
			local dc = math.min(W.polylineDist(x, z, W.coast), 600)
			-- En el borde oeste y norte el punto se mira un poco hacia dentro para no confundirlo con el mar
			fCoast[i] = W.inLandPoly(math.max(x, -S + 1), math.max(z, -S + 1)) and dc or -dc
		end
		if iz % 32 == 0 then
			task.wait()
		end
	end

	-- Interpolación bilineal de los cuatro campos
	local function fields(x, z)
		local fx = math.min(math.max((x + S) / STEP, 0), NG - 1.0001)
		local fz = math.min(math.max((z + S) / STEP, 0), NG - 1.0001)
		local ix, iz = math.floor(fx), math.floor(fz)
		local tx, tz = fx - ix, fz - iz
		local i = iz * NG + ix + 1
		local j = i + NG
		local function lerp(f)
			local a = f[i] + (f[i + 1] - f[i]) * tx
			local c = f[j] + (f[j + 1] - f[j]) * tx
			return a + (c - a) * tz
		end
		return lerp(fRoad), lerp(fRiver), lerp(fZone), lerp(fCoast)
	end
	T.fields = fields

	-- =================================================================
	--  Cantera y meseta
	-- =================================================================
	local Q, PL = W.quarry, W.plateau
	local LEVELS = { { 170, -12 }, { 130, -24 }, { 90, -36 }, { 55, -48 } }
	local function quarry(x, z)
		local dx, dz = x - Q.x, z - Q.z
		local r = math.sqrt(dx * dx + dz * dz)
		if r >= 196 then
			return nil, r
		end
		if r < 40 then
			return -56, r
		end
		local h, outer = 0, 0
		for _, lv in ipairs(LEVELS) do
			if r < lv[1] then
				outer, h = h, lv[2]
			end
		end
		-- Rampas para bajar de una terraza a otra
		local a = math.deg(math.atan2(dz, dx)) % 360
		for i, lv in ipairs(LEVELS) do
			local diff = math.abs(((a - i * 95) + 180) % 360 - 180)
			if diff < 8 and r > lv[1] - 34 and r < lv[1] + 4 then
				local upper = (i == 1) and 0 or LEVELS[i - 1][2]
				h = lv[2] + (upper - lv[2]) * smooth01((r - (lv[1] - 34)) / 38)
			end
		end
		return h, r
	end

	-- =================================================================
	--  Altura del suelo
	-- =================================================================
	function T.heightAt(x, z, road, river, zone, coast)
		-- Colinas y ondulación suave
		local h = math.max(0, fbm(x / 650 + 11.3, z / 650 - 7.1, 4)) * 95 + fbm(x / 170 + 3.1, z / 170 + 1.7, 2) * 2.5
		-- Montañas en los bordes norte y oeste
		local edge = math.min(x + S, z + S)
		if edge < 560 then
			local e = smooth01(1 - edge / 560)
			local ridge = 1 - math.abs(fbm(x / 360 - 3.7, z / 360 + 9.2, 4))
			h = h + e * (50 + ridge * ridge * 240)
		end
		-- Explanadas bajo carreteras y zonas
		local flat = math.max(near(road, 14, 90), near(zone, 4, 120))
		h = h * (1 - flat)
		-- Meseta de la Colina Alta
		local dp = math.sqrt((x - PL.x) ^ 2 + (z - PL.z) ^ 2)
		if dp < PL.rBase + 40 then
			h = h + (PL.top - h) * near(dp, PL.rTop, PL.rBase + 40)
		end
		-- Cantera
		local qh = quarry(x, z)
		if qh then
			h = qh
		end
		-- Valles de ríos y lagos: talud suave y cauce
		if river < 80 then
			local bank = (river < 0) and (-4 - 7 * math.min(1, -river / 10)) or (-4 + river * 0.35)
			if bank < h then
				h = bank
			end
		end
		-- Playa y fondo del mar (tierra adentro la costa deja de influir)
		local beach = -4 + coast * 0.12 + math.max(0, coast - 50) ^ 1.5 * 0.2
		if beach < h then
			h = beach
		end
		if coast < 0 and h < -34 then
			h = -34 + fbm(x / 90, z / 90, 2) * 2
		end
		return h
	end

	function T.height(x, z)
		return T.heightAt(x, z, fields(x, z))
	end
	W.groundY = T.height

	-- Nivel del agua en un punto (nil si no hay agua)
	function T.waterAt(x, z, river, coast)
		local _, r = quarry(x, z)
		if r < 40 then
			return -46
		end
		if river < 1 or coast < 6 then
			return -4
		end
		return nil
	end

	-- Densidad de vegetación (la usa también el bosque): alta = maleza y bosque
	function T.veg(x, z)
		return fbm(x / 230 + 5.5, z / 230 - 2.2, 3)
	end

	-- Material de la superficie
	local function zoneGround(x, z)
		for name, r in pairs(W.zones) do
			if x > r[1] - 3 and x < r[2] + 3 and z > r[3] - 3 and z < r[4] + 3 then
				return W.zoneGround[name] or "Grass"
			end
		end
		return "Grass"
	end
	function T.surfaceAt(x, z, h, slope, road, river, zone, coast)
		local _, qr = quarry(x, z)
		if qr < 196 then
			return (qr < 42) and "Mud" or "Rock"
		end
		if coast < 46 and h < 3.5 then
			return "Sand"
		end
		if h > 175 + fbm(x / 80, z / 80, 2) * 25 then
			return "Snow"
		end
		if slope > 0.95 or h > 125 then
			return "Rock"
		end
		if river < 9 then
			return "Mud"
		end
		if road < 13.5 then
			return "Ground"
		end
		if zone < 3 then
			return zoneGround(x, z)
		end
		if fbm(x / 55 - 9.1, z / 55 + 4.4, 2) > 0.42 then
			return "Ground"
		end
		if T.veg(x, z) > 0.02 then
			return "LeafyGrass"
		end
		return "Grass"
	end

	function T.surface(x, z)
		local road, river, zone, coast = fields(x, z)
		local h = T.heightAt(x, z, road, river, zone, coast)
		local sx = (T.height(x + 4, z) - T.height(x - 4, z)) / 8
		local sz = (T.height(x, z + 4) - T.height(x, z - 4)) / 8
		return T.surfaceAt(x, z, h, math.sqrt(sx * sx + sz * sz), road, river, zone, coast), h
	end

	-- =================================================================
	--  Rocas esculpidas en el propio terreno: elipsoides deformados con ruido, de Rock, Slate o Basalt.
	--  Así tienen la textura real de roca de Roblox y formas irregulares, sin ser piezas.
	-- =================================================================
	T.boulders = {}
	local ROCK_MATS = { "Rock", "Rock", "Rock", "Slate", "Slate", "Basalt" }
	function T.addBoulder(x, z, size, mat)
		local rx, ry, rz = size * W.range(0.95, 1.3), size * W.range(0.55, 0.85), size * W.range(0.7, 1)
		local yaw = math.rad(W.range(0, 180))
		table.insert(T.boulders, {
			x = x, z = z, y = T.height(x, z) - ry * 0.35,
			rx = rx, ry = ry, rz = rz, c = math.cos(yaw), s = math.sin(yaw),
			mat = mat or ROCK_MATS[math.floor(W.rand() * #ROCK_MATS) + 1],
			seed = W.range(0, 200), reach = math.max(rx, rz) * 1.6,
		})
	end

	-- Ocupación (0 a 1) de la roca en un punto
	function T.boulderOcc(bd, px, py, pz)
		local dx, dy, dz = px - bd.x, py - bd.y, pz - bd.z
		local u = dx * bd.c + dz * bd.s
		local w = -dx * bd.s + dz * bd.c
		local q = math.sqrt((u / bd.rx) ^ 2 + (dy / bd.ry) ^ 2 + (w / bd.rz) ^ 2)
		-- Bultos y aristas con ruido para que no sea un huevo perfecto
		local bump = noise(u * 0.17 + bd.seed, w * 0.17 + dy * 0.23) * 0.34 + noise(u * 0.43 - bd.seed, dy * 0.41 + w * 0.11) * 0.14
		q = q * (1 - bump)
		local sd = (1 - q) * math.min(bd.rx, bd.ry, bd.rz)
		return math.clamp(0.5 + sd / 4, 0, 1)
	end

	-- =================================================================
	--  Escribir el terreno en Roblox
	-- =================================================================
	local MATS = {}
	for _, m in ipairs({ "Grass", "LeafyGrass", "Ground", "Mud", "Rock", "Slate", "Basalt", "Sand", "Snow", "Water", "Air" }) do
		MATS[m] = Enum.Material[m]
	end

	-- progress(hechos, total) se llama tras cada bloque
	function T.generate(terrain, progress, only)
		local CH, V = 64, 4
		local n = math.floor(2 * S / (CH * V))
		local done = 0
		for bz = 0, n - 1 do
			for bx = 0, n - 1 do
				if not only or only[bz * n + bx + 1] then
					local x0, z0 = -S + bx * CH * V, -S + bz * CH * V
					local H, F = {}, {}
					for i = 0, CH + 1 do
						H[i], F[i] = {}, {}
						for k = 0, CH + 1 do
							local x, z = x0 + (i - 0.5) * V, z0 + (k - 0.5) * V
							local road, river, zone, coast = fields(x, z)
							H[i][k] = T.heightAt(x, z, road, river, zone, coast)
							F[i][k] = { road, river, zone, coast }
						end
					end
					local top, wat = {}, {}
					local hmin, hmax = math.huge, -math.huge
					for i = 1, CH do
						top[i], wat[i] = {}, {}
						for k = 1, CH do
							local x, z = x0 + (i - 0.5) * V, z0 + (k - 0.5) * V
							local h, f = H[i][k], F[i][k]
							local sx = (H[i + 1][k] - H[i - 1][k]) / (2 * V)
							local sz = (H[i][k + 1] - H[i][k - 1]) / (2 * V)
							top[i][k] = T.surfaceAt(x, z, h, math.sqrt(sx * sx + sz * sz), f[1], f[2], f[3], f[4])
							local wl = T.waterAt(x, z, f[2], f[4])
							if wl and wl > h then
								wat[i][k] = wl
								if wl > hmax then
									hmax = wl
								end
							end
							if h < hmin then
								hmin = h
							end
							if h > hmax then
								hmax = h
							end
						end
					end
					-- Rocas que tocan este bloque
					local rocks = {}
					local x1, z1 = x0 + CH * V, z0 + CH * V
					for _, bd in ipairs(T.boulders) do
						if bd.x + bd.reach > x0 and bd.x - bd.reach < x1 and bd.z + bd.reach > z0 and bd.z - bd.reach < z1 then
							table.insert(rocks, bd)
							hmax = math.max(hmax, bd.y + bd.ry * 1.6)
						end
					end
					local y0 = math.floor((hmin - 12) / V) * V
					local y1 = math.ceil((hmax + 2) / V) * V
					local ny = (y1 - y0) / V
					local mats, occs = {}, {}
					for i = 1, CH do
						local mi, oi = {}, {}
						mats[i], occs[i] = mi, oi
						for j = 1, ny do
							mi[j], oi[j] = {}, {}
						end
						for k = 1, CH do
							local h, wl, m0 = H[i][k], wat[i][k], top[i][k]
							local surf = MATS[m0]
							local under = (m0 == "Rock" or m0 == "Snow") and MATS.Rock or ((m0 == "Sand") and MATS.Sand or MATS.Ground)
							for j = 1, ny do
								local vy = y0 + (j - 1) * V
								local m, o = MATS.Air, 0
								if vy < h then
									local depth = h - (vy + V)
									o = math.min(1, (h - vy) / V)
									if depth < 4 then
										m = surf
									elseif depth < 14 then
										m = under
									else
										m = MATS.Rock
									end
								elseif wl and vy < wl then
									m, o = MATS.Water, math.min(1, (wl - vy) / V)
								end
								mi[j][k], oi[j][k] = m, o
							end
						end
					end
					for _, bd in ipairs(rocks) do
						local m = MATS[bd.mat]
						local i0 = math.max(1, math.floor((bd.x - bd.reach - x0) / V) + 1)
						local i1 = math.min(CH, math.floor((bd.x + bd.reach - x0) / V) + 1)
						local k0 = math.max(1, math.floor((bd.z - bd.reach - z0) / V) + 1)
						local k1 = math.min(CH, math.floor((bd.z + bd.reach - z0) / V) + 1)
						local j0 = math.max(1, math.floor((bd.y - bd.ry * 1.6 - y0) / V) + 1)
						local j1 = math.min(ny, math.floor((bd.y + bd.ry * 1.6 - y0) / V) + 1)
						for i = i0, i1 do
							for j = j0, j1 do
								local mj, oj = mats[i][j], occs[i][j]
								for k = k0, k1 do
									local o = T.boulderOcc(bd, x0 + (i - 0.5) * V, y0 + (j - 0.5) * V, z0 + (k - 0.5) * V)
									if o > oj[k] and (o >= 0.5 or mj[k] ~= MATS.Water) then
										mj[k], oj[k] = m, o
									end
								end
							end
						end
					end
					terrain:WriteVoxels(Region3.new(Vector3.new(x0, y0, z0), Vector3.new(x0 + CH * V, y1, z0 + CH * V)), V, mats, occs)
					task.wait()
				end
				done = done + 1
				if progress then
					progress(done, n * n)
				end
			end
		end
	end

	return T
end
]=]
FUENTES["Vegetacion"] = [=[
--[[
	Vegetación del mundo abierto, hecha para parecer natural y no de bolas y cubos:
	  · Abetos: capas de ramas que caen y se acortan hacia una punta afilada (silueta de árbol de navidad)
	  · Robles: tronco grueso, ramas abiertas y copa irregular de muchas matas de hojas de varios tonos
	  · Abedules: tronco blanco con marcas y copa alta y estrecha; árboles secos con ramas rotas
	  · Sotobosque: helechos, arbustos bajos y abetos jóvenes; hierba alta en matas; juncos en las orillas
	  · Troncos caídos que siguen la pendiente, tocones y rocas esculpidas en el propio terreno
	El bosque es más denso donde el terreno tiene maleza (LeafyGrass) y los abetos dominan en el norte
	y en las alturas.

	Modelos propios (opcional): si en ServerStorage hay una carpeta "ModelosMundo" con subcarpetas
	Pino, Roble, Abedul, Muerto o Arbusto que tengan modelos dentro (por ejemplo árboles 3D realistas
	de la Toolbox), se colocan esos en lugar de los hechos con piezas, con tamaño y giro al azar.
]]
return function(b, MB, W, T)
	local P = MB.Props
	local V = {}

	local FIR = { { 38, 66, 44 }, { 44, 74, 50 }, { 33, 58, 40 }, { 50, 80, 54 }, { 42, 70, 56 } }
	local OAK = { { 74, 100, 52 }, { 86, 112, 58 }, { 64, 90, 46 }, { 98, 112, 56 }, { 112, 106, 54 } }
	local BIRCH = { { 122, 150, 72 }, { 138, 158, 80 }, { 112, 140, 66 }, { 150, 150, 70 } }
	local FERN = { { 70, 108, 48 }, { 82, 118, 54 }, { 96, 120, 58 } }
	local GRASS = { { 96, 124, 64 }, { 110, 132, 70 }, { 130, 136, 76 }, { 150, 146, 90 }, { 86, 114, 58 } }
	local REED = { { 104, 120, 66 }, { 120, 128, 72 }, { 138, 132, 80 } }
	local BARK = { 70, 54, 42 }
	local BARK_OAK = { 84, 66, 50 }

	local function pick(list)
		return list[math.floor(W.rand() * #list) + 1]
	end

	local function rod(name, a, c, diameter, color, mat, folder)
		local part = P.rod(b, a, c, diameter, color, mat, folder)
		part.Name = name
		return part
	end

	-- =================================================================
	--  Modelos propios de ServerStorage.ModelosMundo (si los hay)
	-- =================================================================
	local MODELS = {}
	do
		local ok, folder = pcall(function()
			return game:GetService("ServerStorage"):FindFirstChild("ModelosMundo")
		end)
		if ok and folder then
			for _, kind in ipairs({ "Pino", "Roble", "Abedul", "Muerto", "Arbusto" }) do
				local sub = folder:FindFirstChild(kind)
				local list = {}
				if sub then
					for _, m in ipairs(sub:GetChildren()) do
						if m:IsA("Model") or m:IsA("BasePart") then
							table.insert(list, m)
						end
					end
				end
				if #list > 0 then
					MODELS[kind] = list
				end
			end
		end
	end
	V.modelos = MODELS

	-- Coloca una copia de un modelo propio apoyada en el suelo. Devuelve false si no hay modelos de ese tipo
	local function useModel(kind, x, z, s)
		local list = MODELS[kind]
		if not list then
			return false
		end
		local src = list[math.floor(W.rand() * #list) + 1]
		local m = src:Clone()
		if m:IsA("BasePart") then
			local g = Instance.new("Model")
			g.Name = src.Name
			m.Parent = g
			g.PrimaryPart = m
			m = g
		end
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("LuaSourceContainer") then
				d:Destroy() -- los modelos de la Toolbox a veces traen scripts (incluso maliciosos): fuera
			elseif d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		pcall(function()
			m:ScaleTo(m:GetScale() * s)
		end)
		local box, size = m:GetBoundingBox()
		local bottom = CFrame.new(box.Position.X, box.Position.Y - size.Y / 2, box.Position.Z)
		local rel = m:GetPivot():ToObjectSpace(bottom)
		local target = CFrame.new(x, T.height(x, z) - 0.3, z) * CFrame.Angles(0, math.rad(W.range(0, 360)), 0)
		m:PivotTo(target * rel:Inverse())
		m.Parent = b:folder("Mapa")
		return true
	end

	-- =================================================================
	--  Árboles
	-- =================================================================
	-- Abeto: capas de tres ramas en cuña que caen hacia fuera (cada capa girada 60° respecto a la de abajo),
	-- más cortas cuanto más arriba, y punta afilada
	function V.pine(x, z, s)
		if useModel("Pino", x, z, s) then
			return
		end
		local y = T.height(x, z) - 0.6
		local c = pick(FIR)
		local H = 27 * s
		local layers = (H < 15) and 3 or ((H > 34) and 6 or 5)
		b:cylinder({ name = "Tronco", length = H * 0.85, diameter = math.max(0.5, 1.3 * s), pos = { x, y + H * 0.425, z }, color = BARK, mat = "Wood" })
		local spin = W.range(0, 90)
		local function whorl(yy, R, th, w, turn, shade, droop)
			for k = 0, 2 do
				local a = spin + turn + k * 120 + W.range(-14, 14)
				local r = math.rad(a)
				local len = R * W.range(0.9, 1.08)
				b:wedge({ name = "Ramas", size = { w, th, len }, pos = { x - math.sin(r) * len / 2, yy + th / 2, z - math.cos(r) * len / 2 }, rot = { -droop, a, 0 }, color = (k % 2 == 0) and shade or P.darker(shade, 7), mat = "LeafyGrass", folder = "Decoracion" })
			end
		end
		for i = 0, layers - 1 do
			local t = i / (layers - 1)
			local R = H * (0.34 - 0.25 * t) * W.range(0.92, 1.08)
			whorl(y + H * (0.16 + 0.64 * t), R, R * 0.5 + H * 0.06, R * 0.95, i * 60, P.lighter(c, math.floor(t * 14)), W.range(5, 12))
		end
		-- Punta: tres aletas finas en cruz que acaban en pico
		whorl(y + H * 0.78, H * 0.09, H * 0.21, math.max(0.35, 0.5 * s), 30, P.lighter(c, 16), 0)
	end

	-- Roble: tronco grueso, tres o cuatro ramas abiertas y matas de hojas aplastadas alrededor de cada punta
	function V.oak(x, z, s)
		if useModel("Roble", x, z, s) then
			return
		end
		local y = T.height(x, z) - 0.5
		local c = pick(OAK)
		local top = y + 7 * s
		b:cylinder({ name = "Tronco", length = 8 * s, diameter = 2.2 * s, pos = { x, y + 4 * s, z }, color = BARK_OAK, mat = "Wood" })
		local ends = { { x + W.range(-1, 1) * s, top + W.range(6.5, 8) * s, z + W.range(-1, 1) * s } }
		local nb = (W.rand() < 0.5) and 3 or 4
		local spin = W.range(0, 360)
		for k = 1, nb do
			local a = math.rad(spin + k * 360 / nb + W.range(-25, 25))
			local r = W.range(3.5, 5.5) * s
			local e = { x + math.cos(a) * r, top + W.range(3, 5) * s, z + math.sin(a) * r }
			rod("Rama", { x, top - s, z }, e, W.range(0.6, 0.9) * s, BARK_OAK, "Wood", "Decoracion")
			table.insert(ends, e)
		end
		for n, e in ipairs(ends) do
			for j = 1, (n == 1) and 3 or 2 do
				local w = W.range(5.5, 8) * s
				local shade = (j == 1) and c or ((j == 2) and P.lighter(c, 10) or P.darker(c, 10))
				b:blob({ name = "Copa", size = { w, w * W.range(0.7, 0.9), w * W.range(0.8, 1) }, pos = { e[1] + W.range(-1.6, 1.6) * s, e[2] + W.range(-0.4, 1.4) * s, e[3] + W.range(-1.6, 1.6) * s }, rot = { W.range(-15, 15), W.range(0, 180), W.range(-15, 15) }, color = shade, mat = "LeafyGrass", folder = "Decoracion" })
			end
		end
	end

	-- Abedul: tronco blanco con marcas oscuras, dos ramitas y copa alta y estrecha
	function V.birch(x, z, s)
		if useModel("Abedul", x, z, s) then
			return
		end
		local y = T.height(x, z) - 0.5
		local c = pick(BIRCH)
		local H = 17 * s
		b:cylinder({ name = "Tronco", length = H, diameter = 1.1 * s, pos = { x, y + H / 2, z }, color = { 224, 220, 208 }, mat = "Wood" })
		for k = 1, 3 do
			b:cylinder({ name = "Marca", length = 0.35 * s, diameter = 1.16 * s, pos = { x, y + (2.5 + k * 3.1) * s, z }, color = { 52, 50, 48 }, mat = "Wood", folder = "Decoracion" })
		end
		for _ = 1, 2 do
			local a = math.rad(W.range(0, 360))
			local yy = y + H * W.range(0.5, 0.7)
			rod("Rama", { x, yy, z }, { x + math.cos(a) * 3 * s, yy + 2.5 * s, z + math.sin(a) * 3 * s }, 0.4 * s, { 214, 210, 198 }, "Wood", "Decoracion")
		end
		for k = 0, 5 do
			local t = k / 5
			local w = (4.6 - 1.6 * t) * s * W.range(0.85, 1.15)
			b:blob({ name = "Copa", size = { w, w * W.range(1.1, 1.5), w * 0.9 }, pos = { x + W.range(-1.9, 1.9) * s, y + H * (0.5 + 0.48 * t), z + W.range(-1.9, 1.9) * s }, rot = { W.range(-12, 12), W.range(0, 180), W.range(-12, 12) }, color = (k % 2 == 0) and c or P.lighter(c, 10), mat = "LeafyGrass", folder = "Decoracion" })
		end
	end

	-- Árbol seco: tronco gris con la copa partida y ramas desnudas con ramitas
	function V.dead(x, z, s)
		if useModel("Muerto", x, z, s) then
			return
		end
		local y = T.height(x, z) - 0.5
		local gray = { 106, 96, 86 }
		local H = 11 * s
		b:cylinder({ name = "Tronco", length = H, diameter = 1.4 * s, pos = { x, y + H / 2, z }, color = gray, mat = "Wood" })
		local a0 = math.rad(W.range(0, 360))
		rod("Rama", { x, y + H - 0.3, z }, { x + math.cos(a0) * 1.4 * s, y + H + 3.5 * s, z + math.sin(a0) * 1.4 * s }, 0.8 * s, gray, "Wood", "Decoracion")
		for _ = 1, 3 do
			local a = math.rad(W.range(0, 360))
			local yy = y + H * W.range(0.45, 0.85)
			local r = W.range(2.6, 4) * s
			local e = { x + math.cos(a) * r, yy + W.range(2, 3.5) * s, z + math.sin(a) * r }
			rod("Rama", { x, yy, z }, e, 0.5 * s, gray, "Wood", "Decoracion")
			local a2 = a + math.rad(W.range(-50, 50))
			rod("Rama", e, { e[1] + math.cos(a2) * 1.6 * s, e[2] + 1.4 * s, e[3] + math.sin(a2) * 1.6 * s }, 0.28 * s, gray, "Wood", "Decoracion")
		end
	end

	-- =================================================================
	--  Sotobosque y plantas pequeñas
	-- =================================================================
	-- Arbusto: varias matas aplastadas de distinto tono
	function V.bush(x, z, s)
		if useModel("Arbusto", x, z, s) then
			return
		end
		local y = T.height(x, z)
		local c = pick(OAK)
		for k = 1, 4 do
			local w = W.range(2.4, 3.8) * s
			b:blob({ name = "Arbusto", size = { w, w * W.range(0.55, 0.8), w * W.range(0.7, 1) }, pos = { x + W.range(-1.5, 1.5) * s, y + w * 0.25, z + W.range(-1.5, 1.5) * s }, rot = { 0, W.range(0, 180), W.range(-10, 10) }, color = (k == 1) and c or ((k % 2 == 0) and P.lighter(c, 9) or P.darker(c, 8)), mat = "LeafyGrass", folder = "Decoracion", query = false })
		end
	end

	-- Helecho: siete frondas en cuña que salen del centro hacia arriba y hacia fuera
	function V.fern(x, z, s)
		local y = T.height(x, z) - 0.1
		local c = pick(FERN)
		local spin = W.range(0, 360)
		for k = 0, 6 do
			local a = spin + k * 360 / 7 + W.range(-12, 12)
			local r = math.rad(a)
			local len = W.range(2.4, 3.6) * s
			local up = W.range(22, 38)
			local hx, hy = math.cos(math.rad(up)) * len / 2, math.sin(math.rad(up)) * len / 2
			b:wedge({ name = "Helecho", size = { W.range(0.7, 1) * s, 0.45 * s, len }, pos = { x - math.sin(r) * hx, y + 0.25 * s + hy, z - math.cos(r) * hx }, rot = { up, a, 0 }, color = (k % 2 == 0) and c or P.lighter(c, 10), mat = "Grass", folder = "Decoracion", shadow = false, query = false })
		end
	end

	-- Mata de hierba alta: tres hojas en cuña (punta afilada) abiertas en estrella (sin colisión ni sombra)
	function V.tuft(x, z, s, dry)
		local y = T.height(x, z)
		local c = dry and GRASS[4] or pick(GRASS)
		local yaw = W.range(0, 360)
		for k = 0, 2 do
			local h = W.range(2, 4.4) * s
			local a = yaw + k * 120 + W.range(-25, 25)
			local r = math.rad(a)
			b:wedge({ name = "HierbaAlta", size = { 0.08, h, W.range(0.35, 0.7) * s }, pos = { x + math.cos(r) * 0.3, y + h / 2 - 0.3, z + math.sin(r) * 0.3 }, rot = { W.range(-18, 18), a, W.range(-14, 14) }, color = (k == 1) and P.darker(c, 9) or c, mat = "Grass", folder = "Decoracion", shadow = false, query = false })
		end
	end

	-- Juncos de orilla: tallos finos algo inclinados, dos con la espiga marrón
	function V.reeds(x, z, s)
		local y = T.height(x, z)
		for k = 1, 5 do
			local h = W.range(4, 7) * s
			local px, pz = x + W.range(-1.3, 1.3), z + W.range(-1.3, 1.3)
			local tilt, yaw = W.range(0, 10), W.range(0, 360)
			local c = pick(REED)
			b:cylinder({ name = "Junco", length = h, diameter = 0.18, pos = { px, y + h / 2 - 0.3, pz }, rot = { tilt, yaw, 0 }, color = c, mat = "Grass", folder = "Decoracion", shadow = false, query = false })
			if k <= 2 then
				-- La espiga va en la punta del tallo inclinado
				local d = h / 2 - 0.7
				local st, ct = math.sin(math.rad(tilt)), math.cos(math.rad(tilt))
				local sy, cy = math.sin(math.rad(yaw)), math.cos(math.rad(yaw))
				b:cylinder({ name = "Espiga", length = 1.3, diameter = 0.42, pos = { px + sy * d * st, y + h / 2 - 0.3 + d * ct, pz + cy * d * st }, rot = { tilt, yaw, 0 }, color = { 96, 64, 40 }, mat = "Fabric", folder = "Decoracion", shadow = false, query = false })
			end
		end
	end

	-- Tronco caído apoyado en el suelo (sigue la pendiente), con musgo encima y una rama rota
	function V.log(x, z)
		local len = W.range(10, 18)
		local a = math.rad(W.range(0, 360))
		local dx, dz = math.cos(a) * len / 2, math.sin(a) * len / 2
		local d = W.range(1.6, 2.4)
		local p1 = { x - dx, T.height(x - dx, z - dz) + d * 0.35, z - dz }
		local p2 = { x + dx, T.height(x + dx, z + dz) + d * 0.35, z + dz }
		rod("TroncoCaido", p1, p2, d, { 88, 70, 52 }, "Wood", "Mapa")
		local mid = { (p1[1] + p2[1]) / 2, (p1[2] + p2[2]) / 2, (p1[3] + p2[3]) / 2 }
		rod("Musgo", { p1[1], p1[2] + d * 0.3, p1[3] }, { mid[1], mid[2] + d * 0.3, mid[3] }, d * 0.75, { 74, 102, 56 }, "LeafyGrass", "Decoracion")
		local q = { mid[1] + dx * 0.4, mid[2] + d * 0.3, mid[3] + dz * 0.4 }
		rod("Rama", q, { q[1] - dz * 0.2, q[2] + 2.8, q[3] + dx * 0.2 }, 0.45, { 92, 74, 56 }, "Wood", "Decoracion")
	end

	-- Tocón de un árbol talado, con el corte claro arriba
	function V.stump(x, z)
		local y = T.height(x, z)
		local d, h = W.range(2, 3), W.range(1.2, 2.4)
		b:cylinder({ name = "Tocon", length = h + 0.6, diameter = d, pos = { x, y + h / 2 - 0.3, z }, color = BARK, mat = "Wood" })
		b:cylinder({ name = "Corte", length = 0.12, diameter = d * 0.86, pos = { x, y + h - 0.05, z }, color = { 158, 128, 92 }, mat = "Wood", folder = "Decoracion" })
	end

	-- Rocas: se esculpen en el terreno (ver Terreno.addBoulder); a veces en grupos de dos o tres
	function V.rock(x, z, s)
		T.addBoulder(x, z, 4.5 * s)
		for _ = 1, math.floor(W.range(0, 2.99)) do
			local a = W.range(0, 2 * math.pi)
			local d = W.range(5, 9) * s
			T.addBoulder(x + math.cos(a) * d, z + math.sin(a) * d, W.range(2.6, 3.6) * s)
		end
	end

	-- =================================================================
	--  Repartir por el mapa
	-- =================================================================
	-- Sitio libre: en tierra, fuera de zonas, carreteras y agua, y sin pendiente fuerte
	local function free(x, z, roadMargin, zoneMargin)
		local road, river, zone, coast = T.fields(x, z)
		if coast < 55 or river < 14 or road < 11 + roadMargin or zone < zoneMargin then
			return false
		end
		return true
	end

	-- Orilla de río o lago: entre "lo" (dentro del agua) y "hi" studs del borde
	local function bank(x, z, lo, hi)
		local road, river, zone, coast = T.fields(x, z)
		return river > lo and river < hi and coast > 60 and road > 14 and zone > 8
	end

	local function randomPoint()
		return W.range(-2030, 1560), W.range(-2030, 1500)
	end

	function V.buildAll(counts)
		local placed = { trees = 0, bushes = 0, ferns = 0, saplings = 0, tufts = 0, reeds = 0, logs = 0, stumps = 0, rocks = 0, riverRocks = 0 }
		-- Árboles: el bosque se espesa donde hay maleza; abetos sobre todo en el norte y en las alturas
		local tries = 0
		while placed.trees < counts.trees and tries < counts.trees * 10 do
			tries = tries + 1
			local x, z = randomPoint()
			if free(x, z, 9, 14) then
				local veg = T.veg(x, z)
				local density = 0.04 + 0.9 * math.max(0, math.min(1, (veg + 0.2) / 0.45))
				if W.rand() < density then
					local surf, h = T.surface(x, z)
					if surf ~= "Rock" and surf ~= "Snow" and surf ~= "Sand" and h < 150 then
						local r = W.rand()
						local _, river = T.fields(x, z)
						if r < 0.07 then
							V.dead(x, z, W.range(0.9, 1.3))
						elseif (z < -1100 or h > 45) and r < 0.88 or r < 0.62 then
							V.pine(x, z, W.range(0.85, 1.5))
						elseif river < 60 and r < 0.85 then
							V.birch(x, z, W.range(0.9, 1.3))
						else
							V.oak(x, z, W.range(0.9, 1.4))
						end
						placed.trees = placed.trees + 1
					end
				end
			end
		end
		-- Sotobosque: helechos y abetos jóvenes bajo los árboles; arbustos en los claros y bordes
		tries = 0
		while placed.bushes + placed.ferns + placed.saplings < counts.bushes and tries < counts.bushes * 10 do
			tries = tries + 1
			local x, z = randomPoint()
			if free(x, z, 4, 8) then
				local veg = T.veg(x, z)
				if veg > -0.15 and W.rand() < 0.7 then
					local surf, h = T.surface(x, z)
					if (surf == "Grass" or surf == "LeafyGrass") and h < 150 then
						local r = W.rand()
						local dense = veg > 0.15
						if (dense and r < 0.6) or (not dense and r < 0.2) then
							V.fern(x, z, W.range(0.8, 1.3))
							placed.ferns = placed.ferns + 1
						elseif (dense and r < 0.85) or (not dense and r < 0.4) then
							V.pine(x, z, W.range(0.3, 0.5))
							placed.saplings = placed.saplings + 1
						else
							V.bush(x, z, W.range(0.8, 1.5))
							placed.bushes = placed.bushes + 1
						end
					end
				end
			end
		end
		-- Hierba alta en grupos, sobre todo donde hay maleza
		tries = 0
		while placed.tufts < counts.tufts and tries < counts.tufts * 4 do
			tries = tries + 1
			local cx, cz = randomPoint()
			if free(cx, cz, 2, 4) then
				local surf = T.surface(cx, cz)
				if surf == "LeafyGrass" or (surf == "Grass" and W.rand() < 0.3) then
					local dry = W.rand() < 0.25
					for _ = 1, math.floor(W.range(3, 7)) do
						local x, z = cx + W.range(-6, 6), cz + W.range(-6, 6)
						if free(x, z, 1, 3) then
							V.tuft(x, z, W.range(0.8, 1.3), dry)
							placed.tufts = placed.tufts + 1
						end
					end
				end
			end
		end
		-- Juncos en las orillas (en grupos a lo largo del borde) y rocas en el agua poco profunda
		tries = 0
		while placed.reeds < counts.reeds and tries < counts.reeds * 300 do
			tries = tries + 1
			local cx, cz = randomPoint()
			if bank(cx, cz, -1.5, 6) then
				for _ = 1, math.floor(W.range(2, 5)) do
					local x, z = cx + W.range(-7, 7), cz + W.range(-7, 7)
					if placed.reeds < counts.reeds and bank(x, z, -1.5, 6) then
						V.reeds(x, z, W.range(0.8, 1.2))
						placed.reeds = placed.reeds + 1
					end
				end
			end
		end
		tries = 0
		while placed.riverRocks < counts.riverRocks and tries < counts.riverRocks * 300 do
			tries = tries + 1
			local x, z = randomPoint()
			if bank(x, z, -4, 8) then
				T.addBoulder(x, z, W.range(3, 5.5))
				placed.riverRocks = placed.riverRocks + 1
			end
		end
		-- Troncos caídos y tocones en el bosque
		tries = 0
		while placed.logs < counts.logs and tries < counts.logs * 20 do
			tries = tries + 1
			local x, z = randomPoint()
			if free(x, z, 6, 10) and T.veg(x, z) > 0.15 then
				local surf = T.surface(x, z)
				if surf == "LeafyGrass" or surf == "Grass" then
					V.log(x, z)
					placed.logs = placed.logs + 1
				end
			end
		end
		tries = 0
		while placed.stumps < counts.stumps and tries < counts.stumps * 20 do
			tries = tries + 1
			local x, z = randomPoint()
			if free(x, z, 4, 8) and T.veg(x, z) > 0 then
				V.stump(x, z)
				placed.stumps = placed.stumps + 1
			end
		end
		-- Rocas: más en las colinas
		tries = 0
		while placed.rocks < counts.rocks and tries < counts.rocks * 10 do
			tries = tries + 1
			local x, z = randomPoint()
			if free(x, z, 4, 8) then
				local _, h = T.surface(x, z)
				if h > 12 or W.rand() < 0.3 then
					V.rock(x, z, W.range(0.7, 1.6))
					placed.rocks = placed.rocks + 1
				end
			end
		end
		return placed
	end

	return V
end
]=]
local ZONAS = {}
ZONAS["Antena"] = [=[
-- Antena: puesto de comunicaciones con torre de radio, antenas parabólicas, búnker y generador.
return function(b, MB, W)
	local P = MB.Props
	W.road({ { 300, -560 }, { 300, -431 } }, 16)
	W.wallRect(230, 400, -550, -445, { { "S", 288, 312 }, { "N", 288, 312 } }, function(a, c)
		P.chainFence(b, { a[1], 0, a[2] }, { c[1], 0, c[2] }, 9)
	end)
	P.radioTower(b, { 355, 0, -500 }, 120)
	for i, p in ipairs({ { 250, -470 }, { 258, -530 }, { 380, -460 } }) do
		P.satelliteDish(b, { p[1], 0, p[2] }, i * 70)
	end
	P.house(b, { 255, 0, -505 }, -90, { w = 26, h = 9, d = 20, color = { 140, 140, 132 }, mat = "Concrete", trim = { 90, 96, 90 }, floors = 1, shop = "COMUNICACIONES", shopColor = { 60, 80, 70 }, ruined = true })
	P.sandbags(b, { 278, 0, -476 }, 90, 10, 3)
	b:box({ name = "Generador", size = { 8, 5, 5 }, pos = { 330, 2.5, -465 }, color = { 80, 100, 80 }, mat = "Metal" })
	b:cylinder({ name = "Escape", length = 4, diameter = 0.6, pos = { 333, 7, -465 }, color = { 40, 40, 40 }, mat = "Metal", folder = "Decoracion" })
	for i, p in ipairs({ { 340, -456 }, { 343, -456 }, { 341.5, -453.4 } }) do
		P.drum(b, { p[1], 0, p[2] }, (i == 3) and { 200, 60, 40 } or { 60, 80, 60 })
	end
	for i = 0, 3 do
		P.solarPanel(b, { 370 + (i % 2) * 8, 0, -535 + math.floor(i / 2) * 8 }, 180)
	end
	for _, p in ipairs({ { 240, -540 }, { 392, -540 } }) do
		b:cylinder({ name = "Mastil", length = 30, diameter = 0.4, pos = { p[1], 15, p[2] }, color = { 200, 200, 206 }, mat = "Metal" })
	end
	P.truck(b, { 320, 0, -520 }, 0, { 84, 94, 70 })
	W.spawn(300, -470, 180)
end
]=]
ZONAS["Cantera"] = [=[
-- Cantera: gran agujero de roca en terrazas (el relieve se hace en Terreno.luau) con charca en el fondo,
-- cintas transportadoras, camiones volquete, excavadora y planta de machaqueo.
return function(b, MB, W)
	local P = MB.Props
	local q = W.quarry
	-- Altura del suelo dentro de la cantera según el radio
	local function pitY(x, z)
		local r = math.sqrt((x - q.x) ^ 2 + (z - q.z) ^ 2)
		if r < 55 then
			return -48
		elseif r < 90 then
			return -36
		elseif r < 130 then
			return -24
		elseif r < 170 then
			return -12
		end
		return 0
	end
	local function at(angle, r)
		local a = math.rad(angle)
		local x, z = q.x + math.cos(a) * r, q.z + math.sin(a) * r
		return x, pitY(x, z), z
	end

	-- Planta de machaqueo y cinta que sube desde la primera terraza
	P.house(b, { 1110, 0, -1500 }, 0, { w = 30, h = 16, d = 20, color = { 150, 150, 146 }, mat = "CorrodedMetal", trim = { 200, 160, 50 }, floors = 1, ruined = true })
	local ax, ay, az = at(129, 150)
	local a, c = { ax, ay + 2, az }, { 1118, 12, -1512 }
	P.segment(b, a, c, 2.4, { 60, 60, 62 }, "Rubber")
	for i = 1, 3 do
		local t = i / 4
		local x, z = a[1] + (c[1] - a[1]) * t, a[3] + (c[3] - a[3]) * t
		local y = a[2] + (c[2] - a[2]) * t
		local g = pitY(x, z)
		b:box({ name = "Pata", size = { 1, y - g, 1 }, pos = { x, (y + g) / 2, z }, color = { 200, 160, 50 }, mat = "Metal" })
	end
	-- Montones de grava
	for i, p in ipairs({ { 1080, -1560 }, { 1095, -1590 }, { 1420, -1560 } }) do
		for k, d in ipairs({ 22, 15, 8 }) do
			b:cylinder({ name = "Grava", length = 4, diameter = d, pos = { p[1], 2 + (k - 1) * 4, p[2] }, color = (i % 2 == 0) and { 150, 146, 138 } or { 170, 160, 140 }, mat = "Pebble" })
		end
	end
	-- Camiones volquete en las terrazas y excavadora en el fondo
	for _, t in ipairs({ { 30, 110 }, { 200, 150 }, { 300, 72 } }) do
		local x, y, z = at(t[1], t[2])
		P.truck(b, { x, y, z }, -t[1], { 230, 180, 40 })
	end
	local ex, ey, ez = at(160, 46)
	local exc = b:at({ ex, ey, ez }, 30)
	for _, side in ipairs({ -1, 1 }) do
		exc:box({ name = "Oruga", size = { 2.4, 2.4, 12 }, pos = { side * 3.4, 1.2, 0 }, color = { 40, 40, 42 }, mat = "Rubber" })
	end
	exc:box({ name = "Cuerpo", size = { 8, 5, 9 }, pos = { 0, 5, 1 }, color = { 230, 180, 40 }, mat = "Metal" })
	exc:box({ name = "Cabina", size = { 3.4, 4, 3.4 }, pos = { -2, 9, -1.4 }, color = { 50, 60, 66 }, mat = "Glass", transparency = 0.3 })
	P.segment(exc, { 1.6, 7, -3 }, { 1.6, 14, -11 }, 1.4, { 230, 180, 40 }, "Metal")
	P.segment(exc, { 1.6, 14, -11 }, { 1.6, 4, -16 }, 1.2, { 230, 180, 40 }, "Metal")
	exc:box({ name = "Pala", size = { 3, 2.4, 2.4 }, pos = { 1.6, 3, -16.4 }, color = { 90, 90, 90 }, mat = "Metal" })
	-- Rocas sueltas, valla del borde y caseta
	for i = 0, 9 do
		local x, y, z = at(i * 36 + 10, 60 + (i % 4) * 35)
		b:ball({ name = "Roca", diameter = 4 + (i % 3) * 2, pos = { x, y + 1, z }, color = { 120, 118, 112 }, mat = "Rock" })
	end
	for i = 0, 11 do
		if i ~= 3 and i ~= 4 then
			local a1, a2 = math.rad(i * 30), math.rad((i + 1) * 30)
			W.fence({ q.x + math.cos(a1) * 198, q.z + math.sin(a1) * 198 }, { q.x + math.cos(a2) * 198, q.z + math.sin(a2) * 198 }, 4, { 200, 160, 50 })
		end
	end
	P.container(b, { 1160, 0, -1490 }, 0, { 240, 240, 236 }, false, "OFICINA")
	P.poster(b, { 1085, 6, -1525 }, -120, { 12, 3 }, { 240, 200, 40 }, "PELIGRO · CANTERA", { 30, 30, 30 }, "GothamBlack")
end
]=]
ZONAS["Ciudadela"] = [=[
-- Ciudadela: barrio residencial amurallado donde viven supervivientes. Tiene luz, huertos,
-- placas solares, iglesia, torres de vigilancia y casas (algunas se pueden recorrer).
return function(b, MB, W)
	local P = MB.Props
	local x0, x1, z0, z1 = -420, 80, 700, 1150
	local COLORS = { { 220, 210, 190 }, { 180, 196, 210 }, { 210, 186, 160 }, { 196, 210, 180 }, { 230, 224, 214 }, { 200, 180, 196 } }

	W.wallRect(x0, x1, z0, z1, { { "N", -276, -244 }, { "O", 904, 936 }, { "E", 904, 936 } }, function(a, c)
		P.metalWall(b, { a[1], 0, a[2] }, { c[1], 0, c[2] }, 14)
	end)
	for _, t in ipairs({ { x0 + 8, z0 + 8 }, { x1 - 8, z0 + 8 }, { x0 + 8, z1 - 8 }, { x1 - 8, z1 - 8 }, { -232, z0 + 10 }, { x0 + 10, 950 }, { x1 - 10, 890 } }) do
		P.watchTower(b, { t[1], 0, t[2] }, 0, 16)
	end
	P.poster(b, { -260, 12, z0 - 1.2 }, 0, { 30, 4 }, { 60, 70, 60 }, "CIUDADELA", { 236, 230, 200 }, "GothamBlack")

	-- Calles
	W.road({ { x0 - 10, 920 }, { x1 + 10, 920 } }, 20)
	W.road({ { -260, z0 - 10 }, { -260, z1 } }, 18)
	for _, p in ipairs({ { -330, 909 }, { -150, 909 }, { 0, 931 }, { -272, 800 }, { -248, 1060 } }) do
		P.streetLight(b, { p[1], 0, p[2] }, 0, 14)
	end

	-- Casas a lo largo de las calles (las de openHouse se pueden recorrer)
	local i = 0
	local function home(x, z, yaw)
		i = i + 1
		local color = COLORS[(i % #COLORS) + 1]
		if i % 3 == 1 then
			P.openHouse(b, { x, 0, z }, yaw, { color = color, trim = { 248, 246, 240 }, roofColor = { 80, 76, 74 } })
		else
			P.house(b, { x, 0, z }, yaw, { w = 24, h = 16, d = 16, color = color, trim = { 248, 246, 240 }, roof = "gable", roofColor = { 80, 76, 74 }, roofMat = "RoofShingles", floors = 2, lit = true })
		end
	end
	for _, x in ipairs({ -390, -340, -200, -150, -100, -50, 0, 50 }) do
		home(x, 894, 180)
		home(x, 946, 0)
	end
	for _, z in ipairs({ 760, 820, 1030, 1090 }) do
		home(-292, z, -90)
		home(-228, z, 90)
	end

	-- Iglesia, huertos, placas solares, invernadero y obras de ampliación de la muralla
	P.house(b, { -60, 0, 780 }, 0, { w = 24, h = 16, d = 36, color = { 236, 230, 220 }, trim = { 120, 100, 80 }, roof = "gable", roofColor = { 90, 70, 60 }, floors = 1, cols = 3, lit = true })
	P.bellTower(b, { -60, 0, 760 }, 0, 26, { 236, 230, 220 }, { 90, 70, 60 })
	for k = 0, 9 do
		P.gardenBed(b, { -200 + (k % 5) * 16, 0, 740 + math.floor(k / 5) * 10 }, 0, 12, 5)
	end
	for k = 0, 11 do
		P.solarPanel(b, { 20 + (k % 4) * 9, 0, 1000 + math.floor(k / 4) * 9 }, 180)
	end
	b:box({ name = "Invernadero", size = { 30, 8, 14 }, pos = { -120, 4, 1050 }, color = { 200, 220, 210 }, mat = "Glass", transparency = 0.5 })
	for k = 0, 3 do
		P.gardenBed(b, { -130 + k * 7, 0, 1050 }, 90, 12, 3)
	end
	P.waterTank(b, { -380, 0, 1110 })
	P.crate(b, { -360, 0, 760 }, 5, 10)
	P.pallet(b, { -350, 0, 770 }, 20)
	b:box({ name = "Chapas", size = { 10, 2, 8 }, pos = { -370, 1, 780 }, color = { 120, 90, 70 }, mat = "CorrodedMetal" })
	P.campfire(b, { -150, 0, 1100 }, true)
	P.fireBarrel(b, { -141, 0, 1093 })
	P.tiendaCaza(b, { -152, 0, 1119 }, 0, "Tienda de caza de la Ciudadela")
	for k = 0, 3 do
		P.bench(b, { -170 + k * 9, 0, 1090 }, 0, { 120, 90, 60 })
	end
	W.spawn(-240, 920, 90)
	W.spawn(-100, 920, -90)
end
]=]
ZONAS["ColinaAlta"] = [=[
-- Colina Alta: comunidad en lo alto de una meseta, con empalizada, mansión, huertos, herrería y caravanas.
return function(b, MB, W)
	local P = MB.Props
	local p = W.plateau
	local cx, cz, y = p.x, p.z, p.top
	-- Empalizada octogonal con puertas al oeste y al sur
	for k = 0, 7 do
		local a1, a2 = math.rad(22.5 + k * 45), math.rad(67.5 + k * 45)
		local A = { cx + math.cos(a1) * 110, y, cz + math.sin(a1) * 110 }
		local C = { cx + math.cos(a2) * 110, y, cz + math.sin(a2) * 110 }
		local center = (45 + k * 45) % 360
		if center == 180 or center == 90 then
			local mx, mz = (A[1] + C[1]) / 2, (A[3] + C[3]) / 2
			local dx, dz = C[1] - A[1], C[3] - A[3]
			local len = math.sqrt(dx * dx + dz * dz)
			local ux, uz = dx / len, dz / len
			P.plankWall(b, A, { mx - ux * 9, y, mz - uz * 9 }, 10)
			P.plankWall(b, { mx + ux * 9, y, mz + uz * 9 }, C, 10)
		else
			P.plankWall(b, A, C, 10)
		end
	end
	P.watchTower(b, { cx - 92, y, cz + 22 }, 90, 12)
	P.watchTower(b, { cx + 20, y, cz + 92 }, 0, 12)

	-- Mansión con porche de columnas mirando a la puerta oeste
	P.house(b, { cx + 22, y, cz }, 90, { w = 44, h = 26, d = 28, floors = 3, color = { 236, 232, 222 }, trim = { 120, 110, 100 }, roof = "gable", roofColor = { 70, 66, 64 }, roofMat = "Slate", shutters = { 60, 70, 60 }, lit = true })
	for _, dz in ipairs({ -15, -5, 5, 15 }) do
		P.column(b, { cx + 3, y, cz + dz }, 16, 1.6, { 240, 236, 228 }, "Plaster")
	end
	b:box({ name = "Porche", size = { 6, 1, 36 }, pos = { cx + 4, y + 19.2, cz }, color = { 236, 232, 222 }, mat = "Plaster" })
	P.stairs(b, { cx - 4, y, cz }, 90, 2, 0.6, 1.4, 14, { 200, 196, 190 })

	-- Huertos, herrería, caravanas, tiendas, pozo y corral
	for i = 0, 7 do
		P.gardenBed(b, { cx - 60 + (i % 4) * 16, y, cz + 40 + math.floor(i / 4) * 12 }, 0, 12, 5)
	end
	local fx, fz = cx - 40, cz - 60
	b:box({ name = "Forja", size = { 8, 4, 6 }, pos = { fx, y + 2, fz }, color = { 90, 80, 74 }, mat = "Brick" })
	b:cylinder({ name = "Chimenea", length = 12, diameter = 2, pos = { fx + 2, y + 10, fz }, color = { 90, 80, 74 }, mat = "Brick" })
	local fire = b:box({ name = "Brasas", size = { 4, 0.6, 3 }, pos = { fx - 1, y + 4.3, fz }, color = { 255, 120, 40 }, mat = "Neon", folder = "Decoracion" })
	MB.fire(fire, { size = 3, smoke = false, range = 16, brightness = 1.5 })
	b:box({ name = "Yunque", size = { 2.4, 2, 1.2 }, pos = { fx - 8, y + 1, fz + 2 }, color = { 50, 50, 54 }, mat = "Metal" })
	b:box({ name = "Tejadillo", size = { 16, 0.6, 12 }, pos = { fx - 3, y + 9, fz + 1 }, color = { 100, 80, 60 }, mat = "WoodPlanks", folder = "Decoracion" })
	for i, t in ipairs({ { cx - 10, cz - 80 }, { cx + 15, cz - 84 }, { cx + 40, cz - 76 } }) do
		b:box({ name = "Caravana", size = { 16, 7, 7 }, pos = { t[1], y + 4, t[2] }, rot = { 0, i * 12, 0 }, color = { 236, 230, 214 }, mat = "Metal" })
		b:box({ name = "Franja", size = { 16.1, 1, 7.1 }, pos = { t[1], y + 4, t[2] }, rot = { 0, i * 12, 0 }, color = ({ { 160, 80, 50 }, { 70, 110, 140 }, { 90, 120, 70 } })[i], folder = "Decoracion" })
	end
	for i, t in ipairs({ { cx - 70, cz - 20 }, { cx - 76, cz - 40 } }) do
		P.tent(b, { t[1], y, t[2] }, 90, { 120, 110, 86 })
	end
	P.campfire(b, { cx - 55, y, cz - 30 }, true)
	b:cylinder({ name = "Pozo", length = 3, diameter = 5, pos = { cx - 30, y + 1.5, cz + 10 }, color = { 130, 126, 120 }, mat = "Cobblestone" })
	b:wedge({ name = "Tejadillo", size = { 6, 2, 3 }, pos = { cx - 30, y + 7, cz + 8.5 }, color = { 100, 80, 60 }, mat = "WoodPlanks", folder = "Decoracion" })
	b:wedge({ name = "Tejadillo", size = { 6, 2, 3 }, pos = { cx - 30, y + 7, cz + 11.5 }, rot = { 0, 180, 0 }, color = { 100, 80, 60 }, mat = "WoodPlanks", folder = "Decoracion" })
	local pen = { { cx + 50, cz + 40 }, { cx + 80, cz + 40 }, { cx + 80, cz + 70 }, { cx + 50, cz + 70 }, { cx + 50, cz + 40 } }
	for i = 1, 4 do
		W.fence(pen[i], pen[i + 1], 4, nil, y)
	end
	W.spawn(cx - 30, cz - 10, -90)
end
]=]
ZONAS["Comisaria"] = [=[
-- Comisaría junto a la carretera: edificio en el que se puede entrar, coches patrulla y barricadas.
return function(b, MB, W)
	local P = MB.Props
	-- La carretera pasa por x ≈ -1395: la comisaría queda al oeste mirando a la carretera
	P.openHouse(b, { -1440, 0, -70 }, -90, { w = 40, d = 24, color = { 120, 130, 150 }, trim = { 230, 230, 226 }, roofColor = { 60, 64, 72 }, floor = { 140, 140, 136 }, sofa = { 60, 70, 90 }, ruined = true })
	P.poster(b, { -1427.3, 15.6, -70 }, -90, { 18, 2.6 }, { 30, 50, 100 }, "COMISARÍA", { 240, 240, 240 }, "GothamBlack")
	P.house(b, { -1460, 0, -132 }, 0, { w = 30, h = 10, d = 20, color = { 110, 118, 130 }, trim = { 220, 220, 216 }, floors = 1, ruined = true })
	W.parking(-1380, -1306, -140, -10)
	W.policeCar(-1360, 0.2, -110, 90)
	W.policeCar(-1340, 0.2, -60, 75)
	W.policeCar(-1325, 0.2, -30, 100)
	P.car(b, { -1350, 0.2, -130 }, 90, { 90, 96, 100 }, true)
	for _, z in ipairs({ -150, 10 }) do
		P.barrier(b, { -1395, 0.2, z }, 0)
		P.sandbags(b, { -1420, 0, z }, 90, 8, 3)
	end
	P.debris(b, { -1415, 0, -96 }, 1)
	P.dumpster(b, { -1462, 0, -108 }, 90, { 50, 80, 70 })
	W.spawn(-1370, -80, 90)
end
]=]
ZONAS["Condado"] = [=[
-- Ciudad del Condado: ciudad en ruinas con hospital (planta baja recorrible), oficinas rotas,
-- gasolinera, campamento militar y un control de cuarentena amurallado en la entrada sur.
return function(b, MB, W)
	local P = MB.Props
	local AVENUES = { -1260, -1500, -1720 }
	local STREETS = { 360, 520, 680, 840 }
	local OLIVE = { 84, 94, 70 }
	local SHOPS = {
		{ w = 22, h = 14, color = { 176, 150, 120 }, mat = "Brick", trim = { 236, 226, 210 }, shop = "FARMACIA", shopColor = { 40, 120, 70 }, ruined = true },
		{ w = 20, h = 16, color = { 150, 160, 170 }, trim = { 90, 96, 104 }, shop = "LIBRERÍA", shopColor = { 90, 60, 50 }, ruined = true },
		{ w = 24, h = 12, color = { 196, 186, 160 }, trim = { 120, 90, 60 }, shop = "CAFETERÍA", shopColor = { 110, 70, 40 }, ruined = true },
		{ w = 22, h = 18, color = { 160, 110, 90 }, mat = "Brick", trim = { 236, 226, 210 }, shop = "ARMERÍA", shopColor = { 50, 50, 56 }, ruined = true },
	}
	local APTS = {
		{ w = 34, h = 30, color = { 170, 120, 96 }, mat = "Brick", trim = { 230, 224, 210 }, fireEscape = true, ruined = true },
		{ w = 30, h = 24, color = { 150, 146, 140 }, mat = "Concrete", trim = { 100, 100, 104 }, fireEscape = true, ruined = true },
		{ w = 36, h = 34, color = { 186, 150, 120 }, mat = "Brick", trim = { 236, 230, 220 }, fireEscape = true, ruined = true },
	}
	local OFFICES = {
		{ w = 40, h = 48, color = { 130, 140, 150 }, mat = "Concrete", trim = { 80, 86, 96 }, ruined = true },
		{ w = 36, h = 56, color = { 170, 166, 156 }, mat = "Concrete", trim = { 110, 106, 100 }, ruined = true },
		{ w = 40, h = 40, color = { 120, 126, 136 }, mat = "Concrete", trim = { 70, 76, 86 }, ruined = true },
	}
	local SMALL = {
		{ w = 20, h = 12, color = { 196, 176, 150 }, trim = { 110, 80, 60 }, roof = "gable", roofColor = { 80, 70, 64 }, roofMat = "RoofShingles", ruined = true },
		{ w = 18, h = 10, color = { 160, 170, 160 }, trim = { 236, 232, 222 }, roof = "gable", roofColor = { 90, 80, 76 }, roofMat = "RoofShingles", ruined = true },
	}

	-- Calles
	for _, z in ipairs(AVENUES) do
		W.road({ { 300, z }, { 990, z } }, 22)
	end
	for _, x in ipairs(STREETS) do
		W.road({ { x, -1780 }, { x, (x == 520) and -1180 or -1215 } }, 22)
	end

	-- Aceras y suelo pavimentado en las manzanas (la plaza tiene el suyo)
	local XB = { { 300, 349 }, { 371, 509 }, { 531, 669 }, { 691, 829 }, { 851, 990 } }
	local ZB = { { -1790, -1731 }, { -1709, -1511 }, { -1489, -1271 }, { -1249, -1210 } }
	for _, xb in ipairs(XB) do
		for _, zb in ipairs(ZB) do
			if not (xb[1] == 531 and zb[1] == -1709) then
				b:box({ name = "Acera", size = { xb[2] - xb[1], 0.3, zb[2] - zb[1] }, pos = { (xb[1] + xb[2]) / 2, 0.15, (zb[1] + zb[2]) / 2 }, color = { 146, 142, 136 }, mat = "Pavement" })
			end
		end
	end

	-- Bordes rotos en lo alto de un edificio
	local function brokenTop(x, z, w, d, h, yaw)
		local g = b:at({ x, h, z }, yaw)
		for k, s in ipairs({ { -0.3, 0.4, 6 }, { 0.1, 0.5, 3 }, { 0.35, 0.3, 8 } }) do
			g:box({ name = "Ruina", size = { w * 0.3, s[3], d * s[2] }, pos = { w * s[1], s[3] / 2, (k - 2) * d * 0.2 }, color = { 140, 136, 130 }, mat = "Concrete" })
		end
	end

	-- =================================================================
	--  Hospital (x 385..495, z -1420..-1300): planta baja abierta y plantas altas
	-- =================================================================
	local hx0, hx1, hz0, hz1, H = 385, 495, -1420, -1300, 10
	local HW = { 220, 220, 214 }
	b:box({ name = "Suelo", size = { hx1 - hx0, 0.4, hz1 - hz0 }, pos = { (hx0 + hx1) / 2, 0.2, (hz0 + hz1) / 2 }, color = { 200, 204, 200 }, mat = "Marble" })
	P.wallWithHoles(b, hx0, hx1, hz1 - 0.75, 0, H, 1.5, { { 425, 455, 0, 8 }, { 395, 415, 3, 7 }, { 465, 485, 3, 7 } }, HW, "Concrete")
	P.wallWithHoles(b, hx0, hx1, hz0 + 0.75, 0, H, 1.5, { { 430, 450, 0, 8 } }, HW, "Concrete")
	for _, x in ipairs({ hx0 + 0.75, hx1 - 0.75 }) do
		P.wallWithHolesZ(b, hz0 + 1.5, hz1 - 1.5, x, 0, H, 1.5, { { -1370, -1350, 0, 8 } }, HW, "Concrete")
	end
	b:box({ name = "Plantas", size = { hx1 - hx0, 30, hz1 - hz0 }, pos = { (hx0 + hx1) / 2, H + 15, (hz0 + hz1) / 2 }, color = HW, mat = "Concrete" })
	for f = 0, 3 do
		for k = 0, 9 do
			b:box({ name = "Ventana", size = { 6, 4, 0.3 }, pos = { hx0 + 8 + k * 10.5, H + 4 + f * 7, hz1 + 0.1 }, color = { 40, 46, 50 }, mat = "Glass", folder = "Decoracion" })
		end
	end
	P.overgrowth(b:at({ (hx0 + hx1) / 2, 0, hz1 }, 180), hx1 - hx0, H + 30, -0.3)
	local sign = b:box({ name = "Rotulo", size = { 40, 5, 0.4 }, pos = { 440, H + 31, hz1 + 0.4 }, color = HW, folder = "Decoracion" })
	MB.sign(sign, "HOSPITAL", { face = "Back", font = "GothamBlack", color = { 180, 40, 40 } })
	b:box({ name = "Cruz", size = { 8, 2.4, 0.5 }, pos = { 476, H + 31, hz1 + 0.4 }, color = { 200, 40, 40 }, folder = "Decoracion" })
	b:box({ name = "Cruz", size = { 2.4, 8, 0.5 }, pos = { 476, H + 31, hz1 + 0.4 }, color = { 200, 40, 40 }, folder = "Decoracion" })
	b:cylinder({ name = "Helipuerto", length = 0.3, diameter = 30, pos = { 440, H + 30.2, -1360 }, color = { 70, 74, 78 }, mat = "Concrete" })
	-- Recepción, camas, cortinas y escombros
	b:box({ name = "Recepcion", size = { 16, 3.4, 3 }, pos = { 440, 2.1, -1318 }, color = { 180, 190, 200 }, mat = "Marble" })
	for row = 0, 1 do
		for k = 0, 5 do
			local x, z = 400 + k * 14, -1345 - row * 40
			b:box({ name = "Cama", size = { 4, 2, 7 }, pos = { x, 1.4, z }, rot = { 0, (k % 3) * 8, 0 }, color = { 230, 230, 226 }, mat = "Fabric" })
			b:box({ name = "Cortina", size = { 0.2, 7, 8 }, pos = { x + 5, 3.9, z }, color = { 140, 180, 170 }, mat = "Fabric", transparency = 0.2, folder = "Decoracion" })
		end
	end
	for x = 405, 475, 35 do
		for _, z in ipairs({ -1330, -1390 }) do
			b:box({ name = "Pilar", size = { 1.6, H, 1.6 }, pos = { x, H / 2, z }, color = HW, mat = "Concrete" })
		end
	end
	P.debris(b, { 470, 0.4, -1400 }, 1.6)
	for k, x in ipairs({ 410, 470 }) do
		local amb = P.truck(b, { x, 0.2, -1285 }, 90 + k * 8, { 236, 236, 232 })
		MB.sign(amb, "AMBULANCIA", { face = "Left", font = "GothamBlack", color = { 200, 40, 40 }, height = 0.3 })
	end

	-- =================================================================
	--  Tiendas, gasolinera, apartamentos, oficinas, campamento y almacenes
	-- =================================================================
	P.houseRow(b, -1279, 180, 531, 669, SHOPS, 16)
	P.houseRow(b, -1481, 0, 531, 669, SHOPS, 16)
	P.houseRow(b, -1281, 180, 851, 990, APTS, 20)
	P.houseRow(b, -1479, 0, 851, 990, APTS, 20)
	P.houseRow(b, -1521, 180, 371, 509, OFFICES, 20)
	P.houseRow(b, -1699, 0, 371, 509, OFFICES, 20)
	brokenTop(391, -1521, 40, 20, 48, 180)
	brokenTop(489, -1699, 40, 20, 40, 0)
	P.houseRow(b, -1521, 180, 691, 829, APTS, 20)
	P.houseRow(b, -1699, 0, 691, 829, APTS, 20)
	for _, r in ipairs({ { 371, 509 }, { 531, 669 }, { 691, 829 }, { 851, 980 } }) do
		P.houseRow(b, -1738, 180, r[1], r[2], SMALL, 14)
	end
	-- Edificio derrumbado
	for k, d in ipairs({ { 740, -1610, 3 }, { 770, -1590, 2.4 }, { 720, -1580, 2 } }) do
		P.debris(b, { d[1], 0, d[2] }, d[3])
	end
	b:box({ name = "Forjado", size = { 40, 2, 24 }, pos = { 760, 10, -1610 }, rot = { 0, 15, 24 }, color = { 150, 146, 140 }, mat = "Concrete" })

	-- Gasolinera
	for _, x in ipairs({ 742, 778 }) do
		for _, z in ipairs({ -1395, -1365 }) do
			b:box({ name = "Pilar", size = { 1.4, 10, 1.4 }, pos = { x, 5, z }, color = { 220, 220, 226 }, mat = "Metal" })
		end
	end
	b:box({ name = "Marquesina", size = { 46, 1.4, 38 }, pos = { 760, 10.7, -1380 }, rot = { 4, 0, 3 }, color = { 226, 226, 230 }, mat = "Metal" })
	for _, x in ipairs({ 750, 770 }) do
		P.pump(b, { x, 0, -1380 }, 0)
	end
	P.house(b, { 760, 0, -1460 }, 180, { w = 34, h = 10, d = 14, color = { 236, 236, 230 }, trim = { 40, 120, 70 }, floors = 1, shop = "24 HORAS", shopColor = { 40, 120, 70 }, ruined = true })
	P.pricePylon(b, { 820, 0, -1285 }, 0, "GAS", { 40, 120, 70 })
	P.car(b, { 745, 0.2, -1350 }, 10, { 40, 40, 42 }, true)

	-- Plaza con campamento militar
	b:box({ name = "Plaza", size = { 138, 0.4, 198 }, pos = { 600, 0.2, -1610 }, color = { 150, 146, 138 }, mat = "Pavement" })
	P.fountain(b, { 600, 0.4, -1610 }, 8)
	for k = 0, 5 do
		P.tent(b, { 550 + (k % 3) * 50, 0.4, -1660 + math.floor(k / 3) * 100 }, 0, OLIVE, 16, 10, 7)
	end
	P.truck(b, { 640, 0.4, -1560 }, 90, OLIVE)
	P.truck(b, { 560, 0.4, -1570 }, 80, OLIVE)
	for k = 0, 3 do
		local a = math.rad(k * 90 + 45)
		P.sandbags(b, { 600 + math.cos(a) * 26, 0.4, -1610 + math.sin(a) * 26 }, -k * 90 - 45 + 90, 12, 3)
	end
	P.floodLight(b, { 540, 0.4, -1530 }, 160, 16)
	P.floodLight(b, { 660, 0.4, -1690 }, -20, 16)
	P.container(b, { 640, 0.4, -1690 }, 0, OLIVE, true)

	-- Almacenes
	P.house(b, { 920, 0, -1560 }, 180, { w = 110, h = 16, d = 40, color = { 130, 136, 140 }, mat = "CorrodedMetal", trim = { 80, 86, 90 }, floors = 1, ruined = true })
	P.house(b, { 920, 0, -1665 }, 0, { w = 110, h = 14, d = 36, color = { 150, 120, 100 }, mat = "Brick", trim = { 90, 80, 70 }, floors = 1, ruined = true })
	P.container(b, { 900, 0, -1610 }, 0, { 176, 60, 46 }, false)
	P.forklift(b, { 940, 0, -1606 }, 30, { 240, 190, 40 })

	-- =================================================================
	--  Control de cuarentena en la entrada sur
	-- =================================================================
	W.wallRect(300, 990, -1205, -1195, { { "N", 504, 536 }, { "S", 504, 536 } }, function(a, c)
		if math.abs(a[2] - c[2]) < 1 and a[2] < -1200 then
			P.metalWall(b, { a[1], 0, a[2] }, { c[1], 0, c[2] }, 14, { { 110, 116, 104 }, { 96, 100, 94 }, { 120, 110, 90 } })
		end
	end)
	P.poster(b, { 470, 11, -1206.4 }, 180, { 40, 4 }, { 240, 200, 40 }, "ZONA DE CUARENTENA · CONTROL MILITAR", { 30, 30, 30 }, "GothamBlack")
	for _, x in ipairs({ 490, 550 }) do
		P.watchTower(b, { x, 0, -1225 }, 0, 16)
	end
	for _, x in ipairs({ 470, 570 }) do
		P.sandbags(b, { x, 0, -1235 }, 0, 14, 3)
	end
	P.truck(b, { 600, 0, -1230 }, 90, OLIVE)
	b:box({ name = "Barrera", size = { 30, 0.6, 0.6 }, pos = { 520, 4, -1190 }, color = { 220, 60, 50 }, mat = "Metal" })
	P.floodLight(b, { 440, 0, -1222 }, 180, 14)

	-- Coches, autobús volcado, barreras y árboles que crecen entre las ruinas
	local RUST = { { 120, 70, 50 }, { 90, 96, 100 }, { 140, 120, 90 }, { 60, 70, 90 }, { 40, 40, 42 } }
	for k, c in ipairs({ { 420, -1262, 80 }, { 600, -1255, 100 }, { 760, -1505, 85 }, { 900, -1495, 95 }, { 362, -1600, 10 }, { 678, -1650, 170 }, { 842, -1350, 5 }, { 470, -1722, 92 }, { 522, -1420, 20 }, { 610, -1718, 70 } }) do
		P.car(b, { c[1], 0.2, c[2] }, c[3], RUST[(k % #RUST) + 1], true)
	end
	P.bus(b, { 700, 0.2, -1720 }, 60, { 200, 170, 60 }, "LÍNEA 3")
	for _, p in ipairs({ { 360, -1500 }, { 680, -1260 }, { 840, -1720 } }) do
		P.barrier(b, { p[1], 0.2, p[2] }, 45)
	end
	for k, t in ipairs({ { 320, -1300 }, { 330, -1450 }, { 325, -1650 }, { 600, -1380 }, { 620, -1420 }, { 900, -1380 }, { 940, -1390 }, { 440, -1600 }, { 800, -1640 }, { 330, -1760 } }) do
		W.tree(t[1], t[2], (k % 3 == 0) and "muerto" or "roble", 1.2)
	end
	W.spawn(520, -1230, 180)
	W.spawn(600, -1600, 0)
end
]=]
ZONAS["Estacion"] = [=[
-- Estación Término: final de la vía del tren con andén cubierto, estación (se puede entrar),
-- vagones abandonados en las vías muertas, almacén y depósito de agua.
return function(b, MB, W)
	local P = MB.Props
	-- Andén y marquesina (parte hundida)
	b:box({ name = "Anden", size = { 14, 3, 220 }, pos = { -316, 1.5, -420 }, color = { 150, 146, 138 }, mat = "Concrete" })
	b:box({ name = "Borde", size = { 1, 3.05, 220 }, pos = { -322.6, 1.5, -420 }, color = { 230, 200, 60 }, folder = "Decoracion" })
	for z = -520, -320, 25 do
		b:box({ name = "Pilar", size = { 0.8, 10, 0.8 }, pos = { -312, 8, z }, color = { 90, 96, 90 }, mat = "Metal" })
	end
	b:box({ name = "Marquesina", size = { 16, 0.8, 120 }, pos = { -316, 13.4, -460 }, color = { 110, 116, 110 }, mat = "CorrodedMetal" })
	b:box({ name = "Marquesina", size = { 16, 0.8, 60 }, pos = { -316, 13.4, -342 }, color = { 110, 116, 110 }, mat = "CorrodedMetal" })
	b:box({ name = "Marquesina", size = { 16, 0.8, 30 }, pos = { -318, 9, -386 }, rot = { 0, 0, 28 }, color = { 110, 116, 110 }, mat = "CorrodedMetal" })
	for _, z in ipairs({ -500, -440, -380 }) do
		P.bench(b, { -310, 3, z }, 90, { 110, 90, 70 })
	end
	-- Edificio de la estación (se puede entrar)
	P.openHouse(b, { -280, 0, -420 }, 90, { w = 40, d = 24, color = { 180, 150, 120 }, trim = { 236, 226, 210 }, roofColor = { 80, 60, 50 }, ruined = true })
	P.poster(b, { -293.2, 15.6, -420 }, 90, { 26, 2.8 }, { 60, 50, 40 }, "ESTACIÓN TÉRMINO", { 236, 220, 180 }, "Garamond")

	-- Vías muertas con vagones y locomotora en la vía principal
	for _, x in ipairs({ -352, -374 }) do
		P.rails(b, { x, 0, -660 }, { x, 0, -240 }, false)
	end
	local cars = { { -352, -620, "vagon", { 130, 70, 50 } }, { -352, -588, "cisterna", { 200, 200, 196 } }, { -352, -556, "vagon", { 70, 90, 110 } },
		{ -374, -500, "plataforma", { 90, 90, 90 } }, { -374, -468, "vagon", { 150, 110, 60 } }, { -374, -436, "vagon", { 130, 70, 50 } }, { -374, -404, "cisterna", { 40, 40, 40 } } }
	for _, c in ipairs(cars) do
		P.trainCar(b, { c[1], 0.6, c[2] }, 90, c[3], c[4])
	end
	P.trainCar(b, { -330, 0.6, -640 }, 90, "locomotora", { 160, 50, 40 })
	P.trainCar(b, { -330, 0.6, -608 }, 90, "vagon", { 90, 100, 110 })
	b:box({ name = "Tope", size = { 8, 3, 2 }, pos = { -330, 1.5, -702 }, color = { 200, 50, 40 }, mat = "Metal" })

	-- Almacén, depósito de agua y campamento de supervivientes
	P.house(b, { -415, 0, -560 }, -90, { w = 80, h = 16, d = 40, color = { 140, 120, 100 }, mat = "Brick", trim = { 90, 80, 70 }, floors = 2, ruined = true })
	P.waterTank(b, { -410, 0, -440 })
	for i, t in ipairs({ { -270, -260 }, { -250, -230 }, { -290, -220 } }) do
		P.tent(b, { t[1], 0, t[2] }, i * 30, { 110, 100, 80 })
	end
	P.campfire(b, { -268, 0, -238 }, true)
	P.fireBarrel(b, { -259, 0, -246 })
	P.crate(b, { -300, 0, -300 }, 4.5, 20)
	P.crate(b, { -296, 0, -296 }, 3.5, -10)
	-- Cartel de bienvenida
	for _, x in ipairs({ -312, -288 }) do
		b:box({ name = "Poste", size = { 1, 16, 1 }, pos = { x, 8, -160 }, color = { 90, 70, 50 }, mat = "Wood" })
	end
	P.poster(b, { -300, 13, -160.6 }, 180, { 30, 5 }, { 220, 210, 180 }, "TÉRMINO · AQUÍ ESTARÁS A SALVO", { 140, 40, 30 }, "Fantasy")
	for _, z in ipairs({ -500, -400, -300 }) do
		P.streetLight(b, { -322, 3, z }, 90, 10)
	end
	W.spawn(-380, -200, 0)
end
]=]
ZONAS["Granjas"] = [=[
-- Granjas del Norte: granja con casa, granero, silos y molino, campos de cultivo y una pista de aterrizaje.
return function(b, MB, W)
	local P = MB.Props
	local DIRT = { 118, 100, 76 }

	-- Caminos de tierra entre los campos
	W.road({ { -1440, -1560 }, { -1200, -1600 }, { -900, -1640 } }, 14, DIRT, "Ground")
	W.road({ { -900, -1640 }, { -900, -1780 } }, 12, DIRT, "Ground")

	-- Campos de cultivo con valla
	local fields = {
		{ -1480, -1260, -1860, -1680, { 176, 156, 84 } },
		{ -1240, -1080, -1860, -1700, { 96, 132, 62 } },
		{ -1480, -1260, -1540, -1380, { 120, 144, 70 } },
		{ -1180, -960, -1580, -1380, { 170, 150, 80 } },
		{ -860, -720, -1580, -1380, { 104, 136, 64 } },
	}
	for _, f in ipairs(fields) do
		P.cropField(b, f[1], f[2], f[3], f[4], 0, f[5])
		W.fence({ f[1], f[3] }, { f[2], f[3] }, 4)
		W.fence({ f[1], f[4] }, { f[2], f[4] }, 4)
		W.fence({ f[1], f[3] }, { f[1], f[4] }, 4)
	end
	-- Espantapájaros, tractor y balas de paja
	for _, s in ipairs({ { -1370, -1770 }, { -1070, -1480 } }) do
		b:box({ name = "Palo", size = { 0.5, 9, 0.5 }, pos = { s[1], 4.5, s[2] }, color = { 110, 84, 60 }, mat = "Wood" })
		P.mannequin(b, { s[1], 3, s[2] }, 20, { 120, 90, 70 })
		b:box({ name = "Sombrero", size = { 2.4, 0.3, 2.4 }, pos = { s[1], 10.4, s[2] }, color = { 170, 140, 80 }, mat = "Fabric", folder = "Decoracion" })
	end
	P.tractor(b, { -1150, 0, -1790 }, 70, { 60, 120, 60 })
	for i, p in ipairs({ { -1300, -1450 }, { -1290, -1456 }, { -1100, -1500 }, { -800, -1450 }, { -820, -1470 }, { -960, -1700 } }) do
		P.hayBale(b, { p[1], 0, p[2] }, i * 37)
	end

	-- Casa de la granja (se puede entrar), granero, silos, molino y depósito de agua
	P.openHouse(b, { -840, 0, -1740 }, 180, { color = { 236, 228, 210 }, trim = { 150, 60, 50 }, roofColor = { 90, 70, 60 }, ruined = true })
	local barn = { 170, 50, 40 }
	local bx, bz = -1000, -1760
	P.wallWithHoles(b, bx - 18, bx + 18, bz - 25, 0, 16, 1, { { bx - 6, bx + 6, 0, 12 } }, barn, "WoodPlanks")
	P.wallWithHoles(b, bx - 18, bx + 18, bz + 25, 0, 16, 1, { { bx - 6, bx + 6, 0, 12 } }, barn, "WoodPlanks")
	for _, x in ipairs({ bx - 18, bx + 18 }) do
		P.wallWithHolesZ(b, bz - 24.5, bz + 24.5, x, 0, 16, 1, { { bz - 4, bz + 4, 6, 10 } }, barn, "WoodPlanks")
	end
	b:box({ name = "Suelo", size = { 36, 0.4, 50 }, pos = { bx, 0.2, bz }, color = { 120, 96, 70 }, mat = "WoodPlanks" })
	b:box({ name = "Pajar", size = { 34, 0.8, 16 }, pos = { bx, 9, bz + 16 }, color = { 120, 90, 60 }, mat = "WoodPlanks" })
	b:truss({ name = "Escalera", size = { 2, 10, 2 }, pos = { bx, 5, bz + 7 }, color = { 110, 80, 54 } })
	b:wedge({ name = "Tejado", size = { 52, 9, 19.6 }, pos = { bx - 9.8, 20.5, bz }, rot = { 0, 90, 0 }, color = { 90, 70, 60 }, mat = "CorrodedMetal" })
	b:wedge({ name = "Tejado", size = { 52, 9, 19.6 }, pos = { bx + 9.8, 20.5, bz }, rot = { 0, -90, 0 }, color = { 90, 70, 60 }, mat = "CorrodedMetal" })
	for i, p in ipairs({ { bx - 10, bz + 20 }, { bx - 6, bz + 19 }, { bx + 12, bz - 16 }, { bx - 8, bz + 16 } }) do
		P.hayBale(b, { p[1], (i == 4) and 9.4 or 0.4, p[2] }, i * 30)
	end
	P.silo(b, { -1060, 0, -1820 }, 8, 40, { 176, 178, 180 })
	P.silo(b, { -1060, 0, -1795 }, 7, 34, { 160, 150, 140 })
	P.windmill(b, { -780, 0, -1820 }, 30)
	P.waterTank(b, { -780, 0, -1690 })
	P.car(b, { -880, 0.2, -1680 }, 100, { 120, 70, 50 }, true)
	P.campfire(b, { -930, 0, -1700 }, true)
	W.fence({ -880, -1800 }, { -780, -1800 }, 4)

	-- Pista de aterrizaje con hangar y avioneta estrellada
	local yaw = -45
	local strip = b:at({ -1020, 0, -1040 }, yaw)
	strip:box({ name = "Pista", size = { 420, 0.4, 40 }, pos = { 0, 0, 0 }, color = { 120, 118, 112 }, mat = "Concrete" })
	for x = -190, 190, 30 do
		strip:box({ name = "Marca", size = { 14, 0.12, 1.4 }, pos = { x, 0.22, 0 }, color = { 220, 218, 210 }, folder = "Decoracion", shadow = false })
	end
	for i = 0, 3 do
		strip:box({ name = "Hierba", size = { 30, 0.15, 8 + i * 3 }, pos = { -150 + i * 95, 0.24, (i % 2 == 0) and 10 or -12 }, color = { 80, 106, 60 }, mat = "LeafyGrass", folder = "Decoracion", shadow = false })
	end
	P.planeWreck(strip, { 60, 0.2, 6 }, 20)
	local hangar = strip:at({ -60, 0, 52 }, 0)
	hangar:box({ name = "Suelo", size = { 40, 0.4, 30 }, pos = { 0, 0.2, 0 }, color = { 110, 110, 106 }, mat = "Concrete" })
	P.wallWithHoles(hangar, -20, 20, 15, 0, 14, 1, {}, { 140, 146, 150 }, "CorrodedMetal")
	P.wallWithHolesZ(hangar, -15, 15, -20, 0, 14, 1, { { -6, 6, 0, 10 } }, { 140, 146, 150 }, "CorrodedMetal")
	P.wallWithHolesZ(hangar, -15, 15, 20, 0, 14, 1, {}, { 140, 146, 150 }, "CorrodedMetal")
	hangar:box({ name = "Techo", size = { 42, 1, 32 }, pos = { 0, 14.5, 0 }, color = { 120, 124, 128 }, mat = "CorrodedMetal" })
	hangar:box({ name = "Puerta", size = { 18, 12, 0.4 }, pos = { -8, 6, -15 }, color = { 120, 124, 128 }, mat = "CorrodedMetal" })
	for i, x in ipairs({ -12, -9, 10 }) do
		P.drum(hangar, { x, 0.4, 10 - i }, { 180, 60, 40 })
	end
	local tower = strip:at({ 120, 0, 48 }, 0)
	P.watchTower(tower, { 0, 0, 0 }, 0, 14)
	tower:cylinder({ name = "Manga", axis = "x", length = 4, diameter = 1.4, pos = { 6, 20, -4 }, color = { 240, 120, 40 }, mat = "Fabric", folder = "Decoracion" })

	W.spawn(-920, -1690, 180)
end
]=]
ZONAS["Ladera"] = [=[
-- Ladera: barrio de casas abandonadas a lo largo de la carretera de la costa, con una calle sin salida.
return function(b, MB, W)
	local P = MB.Props
	local COLORS = { { 200, 186, 160 }, { 160, 176, 190 }, { 190, 160, 150 }, { 170, 186, 150 }, { 210, 204, 190 } }
	local i = 0
	local function home(x, z, yaw, open)
		i = i + 1
		local color = COLORS[(i % #COLORS) + 1]
		if open then
			P.openHouse(b, { x, 0, z }, yaw, { color = color, trim = { 236, 232, 222 }, roofColor = { 86, 80, 76 }, ruined = true })
		else
			P.house(b, { x, 0, z }, yaw, { w = 24, h = 15, d = 16, color = color, trim = { 236, 232, 222 }, roof = "gable", roofColor = { 86, 80, 76 }, roofMat = "RoofShingles", floors = 2, ruined = true })
		end
		local g = b:at({ x, 0, z }, yaw)
		g:box({ name = "Buzon", size = { 1.2, 4.4, 1.2 }, pos = { 11, 2.2, -18 }, color = { 70, 70, 74 }, mat = "Metal" })
	end
	-- Casas al norte y al sur de la carretera (z = 900)
	for k, x in ipairs({ 530, 575, 620, 665, 710, 755 }) do
		local open = (k % 3 == 2)
		home(x, open and 873 or 877, 180, open)
	end
	for k, x in ipairs({ 530, 575, 705, 750 }) do
		local open = (k % 2 == 1)
		home(x, open and 927 or 923, 0, open)
	end
	-- Calle sin salida hacia el sur
	W.road({ { 640, 911 }, { 640, 1046 } }, 16)
	b:cylinder({ name = "Rotonda", length = 0.4, diameter = 34, pos = { 640, 0, 1050 }, color = { 66, 66, 68 }, mat = "Asphalt" })
	for _, z in ipairs({ 975, 1025 }) do
		home(620, z, -90, false)
		home(660, z, 90, z == 975)
	end
	-- Coches quemados, columpio, canasta y valla
	for k, c in ipairs({ { 600, 905, 95 }, { 690, 893, 80 }, { 640, 1000, 10 }, { 520, 960, 40 } }) do
		P.car(b, { c[1], 0.2, c[2] }, c[3], (k % 2 == 0) and { 40, 40, 42 } or { 120, 70, 50 }, true)
	end
	for _, z in ipairs({ 1060, 1066 }) do
		P.segment(b, { 700, 0, z }, { 703, 8, z }, 0.4, { 60, 120, 160 }, "Metal")
		P.segment(b, { 706, 0, z }, { 703, 8, z }, 0.4, { 60, 120, 160 }, "Metal")
	end
	b:box({ name = "Canasta", size = { 0.5, 10, 0.5 }, pos = { 590, 5, 1040 }, color = { 80, 80, 84 }, mat = "Metal" })
	b:box({ name = "Tablero", size = { 5, 3, 0.3 }, pos = { 590, 10, 1039 }, color = { 230, 230, 226 }, folder = "Decoracion" })
	W.fence({ 505, 1065 }, { 600, 1065 }, 4, { 230, 228, 220 })
	W.fence({ 680, 1065 }, { 775, 1065 }, 4, { 230, 228, 220 })
	W.spawn(600, 900, 90)
end
]=]
ZONAS["LagoSereno"] = [=[
-- Lago Sereno: urbanización en círculo junto al lago, con casas abandonadas (algunas se pueden recorrer).
return function(b, MB, W)
	local P = MB.Props
	local cx, cz = -960, 60
	-- Calle de entrada desde la carretera y anillo
	W.road({ { cx, -100 }, { cx, cz - 100 } }, 18)
	local ring = {}
	for i = 0, 16 do
		local a = math.rad(i * 22.5)
		table.insert(ring, { cx + math.cos(a) * 100, cz + math.sin(a) * 100 })
	end
	W.road(ring, 18)
	-- Casas alrededor mirando al centro
	local COLORS = { { 210, 196, 170 }, { 160, 180, 196 }, { 196, 160, 140 }, { 180, 190, 160 }, { 220, 214, 200 }, { 170, 150, 170 } }
	for i, deg in ipairs({ 0, 45, 90, 135, 225, 315 }) do
		local a = math.rad(deg)
		local x, z = cx + math.cos(a) * 150, cz + math.sin(a) * 150
		local yaw = math.deg(math.atan2(math.cos(a), math.sin(a)))
		local color = COLORS[i]
		if i % 2 == 1 then
			P.openHouse(b, { x, 0, z }, yaw, { color = color, trim = { 240, 238, 230 }, roofColor = { 90, 80, 76 }, ruined = true })
		else
			P.house(b, { x, 0, z }, yaw, { w = 22, h = 16, d = 16, color = color, trim = { 240, 238, 230 }, roof = "gable", roofColor = { 90, 80, 76 }, roofMat = "RoofShingles", floors = 2, ruined = true })
		end
		-- Coche en la entrada de cada casa
		local g = b:at({ x, 0, z }, yaw)
		P.car(g, { 16, 0.2, -16 }, 0, ({ { 120, 70, 50 }, { 90, 96, 100 }, { 60, 70, 90 } })[(i % 3) + 1], true)
		P.mannequin(g, { -10, 0, -18 }, 30, { 90, 80, 70 })
	end
	-- Parque en el centro del anillo
	b:cylinder({ name = "Cesped", length = 0.3, diameter = 170, pos = { cx, 0.1, cz }, color = { 84, 110, 62 }, mat = "LeafyGrass", folder = "Decoracion" })
	for i, t in ipairs({ { -30, -20 }, { 25, 30 }, { 40, -35 }, { -40, 40 } }) do
		W.tree(cx + t[1], cz + t[2], (i % 2 == 0) and "roble" or "muerto", 1.2)
	end
	for _, z in ipairs({ -6, 6 }) do
		P.segment(b, { cx - 3, 0, cz + z }, { cx, 9, cz + z }, 0.4, { 160, 60, 50 }, "Metal")
		P.segment(b, { cx + 3, 0, cz + z }, { cx, 9, cz + z }, 0.4, { 160, 60, 50 }, "Metal")
	end
	b:cylinder({ name = "Barra", axis = "z", length = 12, diameter = 0.4, pos = { cx, 9, cz }, color = { 160, 60, 50 }, mat = "Metal", folder = "Decoracion" })
	P.car(b, { cx + 70, 0.2, cz - 50 }, 30, { 40, 40, 42 }, true)
	P.bench(b, { cx + 20, 0, cz + 10 }, 90, { 110, 90, 70 })
	P.campfire(b, { cx - 20, 0, cz + 10 }, true)
	-- Tienda de caza y pesca a la orilla del lago, con embarcadero para pescar
	P.tiendaCaza(b, { -1096, 0, -12 }, -90, "Tienda de caza y pesca del lago")
	P.embarcadero(b, { -1108, 0, -36 }, 90, 42, -10)
	W.spawn(cx + 10, cz - 20, 0)
end
]=]
ZONAS["Megatienda"] = [=[
-- Megatienda: gran supermercado abandonado en el que se puede entrar (estanterías, cajas,
-- techo hundido) y su aparcamiento lleno de coches.
return function(b, MB, W)
	local P = MB.Props
	local x0, x1, z0, z1, H, T = -730, -530, -730, -650, 20, 1.5
	local WALL = { 176, 174, 168 }
	b:box({ name = "Suelo", size = { x1 - x0, 0.4, z1 - z0 }, pos = { (x0 + x1) / 2, 0.2, (z0 + z1) / 2 }, color = { 190, 186, 176 }, mat = "Marble" })
	P.wallWithHoles(b, x0, x1, z1 - T / 2, 0, H, T, { { -670, -650, 0, 10 }, { -610, -590, 0, 10 }, { -725, -680, 3, 9 }, { -580, -535, 3, 9 } }, WALL, "Concrete")
	P.wallWithHoles(b, x0, x1, z0 + T / 2, 0, H, T, { { -650, -630, 0, 12 } }, WALL, "Concrete")
	for _, x in ipairs({ x0 + T / 2, x1 - T / 2 }) do
		P.wallWithHolesZ(b, z0 + T, z1 - T, x, 0, H, T, { { -700, -690, 0, 8 } }, WALL, "Concrete")
	end
	-- Techo con una parte hundida
	for _, x in ipairs({ -705, -655, -555 }) do
		b:box({ name = "Techo", size = { 50, 1.5, z1 - z0 }, pos = { x, H + 0.75, (z0 + z1) / 2 }, color = { 140, 140, 136 }, mat = "Concrete" })
	end
	b:box({ name = "Techo", size = { 50, 1.5, 30 }, pos = { -605, H + 0.75, z0 + 15 }, color = { 140, 140, 136 }, mat = "Concrete" })
	P.debris(b, { -605, 0.4, -675 }, 2)
	P.debris(b, { -596, 0.4, -688 }, 1.4)
	P.overgrowth(b:at({ -605, 0, -700 }, 0), 40, H, -15)
	for x = -705, -555, 25 do
		for _, z in ipairs({ -710, -670 }) do
			b:box({ name = "Pilar", size = { 1.6, H, 1.6 }, pos = { x, H / 2, z }, color = { 200, 198, 190 }, mat = "Concrete" })
		end
	end
	-- Estanterías y cajas registradoras
	local goods = { { 200, 60, 50 }, { 60, 120, 200 }, { 240, 200, 60 }, { 80, 160, 90 } }
	for i, z in ipairs({ -722, -712, -702, -692, -682 }) do
		for _, x in ipairs({ -686, -574 }) do
			b:box({ name = "Estanteria", size = { 66, 7, 3 }, pos = { x, 3.9, z }, color = { 150, 150, 156 }, mat = "Metal" })
			for k, y in ipairs({ 2.4, 5 }) do
				b:box({ name = "Productos", size = { 64, 1.2, 3.2 }, pos = { x, y, z }, color = goods[((i + k) % 4) + 1], folder = "Decoracion" })
			end
		end
	end
	for x = -700, -560, 28 do
		b:box({ name = "Caja", size = { 6, 3, 2 }, pos = { x, 1.9, -662 }, color = { 60, 60, 66 }, mat = "Metal" })
	end
	P.poster(b, { -630, 16, z1 + 0.3 }, 180, { 80, 6 }, { 180, 40, 40 }, "MEGATIENDA", { 250, 240, 230 }, "GothamBlack")

	-- Aparcamiento, carritos, farolas y camión en el muelle de carga
	W.parking(-760, -500, -640, -460)
	local RUST = { { 120, 70, 50 }, { 90, 96, 100 }, { 140, 120, 90 }, { 60, 70, 90 }, { 40, 40, 42 } }
	for i, c in ipairs({ { -740, -610, 0 }, { -712, -490, 180 }, { -690, -600, 10 }, { -650, -495, 170 }, { -600, -605, 0 }, { -560, -500, 190 }, { -530, -600, 5 }, { -620, -540, 80 } }) do
		P.car(b, { c[1], 0.2, c[2] }, c[3], RUST[(i % #RUST) + 1], true)
	end
	for i = 0, 5 do
		b:box({ name = "Carrito", size = { 2, 2.4, 3 }, pos = { -680 + i * 23, 1.4, -560 + (i % 2) * 14 }, rot = { 0, i * 40, 0 }, color = { 170, 170, 176 }, mat = "Metal", transparency = 0.4 })
	end
	for _, x in ipairs({ -720, -630, -540 }) do
		P.streetLight(b, { x, 0.2, -550 }, 0, 18)
	end
	P.truck(b, { -640, 0, -748 }, 180, { 200, 200, 196 })
	W.spawn(-660, -470, 0)
end
]=]
ZONAS["Motel"] = [=[
-- Motel Luna: motel de carretera de dos plantas con pasarela, recepción, aparcamiento y cartel.
return function(b, MB, W)
	local P = MB.Props
	local WALL, TRIM = { 200, 170, 140 }, { 110, 70, 50 }
	W.parking(-740, -622, 20, 108)
	P.house(b, { -690, 0, 125 }, 0, { w = 130, h = 20, d = 18, floors = 2, cols = 10, color = WALL, trim = TRIM, door = false, ruined = true })
	for i = 0, 9 do
		local x = -755 + 6.5 + 13 * i
		for _, y in ipairs({ 3.2, 13.2 }) do
			b:box({ name = "Puerta", size = { 3, 6, 0.3 }, pos = { x + 3, y, 115.8 }, color = (i % 3 == 0) and { 80, 60, 50 } or { 60, 90, 110 }, mat = "WoodPlanks", folder = "Decoracion" })
		end
	end
	-- Pasarela del primer piso con barandilla, pilares y escalera
	b:box({ name = "Pasarela", size = { 130, 0.6, 4 }, pos = { -690, 10, 114 }, color = { 150, 146, 140 }, mat = "Concrete" })
	P.railing(b, { -755, 10.3, 112.2 }, { -634, 10.3, 112.2 }, 3, TRIM)
	for x = -752, -628, 31 do
		b:box({ name = "Pilar", size = { 0.8, 10, 0.8 }, pos = { x, 5, 112.4 }, color = TRIM })
	end
	P.stairs(b, { -630, 0, 99 }, 0, 10, 1, 1.3, 4, { 150, 146, 140 })
	-- Ala lateral y recepción
	P.house(b, { -750, 0, 72 }, -90, { w = 60, h = 10, d = 16, floors = 1, cols = 6, color = WALL, trim = TRIM, ruined = true })
	P.house(b, { -612, 0, 60 }, 90, { w = 24, h = 10, d = 14, floors = 1, color = { 220, 200, 170 }, trim = TRIM, shop = "RECEPCIÓN", shopColor = { 60, 80, 120 }, ruined = true })
	-- Cartel de neón apagado
	b:box({ name = "Poste", size = { 1.4, 24, 1.4 }, pos = { -606, 12, 22 }, color = { 70, 70, 74 }, mat = "Metal" })
	local sign = b:box({ name = "Cartel", size = { 18, 6, 1 }, pos = { -606, 26, 22 }, color = { 40, 40, 50 }, folder = "Decoracion" })
	MB.sign(sign, "MOTEL LUNA", { font = "LuckiestGuy", color = { 160, 120, 150 } })
	b:cylinder({ name = "Luna", axis = "z", length = 0.6, diameter = 5, pos = { -606, 31.6, 22 }, color = { 220, 210, 150 }, folder = "Decoracion" })
	-- Coches, máquinas y basura
	for i, c in ipairs({ { -730, 40, 90 }, { -700, 95, 0 }, { -660, 92, 10 }, { -640, 40, 120 } }) do
		P.car(b, { c[1], 0.2, c[2] }, c[3], ({ { 120, 70, 50 }, { 60, 70, 90 }, { 140, 120, 90 }, { 90, 96, 100 } })[i], true)
	end
	P.vending(b, { -625, 0, 106 }, 180, { 160, 50, 50 }, "COLA")
	P.dumpster(b, { -760, 0, 112 }, 90, { 60, 90, 70 })
	P.debris(b, { -700, 0, 70 }, 0.8)
	W.spawn(-680, 60, 0)
end
]=]
ZONAS["Penal"] = [=[
-- Penal: prisión con doble valla, torres, dos pabellones de celdas en los que se puede entrar, patio y oficinas.
return function(b, MB, W)
	local P = MB.Props
	local CONCRETE = { 168, 166, 158 }

	-- Pabellón de celdas: pasillo central con celdas a los dos lados (largo a lo largo de X local)
	local function cellBlock(cx, cz)
		local g = b:at({ cx, 0, cz }, 0)
		local L, D, H = 64, 26, 12
		g:box({ name = "Suelo", size = { L, 0.4, D }, pos = { 0, 0.2, 0 }, color = { 140, 138, 132 }, mat = "Concrete" })
		local windows = {}
		for x = -26, 26, 13 do
			table.insert(windows, { x - 2, x + 2, 8, 10 })
		end
		P.wallWithHoles(g, -L / 2, L / 2, -D / 2 + 0.5, 0, H, 1, windows, CONCRETE, "Concrete")
		P.wallWithHoles(g, -L / 2, L / 2, D / 2 - 0.5, 0, H, 1, windows, CONCRETE, "Concrete")
		for _, x in ipairs({ -L / 2 + 0.5, L / 2 - 0.5 }) do
			P.wallWithHolesZ(g, -D / 2 + 1, D / 2 - 1, x, 0, H, 1, { { -3, 3, 0, 8 } }, CONCRETE, "Concrete")
		end
		g:box({ name = "Techo", size = { L + 1, 1, D + 1 }, pos = { 0, H + 0.5, 0 }, color = { 130, 128, 122 }, mat = "Concrete" })
		for _, side in ipairs({ -1, 1 }) do
			for k = 0, 7 do
				local x = -L / 2 + 1 + k * 8
				g:box({ name = "Tabique", size = { 0.6, H, 8 }, pos = { x, H / 2, side * 8.5 }, color = CONCRETE, mat = "Concrete" })
				for _, bx in ipairs({ 1.6, 3.2, 6.4 }) do
					g:cylinder({ name = "Barrote", length = H - 1, diameter = 0.25, pos = { x + bx, (H - 1) / 2 + 0.4, side * 4.5 }, color = { 80, 80, 84 }, mat = "Metal" })
				end
				g:box({ name = "Litera", size = { 2.4, 1.6, 5 }, pos = { x + 5.8, 1.2, side * 9.8 }, color = { 110, 110, 104 }, mat = "Metal" })
			end
		end
		for x = -20, 20, 20 do
			g:box({ name = "Lampara", size = { 6, 0.3, 1 }, pos = { x, H - 0.3, 0 }, color = { 230, 236, 220 }, mat = "Neon", folder = "Decoracion" })
		end
		P.overgrowth(g, L, H, -D / 2 - 0.2)
	end

	-- Doble valla con alambre de espino y puertas norte y sur
	for _, inset in ipairs({ 0, 8 }) do
		W.wallRect(-1690 + inset, -1410 - inset, 420 + inset, 660 - inset, { { "N", -1556, -1524 }, { "S", -1556, -1524 } }, function(a, c)
			P.chainFence(b, { a[1], 0, a[2] }, { c[1], 0, c[2] }, 12)
			P.rod(b, { a[1], 12.6, a[2] }, { c[1], 12.6, c[2] }, 1, { 90, 90, 92 }, "Metal", "Decoracion")
		end)
	end
	for _, c in ipairs({ { -1678, 432 }, { -1422, 432 }, { -1678, 648 }, { -1422, 648 } }) do
		P.watchTower(b, { c[1], 0, c[2] }, 0, 16)
	end
	W.road({ { -1540, 410 }, { -1540, 670 } }, 18)

	-- Pabellones, oficinas y patio
	cellBlock(-1620, 480)
	cellBlock(-1620, 600)
	P.house(b, { -1462, 0, 470 }, 90, { w = 40, h = 14, d = 24, color = { 150, 150, 146 }, trim = { 90, 96, 104 }, floors = 2, shop = "PENITENCIARÍA", shopColor = { 60, 70, 80 }, ruined = true })
	b:box({ name = "Pista", size = { 44, 0.2, 28 }, pos = { -1470, 0.1, 585 }, color = { 120, 96, 80 }, mat = "Concrete" })
	for _, x in ipairs({ -1490, -1450 }) do
		b:box({ name = "Poste", size = { 0.6, 10, 0.6 }, pos = { x, 5, 585 }, color = { 80, 80, 84 }, mat = "Metal" })
		b:box({ name = "Tablero", size = { 0.3, 3, 5 }, pos = { x + (x < -1470 and 0.6 or -0.6), 10, 585 }, color = { 230, 230, 226 }, folder = "Decoracion" })
	end
	P.bleachers(b, { -1470, 0, 610 }, 180, 3, 30, { { 120, 120, 120 } })
	for _, x in ipairs({ -1560, -1520 }) do
		b:box({ name = "Garita", size = { 5, 8, 5 }, pos = { x, 4, 430 }, color = { 140, 140, 136 }, mat = "Concrete" })
	end

	-- Autobús de presos estrellado en la entrada
	P.bus(b, { -1590, 0.2, 395 }, 80, { 220, 220, 214 }, "TRASLADOS")
	P.sandbags(b, { -1500, 0, 398 }, 0, 10, 3)
	P.debris(b, { -1520, 0, 445 }, 1.2)
	W.spawn(-1515, 380, 180)
end
]=]
ZONAS["Refugio"] = [=[
-- Refugio: fábrica abandonada junto a la costa, final de la vía del tren, con naves, chimeneas,
-- vagones, contenedores y una grúa.
return function(b, MB, W)
	local P = MB.Props
	local x0, x1, z0, z1 = 870, 1190, 530, 830
	W.wallRect(x0, x1, z0, z1, { { "N", 1004, 1036 }, { "O", 676, 712 }, { "S", 886, 914 } }, function(a, c)
		P.metalWall(b, { a[1], 0, a[2] }, { c[1], 0, c[2] }, 12, { { 110, 116, 120 }, { 96, 100, 104 }, { 130, 110, 90 } })
	end)
	P.poster(b, { 1020, 10, z0 - 1.2 }, 0, { 26, 4 }, { 50, 54, 60 }, "FÁBRICA DEL REFUGIO", { 230, 226, 210 }, "GothamBlack")
	-- Nave principal con tejado en diente de sierra y chimeneas
	P.house(b, { 1080, 0, 640 }, 180, { w = 120, h = 22, d = 70, color = { 150, 120, 100 }, mat = "Brick", trim = { 90, 80, 70 }, floors = 2, cols = 14, ruined = true })
	for k = 0, 5 do
		b:wedge({ name = "Diente", size = { 20, 6, 70 }, pos = { 1030 + k * 20, 25, 640 }, rot = { 0, 90, 0 }, color = { 110, 116, 120 }, mat = "CorrodedMetal" })
	end
	for k, p in ipairs({ { 1150, 590 }, { 1166, 600 } }) do
		b:cylinder({ name = "Chimenea", length = 64 - k * 8, diameter = 7, pos = { p[1], 32 - k * 4, p[2] }, color = { 140, 100, 80 }, mat = "Brick" })
		for _, y in ipairs({ 40, 50 }) do
			b:cylinder({ name = "Franja", length = 2, diameter = 7.3, pos = { p[1], y - k * 4, p[2] }, color = { 220, 220, 214 }, folder = "Decoracion" })
		end
	end
	P.house(b, { 960, 0, 590 }, 180, { w = 60, h = 16, d = 40, color = { 120, 128, 132 }, mat = "CorrodedMetal", trim = { 80, 86, 90 }, floors = 1, ruined = true })
	P.house(b, { 1150, 0, 790 }, -90, { w = 40, h = 12, d = 20, color = { 196, 190, 176 }, trim = { 90, 90, 96 }, floors = 2, shop = "OFICINAS", shopColor = { 60, 70, 80 }, ruined = true })
	-- Vía interior con vagones y grúa pórtico
	P.rails(b, { 900, 0, 700 }, { 1110, 0, 712 }, false)
	for k, c in ipairs({ { 960, "vagon", { 130, 70, 50 } }, { 992, "vagon", { 70, 90, 110 } }, { 1024, "cisterna", { 220, 220, 214 } }, { 1056, "plataforma", { 90, 90, 90 } } }) do
		local t = (c[1] - 900) / 210
		P.trainCar(b, { c[1], 0.6, 700 + 12 * t }, -3.3, c[2], c[3])
	end
	for _, x in ipairs({ 990, 1030 }) do
		for _, z in ipairs({ 688, 722 }) do
			b:box({ name = "Pata", size = { 2, 26, 2 }, pos = { x, 13, z }, color = { 200, 160, 50 }, mat = "Metal" })
		end
	end
	for _, z in ipairs({ 688, 722 }) do
		b:box({ name = "Viga", size = { 44, 2.4, 2.4 }, pos = { 1010, 26, z }, color = { 200, 160, 50 }, mat = "Metal" })
	end
	b:box({ name = "Carro", size = { 6, 3, 38 }, pos = { 1010, 27, 705 }, color = { 180, 140, 40 }, mat = "Metal", folder = "Decoracion" })
	-- Patio de carga
	for k, c in ipairs({ { 940, 770, 0 }, { 940, 780, 0 }, { 1060, 770, 90 } }) do
		P.container(b, { c[1], (k == 2) and 9 or 0, c[2] }, c[3], ({ { 176, 60, 46 }, { 46, 96, 150 }, { 70, 120, 80 } })[k], false)
	end
	P.forklift(b, { 1000, 0, 760 }, 30, { 240, 190, 40 })
	for k = 0, 3 do
		P.pallet(b, { 1090 + k * 6, 0, 750 }, k * 10)
	end
	for k, p in ipairs({ { 900, 760 }, { 903, 762 }, { 1120, 700 } }) do
		P.drum(b, { p[1], 0, p[2] }, (k % 2 == 0) and { 200, 60, 40 } or { 60, 80, 120 })
	end
	P.floodLight(b, { 880, 0, 540 }, 135, 16)
	P.floodLight(b, { 1180, 0, 820 }, -45, 16)
	W.spawn(960, 790, 0)
end
]=]
ZONAS["Villamuro"] = [=[
-- Villamuro: pueblo de supervivientes rodeado por una muralla de chapas y camiones, con torres de vigilancia.
return function(b, MB, W)
	local P = MB.Props
	local x0, x1, z0, z1 = -1810, -1490, -770, -510
	local STYLES = {
		{ w = 16, h = 12, color = { 196, 176, 150 }, trim = { 110, 80, 60 }, shop = "TIENDA", shopColor = { 140, 60, 40 }, lit = true },
		{ w = 14, h = 14, color = { 150, 160, 150 }, trim = { 240, 236, 226 }, shutters = { 80, 60, 50 }, lit = true },
		{ w = 18, h = 13, color = { 176, 120, 90 }, mat = "Brick", trim = { 236, 226, 210 }, shop = "BAR", shopColor = { 60, 90, 60 }, lit = true },
		{ w = 14, h = 12, color = { 210, 200, 180 }, trim = { 90, 100, 110 }, shop = "ENFERMERÍA", shopColor = { 180, 40, 40 }, lit = true },
		{ w = 16, h = 16, color = { 160, 150, 136 }, trim = { 236, 230, 220 }, shop = "ARMERÍA", shopColor = { 50, 50, 56 }, lit = true },
	}

	-- Muralla con puertas al este y al norte
	W.wallRect(x0, x1, z0, z1, { { "E", -660, -620 }, { "N", -1716, -1684 } }, function(a, c)
		P.metalWall(b, { a[1], 0, a[2] }, { c[1], 0, c[2] }, 12)
	end)
	for _, c in ipairs({ { x0 + 8, z0 + 8 }, { x1 - 8, z0 + 8 }, { x0 + 8, z1 - 8 }, { x1 - 8, z1 - 8 }, { x1 - 10, -676 }, { -1730, z0 + 10 } }) do
		P.watchTower(b, { c[1], 0, c[2] }, 0, 14)
	end
	-- Camiones atravesados reforzando la muralla
	P.truck(b, { x1 - 6, 0, -560 }, 0, { 90, 96, 90 })
	P.truck(b, { -1600, 0, z0 + 6 }, 90, { 120, 80, 60 })
	P.poster(b, { x1 + 0.6, 10, -640 }, -90, { 20, 3 }, { 40, 40, 40 }, "VILLAMURO · BIENVENIDOS", { 230, 220, 190 }, "GothamBlack")

	-- Calle mayor y casas
	W.road({ { x1 + 20, -640 }, { -1766, -640 } }, 22)
	W.road({ { -1700, z0 }, { -1700, -651 } }, 16)
	P.houseRow(b, -662, 180, -1750, -1720, STYLES, 14)
	P.houseRow(b, -662, 180, -1680, -1520, STYLES, 14)
	P.houseRow(b, -618, 0, -1750, -1520, STYLES, 14)
	for _, x in ipairs({ -1740, -1640, -1560 }) do
		P.streetLight(b, { x, 0, -627 }, 180, 14)
	end

	-- Ayuntamiento al fondo de la calle
	P.house(b, { -1785, 0, -640 }, -90, { w = 34, h = 18, d = 18, color = { 220, 210, 190 }, trim = { 120, 90, 70 }, floors = 2, shop = "AYUNTAMIENTO", shopColor = { 60, 70, 90 }, lit = true })

	-- Patios: huertos, tiendas de campaña, hogueras y la arena de neumáticos
	for i = 0, 5 do
		if i ~= 3 then
			P.gardenBed(b, { -1780 + i * 24, 0, -740 }, 0, 14, 5)
		end
	end
	for _, t in ipairs({ { -1610, -720 }, { -1560, -730 }, { -1520, -700 } }) do
		P.tent(b, { t[1], 0, t[2] }, 15, { 92, 110, 70 })
	end
	P.campfire(b, { -1590, 0, -700 }, true)
	P.fireBarrel(b, { -1581, 0, -708 })
	P.tiendaCaza(b, { -1607, 0, -694 }, -90, "Armería de Villamuro")
	local ax, az = -1650, -555
	for i = 0, 23 do
		local a = math.rad(i * 15)
		P.tires(b, { ax + math.cos(a) * 26, 0, az + math.sin(a) * 26 }, 3)
	end
	for i = 0, 7 do
		local a = math.rad(i * 45)
		b:box({ name = "Grada", size = { 10, 3, 3 }, pos = { ax + math.cos(a) * 32, 1.5, az + math.sin(a) * 32 }, rot = { 0, -i * 45 + 90, 0 }, color = { 110, 90, 70 }, mat = "WoodPlanks" })
	end
	P.waterTank(b, { -1760, 0, -545 })
	P.solarPanel(b, { -1530, 0, -540 }, 180)
	P.solarPanel(b, { -1530, 0, -556 }, 180)

	W.spawn(-1600, -640, -90)
end
]=]
ZONAS["ZonaProhibida"] = [=[
-- Zona Prohibida: campamento militar de cuarentena junto a la costa, con muros de hormigón,
-- tiendas, camiones y un helicóptero estrellado.
return function(b, MB, W)
	local P = MB.Props
	local x0, x1, z0, z1 = -1600, -1300, 1080, 1320
	local OLIVE = { 84, 94, 70 }

	-- Muros de hormigón en T
	W.wallRect(x0, x1, z0, z1, { { "N", -1476, -1444 } }, function(a, c)
		local dx, dz = c[1] - a[1], c[2] - a[2]
		local len = math.sqrt(dx * dx + dz * dz)
		local yaw = math.deg(math.atan2(-dz, dx))
		local n = math.max(1, math.floor(len / 6))
		local g = b:at({ (a[1] + c[1]) / 2, 0, (a[2] + c[2]) / 2 }, yaw)
		for i = 0, n - 1 do
			local x = -len / 2 + (i + 0.5) * len / n
			g:box({ name = "MuroT", size = { len / n - 0.3, 10, 1.6 }, pos = { x, 5, 0 }, color = (i % 4 == 0) and { 150, 146, 138 } or { 170, 166, 158 }, mat = "Concrete" })
			g:box({ name = "Pie", size = { len / n - 0.3, 1.2, 4 }, pos = { x, 0.6, 0 }, color = { 150, 146, 138 }, mat = "Concrete" })
		end
	end)
	for _, x in ipairs({ -1560, -1380 }) do
		P.poster(b, { x, 6, z0 - 1 }, 0, { 30, 4 }, { 240, 200, 40 }, "☣ ZONA DE CUARENTENA ☣", { 30, 30, 30 }, "GothamBlack")
	end
	P.poster(b, { x0 - 1, 6, 1200 }, 90, { 30, 4 }, { 240, 200, 40 }, "PROHIBIDO EL PASO", { 30, 30, 30 }, "GothamBlack")

	-- Control de entrada
	b:box({ name = "Garita", size = { 6, 8, 6 }, pos = { -1488, 4, 1092 }, color = OLIVE, mat = "Metal" })
	b:box({ name = "Barrera", size = { 30, 0.6, 0.6 }, pos = { -1460, 4, 1082 }, rot = { 0, 0, 12 }, color = { 220, 60, 50 }, mat = "Metal" })
	for _, x in ipairs({ -1490, -1430 }) do
		P.sandbags(b, { x, 0, 1066 }, 0, 12, 3)
	end

	-- Campamento: tiendas, tienda de descontaminación, camiones, contenedores y focos
	for i = 0, 3 do
		for k = 0, 1 do
			P.tent(b, { -1570 + i * 22, 0, 1130 + k * 26 }, 0, OLIVE, 14, 10, 7)
		end
	end
	P.tent(b, { -1360, 0, 1140 }, 90, { 230, 230, 226 }, 30, 16, 10)
	b:box({ name = "Cruz", size = { 0.4, 4, 8 }, pos = { -1360, 6, 1140 - 8.2 }, color = { 200, 40, 40 }, folder = "Decoracion" })
	P.truck(b, { -1420, 0, 1210 }, 30, OLIVE)
	P.truck(b, { -1330, 0, 1250 }, -10, OLIVE)
	P.container(b, { -1560, 0, 1290 }, 0, { 80, 90, 70 }, true)
	P.container(b, { -1520, 0, 1296 }, 90, { 120, 120, 110 }, false, "MATERIAL")
	P.helicopterWreck(b, { -1460, 0, 1250 }, 40)
	for i, p in ipairs({ { -1500, 1180 }, { -1497, 1183 }, { -1503, 1185 }, { -1380, 1300 }, { -1376, 1302 } }) do
		P.drum(b, { p[1], 0, p[2] }, (i % 2 == 0) and { 230, 190, 40 } or { 60, 70, 60 })
	end
	for _, p in ipairs({ { -1530, 1220 }, { -1410, 1170 } }) do
		P.crate(b, { p[1], 0, p[2] }, 4.5, 10, OLIVE)
		P.crate(b, { p[1] + 5, 0, p[2] + 1 }, 4, -15, OLIVE)
	end
	P.floodLight(b, { -1590, 0, 1090 }, 135, 16)
	P.floodLight(b, { -1310, 0, 1310 }, -45, 16)
	P.watchTower(b, { -1310, 0, 1092 }, 0, 16)
	P.watchTower(b, { -1590, 0, 1310 }, 0, 16)
end
]=]
local CLIMA_CONFIG = [=[
--[[
	Configuración del clima del mundo abierto (va en ReplicatedStorage como ClimaConfig).
	La usan ClimaServidor (cambia el clima, la luz, el viento y la nieve en el suelo) y
	ClimaCliente (lluvia, nieve, polvo, rayos y sonidos de cada jugador).
]]
local Config = {}

-- Cuánto dura cada clima (en minutos) y cuánto tarda en pasar de uno a otro (en segundos)
Config.DuracionMinima = 4
Config.DuracionMaxima = 9
Config.Transicion = 30
-- Clima con el que empieza el servidor (nil = al azar)
Config.ClimaInicial = "Nublado"

-- Ciclo de día y noche: minutos que dura un día completo (0 = hora fija)
Config.MinutosPorDia = 0
Config.HoraFija = 14.5

--[[
	SONIDOS. Roblox no trae de serie sonidos de lluvia ni de truenos, así que pega aquí los IDs.
	En Studio: Ver > Caja de herramientas > Audio, busca "rain", "thunder", "wind", "birds", "crickets"...,
	elige uno, clic derecho > Copiar ID del recurso y pégalo como "rbxassetid://NUMERO".
	Los sonidos subidos por la cuenta "Roblox" son gratis y funcionan en cualquier juego.
	Si un hueco se queda vacío ("") ese sonido simplemente no suena.
]]
Config.Sonidos = {
	Lluvia = "",                                     -- lluvia suave, en bucle
	LluviaFuerte = "",                               -- lluvia fuerte / aguacero, en bucle
	Viento = "rbxasset://sounds/action_falling.mp3", -- viento (viene con Roblox), en bucle
	Pajaros = "",                                    -- pájaros de día, en bucle
	Ambiente = "",                                   -- ambiente de bosque o grillos, en bucle
	Truenos = { "", "", "" },                        -- truenos (uno o varios, sin bucle)
	Fuego = "",                                      -- crepitar de hoguera, en bucle (suena cerca de cada fuego)
}

-- Texturas de las gotas y los copos ("" = la textura de partículas que trae Roblox)
Config.TexturaLluvia = ""
Config.TexturaNieve = ""

-- Colores del terreno normales y cubiertos de nieve
Config.ColoresTerreno = {
	Grass = { 76, 100, 58 }, LeafyGrass = { 62, 86, 48 }, Ground = { 98, 86, 68 }, Mud = { 74, 64, 50 },
	Rock = { 108, 106, 102 }, Slate = { 98, 100, 102 }, Basalt = { 72, 72, 76 }, Sand = { 190, 178, 144 }, Snow = { 236, 240, 246 },
}
Config.ColoresNevado = {
	Grass = { 226, 232, 238 }, LeafyGrass = { 214, 222, 228 }, Ground = { 214, 218, 224 }, Mud = { 190, 196, 204 },
	Rock = { 196, 200, 206 }, Slate = { 192, 196, 202 }, Basalt = { 186, 190, 198 }, Sand = { 226, 230, 236 }, Snow = { 240, 244, 250 },
}

--[[
	Climas. peso = probabilidad relativa de que salga.
	luz: Lighting · atmosfera: niebla · nubes · color: corrección de color · rayosSol · brillo
	viento: dirección y fuerza (mueve la hierba del terreno, las nubes y las partículas)
	olas: tamaño y velocidad del oleaje · agua: color y transparencia del agua (con lluvia baja turbia)
	lluvia/nieve/polvo: cantidad de partículas (0 = nada)
	rayos: hay relámpagos y truenos · nevar: el suelo se va cubriendo de nieve
	sonidos: volumen de cada sonido (0 a 1)
]]
Config.Climas = {
	Soleado = {
		peso = 4,
		luz = { Brightness = 3, Ambient = { 118, 118, 110 }, OutdoorAmbient = { 158, 158, 148 }, EnvironmentDiffuseScale = 0.8, EnvironmentSpecularScale = 0.6, ExposureCompensation = 0, ShadowSoftness = 0.15 },
		atmosfera = { Density = 0.26, Offset = 0.1, Haze = 1, Glare = 0.4, Color = { 199, 214, 226 }, Decay = { 110, 128, 150 } },
		nubes = { Cover = 0.4, Density = 0.5, Color = { 255, 255, 255 } },
		color = { Brightness = 0.02, Contrast = 0.1, Saturation = 0.05, TintColor = { 255, 250, 240 } },
		rayosSol = 0.15, brillo = 0.3,
		viento = { 6, 0, 3 }, olas = { 0.08, 6 }, agua = { { 30, 84, 90 }, 0.5 },
		lluvia = 0, nieve = 0, polvo = 0, rayos = false, nevar = false,
		sonidos = { Pajaros = 0.5, Ambiente = 0.3, Viento = 0.08 },
	},
	Nublado = {
		peso = 3,
		luz = { Brightness = 2, Ambient = { 108, 112, 110 }, OutdoorAmbient = { 136, 142, 138 }, EnvironmentDiffuseScale = 0.8, EnvironmentSpecularScale = 0.5, ExposureCompensation = 0.1, ShadowSoftness = 0.45 },
		atmosfera = { Density = 0.35, Offset = 0.12, Haze = 1.9, Glare = 0.1, Color = { 198, 205, 204 }, Decay = { 118, 128, 128 } },
		nubes = { Cover = 0.84, Density = 0.65, Color = { 202, 206, 208 } },
		color = { Brightness = 0, Contrast = 0.07, Saturation = -0.12, TintColor = { 244, 248, 246 } },
		rayosSol = 0.04, brillo = 0.25,
		viento = { 10, 0, 6 }, olas = { 0.12, 7 }, agua = { { 34, 74, 78 }, 0.35 },
		lluvia = 0, nieve = 0, polvo = 0, rayos = false, nevar = false,
		sonidos = { Pajaros = 0.15, Ambiente = 0.3, Viento = 0.2 },
	},
	Niebla = {
		peso = 2,
		luz = { Brightness = 1.6, Ambient = { 120, 124, 122 }, OutdoorAmbient = { 140, 146, 144 }, EnvironmentDiffuseScale = 0.9, EnvironmentSpecularScale = 0.4, ExposureCompensation = 0.15, ShadowSoftness = 0.8 },
		atmosfera = { Density = 0.62, Offset = 0.25, Haze = 3, Glare = 0, Color = { 196, 202, 200 }, Decay = { 150, 158, 156 } },
		nubes = { Cover = 0.9, Density = 0.7, Color = { 210, 214, 214 } },
		color = { Brightness = 0.02, Contrast = 0.02, Saturation = -0.22, TintColor = { 240, 246, 246 } },
		rayosSol = 0, brillo = 0.2,
		viento = { 2, 0, 1 }, olas = { 0.05, 4 }, agua = { { 46, 74, 76 }, 0.3 },
		lluvia = 0, nieve = 0, polvo = 0, rayos = false, nevar = false,
		sonidos = { Ambiente = 0.25, Viento = 0.06 },
	},
	Viento = {
		peso = 2,
		luz = { Brightness = 2.4, Ambient = { 114, 116, 110 }, OutdoorAmbient = { 150, 152, 144 }, EnvironmentDiffuseScale = 0.8, EnvironmentSpecularScale = 0.5, ExposureCompensation = 0, ShadowSoftness = 0.3 },
		atmosfera = { Density = 0.32, Offset = 0.1, Haze = 1.8, Glare = 0.2, Color = { 206, 204, 190 }, Decay = { 140, 130, 110 } },
		nubes = { Cover = 0.62, Density = 0.5, Color = { 236, 236, 232 } },
		color = { Brightness = 0, Contrast = 0.08, Saturation = -0.05, TintColor = { 252, 248, 238 } },
		rayosSol = 0.08, brillo = 0.25,
		viento = { 55, 0, 26 }, olas = { 0.3, 14 }, agua = { { 38, 76, 78 }, 0.3 },
		lluvia = 0, nieve = 0, polvo = 60, rayos = false, nevar = false,
		sonidos = { Viento = 0.9, Ambiente = 0.1 },
	},
	Lluvia = {
		peso = 3,
		luz = { Brightness = 1.3, Ambient = { 90, 96, 100 }, OutdoorAmbient = { 110, 118, 124 }, EnvironmentDiffuseScale = 0.9, EnvironmentSpecularScale = 1, ExposureCompensation = 0.1, ShadowSoftness = 0.7 },
		atmosfera = { Density = 0.45, Offset = 0.15, Haze = 2.2, Glare = 0, Color = { 170, 180, 186 }, Decay = { 100, 110, 120 } },
		nubes = { Cover = 0.97, Density = 0.82, Color = { 120, 126, 132 } },
		color = { Brightness = 0, Contrast = 0.05, Saturation = -0.25, TintColor = { 230, 238, 245 } },
		rayosSol = 0, brillo = 0.2,
		viento = { 12, 0, 8 }, olas = { 0.2, 10 }, agua = { { 54, 70, 62 }, 0.15 },
		lluvia = 500, nieve = 0, polvo = 0, rayos = false, nevar = false,
		sonidos = { Lluvia = 0.8, Viento = 0.25 },
	},
	Tormenta = {
		peso = 1.5,
		luz = { Brightness = 0.9, Ambient = { 70, 74, 82 }, OutdoorAmbient = { 86, 92, 104 }, EnvironmentDiffuseScale = 1, EnvironmentSpecularScale = 1, ExposureCompensation = 0.15, ShadowSoftness = 0.8 },
		atmosfera = { Density = 0.52, Offset = 0.18, Haze = 2.6, Glare = 0, Color = { 140, 146, 156 }, Decay = { 80, 86, 98 } },
		nubes = { Cover = 1, Density = 1, Color = { 80, 84, 92 } },
		color = { Brightness = -0.02, Contrast = 0.12, Saturation = -0.3, TintColor = { 220, 228, 240 } },
		rayosSol = 0, brillo = 0.2,
		viento = { 40, 0, 22 }, olas = { 0.45, 18 }, agua = { { 58, 66, 58 }, 0.08 },
		lluvia = 950, nieve = 0, polvo = 0, rayos = true, nevar = false,
		sonidos = { LluviaFuerte = 1, Lluvia = 0.4, Viento = 0.6 },
	},
	Nieve = {
		peso = 1.2,
		luz = { Brightness = 1.8, Ambient = { 130, 136, 146 }, OutdoorAmbient = { 170, 178, 190 }, EnvironmentDiffuseScale = 1, EnvironmentSpecularScale = 0.6, ExposureCompensation = 0.1, ShadowSoftness = 0.7 },
		atmosfera = { Density = 0.5, Offset = 0.2, Haze = 2.4, Glare = 0, Color = { 220, 228, 236 }, Decay = { 170, 180, 196 } },
		nubes = { Cover = 0.95, Density = 0.7, Color = { 230, 234, 240 } },
		color = { Brightness = 0.02, Contrast = 0.04, Saturation = -0.2, TintColor = { 232, 240, 255 } },
		rayosSol = 0.02, brillo = 0.3,
		viento = { 8, 0, 5 }, olas = { 0.06, 4 }, agua = { { 40, 70, 84 }, 0.35 },
		lluvia = 0, nieve = 350, polvo = 0, rayos = false, nevar = true,
		sonidos = { Viento = 0.35 },
	},
}

-- Convierte un clima en propiedades para cada objeto de iluminación
local function rgb(c)
	return Color3.fromRGB(c[1], c[2], c[3])
end
local function convertir(t)
	local out = {}
	for k, v in pairs(t) do
		out[k] = (type(v) == "table") and rgb(v) or v
	end
	return out
end
function Config.propiedades(nombre)
	local c = Config.Climas[nombre]
	return {
		Lighting = convertir(c.luz),
		Atmosfera = convertir(c.atmosfera),
		Nubes = convertir(c.nubes),
		ColorClima = convertir(c.color),
		RayosSol = { Intensity = c.rayosSol },
		BrilloClima = { Intensity = c.brillo },
		Terrain = { WaterWaveSize = c.olas[1], WaterWaveSpeed = c.olas[2], WaterColor = rgb(c.agua[1]), WaterTransparency = c.agua[2] },
		Viento = Vector3.new(c.viento[1], c.viento[2], c.viento[3]),
	}
end

-- Crea (si faltan) los objetos de iluminación que usa el clima y los devuelve por nombre
function Config.objetos()
	local Lighting = game:GetService("Lighting")
	local terrain = workspace.Terrain
	local function asegurar(parent, clase, nombre)
		local obj = parent:FindFirstChild(nombre)
		if not obj then
			obj = Instance.new(clase)
			obj.Name = nombre
			obj.Parent = parent
		end
		return obj
	end
	local o = {
		Lighting = Lighting,
		Terrain = terrain,
		Atmosfera = asegurar(Lighting, "Atmosphere", "Atmosfera"),
		ColorClima = asegurar(Lighting, "ColorCorrectionEffect", "ColorClima"),
		RayosSol = asegurar(Lighting, "SunRaysEffect", "RayosSol"),
		BrilloClima = asegurar(Lighting, "BloomEffect", "BrilloClima"),
		Nubes = asegurar(terrain, "Clouds", "Nubes"),
	}
	terrain.WaterReflectance = 1
	o.BrilloClima.Threshold = 0.95
	o.BrilloClima.Size = 24
	o.RayosSol.Spread = 0.7
	return o
end

-- Aplica un clima al instante (sin transición)
function Config.aplicar(nombre)
	local o = Config.objetos()
	for objeto, props in pairs(Config.propiedades(nombre)) do
		if objeto == "Viento" then
			workspace.GlobalWind = props
		else
			for prop, valor in pairs(props) do
				o[objeto][prop] = valor
			end
		end
	end
	for mat, c in pairs(Config.ColoresTerreno) do
		o.Terrain:SetMaterialColor(Enum.Material[mat], rgb(c))
	end
end

return Config
]=]
local CLIMA_SERVIDOR = [=[
--[[
	ClimaServidor (va en ServerScriptService).
	Cambia el clima cada pocos minutos con transiciones suaves (luz, niebla, nubes, viento y oleaje),
	va cubriendo el suelo de nieve cuando nieva y lanza los rayos de las tormentas.

	Para forzar un clima desde otro script del servidor:
		game.ServerStorage.CambiarClima:Fire("Tormenta")
	El creador del juego (o cualquiera en Studio) también puede escribir en el chat: /clima tormenta
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Config = require(ReplicatedStorage:WaitForChild("ClimaConfig"))

local objetos = Config.objetos()
local terrain = workspace.Terrain

local function asegurar(parent, clase, nombre)
	local obj = parent:FindFirstChild(nombre)
	if not obj then
		obj = Instance.new(clase)
		obj.Name = nombre
		obj.Parent = parent
	end
	return obj
end
local rayo = asegurar(ReplicatedStorage, "RemoteEvent", "ClimaRayo")
local cambiar = asegurar(ServerStorage, "BindableEvent", "CambiarClima")

local function rgb(c)
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- =====================================================================
--  Cambio de clima
-- =====================================================================
local actual = nil
local finClima = 0

local function duracion()
	return (Config.DuracionMinima + math.random() * (Config.DuracionMaxima - Config.DuracionMinima)) * 60
end

local function ponerClima(nombre, instantaneo)
	if not Config.Climas[nombre] then
		warn("[Clima] No existe el clima " .. tostring(nombre))
		return
	end
	actual = nombre
	finClima = os.clock() + duracion()
	if instantaneo then
		Config.aplicar(nombre)
	else
		local info = TweenInfo.new(Config.Transicion, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		for objeto, props in pairs(Config.propiedades(nombre)) do
			if objeto == "Viento" then
				TweenService:Create(workspace, info, { GlobalWind = props }):Play()
			else
				TweenService:Create(objetos[objeto], info, props):Play()
			end
		end
	end
	ReplicatedStorage:SetAttribute("Clima", nombre)
	ReplicatedStorage:SetAttribute("ClimaDesde", os.time())
	print("[Clima] Ahora: " .. nombre)
end

-- Elige el siguiente clima al azar según su peso (nunca repite el actual)
local function elegir()
	local total = 0
	for nombre, c in pairs(Config.Climas) do
		if nombre ~= actual then
			total = total + c.peso
		end
	end
	local r = math.random() * total
	for nombre, c in pairs(Config.Climas) do
		if nombre ~= actual then
			r = r - c.peso
			if r <= 0 then
				return nombre
			end
		end
	end
	return "Nublado"
end

-- =====================================================================
--  Nieve en el suelo: se acumula en 2 minutos mientras nieva y se derrite en 3
-- =====================================================================
local nieveSuelo = 0
local function pintarSuelo(t)
	for mat, c in pairs(Config.ColoresTerreno) do
		local blanco = Config.ColoresNevado[mat] or c
		terrain:SetMaterialColor(Enum.Material[mat], rgb(c):Lerp(rgb(blanco), t))
	end
end
task.spawn(function()
	while true do
		local objetivo = (actual and Config.Climas[actual].nevar) and 1 or 0
		if math.abs(objetivo - nieveSuelo) > 0.001 then
			local paso = (objetivo > nieveSuelo) and (1 / 120) or (1 / 180)
			nieveSuelo = nieveSuelo + math.clamp(objetivo - nieveSuelo, -paso, paso)
			pintarSuelo(nieveSuelo)
		end
		task.wait(1)
	end
end)

-- =====================================================================
--  Rayos: cerca de un jugador al azar, cada 6-16 segundos durante las tormentas
-- =====================================================================
task.spawn(function()
	while true do
		task.wait(6 + math.random() * 10)
		if actual and Config.Climas[actual].rayos then
			local centro = Vector3.new(0, 0, 0)
			local jugadores = Players:GetPlayers()
			if #jugadores > 0 then
				local j = jugadores[math.random(1, #jugadores)]
				local raiz = j.Character and j.Character:FindFirstChild("HumanoidRootPart")
				if raiz then
					centro = raiz.Position
				end
			end
			local angulo = math.random() * math.pi * 2
			local distancia = 120 + math.random() * 650
			rayo:FireAllClients(centro + Vector3.new(math.cos(angulo) * distancia, 0, math.sin(angulo) * distancia))
		end
	end
end)

-- =====================================================================
--  Día y noche
-- =====================================================================
if Config.MinutosPorDia > 0 then
	task.spawn(function()
		while true do
			local dt = task.wait(0.5)
			Lighting.ClockTime = (Lighting.ClockTime + dt * 24 / (Config.MinutosPorDia * 60)) % 24
		end
	end)
else
	Lighting.ClockTime = Config.HoraFija
end

-- =====================================================================
--  Cambiar el clima a mano
-- =====================================================================
cambiar.Event:Connect(function(nombre)
	ponerClima(nombre)
end)

local nombres = {}
for nombre in pairs(Config.Climas) do
	nombres[string.lower(nombre)] = nombre
end
local function escuchar(jugador)
	jugador.Chatted:Connect(function(mensaje)
		local pedido = string.match(string.lower(mensaje), "^/clima%s+(%S+)")
		if pedido and (RunService:IsStudio() or jugador.UserId == game.CreatorId) then
			if nombres[pedido] then
				ponerClima(nombres[pedido])
			else
				warn("[Clima] Climas disponibles: Soleado, Nublado, Niebla, Viento, Lluvia, Tormenta, Nieve")
			end
		end
	end)
end
Players.PlayerAdded:Connect(escuchar)
for _, j in ipairs(Players:GetPlayers()) do
	escuchar(j)
end

-- =====================================================================
--  Bucle principal
-- =====================================================================
ponerClima(Config.ClimaInicial or elegir(), true)
while true do
	task.wait(5)
	if os.clock() >= finClima then
		ponerClima(elegir())
	end
end
]=]
local CLIMA_CLIENTE = [=[
--[[
	ClimaCliente (va en StarterPlayer > StarterPlayerScripts).
	Lluvia, nieve y polvo alrededor de la cámara, relámpagos con trueno y sonidos de cada clima.
	Bajo techo deja de llover encima y los sonidos se oyen apagados.
	También hace parpadear la luz de los fuegos (hogueras, bidones) y les pone el crepitar si hay ID.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")
local Config = require(ReplicatedStorage:WaitForChild("ClimaConfig"))

local jugador = Players.LocalPlayer
local camara = workspace.CurrentCamera

-- =====================================================================
--  Partículas: una pieza invisible que sigue a la cámara desde arriba
-- =====================================================================
local emisor = Instance.new("Part")
emisor.Name = "ClimaEmisor"
emisor.Anchored = true
emisor.CanCollide = false
emisor.CanQuery = false
emisor.CanTouch = false
emisor.CastShadow = false
emisor.Transparency = 1
emisor.Size = Vector3.new(170, 1, 170)
emisor.Parent = camara

local function particulas(nombre, props)
	local e = Instance.new("ParticleEmitter")
	e.Name = nombre
	for k, v in pairs(props) do
		e[k] = v
	end
	e.Rate = 0
	e.Parent = emisor
	return e
end

local lluvia = particulas("Lluvia", {
	EmissionDirection = Enum.NormalId.Bottom,
	Orientation = Enum.ParticleOrientation.VelocityParallel,
	Speed = NumberRange.new(85, 105),
	Lifetime = NumberRange.new(0.75, 0.9),
	Size = NumberSequence.new(0.12),
	Squash = NumberSequence.new(2.6),
	Transparency = NumberSequence.new(0.35),
	Color = ColorSequence.new(Color3.fromRGB(196, 206, 216)),
	LightEmission = 0.05,
	Drag = 0.2,
	WindAffectsDrag = true,
})
local nieve = particulas("Nieve", {
	EmissionDirection = Enum.NormalId.Bottom,
	Speed = NumberRange.new(6, 9),
	Lifetime = NumberRange.new(9, 11),
	SpreadAngle = Vector2.new(25, 25),
	Size = NumberSequence.new(0.35),
	Rotation = NumberRange.new(0, 360),
	RotSpeed = NumberRange.new(-60, 60),
	Transparency = NumberSequence.new(0.05),
	Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
	LightEmission = 0.2,
	Drag = 0.8,
	WindAffectsDrag = true,
})
local polvo = particulas("Polvo", {
	EmissionDirection = Enum.NormalId.Bottom,
	Speed = NumberRange.new(4, 8),
	Lifetime = NumberRange.new(5, 7),
	SpreadAngle = Vector2.new(70, 70),
	Size = NumberSequence.new(0.45),
	Rotation = NumberRange.new(0, 360),
	RotSpeed = NumberRange.new(-120, 120),
	Transparency = NumberSequence.new(0.3),
	Color = ColorSequence.new(Color3.fromRGB(150, 126, 84), Color3.fromRGB(110, 120, 70)),
	Drag = 1.5,
	WindAffectsDrag = true,
})
if Config.TexturaLluvia ~= "" then
	lluvia.Texture = Config.TexturaLluvia
end
if Config.TexturaNieve ~= "" then
	nieve.Texture = Config.TexturaNieve
end

-- =====================================================================
--  Sonidos en bucle (los huecos vacíos de la configuración no suenan)
-- =====================================================================
local sonidos = {}
for nombre, id in pairs(Config.Sonidos) do
	if nombre ~= "Truenos" and nombre ~= "Fuego" and id ~= "" then
		local s = Instance.new("Sound")
		s.Name = "Clima" .. nombre
		s.SoundId = id
		s.Looped = true
		s.Volume = 0
		if nombre == "Viento" then
			s.PlaybackSpeed = 0.6
		end
		local apagado = Instance.new("EqualizerSoundEffect")
		apagado.HighGain = -25
		apagado.MidGain = -8
		apagado.LowGain = 0
		apagado.Enabled = false
		apagado.Parent = s
		s.Parent = SoundService
		s:Play()
		sonidos[nombre] = s
	end
end

-- =====================================================================
--  ¿Hay techo encima? (deja de llover encima y se apagan los sonidos)
-- =====================================================================
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
local dentro = false
local function comprobarTecho()
	local filtro = { emisor }
	if jugador.Character then
		table.insert(filtro, jugador.Character)
	end
	params.FilterDescendantsInstances = filtro
	dentro = workspace:Raycast(camara.CFrame.Position, Vector3.new(0, 150, 0), params) ~= nil
end

-- =====================================================================
--  Relámpagos y truenos
-- =====================================================================
local destello = Instance.new("ColorCorrectionEffect")
destello.Name = "Relampago"
destello.Parent = Lighting

local function relampago(pos)
	local suelo = pos
	local golpe = workspace:Raycast(pos + Vector3.new(0, 600, 0), Vector3.new(0, -1200, 0))
	if golpe then
		suelo = golpe.Position
	end
	-- Rayo en zigzag
	local tramos = {}
	local p = suelo + Vector3.new(0, 420, 0)
	for i = 1, 10 do
		local siguiente = (i == 10) and suelo or (p + Vector3.new(math.random(-20, 20), -42, math.random(-20, 20)))
		local t = Instance.new("Part")
		t.Anchored = true
		t.CanCollide = false
		t.CanQuery = false
		t.CanTouch = false
		t.CastShadow = false
		t.Material = Enum.Material.Neon
		t.Color = Color3.fromRGB(214, 226, 255)
		t.Size = Vector3.new(0.9, 0.9, (siguiente - p).Magnitude)
		t.CFrame = CFrame.lookAt((p + siguiente) / 2, siguiente)
		t.Parent = camara
		table.insert(tramos, t)
		p = siguiente
	end
	local luz = Instance.new("PointLight")
	luz.Range = 60
	luz.Brightness = 8
	luz.Color = Color3.fromRGB(200, 214, 255)
	luz.Parent = tramos[#tramos]
	destello.Brightness = dentro and 0.15 or 0.5
	TweenService:Create(destello, TweenInfo.new(0.4), { Brightness = 0 }):Play()
	task.delay(0.18, function()
		for _, t in ipairs(tramos) do
			t:Destroy()
		end
	end)
	-- El trueno llega más tarde y más flojo cuanto más lejos cae el rayo
	local ids = {}
	for _, id in ipairs(Config.Sonidos.Truenos or {}) do
		if id ~= "" then
			table.insert(ids, id)
		end
	end
	if #ids > 0 then
		local distancia = (suelo - camara.CFrame.Position).Magnitude
		task.delay(distancia / 1200, function()
			local s = Instance.new("Sound")
			s.SoundId = ids[math.random(1, #ids)]
			s.Volume = math.clamp(1.4 - distancia / 1200, 0.25, 1) * (dentro and 0.6 or 1)
			s.PlaybackSpeed = 0.9 + math.random() * 0.2
			s.Parent = SoundService
			s:Play()
			Debris:AddItem(s, 20)
		end)
	end
end
ReplicatedStorage:WaitForChild("ClimaRayo").OnClientEvent:Connect(relampago)

-- =====================================================================
--  Fuegos: la luz parpadea como una llama y, si hay ID, se oye crepitar al acercarse
-- =====================================================================
local lucesFuego = {}
local function nuevaLuz(luz)
	lucesFuego[luz] = { base = luz:GetAttribute("Base") or luz.Brightness, semilla = math.random() * 100 }
end
local function nuevoFuego(pieza)
	if (Config.Sonidos.Fuego or "") ~= "" and not pieza:FindFirstChild("Crepitar") then
		local s = Instance.new("Sound")
		s.Name = "Crepitar"
		s.SoundId = Config.Sonidos.Fuego
		s.Looped = true
		s.Volume = 0.6
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = 6
		s.RollOffMaxDistance = 60
		s.Parent = pieza
		s:Play()
	end
end
for _, luz in ipairs(CollectionService:GetTagged("LuzFuego")) do
	nuevaLuz(luz)
end
CollectionService:GetInstanceAddedSignal("LuzFuego"):Connect(nuevaLuz)
CollectionService:GetInstanceRemovedSignal("LuzFuego"):Connect(function(luz)
	lucesFuego[luz] = nil
end)
for _, pieza in ipairs(CollectionService:GetTagged("Fuego")) do
	nuevoFuego(pieza)
end
CollectionService:GetInstanceAddedSignal("Fuego"):Connect(nuevoFuego)

-- =====================================================================
--  Bucle: sigue a la cámara y mezcla suavemente partículas y sonidos
-- =====================================================================
local tasas = { Lluvia = 0, Nieve = 0, Polvo = 0 }
local siguienteTecho = 0
RunService.RenderStepped:Connect(function(dt)
	local clima = Config.Climas[ReplicatedStorage:GetAttribute("Clima") or ""] or Config.Climas.Nublado
	local cf = camara.CFrame
	local delante = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z) * 25
	emisor.CFrame = CFrame.new(cf.Position + Vector3.new(0, 70, 0) + delante)

	if os.clock() >= siguienteTecho then
		siguienteTecho = os.clock() + 0.25
		comprobarTecho()
	end

	local mezcla = math.min(1, dt * 0.4)
	local fuera = dentro and 0 or 1
	tasas.Lluvia = tasas.Lluvia + (clima.lluvia * fuera - tasas.Lluvia) * mezcla
	tasas.Nieve = tasas.Nieve + (clima.nieve * fuera - tasas.Nieve) * mezcla
	tasas.Polvo = tasas.Polvo + (clima.polvo * fuera - tasas.Polvo) * mezcla
	lluvia.Rate = tasas.Lluvia
	nieve.Rate = tasas.Nieve
	polvo.Rate = tasas.Polvo

	local fuerzaViento = math.clamp(workspace.GlobalWind.Magnitude / 45, 0.3, 1.3)
	for nombre, s in pairs(sonidos) do
		local objetivo = (clima.sonidos[nombre] or 0) * (dentro and 0.4 or 1)
		if nombre == "Viento" then
			objetivo = objetivo * fuerzaViento
		end
		s.Volume = s.Volume + (objetivo - s.Volume) * math.min(1, dt * 0.6)
		s.EqualizerSoundEffect.Enabled = dentro
	end

	local t = os.clock()
	for luz, d in pairs(lucesFuego) do
		luz.Brightness = d.base * (0.82 + 0.26 * math.noise(t * 6, d.semilla) + 0.12 * math.noise(t * 17, d.semilla + 50))
	end
end)
]=]
local CAZA_CONFIG = [=[
--[[
	Configuración de la caza, la pesca y las armas del mundo abierto (va en ReplicatedStorage como CazaConfig).
	La usan CazaServidor (animales, disparos, pesca, tienda y dinero) y CazaCliente (controles, pantalla y efectos).

	Todo está pensado para ser realista:
	  · Distancias en METROS, velocidades en METROS POR SEGUNDO y pesos en KILOS (el código lo pasa a studs).
	  · Las balas y las flechas vuelan con su velocidad real y caen por la gravedad.
	  · Un disparo en la cabeza o en el pecho (corazón y pulmones) mata mucho antes que en las patas.
	  · Un animal herido sangra, huye y deja rastro de sangre hasta que cae.
	  · Los animales te huelen si el viento les lleva tu olor, te oyen si corres y huyen de los disparos.
	  · Al despellejar se saca la carne según el peso del animal y la piel vale menos si está destrozada.
]]
local Config = {}

-- Un personaje de Roblox mide 5 studs (1,75 m): 1 metro = 2,9 studs
Config.StudsPorMetro = 2.9
-- Gravedad real (9,81 m/s²) para balas, flechas y lanzables
Config.Gravedad = 9.81

-- =====================================================================
--  General
-- =====================================================================
Config.DineroInicial = 150
-- Lo que tiene cada jugador nuevo
Config.KitInicial = { armas = { "Cuchillo", "Arco" }, canas = { "CanaBambu" }, municion = { Flechas = 12 } }
-- Las armas también hacen daño a otros jugadores (false = solo a los animales)
Config.DanoEntreJugadores = false
-- Guardar dinero, equipo y capturas entre partidas (necesita el juego publicado; para probarlo en Studio
-- activa "Permitir acceso de Studio a los servicios de API" en la configuración del juego)
Config.GuardarDatos = true

-- Cómo te detectan los animales (se multiplica la distancia de huida o de ataque)
Config.Deteccion = {
	Agachado = 0.5,       -- tecla C: andas despacio y casi no te ven
	Corriendo = 1.4,      -- moverse rápido hace ruido
	VientoAFavor = 1.6,   -- el viento lleva tu olor hacia el animal
	VientoEnContra = 0.7, -- el viento sopla de él hacia ti: no te huele
}

-- =====================================================================
--  Sonidos: pega IDs de la Caja de herramientas como "rbxassetid://NUMERO" ("" = sin sonido)
-- =====================================================================
Config.Sonidos = {
	Pistola = "", Revolver = "", Escopeta = "", RifleCaza = "", Fusil = "", Subfusil = "", Francotirador = "",
	Arco = "", Ballesta = "", Recarga = "", Vacio = "", Impacto = "",
	Cuerpo = "rbxasset://sounds/swordslash.wav", -- golpe cuerpo a cuerpo (viene con Roblox)
	Lanzar = "rbxasset://sounds/swordlunge.wav", -- lanzar molotov o granada (viene con Roblox)
	Chapoteo = "rbxasset://sounds/impact_water.mp3", -- el anzuelo cae al agua (viene con Roblox)
	Carrete = "", Picada = "", Captura = "", SedalRoto = "", Caja = "",
	Lobo = "", Oso = "", Jabali = "", Ciervo = "", Pato = "", Pavo = "", Conejo = "", Cangrejo = "",
}

-- =====================================================================
--  Munición (se compra por cajas en la tienda)
-- =====================================================================
Config.Municion = {
	Flechas = { nombre = "Flechas de caza", paquete = 6, precio = 18, orden = 1 },
	Virotes = { nombre = "Virotes de ballesta", paquete = 6, precio = 24, orden = 2 },
	Pistola = { nombre = "Cartuchos 9 mm", paquete = 30, precio = 28, orden = 3 },
	Revolver = { nombre = "Cartuchos .357 Magnum", paquete = 18, precio = 30, orden = 4 },
	Cartuchos = { nombre = "Cartuchos del calibre 12", paquete = 10, precio = 30, orden = 5 },
	Rifle = { nombre = "Cartuchos .308", paquete = 10, precio = 40, orden = 6 },
	Fusil = { nombre = "Cartuchos 5,56 mm", paquete = 30, precio = 42, orden = 7 },
	Magnum = { nombre = "Cartuchos .338 Lapua", paquete = 5, precio = 55, orden = 8 },
	Molotov = { nombre = "Cóctel molotov", paquete = 1, precio = 35, orden = 9 },
	Granada = { nombre = "Granada de fragmentación", paquete = 1, precio = 60, orden = 10 },
}

--[[
	ARMAS
	tipo: "cuerpo" (cuerpo a cuerpo), "bala" (arma de fuego), "proyectil" (arco y ballesta), "lanzable"
	dano: daño por golpe, bala o perdigón (un ciervo tiene 100 de vida; ver los multiplicadores por zona abajo)
	velocidad: m/s al salir del cañón · alcance: metros hasta que la bala se pierde
	cadencia: segundos entre disparos · cargador · recarga: segundos
	dispersion: grados de desvío parado (se dobla al moverte y se reduce agachado o apuntando)
	retroceso: cuánto sube la cámara al disparar · perdigones: balas por disparo (escopeta)
	automatica: se dispara manteniendo pulsado · zoom: campo de visión al apuntar (clic derecho)
	mira: con mira telescópica (pantalla de la mira al apuntar) · ruido: metros a los que espanta animales
	sangrado: cuánto sangra lo que hieres (las flechas matan por desangrado) · piel: daño que hace a la piel
	radio y duracion: explosión o fuego de los lanzables
]]
Config.Armas = {
	Cuchillo = { nombre = "Cuchillo de caza", tipo = "cuerpo", dano = 30, alcance = 2.2, cadencia = 0.45, sangrado = 0.5, piel = 0.1,
		precio = 0, orden = 1, desc = "Hoja de acero de 15 cm. Para rematar." },
	Bate = { nombre = "Bate de madera", tipo = "cuerpo", dano = 34, alcance = 2.6, cadencia = 0.8, sangrado = 0, piel = 0.2,
		precio = 40, orden = 2, desc = "Golpes contundentes." },
	Machete = { nombre = "Machete", tipo = "cuerpo", dano = 46, alcance = 2.6, cadencia = 0.7, sangrado = 0.6, piel = 0.25,
		precio = 90, orden = 3, desc = "Hoja de 45 cm." },
	Hacha = { nombre = "Hacha", tipo = "cuerpo", dano = 64, alcance = 2.6, cadencia = 1.1, sangrado = 0.5, piel = 0.35,
		precio = 140, orden = 4, desc = "Lenta pero brutal." },
	Lanza = { nombre = "Lanza de caza", tipo = "cuerpo", dano = 52, alcance = 3.6, cadencia = 0.95, sangrado = 0.7, piel = 0.15,
		precio = 120, orden = 5, desc = "Asta de 2 m con punta de acero. Llega más lejos." },
	Arco = { nombre = "Arco recurvo", tipo = "proyectil", municion = "Flechas", dano = 70, velocidad = 60, alcance = 90, cadencia = 1,
		cargador = 1, recarga = 0.9, dispersion = 0.4, retroceso = 0, ruido = 0, sangrado = 0.9, piel = 0.05,
		precio = 0, orden = 6, desc = "Silencioso. La flecha cae con la distancia: apunta por encima si está lejos." },
	Ballesta = { nombre = "Ballesta", tipo = "proyectil", municion = "Virotes", dano = 95, velocidad = 100, alcance = 120, cadencia = 1,
		cargador = 1, recarga = 2.2, dispersion = 0.25, retroceso = 0.4, ruido = 8, sangrado = 0.9, piel = 0.05, zoom = 45, mira = true,
		precio = 320, orden = 7, desc = "Más potente y plana que el arco. Recarga lenta." },
	Pistola = { nombre = "Pistola 9 mm", tipo = "bala", municion = "Pistola", dano = 30, velocidad = 360, alcance = 120, cadencia = 0.18,
		cargador = 15, recarga = 1.6, dispersion = 1.1, retroceso = 1.6, ruido = 160, sangrado = 0.4, piel = 0.15,
		precio = 220, orden = 8, desc = "15 balas. Poca potencia para caza mayor." },
	Revolver = { nombre = "Revólver .357 Magnum", tipo = "bala", municion = "Revolver", dano = 55, velocidad = 440, alcance = 150, cadencia = 0.55,
		cargador = 6, recarga = 2.8, dispersion = 0.8, retroceso = 3.6, ruido = 200, sangrado = 0.5, piel = 0.2,
		precio = 380, orden = 9, desc = "6 balas muy potentes." },
	Escopeta = { nombre = "Escopeta de corredera calibre 12", tipo = "bala", municion = "Cartuchos", dano = 16, perdigones = 9, velocidad = 400,
		alcance = 45, cadencia = 0.95, cargador = 5, recarga = 3.2, dispersion = 3.2, retroceso = 5, ruido = 240, sangrado = 0.3, piel = 0.6,
		precio = 480, orden = 10, desc = "9 perdigones por disparo. Letal de cerca, destroza la piel." },
	Subfusil = { nombre = "Subfusil 9 mm", tipo = "bala", municion = "Pistola", dano = 22, velocidad = 390, alcance = 100, cadencia = 0.075,
		automatica = true, cargador = 30, recarga = 2, dispersion = 2, retroceso = 0.9, ruido = 170, sangrado = 0.4, piel = 0.3, zoom = 60,
		precio = 640, orden = 11, desc = "Automático. Usa cartuchos de 9 mm." },
	RifleCaza = { nombre = "Rifle de cerrojo .308", tipo = "bala", municion = "Rifle", dano = 98, velocidad = 850, alcance = 600, cadencia = 1.3,
		cargador = 5, recarga = 3, dispersion = 0.12, retroceso = 4.2, ruido = 330, sangrado = 0.6, piel = 0.1, zoom = 22, mira = true,
		precio = 760, orden = 12, desc = "Mira 6x. El arma de caza mayor por excelencia." },
	Fusil = { nombre = "Fusil de asalto 5,56", tipo = "bala", municion = "Fusil", dano = 30, velocidad = 920, alcance = 450, cadencia = 0.085,
		automatica = true, cargador = 30, recarga = 2.4, dispersion = 1.2, retroceso = 1.3, ruido = 280, sangrado = 0.45, piel = 0.35, zoom = 50,
		precio = 900, orden = 13, desc = "Automático, 30 balas." },
	Francotirador = { nombre = "Rifle de francotirador .338", tipo = "bala", municion = "Magnum", dano = 170, velocidad = 900, alcance = 1500,
		cadencia = 1.8, cargador = 5, recarga = 3.6, dispersion = 0.04, retroceso = 6, ruido = 420, sangrado = 0.7, piel = 0.2, zoom = 8, mira = true,
		precio = 1450, orden = 14, desc = "Mira 12x. A 300 m la bala cae casi un metro." },
	Molotov = { nombre = "Cóctel molotov", tipo = "lanzable", municion = "Molotov", dano = 7, radio = 3.5, duracion = 9, velocidad = 16,
		cadencia = 1, ruido = 30, sangrado = 0, piel = 1, precio = 0, orden = 15, desc = "Incendia el suelo unos segundos." },
	Granada = { nombre = "Granada de fragmentación", tipo = "lanzable", municion = "Granada", dano = 140, radio = 6, espoleta = 3, velocidad = 17,
		cadencia = 1, ruido = 500, sangrado = 0, piel = 1, precio = 0, orden = 16, desc = "Explota a los 3 segundos de lanzarla." },
}

-- Daño según dónde acierta (las piezas de los animales tienen estos nombres)
Config.Zonas = {
	Cabeza = 2.4, Cuello = 1.7, Pecho = 1.5, Cuerpo = 0.9, Pata = 0.5, Cola = 0.4,
}

--[[
	CAÑAS DE PESCAR
	distancia: metros que lanzas · recogida: metros por segundo que recoge el carrete
	resistencia: kilos de tirón que aguanta el sedal (un pez que pesa más tensa mucho más)
	rapidez: multiplica la espera hasta la picada (menos = antes) · suerte: más peces grandes y raros
]]
Config.Canas = {
	CanaBambu = { nombre = "Caña de bambú", distancia = 10, recogida = 1.4, resistencia = 4, rapidez = 1, suerte = 0, precio = 0, orden = 1,
		color = { 196, 170, 100 }, desc = "Sedal de 0,20 mm. Para percas y truchas." },
	CanaMadera = { nombre = "Caña de madera con carrete", distancia = 16, recogida = 1.7, resistencia = 8, rapidez = 0.92, suerte = 0.05, precio = 110, orden = 2,
		color = { 120, 82, 52 }, desc = "Sedal de 0,25 mm. Aguanta carpas medianas." },
	CanaFibra = { nombre = "Caña de fibra de vidrio", distancia = 24, recogida = 2.1, resistencia = 15, rapidez = 0.85, suerte = 0.1, precio = 320, orden = 3,
		color = { 60, 110, 160 }, desc = "Sedal de 0,30 mm. Ligera y resistente." },
	CanaCarbono = { nombre = "Caña de carbono", distancia = 32, recogida = 2.6, resistencia = 30, rapidez = 0.75, suerte = 0.18, precio = 780, orden = 4,
		color = { 40, 40, 44 }, desc = "Trenzado de 0,20 mm. Lucios y siluros." },
	CanaMar = { nombre = "Caña de mar (surfcasting)", distancia = 45, recogida = 3, resistencia = 70, rapidez = 0.8, suerte = 0.15, precio = 1250, orden = 5,
		color = { 210, 210, 206 }, desc = "4,2 m y carrete grande. Para pescar desde la playa." },
	CanaCurrican = { nombre = "Caña de curricán", distancia = 50, recogida = 3.6, resistencia = 220, rapidez = 0.65, suerte = 0.3, precio = 3200, orden = 6,
		color = { 214, 170, 60 }, desc = "Carrete de altura. Atunes, peces espada y esturiones." },
}

-- Cuánto tardan en picar según el clima (menos = antes): con lluvia y nublado pican más
Config.ClimaPesca = { Soleado = 1.15, Nublado = 0.9, Niebla = 0.85, Viento = 1.05, Lluvia = 0.7, Tormenta = 0.65, Nieve = 1.25 }
-- Segundos de espera hasta la picada (antes de aplicar la caña y el clima)
Config.EsperaPicada = { 7, 20 }
-- Segundos que tienes para clavar el anzuelo cuando pican
Config.TiempoClavar = 1.4

--[[
	PECES (pesos reales; la mayoría salen pequeños y los ejemplares grandes son raros)
	aguas: rio, lago, mar · peso: kilos mínimo y máximo · precioKg · prob: frecuencia
	fuerza: lo que tira para su tamaño (0 a 1) · aguante: cuánto tarda en cansarse (0 a 1)
]]
Config.Peces = {
	Perca = { nombre = "Perca", aguas = { rio = true, lago = true }, peso = { 0.1, 1.8 }, precioKg = 9, prob = 30, fuerza = 0.2, aguante = 0.2, color = { 140, 150, 80 } },
	Trucha = { nombre = "Trucha común", aguas = { rio = true, lago = true }, peso = { 0.2, 4 }, precioKg = 12, prob = 30, fuerza = 0.45, aguante = 0.35, color = { 150, 140, 120 } },
	Carpa = { nombre = "Carpa", aguas = { lago = true }, peso = { 1, 20 }, precioKg = 6, prob = 22, fuerza = 0.4, aguante = 0.6, color = { 170, 140, 70 } },
	Lucio = { nombre = "Lucio", aguas = { lago = true, rio = true }, peso = { 1, 18 }, precioKg = 10, prob = 12, fuerza = 0.65, aguante = 0.45, color = { 110, 130, 80 } },
	Salmon = { nombre = "Salmón atlántico", aguas = { rio = true, mar = true }, peso = { 2, 20 }, precioKg = 16, prob = 12, fuerza = 0.7, aguante = 0.6, color = { 200, 120, 100 } },
	Siluro = { nombre = "Siluro", aguas = { lago = true, rio = true }, peso = { 4, 90 }, precioKg = 5, prob = 6, fuerza = 0.55, aguante = 0.85, color = { 80, 76, 70 } },
	Esturion = { nombre = "Esturión", aguas = { lago = true, rio = true }, peso = { 20, 200 }, precioKg = 22, prob = 1.2, fuerza = 0.7, aguante = 0.9, color = { 120, 120, 110 } },
	Caballa = { nombre = "Caballa", aguas = { mar = true }, peso = { 0.2, 1.6 }, precioKg = 8, prob = 30, fuerza = 0.5, aguante = 0.3, color = { 80, 120, 140 } },
	Lubina = { nombre = "Lubina", aguas = { mar = true }, peso = { 0.5, 9 }, precioKg = 15, prob = 22, fuerza = 0.55, aguante = 0.45, color = { 150, 160, 170 } },
	Bacalao = { nombre = "Bacalao", aguas = { mar = true }, peso = { 1, 40 }, precioKg = 9, prob = 14, fuerza = 0.45, aguante = 0.55, color = { 150, 140, 110 } },
	Atun = { nombre = "Atún rojo", aguas = { mar = true }, peso = { 15, 400 }, precioKg = 24, prob = 2.5, fuerza = 0.95, aguante = 0.95, color = { 60, 70, 110 } },
	PezEspada = { nombre = "Pez espada", aguas = { mar = true }, peso = { 30, 450 }, precioKg = 22, prob = 1, fuerza = 1, aguante = 0.9, color = { 70, 90, 130 } },
	BotaVieja = { nombre = "Bota vieja", aguas = { rio = true, lago = true, mar = true }, peso = { 0.4, 1 }, precioKg = 1, prob = 4, fuerza = 0, aguante = 0, basura = true, color = { 70, 56, 44 } },
}

-- Rareza según la frecuencia (para el color del aviso)
function Config.rareza(pez)
	if pez.basura then
		return "Basura", { 150, 140, 130 }
	elseif pez.prob >= 20 then
		return "Común", { 225, 225, 225 }
	elseif pez.prob >= 8 then
		return "Poco común", { 120, 220, 120 }
	elseif pez.prob >= 2 then
		return "Raro", { 110, 170, 255 }
	end
	return "Legendario", { 255, 190, 60 }
end

-- =====================================================================
--  Lo que se saca al despellejar (se vende en la tienda)
--  porKg: precio por kilo (la carne) · precio: precio por unidad (pieles, cornamentas...)
-- =====================================================================
Config.Objetos = {
	CarneCaza = { nombre = "Carne de caza menor", porKg = 7 },
	CarneVenado = { nombre = "Carne de venado", porKg = 11 },
	CarneJabali = { nombre = "Carne de jabalí", porKg = 9 },
	CarneOso = { nombre = "Carne de oso", porKg = 8 },
	PielConejo = { nombre = "Piel de conejo", precio = 6 },
	PielCiervo = { nombre = "Piel de ciervo", precio = 45 },
	Cornamenta = { nombre = "Cornamenta", precio = 70 },
	Colmillos = { nombre = "Colmillos de jabalí", precio = 30 },
	PielLobo = { nombre = "Piel de lobo", precio = 85 },
	PielOso = { nombre = "Piel de oso", precio = 220 },
	Garras = { nombre = "Garras de oso", precio = 60 },
	Plumas = { nombre = "Plumas", precio = 2 },
	Pinzas = { nombre = "Pinzas de cangrejo", precio = 8 },
}
-- Calidad de la piel según el daño que ha recibido (la escopeta y las explosiones la destrozan)
Config.CalidadPiel = { { 0.15, "Perfecta", 1.3 }, { 0.45, "Buena", 1 }, { 0.8, "Dañada", 0.5 }, { math.huge, "Destrozada", 0 } }

--[[
	ANIMALES (medidas y pesos reales)
	tipo: "presa" (huye), "neutral" (se defiende si le hieres o te acercas mucho), "depredador" (te caza)
	peso: kilos · rendimiento: parte del peso que es carne · vida (con el peso medio)
	andar / correr: m/s · huida / agresion: metros a los que reacciona · dano y espera: su ataque
	cantidad: cuántos hay en el mapa · grupo: tamaño de la manada
	donde: "prado", "bosque", "norte", "montana", "granja", "agua" (lagos y ríos), "playa"
	carne: objeto de carne · botin: otros objetos (piel, cornamenta...) · reaparicion: segundos
]]
Config.Animales = {
	Conejo = { nombre = "Conejo", tipo = "presa", peso = { 1, 2.4 }, rendimiento = 0.5, vida = 10, andar = 1.2, correr = 11, huida = 14,
		cantidad = 28, donde = "prado", carne = "CarneCaza", botin = { PielConejo = 1 }, reaparicion = 90 },
	Ciervo = { nombre = "Ciervo", tipo = "presa", peso = { 45, 120 }, rendimiento = 0.45, vida = 100, andar = 1.4, correr = 13, huida = 40,
		cantidad = 24, grupo = 2, donde = "bosque", carne = "CarneVenado", botin = { PielCiervo = 1 }, macho = { Cornamenta = 1 }, reaparicion = 150 },
	Pavo = { nombre = "Pavo salvaje", tipo = "presa", peso = { 4, 11 }, rendimiento = 0.55, vida = 14, andar = 1, correr = 7, huida = 22,
		cantidad = 16, grupo = 3, donde = "granja", carne = "CarneCaza", botin = { Plumas = 6 }, reaparicion = 90 },
	Jabali = { nombre = "Jabalí", tipo = "neutral", peso = { 50, 140 }, rendimiento = 0.5, vida = 130, andar = 1.3, correr = 10, huida = 0,
		agresion = 5, dano = 18, espera = 1.3, cantidad = 14, grupo = 2, donde = "bosque", carne = "CarneJabali", botin = { Colmillos = 1 },
		reaparicion = 150 },
	Lobo = { nombre = "Lobo gris", tipo = "depredador", peso = { 30, 65 }, rendimiento = 0, vida = 75, andar = 1.8, correr = 11, agresion = 35,
		dano = 9, espera = 1.5, cantidad = 12, grupo = 3, donde = "norte", botin = { PielLobo = 1 }, reaparicion = 180 },
	Oso = { nombre = "Oso pardo", tipo = "depredador", peso = { 150, 380 }, rendimiento = 0.4, vida = 420, andar = 1.3, correr = 10, agresion = 25,
		dano = 42, espera = 1.7, cantidad = 6, donde = "montana", carne = "CarneOso", botin = { PielOso = 1, Garras = 1 }, reaparicion = 300 },
	Pato = { nombre = "Ánade real", tipo = "presa", peso = { 0.9, 1.5 }, rendimiento = 0.6, vida = 8, andar = 0.6, correr = 3, huida = 18,
		cantidad = 18, grupo = 3, donde = "agua", carne = "CarneCaza", botin = { Plumas = 3 }, reaparicion = 90 },
	Cangrejo = { nombre = "Cangrejo de mar", tipo = "presa", peso = { 0.3, 1.2 }, rendimiento = 0.3, vida = 6, andar = 0.4, correr = 1.6, huida = 4,
		cantidad = 16, donde = "playa", carne = "CarneCaza", botin = { Pinzas = 2 }, reaparicion = 90 },
}
-- Los animales solo se mueven si hay algún jugador a menos de estos metros (ahorra servidor)
Config.DistanciaActiva = 160

return Config
]=]
local CAZA_SERVIDOR = [=[
--[[
	CazaServidor (va en ServerScriptService, con sus módulos dentro): caza, pesca y armas del mundo abierto.
	  Modelos   animales a tamaño real, armas, cañas y corcho
	  Animales  aparición, comportamiento, heridas y despiece
	  Armas     disparos con balística real, cuerpo a cuerpo, recarga, granadas y molotov
	  Pesca     lanzar, picada y pelea con el pez
	  Economia  dinero, mochila, equipo, tiendas y guardado
	Se configura en ReplicatedStorage.CazaConfig.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage:WaitForChild("CazaConfig"))
local Modelos = require(script:WaitForChild("Modelos"))
local Animales = require(script:WaitForChild("Animales"))
local Armas = require(script:WaitForChild("Armas"))
local Pesca = require(script:WaitForChild("Pesca"))
local Economia = require(script:WaitForChild("Economia"))

-- Eventos entre servidor y jugadores
local carpeta = ReplicatedStorage:FindFirstChild("CazaRemotos") or Instance.new("Folder")
carpeta.Name = "CazaRemotos"
carpeta.Parent = ReplicatedStorage
local function remoto(nombre)
	local r = carpeta:FindFirstChild(nombre) or Instance.new("RemoteEvent")
	r.Name = nombre
	r.Parent = carpeta
	return r
end
local remotos = {
	Accion = remoto("Accion"), -- jugador -> servidor: disparar, golpear, recargar, lanzar, comprar, vender, agachado
	Pesca = remoto("Pesca"), -- ida y vuelta: lanzar, clavar, resultado / esperando, picada, pelea, capturado...
	Efectos = remoto("Efectos"), -- servidor -> todos: balas, flechas, impactos, explosiones
	Aviso = remoto("Aviso"), -- servidor -> un jugador: avisos en pantalla
	Estado = remoto("Estado"), -- servidor -> un jugador: dinero, equipo y mochila
	Tienda = remoto("Tienda"), -- servidor -> un jugador: abrir la tienda
}

-- Datos del mapa (zonas, lagos y costa) del mundo abierto, si está instalado
local W
do
	local ok, res = pcall(function()
		local modulo = ServerStorage:WaitForChild("MundoAbierto", 10)
		return require(modulo:WaitForChild("Datos"))({}, { Props = {} })
	end)
	if ok then
		W = res
	else
		warn("[Caza] Sin datos del mundo abierto; los animales aparecerán en cualquier sitio:", res)
	end
end

local ctx = {
	Config = Config, Modelos = Modelos, W = W, remotos = remotos,
	Animales = Animales, Armas = Armas, Pesca = Pesca, Economia = Economia,
}
function ctx.darBotin(jugador, botin, animal)
	Economia.darBotin(jugador, botin, animal)
end
function ctx.alMatar(jugador, animal)
	if jugador then
		remotos.Aviso:FireClient(jugador, "abatido", { nombre = animal.def.nombre, peso = animal.peso })
	end
end
function ctx.alAtacar(jugador, animal)
	remotos.Aviso:FireClient(jugador, "atacado", { nombre = animal.def.nombre })
end

Economia.iniciar(ctx)
Armas.iniciar(ctx)
Pesca.iniciar(ctx)

-- Límite de mensajes por jugador (para que nadie sature el servidor)
local cuenta = {}
local function permitido(jugador)
	local t = os.clock()
	local c = cuenta[jugador]
	if not c or t - c.desde > 1 then
		c = { desde = t, n = 0 }
		cuenta[jugador] = c
	end
	c.n = c.n + 1
	return c.n <= 40
end
Players.PlayerRemoving:Connect(function(p)
	cuenta[p] = nil
end)

remotos.Accion.OnServerEvent:Connect(function(jugador, accion, a, b, c)
	if not permitido(jugador) then
		return
	end
	if accion == "disparar" then
		Armas.disparar(jugador, a, b, c)
	elseif accion == "golpear" then
		Armas.golpear(jugador, a, b)
	elseif accion == "recargar" then
		Armas.recargar(jugador, a)
	elseif accion == "lanzar" then
		Armas.lanzar(jugador, a, b)
	elseif accion == "comprar" then
		Economia.comprar(jugador, a, b)
	elseif accion == "vender" then
		Economia.vender(jugador)
	elseif accion == "agachado" then
		jugador:SetAttribute("Agachado", a == true)
	elseif accion == "estado" then
		Economia.enviar(jugador)
	end
end)

remotos.Pesca.OnServerEvent:Connect(function(jugador, accion, a, b)
	if not permitido(jugador) then
		return
	end
	if accion == "lanzar" then
		Pesca.lanzar(jugador, a)
	elseif accion == "clavar" then
		Pesca.clavar(jugador)
	elseif accion == "resultado" then
		Pesca.resultado(jugador, a, b)
	elseif accion == "recoger" then
		Pesca.recoger(jugador)
	end
end)

-- Los animales se reparten por el mapa (tarda unos segundos)
task.spawn(function()
	local n = Animales.iniciar(ctx)
	print(string.format("[Caza] %d animales en el mapa", n))
end)
]=]
local CAZA_CLIENTE = [=[
--[[
	CazaCliente (va en StarterPlayer > StarterPlayerScripts, con sus módulos dentro).

	Controles:
	  Armas de fuego, arco y ballesta: clic para disparar (mantén pulsado con las automáticas),
	    clic derecho para apuntar (las de mira muestran la mira telescópica), R para recargar.
	    Con un arma a distancia la cámara se pone por encima del hombro y el ratón queda en el centro.
	  Cuerpo a cuerpo: clic para golpear. Molotov y granada: clic para lanzar donde apuntas.
	  C: agacharse (los animales te detectan mucho menos) · Mayús: correr (haces más ruido) · B: mochila.
	  Caña: clic para lanzar donde apuntas, clic otra vez para recoger. Cuando el corcho se hunde: clic
	    para clavar. Luego mantén pulsado para recoger sedal y suéltalo cuando la tensión esté en rojo.
	En móvil: toca para disparar o lanzar y usa los botones de la pantalla.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage:WaitForChild("CazaConfig"))
local remotos = ReplicatedStorage:WaitForChild("CazaRemotos")
local Accion = remotos:WaitForChild("Accion")
local PescaR = remotos:WaitForChild("Pesca")
local EfectosR = remotos:WaitForChild("Efectos")
local Aviso = remotos:WaitForChild("Aviso")
local Estado = remotos:WaitForChild("Estado")
local Tienda = remotos:WaitForChild("Tienda")
local Pantalla = require(script:WaitForChild("Pantalla"))
local Efectos = require(script:WaitForChild("Efectos"))

local jugador = Players.LocalPlayer
local camara = workspace.CurrentCamera
local M = Config.StudsPorMetro
local FOV = 70
local VELOCIDAD = { normal = 16, agachado = 7, corriendo = 24 }
local esMovil = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

Pantalla.crear(Config)
Efectos.iniciar(Config)

local e = {
	tool = nil, id = nil, cfg = nil, cana = nil, tirador = false, apuntando = false, disparando = false,
	agachado = false, corriendo = false, ultimo = 0, retroceso = 0, floracion = 0, datos = nil, conexiones = {},
}
local pesca = { fase = nil }

local function humanoide()
	local char = jugador.Character
	return char and char:FindFirstChildOfClass("Humanoid"), char and char:FindFirstChild("HumanoidRootPart")
end

local function sonido(id, volumen)
	if id and id ~= "" then
		local s = Instance.new("Sound")
		s.SoundId = id
		s.Volume = volumen or 0.8
		s.Parent = SoundService
		s:Play()
		game:GetService("Debris"):AddItem(s, 6)
	end
end

-- =====================================================================
--  Hacia dónde apuntas
-- =====================================================================
local paramsMira = RaycastParams.new()
paramsMira.FilterType = Enum.RaycastFilterType.Exclude
local function puntoApuntado()
	local excluir = { jugador.Character }
	for _, n in ipairs({ "EfectosLocales", "EfectosCaza", "Corchos", "RastrosSangre" }) do
		local f = workspace:FindFirstChild(n)
		if f then
			table.insert(excluir, f)
		end
	end
	paramsMira.FilterDescendantsInstances = excluir
	local pantalla
	if e.tirador or esMovil then
		pantalla = camara.ViewportSize / 2
	else
		pantalla = UserInputService:GetMouseLocation()
	end
	local rayo = camara:ViewportPointToRay(pantalla.X, pantalla.Y)
	local res = workspace:Raycast(rayo.Origin, rayo.Direction * 3000, paramsMira)
	return res and res.Position or (rayo.Origin + rayo.Direction * 3000)
end

-- =====================================================================
--  Movimiento: agacharse y correr
-- =====================================================================
local function aplicarVelocidad()
	local hum = humanoide()
	if not hum then
		return
	end
	if e.agachado then
		hum.WalkSpeed = VELOCIDAD.agachado
	elseif e.corriendo and not e.apuntando then
		hum.WalkSpeed = VELOCIDAD.corriendo
	else
		hum.WalkSpeed = VELOCIDAD.normal
	end
	local hombro = e.tirador and Vector3.new(1.6, 0.4, 0) or Vector3.new()
	hum.CameraOffset = hombro + (e.agachado and Vector3.new(0, -1.3, 0) or Vector3.new())
end

local function agacharse(valor)
	if valor == nil then
		valor = not e.agachado
	end
	e.agachado = valor
	Accion:FireServer("agachado", valor)
	aplicarVelocidad()
	Pantalla.aviso(valor and "Agachado: te detectan mucho menos" or "De pie", Color3.fromRGB(190, 190, 180), 1.5)
end

-- =====================================================================
--  Armas
-- =====================================================================
local function reserva()
	local cfg = e.cfg
	return (cfg and cfg.municion) and (jugador:GetAttribute("Municion_" .. cfg.municion) or 0) or 0
end

local function refrescarArma()
	if not e.tool then
		Pantalla.arma(nil)
		return
	end
	if e.cana then
		Pantalla.arma(e.cana.nombre, string.format("%d m", e.cana.distancia), "Clic: lanzar · clic otra vez: recoger")
		return
	end
	local cfg = e.cfg
	if cfg.tipo == "cuerpo" then
		Pantalla.arma(cfg.nombre, "", "Clic: golpear · C: agacharse")
	elseif cfg.tipo == "lanzable" then
		Pantalla.arma(cfg.nombre, "x" .. reserva(), "Clic: lanzar donde apuntas")
	else
		local linea
		if e.tool:GetAttribute("Recargando") then
			linea = "Recargando…"
		else
			linea = string.format("%d / %d", e.tool:GetAttribute("Cargador") or 0, reserva())
		end
		Pantalla.arma(cfg.nombre, linea, esMovil and "Toca: disparar" or "Clic: disparar · clic der.: apuntar · R: recargar")
	end
end

local function disparar()
	local cfg = e.cfg
	if not cfg or not e.tool then
		return
	end
	local t = os.clock()
	if t - e.ultimo < cfg.cadencia then
		return
	end
	if cfg.tipo == "cuerpo" then
		e.ultimo = t
		Accion:FireServer("golpear", e.id, camara.CFrame.LookVector)
		return
	end
	if cfg.tipo == "lanzable" then
		e.ultimo = t
		Accion:FireServer("lanzar", e.id, puntoApuntado())
		return
	end
	if e.tool:GetAttribute("Recargando") then
		return
	end
	if (e.tool:GetAttribute("Cargador") or 0) <= 0 then
		e.ultimo = t
		sonido(Config.Sonidos.Vacio, 0.6)
		if reserva() > 0 then
			Accion:FireServer("recargar", e.id)
		else
			Pantalla.aviso("Sin munición: compra " .. Config.Municion[cfg.municion].nombre:lower() .. " en una tienda de caza", Color3.fromRGB(230, 120, 100), 3)
		end
		return
	end
	e.ultimo = t
	Accion:FireServer("disparar", e.id, puntoApuntado(), e.apuntando)
	e.retroceso = e.retroceso + (cfg.retroceso or 0)
	e.floracion = math.min(e.floracion + (cfg.dispersion or 0) * 1.2, 8)
end

local function recargar()
	if e.cfg and e.cfg.cargador and e.tool and not e.tool:GetAttribute("Recargando") then
		Accion:FireServer("recargar", e.id)
	end
end

local function apuntar(valor)
	if not e.cfg or e.cfg.tipo == "cuerpo" then
		valor = false
	end
	e.apuntando = valor
	aplicarVelocidad()
end

-- =====================================================================
--  Pesca
-- =====================================================================
local pelea
local tocando = false

local function terminarPesca(texto, color)
	pesca.fase = nil
	pelea = nil
	Pantalla.pesca(false)
	if texto then
		Pantalla.aviso(texto, color, 4)
	end
end

local function clicCana()
	if pesca.fase == nil then
		pesca.fase = "lanzando"
		Pantalla.pesca(true, "Lanzando…", "")
		Pantalla.tension(nil)
		PescaR:FireServer("lanzar", puntoApuntado())
	elseif pesca.fase == "esperando" then
		PescaR:FireServer("recoger")
		terminarPesca()
	elseif pesca.fase == "picando" then
		pesca.fase = "clavando"
		PescaR:FireServer("clavar")
	end
end

-- Pelea con el pez: el pez tira en arrancadas y se cansa. Recoges manteniendo pulsado; con mucha tensión
-- el sedal se rompe y si sueltas demasiado sedal el pez se escapa.
local function empezarPelea(d)
	pesca.fase = "luchando"
	pelea = {
		dist = d.distancia, inicial = d.distancia, tension = 0.15, aguante = 1, tirando = false, siguiente = os.clock() + 0.6,
		fin = 0, d = d, t0 = os.clock(),
	}
	Pantalla.pesca(true, d.grande and "¡Algo grande ha picado!" or "¡Clavado!", "")
	Pantalla.tension(0.15)
end

local function actualizarPelea(dt)
	local p = pelea
	local d = p.d
	local t = os.clock()
	local pulsado = tocando or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
	-- Arrancadas del pez (más largas y seguidas cuanto más fuerte y fresco está)
	if d.basura then
		p.tirando = false
	elseif not p.tirando and t >= p.siguiente then
		p.tirando = true
		p.fin = t + (0.6 + 1.8 * d.fuerza * p.aguante) * (0.6 + math.random() * 0.8)
	elseif p.tirando and t >= p.fin then
		p.tirando = false
		p.siguiente = t + (1 + 2.2 * (1 - d.fuerza)) * (0.6 + math.random() * 0.8)
	end
	local potencia = (0.25 + d.fuerza * 0.75) * math.min(1.6, d.ratio * 0.9 + 0.35) * (0.35 + 0.65 * p.aguante)
	if d.basura then
		potencia = 0.06
	end
	if pulsado then
		p.dist = p.dist - d.recogida * dt * (p.tirando and 0.25 or 1)
		p.tension = p.tension + (p.tirando and potencia * 1.1 or (0.12 + potencia * 0.2)) * dt
		if p.tirando then
			p.aguante = math.max(0, p.aguante - dt * 0.07 * (1.25 - d.aguante))
		end
	else
		p.tension = p.tension - 0.5 * dt
		if p.tirando then
			p.dist = p.dist + d.recogida * potencia * 0.9 * dt
		end
	end
	p.tension = math.clamp(p.tension, 0, 1.05)
	local aviso = p.tirando and "¡Tira fuerte! Suelta si la tensión sube" or (pulsado and "Recogiendo…" or "Mantén pulsado para recoger")
	Pantalla.tension(p.tension, string.format("Sedal: %d m · %s", math.max(0, math.floor(p.dist / M + 0.5)), pulsado and "carrete girando" or "carrete suelto"), aviso)
	-- (la fase se cambia antes de avisar al servidor, por si la respuesta llega enseguida)
	if p.tension >= 1 then
		pesca.fase = "esperandoResultado"
		PescaR:FireServer("resultado", false, "sedal")
	elseif p.dist > p.inicial + 15 * M then
		pesca.fase = "esperandoResultado"
		PescaR:FireServer("resultado", false, "escapado")
	elseif p.dist <= 2 then
		pesca.fase = "esperandoResultado"
		PescaR:FireServer("resultado", true)
	end
end

PescaR.OnClientEvent:Connect(function(que, d)
	d = d or {}
	if que == "esperando" then
		pesca.fase = "esperando"
		local aguas = { rio = "río", lago = "lago", mar = "mar" }
		Pantalla.pesca(true, "Esperando a que piquen…", "Pescando en " .. (aguas[d.agua] or "agua") .. " · clic para recoger")
		Pantalla.tension(nil)
	elseif que == "sinAgua" then
		terminarPesca("Ahí no hay agua. Apunta a un río, un lago o el mar.", Color3.fromRGB(200, 200, 190))
	elseif que == "picada" then
		pesca.fase = "picando"
		Pantalla.pesca(true, "¡PICAN! Clic para clavar", "")
		sonido(Config.Sonidos.Picada, 0.9)
		Efectos.sacudir(0.25)
	elseif que == "pelea" then
		empezarPelea(d)
	elseif que == "capturado" then
		local pez = Config.Peces[d.id]
		local rareza, color = Config.rareza(pez)
		terminarPesca()
		sonido(Config.Sonidos.Captura, 0.9)
		Pantalla.aviso(string.format("%s · %s · %s (%s)%s", d.nombre, Pantalla.kg(d.peso), rareza, Pantalla.dineroTexto(d.valor), d.record and " · ¡RÉCORD!" or ""),
			Color3.fromRGB(color[1], color[2], color[3]), 6)
	elseif que == "escapado" then
		if d.motivo == "tarde" then
			pesca.fase = "esperando"
			Pantalla.pesca(true, "Esperando a que piquen…", "Se ha soltado: hay que clavar más rápido")
		else
			terminarPesca("El pez se ha escapado.", Color3.fromRGB(220, 200, 150))
		end
	elseif que == "sedalRoto" then
		sonido(Config.Sonidos.SedalRoto, 0.9)
		terminarPesca(d.motivo == "grande" and "¡Se ha roto el sedal! Ese pez es demasiado grande para esta caña." or "¡Se ha roto el sedal por la tensión!", Color3.fromRGB(230, 110, 90))
	elseif que == "recogido" then
		terminarPesca()
	end
end)

-- =====================================================================
--  Equipar y guardar herramientas
-- =====================================================================
local function desconectar()
	for _, c in ipairs(e.conexiones) do
		c:Disconnect()
	end
	e.conexiones = {}
end

local function alGuardar()
	desconectar()
	if pesca.fase then
		PescaR:FireServer("recoger")
		terminarPesca()
	end
	e.tool, e.id, e.cfg, e.cana = nil, nil, nil, nil
	e.tirador, e.disparando = false, false
	apuntar(false)
	local hum = humanoide()
	if hum then
		hum.AutoRotate = true
	end
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	aplicarVelocidad()
	Pantalla.arma(nil)
	Pantalla.mira(false, 0)
	Pantalla.telescopica(false)
end

local function alEquipar(tool)
	alGuardar()
	local armaId, canaId = tool:GetAttribute("Arma"), tool:GetAttribute("Cana")
	if not armaId and not canaId then
		return
	end
	e.tool = tool
	if canaId then
		e.id, e.cana = canaId, Config.Canas[canaId]
		table.insert(e.conexiones, tool.Activated:Connect(clicCana))
	else
		e.id, e.cfg = armaId, Config.Armas[armaId]
		e.tirador = e.cfg.tipo ~= "cuerpo"
		local hum = humanoide()
		if hum and e.tirador and not esMovil then
			hum.AutoRotate = false
		end
		table.insert(e.conexiones, tool.Activated:Connect(function()
			e.disparando = true
			disparar()
		end))
		table.insert(e.conexiones, tool.Deactivated:Connect(function()
			e.disparando = false
		end))
		for _, atributo in ipairs({ "Cargador", "Recargando" }) do
			table.insert(e.conexiones, tool:GetAttributeChangedSignal(atributo):Connect(refrescarArma))
		end
		if e.cfg.municion then
			table.insert(e.conexiones, jugador:GetAttributeChangedSignal("Municion_" .. e.cfg.municion):Connect(refrescarArma))
		end
	end
	aplicarVelocidad()
	refrescarArma()
end

local function conectarPersonaje(char)
	e.agachado, e.corriendo = false, false
	alGuardar()
	char.ChildAdded:Connect(function(h)
		if h:IsA("Tool") then
			alEquipar(h)
		end
	end)
	char.ChildRemoved:Connect(function(h)
		if h == e.tool then
			alGuardar()
		end
	end)
end
if jugador.Character then
	conectarPersonaje(jugador.Character)
end
jugador.CharacterAdded:Connect(conectarPersonaje)

-- =====================================================================
--  Teclas y botones
-- =====================================================================
UserInputService.InputBegan:Connect(function(input, procesado)
	if input.UserInputType == Enum.UserInputType.Touch then
		tocando = true
	end
	if procesado then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		apuntar(true)
	elseif input.KeyCode == Enum.KeyCode.R then
		recargar()
	elseif input.KeyCode == Enum.KeyCode.C then
		agacharse()
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		e.corriendo = true
		aplicarVelocidad()
	elseif input.KeyCode == Enum.KeyCode.B then
		Pantalla.alternarMochila()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		tocando = false
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		apuntar(false)
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		e.corriendo = false
		aplicarVelocidad()
	end
end)

if esMovil then
	local botones
	botones = Pantalla.botonesMovil({
		{ "recargar", "Recargar", recargar },
		{ "apuntar", "Apuntar", function()
			apuntar(not e.apuntando)
			botones.apuntar.Text = e.apuntando and "Dejar" or "Apuntar"
		end },
		{ "agachar", "Agacharse", function()
			agacharse()
			botones.agachar.Text = e.agachado and "Levantarse" or "Agacharse"
		end },
		{ "mochila", "Mochila", Pantalla.alternarMochila },
	})
end

-- =====================================================================
--  Mensajes del servidor
-- =====================================================================
local ultimoAtaque = 0
Aviso.OnClientEvent:Connect(function(que, d)
	d = d or {}
	if que == "acierto" then
		Pantalla.acierto(d.estado == "muerto", d.zona == "Cabeza")
		if d.estado == "muerto" and d.zona == "Cabeza" then
			Pantalla.aviso("¡En la cabeza!", Color3.fromRGB(255, 220, 120), 2)
		end
	elseif que == "abatido" then
		Pantalla.aviso(string.format("Has abatido: %s (%s). Acércate y mantén E para despellejarlo.", d.nombre, Pantalla.kg(d.peso)), Color3.fromRGB(150, 220, 130), 6)
	elseif que == "botin" then
		local partes = {}
		for _, b in ipairs(d.botin or {}) do
			local cant = (b.unidad == "kg") and Pantalla.kg(b.cantidad) or ("x" .. b.cantidad)
			table.insert(partes, string.format("%s %s%s", b.nombre, cant, b.calidad and (" (" .. b.calidad .. ")") or ""))
		end
		Pantalla.aviso("Botín: " .. ((#partes > 0) and table.concat(partes, " · ") or "nada aprovechable"), Color3.fromRGB(236, 200, 110), 6)
	elseif que == "atacado" then
		Pantalla.herido()
		Efectos.sacudir(0.9)
		if os.clock() - ultimoAtaque > 3 then
			ultimoAtaque = os.clock()
			Pantalla.aviso("¡Te ataca un " .. d.nombre:lower() .. "!", Color3.fromRGB(240, 90, 80), 2.5)
		end
	elseif que == "vacio" then
		sonido(Config.Sonidos.Vacio, 0.6)
	elseif que == "sinMunicion" then
		local m = Config.Municion[d.municion]
		Pantalla.aviso("No te quedan " .. (m and m.nombre:lower() or "balas") .. ". Cómpralos en una tienda de caza.", Color3.fromRGB(230, 120, 100), 4)
	elseif que == "venta" then
		Pantalla.aviso(string.format("Has vendido %d cosas por %s", d.n, Pantalla.dineroTexto(d.total)), Color3.fromRGB(236, 200, 90), 5)
		sonido(Config.Sonidos.Caja, 0.8)
	elseif que == "compra" then
		Pantalla.aviso(string.format("Has comprado: %s (-%s)", d.nombre, Pantalla.dineroTexto(d.precio)), Color3.fromRGB(236, 200, 90), 4)
		sonido(Config.Sonidos.Caja, 0.8)
	elseif que == "mensaje" then
		Pantalla.aviso(d.texto, Color3.fromRGB(230, 226, 214), 4)
	end
end)

Estado.OnClientEvent:Connect(function(datos)
	e.datos = datos
	Pantalla.estado(datos)
	refrescarArma()
end)

local tiendaEn
Tienda.OnClientEvent:Connect(function(que, d)
	if que == "abrir" then
		local _, hrp = humanoide()
		tiendaEn = hrp and hrp.Position
		Pantalla.abrirTienda(d and d.nombre, function(tipo, id)
			Accion:FireServer("comprar", tipo, id)
		end, function()
			Accion:FireServer("vender")
		end)
	end
end)

-- Pide el dinero y la mochila al arrancar (por si el servidor los mandó antes de que este script escuchara)
Accion:FireServer("estado")

EfectosR.OnClientEvent:Connect(function(que, d)
	local f = Efectos[que]
	if f and type(d) == "table" then
		f(d, camara.CFrame.Position)
	end
end)

-- =====================================================================
--  Bucles
-- =====================================================================
-- Después de la cámara de Roblox: hombro, giro del personaje con la cámara, zoom, retroceso y temblor
RunService:BindToRenderStep("CazaCamara", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local hum, hrp = humanoide()
	if e.tirador and hrp and hum and hum.Health > 0 then
		if not esMovil then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		end
		local mirada = camara.CFrame.LookVector
		hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, math.atan2(-mirada.X, -mirada.Z), 0)
	end
	local objetivo = (e.apuntando and e.cfg) and (e.cfg.zoom or 55) or FOV
	camara.FieldOfView = camara.FieldOfView + (objetivo - camara.FieldOfView) * math.min(1, dt * 12)
	UserInputService.MouseDeltaSensitivity = math.clamp(camara.FieldOfView / FOV, 0.15, 1)
	if e.retroceso > 0.01 then
		camara.CFrame = camara.CFrame * CFrame.Angles(math.rad(e.retroceso), 0, 0)
		e.retroceso = e.retroceso * math.exp(-dt * 14)
	end
	Efectos.camara(dt, camara)
end)

RunService.RenderStepped:Connect(function(dt)
	Efectos.actualizar(dt)
	Efectos.peces(dt, camara.CFrame.Position)
	if pesca.fase == "luchando" and pelea then
		actualizarPelea(dt)
	end
	if e.disparando and e.cfg and e.cfg.automatica then
		disparar()
	end
	-- Mira: se abre con la dispersión real del arma (más al moverte, menos agachado o apuntando)
	local cfg = e.cfg
	local conMira = e.tirador and cfg and (cfg.tipo ~= "lanzable")
	local tele = conMira and cfg.mira and e.apuntando and camara.FieldOfView < (cfg.zoom or 55) + 6
	Pantalla.telescopica(tele == true)
	if conMira and not tele then
		local _, hrp = humanoide()
		local disp = (cfg.dispersion or 0) + e.floracion
		if hrp and hrp.AssemblyLinearVelocity.Magnitude > 3 then
			disp = disp * 2
		end
		if e.agachado then
			disp = disp * 0.6
		end
		if e.apuntando then
			disp = disp * 0.5
		end
		local px = math.tan(math.rad(disp)) / math.tan(math.rad(camara.FieldOfView / 2)) * camara.ViewportSize.Y / 2
		Pantalla.mira(true, px)
	else
		Pantalla.mira(false, 0)
	end
	e.floracion = e.floracion * math.exp(-dt * 5)
	-- La tienda se cierra si te alejas
	if Pantalla.tiendaAbierta() and tiendaEn then
		local _, hrp = humanoide()
		if not hrp or (hrp.Position - tiendaEn).Magnitude > 25 then
			Pantalla.cerrarTienda()
		end
	end
end)

-- Las articulaciones de los animales se mueven antes de la física de cada fotograma
RunService.Stepped:Connect(function(_, dt)
	Efectos.animar(dt, camara.CFrame.Position)
end)
]=]
local CAZA_SERVIDOR_MODULOS, CAZA_CLIENTE_MODULOS = {}, {}
CAZA_SERVIDOR_MODULOS["Modelos"] = [=[
--[[
	Modelos de la caza y la pesca (los construye el servidor):
	  · Animales a tamaño real (1 metro = 2,9 studs) hechos con formas orgánicas (elipsoides) y con
	    articulaciones (Motor6D) en caderas, rodillas, cuello y cola para que el cliente los anime al andar,
	    correr o pastar. Cada pieza lleva el atributo "Zona" (Cabeza, Cuello, Pecho, Cuerpo, Pata, Cola)
	    para el daño según dónde acierta el disparo.
	  · Armas y cañas de pescar como herramientas (Tool) con piezas detalladas.
	  · El corcho de la caña y las manchas del rastro de sangre.
	Los animales se construyen mirando hacia -Z con la raíz en el centro del cuerpo; "altura" es la
	distancia de la raíz al suelo.
]]
local Modelos = {}

local ZERO = CFrame.new()
local NEGRO = { 26, 24, 22 }

local function rgb(c)
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function giroDe(rot)
	if not rot then
		return ZERO
	end
	return CFrame.fromEulerAnglesYXZ(math.rad(rot[1] or 0), math.rad(rot[2] or 0), math.rad(rot[3] or 0))
end

local function mezclar(t, extra)
	if extra then
		for k, v in pairs(extra) do
			t[k] = v
		end
	end
	return t
end

-- =====================================================================
--  Piezas: E elipsoide, B bloque, W cuña, S bola, C cilindro (eje x/y/z), R cilindro entre dos puntos
-- =====================================================================
local function E(nombre, tam, pos, color, rot, x)
	return mezclar({ nombre = nombre, tam = tam, pos = pos, color = color, giro = giroDe(rot), elipse = true }, x)
end
local function B(nombre, tam, pos, color, rot, x)
	return mezclar({ nombre = nombre, tam = tam, pos = pos, color = color, giro = giroDe(rot) }, x)
end
local function W(nombre, tam, pos, color, rot, x)
	return mezclar({ nombre = nombre, tam = tam, pos = pos, color = color, giro = giroDe(rot), clase = "WedgePart" }, x)
end
local function S(nombre, d, pos, color, x)
	return mezclar({ nombre = nombre, tam = { d, d, d }, pos = pos, color = color, giro = ZERO, forma = "Ball" }, x)
end
local EJES = { x = ZERO, y = CFrame.Angles(0, 0, math.rad(90)), z = CFrame.Angles(0, math.rad(90), 0) }
local function C(nombre, d, largo, eje, pos, color, rot, x)
	return mezclar({ nombre = nombre, tam = { largo, d, d }, pos = pos, color = color, giro = giroDe(rot) * EJES[eje], forma = "Cylinder" }, x)
end
local function R(nombre, a, b, d, color, x)
	local va, vb = Vector3.new(a[1], a[2], a[3]), Vector3.new(b[1], b[2], b[3])
	local dir = vb - va
	local arriba = (math.abs(dir.Unit.Y) > 0.98) and Vector3.new(0, 0, -1) or Vector3.new(0, 1, 0)
	local m = (va + vb) / 2
	return mezclar({
		nombre = nombre, tam = { dir.Magnitude, d, d }, pos = { m.X, m.Y, m.Z }, color = color, forma = "Cylinder",
		giro = CFrame.lookAt(Vector3.new(0, 0, 0), dir, arriba) * CFrame.Angles(0, math.rad(90), 0),
	}, x)
end

-- Los dos lados (izquierda y derecha) de una pieza simétrica
local function par(lista, hacer)
	table.insert(lista, hacer(1))
	table.insert(lista, hacer(-1))
end

local function fabricar(sp, s)
	local part = Instance.new(sp.clase or "Part")
	part.Name = sp.nombre
	if sp.forma then
		part.Shape = Enum.PartType[sp.forma]
	end
	part.Size = Vector3.new(sp.tam[1] * s, sp.tam[2] * s, sp.tam[3] * s)
	part.CFrame = CFrame.new(sp.pos[1] * s, sp.pos[2] * s, sp.pos[3] * s) * sp.giro
	part.Color = rgb(sp.color)
	part.Material = Enum.Material[sp.mat or "SmoothPlastic"]
	if sp.trans then
		part.Transparency = sp.trans
	end
	if sp.refl then
		part.Reflectance = sp.refl
	end
	if sp.elipse then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanTouch = false
	part.Massless = true
	part.Anchored = false
	part.CastShadow = sp.sombra ~= false
	if sp.zona then
		part:SetAttribute("Zona", sp.zona)
	end
	return part
end

local function soldar(a, b)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

-- Articulación: el cliente gira Motor6D.Transform alrededor del punto "junta" (en studs, ejes del animal)
local function articular(nombre, padre, hijo, junta)
	local j = CFrame.new(junta)
	local m = Instance.new("Motor6D")
	m.Name = nombre
	m.Part0 = padre
	m.Part1 = hijo
	m.C0 = padre.CFrame:Inverse() * j
	m.C1 = hijo.CFrame:Inverse() * j
	m.Parent = hijo
	return m
end

-- =====================================================================
--  Animales (medidas en studs para el peso medio; se escalan según el peso de cada ejemplar)
--  patas: ancho (separación), delante/detras (z de las caderas), cadera (altura de la cadera respecto a
--  la raíz), largoMuslo, muslo/muslo2 (tamaño delante/detrás), grosorCana, pezuna (pie o pezuña)
-- =====================================================================
local ANIMALES = {}

ANIMALES.Ciervo = function(op)
	local pelo = (op.variante == 1) and { 150, 108, 70 } or { 132, 98, 66 }
	local claro, oscuro, asta = { 226, 214, 196 }, { 92, 70, 52 }, { 206, 190, 158 }
	local cabeza = {
		E("Cuello", { 0.5, 1.85, 0.68 }, { 0, 1.0, -1.85 }, pelo, { -35, 0, 0 }, { zona = "Cuello" }),
		E("Garganta", { 0.36, 0.36, 0.3 }, { 0, 1.5, -2.2 }, claro, nil, { zona = "Cuello" }),
		E("Cabeza", { 0.52, 0.56, 1.0 }, { 0, 1.95, -2.38 }, pelo, { -15, 0, 0 }, { zona = "Cabeza" }),
		E("Hocico", { 0.34, 0.36, 0.55 }, { 0, 1.8, -2.82 }, oscuro, { -15, 0, 0 }, { zona = "Cabeza" }),
		S("Nariz", 0.17, { 0, 1.79, -3.07 }, NEGRO, { zona = "Cabeza" }),
	}
	par(cabeza, function(k)
		return S("Ojo", 0.11, { 0.25 * k, 2.03, -2.46 }, NEGRO, { zona = "Cabeza" })
	end)
	par(cabeza, function(k)
		return E("Oreja", { 0.1, 0.5, 0.3 }, { 0.36 * k, 2.3, -2.12 }, pelo, { 0, 0, -40 * k }, { zona = "Cabeza" })
	end)
	if op.macho then
		-- Cornamenta: rama principal curvada con tres puntas por lado
		for _, k in ipairs({ 1, -1 }) do
			local p0, p1, p2, p3 = { 0.2 * k, 2.25, -2.2 }, { 0.5 * k, 2.9, -2.0 }, { 0.72 * k, 3.45, -2.35 }, { 0.6 * k, 3.85, -2.85 }
			table.insert(cabeza, R("Cuerna", p0, p1, 0.15, asta, { zona = "Cabeza", mat = "Wood" }))
			table.insert(cabeza, R("Cuerna", p1, p2, 0.13, asta, { zona = "Cabeza", mat = "Wood" }))
			table.insert(cabeza, R("Cuerna", p2, p3, 0.11, asta, { zona = "Cabeza", mat = "Wood" }))
			table.insert(cabeza, R("Cuerna", p1, { 0.45 * k, 3.45, -1.75 }, 0.09, asta, { zona = "Cabeza", mat = "Wood" }))
			table.insert(cabeza, R("Cuerna", p2, { 0.85 * k, 4.0, -2.2 }, 0.09, asta, { zona = "Cabeza", mat = "Wood" }))
			table.insert(cabeza, R("Cuerna", { 0.28 * k, 2.45, -2.25 }, { 0.3 * k, 2.78, -2.62 }, 0.08, asta, { zona = "Cabeza", mat = "Wood" }))
		end
	end
	return {
		altura = 2.5, mat = "Fabric",
		cuerpo = {
			E("Cuerpo", { 1.35, 1.7, 2.7 }, { 0, 0, 0.7 }, pelo, nil, { zona = "Cuerpo" }),
			E("Pecho", { 1.4, 1.85, 2.2 }, { 0, 0.1, -0.85 }, pelo, nil, { zona = "Pecho" }),
			E("Vientre", { 1.0, 0.75, 2.8 }, { 0, -0.55, 0 }, claro, nil, { zona = "Cuerpo" }),
			E("Lomo", { 0.5, 0.26, 3.0 }, { 0, 0.73, -0.05 }, oscuro, nil, { zona = "Cuerpo" }),
			E("Grupa", { 0.8, 0.75, 0.28 }, { 0, 0.12, 1.98 }, claro, nil, { zona = "Cuerpo" }),
		},
		patas = { ancho = 0.42, delante = -1.2, detras = 1.3, cadera = -0.35, largoMuslo = 1.15, muslo = { 0.4, 1.15, 0.52 },
			muslo2 = { 0.5, 1.35, 0.78 }, grosorMuslo = 0.26, grosorCana = 0.18, colorMuslo = pelo, colorCana = pelo, pezuna = { 0.2, 0.16, 0.26 },
			colorPezuna = { 30, 26, 24 } },
		juntas = {
			{ nombre = "Cuello", junta = { 0, 0.45, -1.45 }, partes = cabeza },
			{ nombre = "Cola", junta = { 0, 0.75, 1.95 }, partes = {
				E("Cola", { 0.34, 0.6, 0.24 }, { 0, 0.5, 2.1 }, pelo, { 20, 0, 0 }, { zona = "Cola" }),
				E("Cola", { 0.26, 0.45, 0.12 }, { 0, 0.45, 2.2 }, claro, { 20, 0, 0 }, { zona = "Cola" }),
			} },
		},
	}
end

ANIMALES.Lobo = function(op)
	local pelo = (op.variante == 1) and { 128, 124, 116 } or { 104, 98, 90 }
	local claro, oscuro = { 206, 200, 188 }, { 62, 58, 54 }
	local cabeza = {
		E("Cuello", { 0.72, 1.15, 0.85 }, { 0, 0.62, -1.5 }, pelo, { -38, 0, 0 }, { zona = "Cuello" }),
		E("Cabeza", { 0.72, 0.68, 0.85 }, { 0, 1.05, -2.0 }, pelo, nil, { zona = "Cabeza" }),
		E("Mejilla", { 0.8, 0.5, 0.5 }, { 0, 0.92, -2.05 }, claro, nil, { zona = "Cabeza" }),
		E("Hocico", { 0.36, 0.36, 0.78 }, { 0, 0.9, -2.55 }, claro, { -6, 0, 0 }, { zona = "Cabeza" }),
		E("Hocico", { 0.3, 0.16, 0.6 }, { 0, 1.02, -2.6 }, pelo, { -6, 0, 0 }, { zona = "Cabeza" }),
		S("Nariz", 0.16, { 0, 0.98, -2.94 }, NEGRO, { zona = "Cabeza" }),
	}
	par(cabeza, function(k)
		return S("Ojo", 0.11, { 0.22 * k, 1.18, -2.32 }, { 196, 150, 50 }, { zona = "Cabeza" })
	end)
	par(cabeza, function(k)
		return W("Oreja", { 0.08, 0.42, 0.3 }, { 0.25 * k, 1.5, -1.92 }, pelo, { 0, 180, 12 * k }, { zona = "Cabeza" })
	end)
	return {
		altura = 2.0, mat = "Fabric",
		cuerpo = {
			E("Cuerpo", { 1.0, 1.2, 2.2 }, { 0, 0, 0.7 }, pelo, nil, { zona = "Cuerpo" }),
			E("Pecho", { 1.1, 1.45, 1.6 }, { 0, 0.05, -0.65 }, pelo, nil, { zona = "Pecho" }),
			E("Vientre", { 0.72, 0.5, 2.2 }, { 0, -0.42, 0.1 }, claro, nil, { zona = "Cuerpo" }),
			E("Lomo", { 0.6, 0.42, 2.8 }, { 0, 0.55, 0.1 }, oscuro, nil, { zona = "Cuerpo" }),
			E("Melena", { 1.2, 1.1, 0.9 }, { 0, 0.35, -1.15 }, pelo, nil, { zona = "Cuello" }),
		},
		patas = { ancho = 0.33, delante = -1.0, detras = 1.25, cadera = -0.2, largoMuslo = 0.85, muslo = { 0.34, 0.95, 0.44 },
			muslo2 = { 0.42, 1.05, 0.62 }, grosorMuslo = 0.22, grosorCana = 0.16, colorMuslo = pelo,
			colorCana = { pelo[1] + 26, pelo[2] + 26, pelo[3] + 26 }, pezuna = { 0.24, 0.14, 0.34 }, colorPezuna = oscuro, dedos = -0.06, pieRedondo = true },
		juntas = {
			{ nombre = "Cuello", junta = { 0, 0.35, -1.2 }, partes = cabeza },
			{ nombre = "Cola", junta = { 0, 0.45, 1.75 }, partes = {
				E("Cola", { 0.42, 0.42, 1.55 }, { 0, 0.02, 2.4 }, pelo, { 38, 0, 0 }, { zona = "Cola" }),
				E("Cola", { 0.3, 0.3, 0.5 }, { 0, -0.38, 2.95 }, oscuro, { 38, 0, 0 }, { zona = "Cola" }),
			} },
		},
	}
end

ANIMALES.Oso = function(op)
	local pelo = (op.variante == 1) and { 96, 66, 44 } or { 78, 56, 40 }
	local claro, oscuro = { 128, 96, 68 }, { 56, 40, 30 }
	local cabeza = {
		E("Cuello", { 1.5, 1.5, 1.3 }, { 0, 0.55, -2.3 }, pelo, nil, { zona = "Cuello" }),
		E("Cabeza", { 1.45, 1.35, 1.35 }, { 0, 0.88, -2.95 }, pelo, nil, { zona = "Cabeza" }),
		E("Hocico", { 0.78, 0.68, 0.9 }, { 0, 0.62, -3.58 }, claro, nil, { zona = "Cabeza" }),
		E("Nariz", { 0.42, 0.3, 0.25 }, { 0, 0.8, -3.98 }, NEGRO, nil, { zona = "Cabeza" }),
	}
	par(cabeza, function(k)
		return S("Ojo", 0.14, { 0.36 * k, 1.15, -3.45 }, NEGRO, { zona = "Cabeza" })
	end)
	par(cabeza, function(k)
		return S("Oreja", 0.46, { 0.56 * k, 1.55, -2.82 }, pelo, { zona = "Cabeza" })
	end)
	return {
		altura = 2.3, mat = "Fabric",
		cuerpo = {
			E("Cuerpo", { 2.4, 2.6, 3.3 }, { 0, 0.1, 0.9 }, pelo, nil, { zona = "Cuerpo" }),
			E("Pecho", { 2.5, 2.8, 2.6 }, { 0, 0.25, -0.9 }, pelo, nil, { zona = "Pecho" }),
			E("Joroba", { 1.8, 1.0, 1.8 }, { 0, 1.2, -0.9 }, pelo, nil, { zona = "Pecho" }),
			E("Vientre", { 1.8, 1.0, 3.6 }, { 0, -0.8, 0 }, oscuro, nil, { zona = "Cuerpo" }),
			S("Cola", 0.45, { 0, 0.6, 2.5 }, pelo, { zona = "Cola" }),
		},
		patas = { ancho = 0.85, delante = -1.6, detras = 1.7, cadera = -0.4, largoMuslo = 1.1, muslo = { 0.72, 1.4, 1.0 },
			muslo2 = { 0.8, 1.5, 1.25 }, grosorMuslo = 0.85, grosorCana = 0.74, colorMuslo = pelo, colorCana = pelo, pezuna = { 0.92, 0.44, 1.15 },
			colorPezuna = oscuro, dedos = -0.12, pieRedondo = true },
		juntas = {
			{ nombre = "Cuello", junta = { 0, 0.6, -2.0 }, partes = cabeza },
		},
	}
end

ANIMALES.Jabali = function(op)
	local pelo = (op.variante == 1) and { 72, 60, 52 } or { 88, 72, 58 }
	local oscuro, hocico, colmillo = { 44, 38, 34 }, { 112, 92, 86 }, { 236, 228, 210 }
	local cabeza = {
		E("Cuello", { 0.95, 1.05, 0.75 }, { 0, 0.25, -1.55 }, pelo, nil, { zona = "Cuello" }),
		E("Cabeza", { 0.58, 0.72, 1.75 }, { 0, -0.06, -2.25 }, pelo, { 22, 0, 0 }, { zona = "Cabeza" }),
		E("Frente", { 0.5, 0.5, 0.9 }, { 0, 0.2, -1.95 }, oscuro, { 22, 0, 0 }, { zona = "Cabeza" }),
		C("Hocico", 0.32, 0.12, "z", { 0, -0.4, -3.02 }, hocico, { 22, 0, 0 }, { zona = "Cabeza" }),
	}
	par(cabeza, function(k)
		return W("Colmillo", { 0.07, 0.28, 0.11 }, { 0.17 * k, -0.3, -2.74 }, colmillo, { -30, 0, 14 * k }, { zona = "Cabeza" })
	end)
	par(cabeza, function(k)
		return S("Ojo", 0.1, { 0.3 * k, 0.25, -2.25 }, NEGRO, { zona = "Cabeza" })
	end)
	par(cabeza, function(k)
		return W("Oreja", { 0.1, 0.36, 0.26 }, { 0.3 * k, 0.55, -1.85 }, oscuro, { 0, 180, 18 * k }, { zona = "Cabeza" })
	end)
	return {
		altura = 1.7, mat = "Fabric",
		cuerpo = {
			E("Cuerpo", { 1.25, 1.5, 2.1 }, { 0, 0, 0.6 }, pelo, nil, { zona = "Cuerpo" }),
			E("Pecho", { 1.35, 1.75, 1.75 }, { 0, 0.12, -0.75 }, pelo, nil, { zona = "Pecho" }),
			E("Crin", { 0.26, 0.36, 2.4 }, { 0, 0.84, -0.3 }, oscuro, nil, { zona = "Cuerpo" }),
			E("Vientre", { 0.95, 0.6, 2.4 }, { 0, -0.5, 0 }, oscuro, nil, { zona = "Cuerpo" }),
		},
		patas = { ancho = 0.38, delante = -1.05, detras = 1.15, cadera = -0.35, largoMuslo = 0.65, muslo = { 0.4, 0.8, 0.5 },
			muslo2 = { 0.46, 0.85, 0.64 }, grosorMuslo = 0.24, grosorCana = 0.16, colorMuslo = pelo, colorCana = oscuro, pezuna = { 0.22, 0.15, 0.26 },
			colorPezuna = NEGRO },
		juntas = {
			{ nombre = "Cuello", junta = { 0, 0.25, -1.35 }, partes = cabeza },
			{ nombre = "Cola", junta = { 0, 0.3, 1.62 }, partes = {
				R("Cola", { 0, 0.3, 1.62 }, { 0, -0.35, 1.82 }, 0.08, oscuro, { zona = "Cola" }),
				E("Cola", { 0.14, 0.26, 0.14 }, { 0, -0.42, 1.84 }, oscuro, nil, { zona = "Cola" }),
			} },
		},
	}
end

ANIMALES.Conejo = function(op)
	local pelo = (op.variante == 1) and { 132, 114, 92 } or { 112, 98, 82 }
	local claro = { 228, 222, 210 }
	local cabeza = {
		E("Cabeza", { 0.38, 0.36, 0.46 }, { 0, 0.32, -0.5 }, pelo, nil, { zona = "Cabeza" }),
		E("Hocico", { 0.2, 0.18, 0.16 }, { 0, 0.26, -0.72 }, claro, nil, { zona = "Cabeza" }),
		S("Nariz", 0.06, { 0, 0.3, -0.79 }, { 170, 120, 120 }, { zona = "Cabeza" }),
	}
	par(cabeza, function(k)
		return S("Ojo", 0.08, { 0.17 * k, 0.39, -0.55 }, NEGRO, { zona = "Cabeza" })
	end)
	par(cabeza, function(k)
		return E("Oreja", { 0.07, 0.5, 0.16 }, { 0.08 * k, 0.72, -0.38 }, pelo, { 18, 0, -10 * k }, { zona = "Cabeza" })
	end)
	return {
		altura = 0.42, mat = "Fabric", salta = true,
		cuerpo = {
			E("Cuerpo", { 0.62, 0.68, 0.85 }, { 0, 0, 0.12 }, pelo, nil, { zona = "Cuerpo" }),
			E("Pecho", { 0.55, 0.6, 0.5 }, { 0, 0.04, -0.24 }, pelo, nil, { zona = "Pecho" }),
			E("Vientre", { 0.42, 0.3, 0.7 }, { 0, -0.2, 0 }, claro, nil, { zona = "Cuerpo" }),
			S("Cola", 0.22, { 0, 0.16, 0.54 }, claro, { zona = "Cola" }),
		},
		patas = { ancho = 0.17, ancho2 = 0.22, delante = -0.26, detras = 0.22, cadera = -0.08, largoMuslo = 0.22, muslo = { 0.12, 0.28, 0.14 },
			muslo2 = { 0.2, 0.42, 0.5 }, grosorCana = 0.07, colorMuslo = pelo, colorCana = pelo, pezuna = { 0.1, 0.07, 0.3 },
			colorPezuna = pelo, dedos = -0.08, pieRedondo = true },
		juntas = {
			{ nombre = "Cuello", junta = { 0, 0.15, -0.32 }, partes = cabeza },
		},
	}
end

ANIMALES.Pavo = function(op)
	local plumas = { 62, 48, 38 }
	local bronce, cabezaC, rojo, pata = { 92, 70, 48 }, { 150, 172, 196 }, { 176, 52, 46 }, { 170, 132, 120 }
	local cuello = {
		E("Cuello", { 0.22, 0.85, 0.26 }, { 0, 0.85, -0.75 }, { 120, 92, 88 }, { -12, 0, 0 }, { zona = "Cuello" }),
		E("Cabeza", { 0.26, 0.28, 0.32 }, { 0, 1.3, -0.86 }, cabezaC, nil, { zona = "Cabeza" }),
		E("Moco", { 0.07, 0.24, 0.07 }, { 0, 1.24, -1.04 }, rojo, nil, { zona = "Cabeza" }),
		E("Barba", { 0.13, 0.32, 0.13 }, { 0, 1.06, -0.93 }, rojo, nil, { zona = "Cabeza" }),
		W("Pico", { 0.09, 0.09, 0.2 }, { 0, 1.27, -1.06 }, { 200, 180, 150 }, { 0, 0, 0 }, { zona = "Cabeza" }),
	}
	par(cuello, function(k)
		return S("Ojo", 0.06, { 0.11 * k, 1.36, -0.92 }, NEGRO, { zona = "Cabeza" })
	end)
	local cuerpo = {
		E("Cuerpo", { 1.25, 1.2, 1.5 }, { 0, 0, 0.1 }, plumas, nil, { zona = "Cuerpo" }),
		E("Pecho", { 1.0, 1.1, 0.85 }, { 0, 0.12, -0.55 }, bronce, nil, { zona = "Pecho" }),
		E("Cola", { 0.95, 0.3, 1.15 }, { 0, -0.02, 0.95 }, plumas, { 25, 0, 0 }, { zona = "Cola" }),
		E("Cola", { 0.86, 0.1, 0.32 }, { 0, -0.22, 1.42 }, { 196, 176, 140 }, { 25, 0, 0 }, { zona = "Cola" }),
	}
	par(cuerpo, function(k)
		return E("Ala", { 0.24, 0.78, 1.25 }, { 0.6 * k, 0.04, 0.12 }, { 76, 62, 48 }, { 0, 0, 6 * k }, { zona = "Cuerpo" })
	end)
	return {
		altura = 1.4, mat = "Fabric", cuerpo = cuerpo,
		piernas = { ancho = 0.25, cadera = -0.35, z = 0.05, grosor = 0.12, color = pata },
		juntas = { { nombre = "Cuello", junta = { 0, 0.45, -0.6 }, partes = cuello } },
	}
end

ANIMALES.Pato = function(op)
	local macho = op.macho
	local cuerpoC = macho and { 150, 146, 140 } or { 140, 112, 82 }
	local cabezaC = macho and { 34, 92, 52 } or { 120, 94, 66 }
	local pechoC = macho and { 104, 66, 48 } or { 132, 104, 76 }
	local cuello = {
		E("Cuello", { 0.28, 0.45, 0.3 }, { 0, 0.55, -0.66 }, cabezaC, nil, { zona = "Cuello" }),
		E("Cabeza", { 0.36, 0.38, 0.5 }, { 0, 0.85, -0.76 }, cabezaC, nil, { zona = "Cabeza" }),
		E("Pico", { 0.18, 0.08, 0.38 }, { 0, 0.78, -1.1 }, { 214, 176, 60 }, nil, { zona = "Cabeza" }),
	}
	if macho then
		table.insert(cuello, E("Collar", { 0.31, 0.07, 0.33 }, { 0, 0.4, -0.64 }, { 236, 236, 232 }, nil, { zona = "Cuello" }))
	end
	par(cuello, function(k)
		return S("Ojo", 0.06, { 0.15 * k, 0.9, -0.88 }, NEGRO, { zona = "Cabeza" })
	end)
	local cuerpo = {
		E("Cuerpo", { 0.75, 0.6, 1.4 }, { 0, 0, 0.05 }, cuerpoC, nil, { zona = "Cuerpo" }),
		E("Pecho", { 0.66, 0.55, 0.52 }, { 0, 0.12, -0.5 }, pechoC, nil, { zona = "Pecho" }),
		E("Lomo", { 0.7, 0.28, 1.1 }, { 0, 0.24, 0.12 }, macho and { 110, 100, 90 } or { 112, 88, 64 }, nil, { zona = "Cuerpo" }),
		W("Cola", { 0.3, 0.16, 0.35 }, { 0, 0.18, 0.8 }, macho and { 30, 30, 30 } or { 112, 88, 64 }, { 0, 180, 0 }, { zona = "Cola" }),
	}
	par(cuerpo, function(k)
		return E("Ala", { 0.08, 0.14, 0.32 }, { 0.36 * k, 0.16, 0.2 }, { 60, 70, 150 }, nil, { zona = "Cuerpo" })
	end)
	return { altura = 0.22, mat = "Fabric", nada = true, cuerpo = cuerpo,
		juntas = { { nombre = "Cuello", junta = { 0, 0.3, -0.55 }, partes = cuello } } }
end

ANIMALES.Cangrejo = function(op)
	local cap, oscuro = { 186, 84, 48 }, { 140, 60, 36 }
	local cuerpo = {
		E("Cuerpo", { 0.78, 0.3, 0.58 }, { 0, 0, 0 }, cap, nil, { zona = "Cuerpo" }),
		E("Pecho", { 0.5, 0.16, 0.35 }, { 0, 0.12, -0.05 }, oscuro, nil, { zona = "Pecho" }),
	}
	par(cuerpo, function(k)
		return R("Ojo", { 0.1 * k, 0.1, -0.24 }, { 0.12 * k, 0.24, -0.28 }, 0.03, oscuro, { zona = "Cabeza" })
	end)
	par(cuerpo, function(k)
		return S("Ojo", 0.06, { 0.12 * k, 0.26, -0.28 }, NEGRO, { zona = "Cabeza" })
	end)
	par(cuerpo, function(k)
		return R("Brazo", { 0.3 * k, 0, -0.2 }, { 0.42 * k, 0.02, -0.42 }, 0.07, cap, { zona = "Pata" })
	end)
	par(cuerpo, function(k)
		return E("Pinza", { 0.2, 0.15, 0.3 }, { 0.4 * k, 0.04, -0.56 }, cap, { 0, -20 * k, 0 }, { zona = "Pata" })
	end)
	return { altura = 0.2, mat = "SmoothPlastic", cuerpo = cuerpo, patasCangrejo = { color = oscuro } }
end

-- Patas de cuadrúpedo: cadera y rodilla articuladas, caña y pezuña
local function patas(def, s, modelo, raiz)
	local P = def.patas
	for _, lado in ipairs({ { "DI", -1, P.delante, P.muslo, P.ancho }, { "DD", 1, P.delante, P.muslo, P.ancho },
		{ "TI", -1, P.detras, P.muslo2, P.ancho2 or P.ancho }, { "TD", 1, P.detras, P.muslo2, P.ancho2 or P.ancho } }) do
		local nombre, k, z, tm, ancho = lado[1], lado[2], lado[3], lado[4], lado[5]
		local x = k * ancho
		local yRodilla = P.cadera - P.largoMuslo
		local largoCana = def.altura + yRodilla - P.pezuna[2]
		-- Pierna (hueso de la cadera) + anca musculosa que se funde con el cuerpo, caña fina y pezuña o pie
		local grosor = P.grosorMuslo or P.grosorCana * 1.5
		local pierna = fabricar(C("Pata", grosor, P.largoMuslo + 0.1, "y", { x, P.cadera - P.largoMuslo / 2, z }, P.colorMuslo, nil, { zona = "Pata" }), s)
		local anca = fabricar(E("Pata", tm, { x * 0.85, P.cadera - tm[2] * 0.08, z }, P.colorMuslo, nil, { zona = "Pata" }), s)
		local cana = fabricar(C("Pata", P.grosorCana, largoCana + 0.1, "y", { x, yRodilla - largoCana / 2, z }, P.colorCana, nil, { zona = "Pata" }), s)
		local forma = P.pieRedondo and E or B
		local pie = fabricar(forma("Pata", P.pezuna, { x, -def.altura + P.pezuna[2] / 2, z + (P.dedos or 0) }, P.colorPezuna, nil, { zona = "Pata" }), s)
		for _, p in ipairs({ pierna, anca, cana, pie }) do
			p.Material = Enum.Material[def.mat]
			p.Parent = modelo
		end
		if not P.pieRedondo then
			pie.Material = Enum.Material.SmoothPlastic
		end
		articular("Cadera" .. nombre, raiz, pierna, Vector3.new(x, P.cadera, z) * s)
		soldar(pierna, anca)
		articular("Rodilla" .. nombre, pierna, cana, Vector3.new(x, yRodilla, z) * s)
		soldar(cana, pie)
	end
end

-- Patas de ave (pavo): dos patas finas con tres dedos
local function piernas(def, s, modelo, raiz)
	local P = def.piernas
	for _, lado in ipairs({ { "I", -1 }, { "D", 1 } }) do
		local x = lado[2] * P.ancho
		local largo = def.altura + P.cadera
		local pierna = fabricar(C("Pata", P.grosor, largo, "y", { x, P.cadera - largo / 2, P.z }, P.color, nil, { zona = "Pata" }), s)
		pierna.Parent = modelo
		articular("Pierna" .. lado[1], raiz, pierna, Vector3.new(x, P.cadera, P.z) * s)
		for _, a in ipairs({ -30, 0, 30 }) do
			local dedo = fabricar(B("Pata", { 0.06, 0.05, 0.36 }, { x + math.sin(math.rad(a)) * -0.15, -def.altura + 0.03, P.z - math.cos(math.rad(a)) * 0.15 }, P.color, { 0, a, 0 }, { zona = "Pata" }), s)
			dedo.Parent = modelo
			soldar(pierna, dedo)
		end
	end
end

-- Patas de cangrejo: cuatro por lado, cada una articulada
local function patasCangrejo(def, s, modelo, raiz)
	local n = 0
	for _, k in ipairs({ 1, -1 }) do
		for i, z in ipairs({ -0.1, 0.04, 0.18, 0.3 }) do
			n = n + 1
			local a, c = { 0.32 * k, 0, z }, { 0.62 * k, -def.altura + 0.03, z + 0.04 * (i - 2) }
			local pata = fabricar(R("Pata", a, c, 0.05, def.patasCangrejo.color, { zona = "Pata" }), s)
			pata.Parent = modelo
			articular("Pata" .. n, raiz, pata, Vector3.new(a[1], a[2], a[3]) * s)
		end
	end
end

--[[
	Construye un animal. op: { escala, macho, variante }. Devuelve el Model (Raiz anclada en el origen,
	las demás piezas unidas a ella) y la altura de la raíz sobre el suelo en studs.
]]
function Modelos.animal(especie, op)
	op = op or {}
	local s = op.escala or 1
	local def = ANIMALES[especie](op)
	local modelo = Instance.new("Model")
	modelo.Name = especie
	local raiz = Instance.new("Part")
	raiz.Name = "Raiz"
	raiz.Size = Vector3.new(0.4, 0.4, 0.4) * s
	raiz.Transparency = 1
	raiz.Anchored = true
	raiz.CanCollide = false
	raiz.CanQuery = false
	raiz.CanTouch = false
	raiz.CFrame = ZERO
	raiz.Parent = modelo
	modelo.PrimaryPart = raiz
	for _, sp in ipairs(def.cuerpo) do
		local p = fabricar(sp, s)
		if sp.forma ~= "Ball" or sp.nombre == "Cola" then
			p.Material = Enum.Material[def.mat]
		end
		p.Parent = modelo
		soldar(raiz, p)
	end
	for _, j in ipairs(def.juntas or {}) do
		local hueso
		for i, sp in ipairs(j.partes) do
			local p = fabricar(sp, s)
			if sp.forma ~= "Ball" and not sp.mat and sp.nombre ~= "Pico" and sp.nombre ~= "Nariz" then
				p.Material = Enum.Material[def.mat]
			end
			p.Parent = modelo
			if i == 1 then
				hueso = p
				articular(j.nombre, raiz, p, Vector3.new(j.junta[1], j.junta[2], j.junta[3]) * s)
			else
				soldar(hueso, p)
			end
		end
	end
	if def.patas then
		patas(def, s, modelo, raiz)
	elseif def.piernas then
		piernas(def, s, modelo, raiz)
	elseif def.patasCangrejo then
		patasCangrejo(def, s, modelo, raiz)
	end
	modelo:SetAttribute("Especie", especie)
	modelo:SetAttribute("Escala", s)
	if def.salta then
		modelo:SetAttribute("Salta", true)
	end
	if def.nada then
		modelo:SetAttribute("Nada", true)
	end
	pcall(function()
		modelo.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end)
	return modelo, def.altura * s
end

-- =====================================================================
--  Armas y cañas (en el espacio del mango: -Z hacia delante, +Y hacia arriba, origen en la mano)
-- =====================================================================
local ACERO, PAVONADO, POLIMERO, NOGAL, MADERA = { 176, 178, 184 }, { 44, 46, 50 }, { 34, 34, 36 }, { 104, 66, 40 }, { 150, 108, 66 }
local VERDE_OLIVA = { 76, 80, 62 }

local HERRAMIENTAS = {}

HERRAMIENTAS.Cuchillo = function()
	return { partes = {
		B("Mango", { 0.17, 0.24, 0.52 }, { 0, 0, 0.02 }, POLIMERO, nil, { mat = "Fabric" }),
		B("Guarda", { 0.3, 0.06, 0.06 }, { 0, 0, -0.27 }, PAVONADO, nil, { mat = "Metal" }),
		B("Hoja", { 0.04, 0.2, 0.52 }, { 0, 0.02, -0.56 }, ACERO, nil, { mat = "Metal", refl = 0.15 }),
		W("Hoja", { 0.04, 0.2, 0.22 }, { 0, 0.02, -0.93 }, ACERO, { 0, 0, 180 }, { mat = "Metal", refl = 0.15 }),
	} }
end
HERRAMIENTAS.Bate = function()
	return { partes = {
		C("Mango", 0.17, 0.6, "z", { 0, 0, 0 }, MADERA, nil, { mat = "Wood" }),
		C("Pomo", 0.24, 0.08, "z", { 0, 0, 0.32 }, MADERA, nil, { mat = "Wood" }),
		C("Bate", 0.22, 0.8, "z", { 0, 0, -0.68 }, MADERA, nil, { mat = "Wood" }),
		C("Bate", 0.29, 0.8, "z", { 0, 0, -1.45 }, MADERA, nil, { mat = "Wood" }),
		C("Bate", 0.35, 0.95, "z", { 0, 0, -2.3 }, MADERA, nil, { mat = "Wood" }),
		S("Bate", 0.35, { 0, 0, -2.78 }, MADERA, { mat = "Wood" }),
		C("Cinta", 0.18, 0.45, "z", { 0, 0, -0.05 }, { 30, 30, 30 }, nil, { mat = "Fabric" }),
	} }
end
HERRAMIENTAS.Machete = function()
	return { partes = {
		B("Mango", { 0.18, 0.26, 0.58 }, { 0, 0, 0.04 }, { 40, 40, 40 }, nil, { mat = "Fabric" }),
		B("Hoja", { 0.04, 0.3, 1.4 }, { 0, 0.03, -0.98 }, { 120, 122, 126 }, nil, { mat = "Metal", refl = 0.1 }),
		B("Hoja", { 0.04, 0.12, 0.5 }, { 0, -0.12, -1.45 }, { 120, 122, 126 }, nil, { mat = "Metal", refl = 0.1 }),
		W("Punta", { 0.04, 0.42, 0.32 }, { 0, -0.03, -1.83 }, { 120, 122, 126 }, { 0, 0, 180 }, { mat = "Metal", refl = 0.1 }),
	} }
end
HERRAMIENTAS.Hacha = function()
	return { partes = {
		C("Mango", 0.2, 2.5, "z", { 0, 0, -0.9 }, MADERA, nil, { mat = "Wood" }),
		B("Cabeza", { 0.22, 0.5, 0.34 }, { 0, 0.12, -2.05 }, PAVONADO, nil, { mat = "Metal" }),
		E("Hoja", { 0.07, 0.78, 0.64 }, { 0, 0.6, -2.05 }, ACERO, nil, { mat = "Metal", refl = 0.15 }),
	} }
end
HERRAMIENTAS.Lanza = function()
	return { partes = {
		C("Asta", 0.14, 5.8, "z", { 0, 0, -1.2 }, { 120, 92, 62 }, nil, { mat = "Wood" }),
		C("Atadura", 0.18, 0.35, "z", { 0, 0, -4.05 }, { 70, 56, 40 }, nil, { mat = "Fabric" }),
		E("Punta", { 0.05, 0.3, 0.85 }, { 0, 0, -4.55 }, ACERO, nil, { mat = "Metal", refl = 0.15 }),
		C("Cinta", 0.17, 0.5, "z", { 0, 0, 0 }, { 40, 34, 30 }, nil, { mat = "Fabric" }),
	} }
end
HERRAMIENTAS.Arco = function()
	local partes = {
		B("Empunadura", { 0.18, 0.62, 0.3 }, { 0, 0, 0 }, { 82, 54, 36 }, nil, { mat = "Wood" }),
		C("Cuerda", 0.025, 4.4, "y", { 0, 0, 0.43 }, { 230, 226, 214 }, nil, { mat = "Fabric", sombra = false }),
	}
	for _, k in ipairs({ 1, -1 }) do
		table.insert(partes, B("Cuerpo", { 0.15, 0.62, 0.22 }, { 0, 0.6 * k, -0.04 }, { 82, 54, 36 }, nil, { mat = "Wood" }))
		local p = { { 0, 0.9 * k, -0.02 }, { 0, 1.55 * k, 0.28 }, { 0, 2.05 * k, 0.5 }, { 0, 2.2 * k, 0.42 } }
		for i = 1, 3 do
			table.insert(partes, R("Pala", p[i], p[i + 1], 0.09 - i * 0.015, { 60, 44, 34 }, { mat = "Wood" }))
		end
	end
	return { partes = partes, boca = { 0, 0.15, -0.3 } }
end
HERRAMIENTAS.Ballesta = function()
	local partes = {
		B("Culata", { 0.24, 0.36, 1.5 }, { 0, 0.08, 0.35 }, { 50, 50, 46 }, nil, { mat = "SmoothPlastic" }),
		B("Empunadura", { 0.2, 0.48, 0.3 }, { 0, -0.12, 0 }, { 40, 40, 38 }, { -15, 0, 0 }),
		B("Riel", { 0.16, 0.12, 1.5 }, { 0, 0.3, -0.65 }, PAVONADO, nil, { mat = "Metal" }),
		B("Estribo", { 0.42, 0.06, 0.06 }, { 0, 0.18, -1.48 }, PAVONADO, nil, { mat = "Metal" }),
		C("Mira", 0.14, 0.7, "z", { 0, 0.55, -0.2 }, PAVONADO, nil, { mat = "Metal" }),
		R("Cuerda", { 0.95, 0.33, -1.15 }, { 0, 0.33, -0.55 }, 0.025, { 220, 216, 200 }, { mat = "Fabric", sombra = false }),
		R("Cuerda", { -0.95, 0.33, -1.15 }, { 0, 0.33, -0.55 }, 0.025, { 220, 216, 200 }, { mat = "Fabric", sombra = false }),
		C("Virote", 0.05, 1.0, "z", { 0, 0.38, -0.95 }, { 40, 40, 40 }),
	}
	par(partes, function(k)
		return R("Pala", { 0.05 * k, 0.33, -1.38 }, { 1.0 * k, 0.33, -1.18 }, 0.1, { 60, 60, 56 }, { mat = "SmoothPlastic" })
	end)
	return { partes = partes, boca = { 0, 0.38, -1.5 } }
end
HERRAMIENTAS.Pistola = function()
	return { partes = {
		B("Empunadura", { 0.22, 0.55, 0.32 }, { 0, -0.06, 0.02 }, POLIMERO, { -14, 0, 0 }),
		B("Armazon", { 0.2, 0.14, 0.8 }, { 0, 0.25, -0.22 }, POLIMERO),
		B("Corredera", { 0.22, 0.2, 0.92 }, { 0, 0.41, -0.24 }, { 56, 56, 60 }, nil, { mat = "Metal" }),
		C("Canon", 0.1, 0.06, "z", { 0, 0.42, -0.72 }, { 14, 14, 14 }),
		B("Guardamonte", { 0.05, 0.05, 0.32 }, { 0, 0.07, -0.32 }, POLIMERO),
		B("Guardamonte", { 0.05, 0.16, 0.05 }, { 0, 0.13, -0.47 }, POLIMERO),
		B("Gatillo", { 0.04, 0.12, 0.04 }, { 0, 0.13, -0.26 }, { 56, 56, 60 }, nil, { mat = "Metal" }),
		B("Mira", { 0.06, 0.05, 0.05 }, { 0, 0.53, -0.66 }, POLIMERO),
		B("Mira", { 0.14, 0.05, 0.06 }, { 0, 0.53, 0.17 }, POLIMERO),
		B("Cargador", { 0.16, 0.08, 0.22 }, { 0, -0.36, 0.06 }, POLIMERO, { -14, 0, 0 }),
	}, boca = { 0, 0.42, -0.76 } }
end
HERRAMIENTAS.Revolver = function()
	return { partes = {
		B("Empunadura", { 0.22, 0.55, 0.3 }, { 0, -0.08, 0.06 }, NOGAL, { -20, 0, 0 }, { mat = "Wood" }),
		B("Armazon", { 0.2, 0.32, 0.55 }, { 0, 0.3, -0.2 }, ACERO, nil, { mat = "Metal", refl = 0.1 }),
		C("Tambor", 0.4, 0.34, "z", { 0, 0.34, -0.24 }, ACERO, nil, { mat = "Metal", refl = 0.1 }),
		C("Canon", 0.14, 0.8, "z", { 0, 0.42, -0.85 }, ACERO, nil, { mat = "Metal", refl = 0.1 }),
		B("Guia", { 0.12, 0.1, 0.76 }, { 0, 0.32, -0.86 }, ACERO, nil, { mat = "Metal" }),
		B("Martillo", { 0.06, 0.14, 0.1 }, { 0, 0.5, 0.06 }, PAVONADO, { 20, 0, 0 }),
		B("Guardamonte", { 0.05, 0.05, 0.28 }, { 0, 0.1, -0.24 }, ACERO, nil, { mat = "Metal" }),
		B("Mira", { 0.04, 0.07, 0.08 }, { 0, 0.52, -1.2 }, ACERO, nil, { mat = "Metal" }),
	}, boca = { 0, 0.42, -1.27 } }
end
HERRAMIENTAS.Escopeta = function()
	return { partes = {
		B("Empunadura", { 0.21, 0.34, 0.6 }, { 0, 0.12, 0.18 }, NOGAL, { -14, 0, 0 }, { mat = "Wood" }),
		B("Culata", { 0.23, 0.44, 1.25 }, { 0, 0.1, 1.02 }, NOGAL, nil, { mat = "Wood" }),
		B("Cantonera", { 0.25, 0.5, 0.08 }, { 0, 0.1, 1.67 }, { 30, 30, 30 }),
		B("Cajon", { 0.26, 0.4, 1.0 }, { 0, 0.28, -0.4 }, PAVONADO, nil, { mat = "Metal" }),
		C("Canon", 0.15, 2.3, "z", { 0, 0.4, -2.05 }, PAVONADO, nil, { mat = "Metal" }),
		C("Deposito", 0.13, 1.7, "z", { 0, 0.24, -1.75 }, PAVONADO, nil, { mat = "Metal" }),
		C("Corredera", 0.24, 0.62, "z", { 0, 0.24, -1.45 }, NOGAL, nil, { mat = "Wood" }),
		B("Guardamonte", { 0.06, 0.05, 0.36 }, { 0, 0.05, -0.18 }, PAVONADO),
		S("Mira", 0.06, { 0, 0.5, -3.15 }, { 230, 210, 160 }),
	}, boca = { 0, 0.4, -3.22 } }
end
HERRAMIENTAS.Subfusil = function()
	return { partes = {
		B("Empunadura", { 0.2, 0.48, 0.28 }, { 0, -0.04, 0.04 }, POLIMERO, { -16, 0, 0 }),
		B("Cajon", { 0.24, 0.38, 1.0 }, { 0, 0.3, -0.28 }, POLIMERO),
		C("Funda", 0.2, 0.42, "z", { 0, 0.34, -0.98 }, PAVONADO, nil, { mat = "Metal" }),
		B("Cargador", { 0.15, 0.72, 0.25 }, { 0, -0.1, -0.5 }, PAVONADO, { 6, 0, 0 }),
		R("Culata", { 0.08, 0.36, 0.2 }, { 0.08, 0.3, 1.0 }, 0.05, PAVONADO),
		R("Culata", { -0.08, 0.36, 0.2 }, { -0.08, 0.3, 1.0 }, 0.05, PAVONADO),
		B("Cantonera", { 0.24, 0.42, 0.06 }, { 0, 0.22, 1.02 }, POLIMERO),
		B("Mira", { 0.06, 0.1, 0.12 }, { 0, 0.54, 0.1 }, POLIMERO),
		B("Mira", { 0.06, 0.1, 0.06 }, { 0, 0.54, -0.72 }, POLIMERO),
	}, boca = { 0, 0.34, -1.22 } }
end
HERRAMIENTAS.Fusil = function()
	return { partes = {
		B("Empunadura", { 0.2, 0.48, 0.28 }, { 0, -0.04, 0.05 }, POLIMERO, { -18, 0, 0 }),
		B("Cajon", { 0.24, 0.42, 1.15 }, { 0, 0.32, -0.32 }, POLIMERO),
		B("Cargador", { 0.17, 0.78, 0.34 }, { 0, -0.12, -0.5 }, POLIMERO, { -14, 0, 0 }),
		B("Culata", { 0.22, 0.45, 0.95 }, { 0, 0.26, 0.78 }, POLIMERO),
		B("Cantonera", { 0.24, 0.55, 0.08 }, { 0, 0.22, 1.28 }, { 20, 20, 20 }),
		B("Guardamanos", { 0.26, 0.3, 1.0 }, { 0, 0.35, -1.38 }, POLIMERO),
		C("Canon", 0.09, 0.66, "z", { 0, 0.37, -2.2 }, PAVONADO, nil, { mat = "Metal" }),
		C("Bocacha", 0.13, 0.16, "z", { 0, 0.37, -2.6 }, PAVONADO, nil, { mat = "Metal" }),
		B("Riel", { 0.12, 0.06, 1.0 }, { 0, 0.56, -0.4 }, POLIMERO),
		C("Visor", 0.18, 0.38, "z", { 0, 0.7, -0.35 }, POLIMERO),
		C("Lente", 0.15, 0.02, "z", { 0, 0.7, -0.55 }, { 120, 40, 40 }, nil, { mat = "Glass", trans = 0.2 }),
	}, boca = { 0, 0.37, -2.7 } }
end

local function rifleCerrojo(op)
	local partes = {
		B("Empunadura", { 0.21, 0.34, 0.6 }, { 0, 0.12, 0.18 }, op.madera, { -14, 0, 0 }, { mat = op.mat }),
		B("Culata", { 0.23, 0.44, 1.2 }, { 0, 0.1, 1.0 }, op.madera, nil, { mat = op.mat }),
		B("Cantonera", { 0.25, 0.5, 0.08 }, { 0, 0.1, 1.62 }, { 30, 30, 30 }),
		B("Fuste", { 0.24, 0.24, 1.5 }, { 0, 0.22, -1.0 }, op.madera, nil, { mat = op.mat }),
		B("Cajon", { 0.22, 0.24, 0.85 }, { 0, 0.36, -0.28 }, PAVONADO, nil, { mat = "Metal" }),
		R("Cerrojo", { 0.08, 0.38, 0.05 }, { 0.3, 0.3, 0.12 }, 0.06, PAVONADO, { mat = "Metal" }),
		S("Cerrojo", 0.12, { 0.32, 0.29, 0.13 }, PAVONADO, { mat = "Metal" }),
		C("Canon", 0.12, op.canon, "z", { 0, 0.38, -0.7 - op.canon / 2 }, PAVONADO, nil, { mat = "Metal" }),
		B("Guardamonte", { 0.06, 0.05, 0.36 }, { 0, 0.1, -0.18 }, PAVONADO),
		C("Mira", op.mira, 1.15, "z", { 0, 0.72, -0.38 }, PAVONADO, nil, { mat = "Metal" }),
		C("Objetivo", op.mira * 1.6, 0.34, "z", { 0, 0.72, -1.05 }, PAVONADO, nil, { mat = "Metal" }),
		C("Ocular", op.mira * 1.35, 0.24, "z", { 0, 0.72, 0.28 }, PAVONADO, nil, { mat = "Metal" }),
		C("Lente", op.mira * 1.45, 0.02, "z", { 0, 0.72, -1.23 }, { 70, 120, 150 }, nil, { mat = "Glass", trans = 0.15, refl = 0.3 }),
		C("Torreta", 0.12, 0.14, "y", { 0, 0.86, -0.38 }, PAVONADO, nil, { mat = "Metal" }),
		B("Anilla", { 0.08, 0.24, 0.1 }, { 0, 0.55, -0.7 }, PAVONADO),
		B("Anilla", { 0.08, 0.24, 0.1 }, { 0, 0.55, -0.05 }, PAVONADO),
	}
	if op.bipode then
		for _, k in ipairs({ 1, -1 }) do
			table.insert(partes, R("Bipode", { 0.05 * k, 0.15, -1.6 }, { 0.35 * k, -0.85, -1.85 }, 0.05, PAVONADO, { mat = "Metal" }))
		end
		table.insert(partes, B("Freno", { 0.2, 0.2, 0.3 }, { 0, 0.38, -0.85 - op.canon }, PAVONADO, nil, { mat = "Metal" }))
	end
	return { partes = partes, boca = { 0, 0.38, -0.75 - op.canon - (op.bipode and 0.2 or 0) } }
end
HERRAMIENTAS.RifleCaza = function()
	return rifleCerrojo({ madera = NOGAL, mat = "Wood", canon = 1.9, mira = 0.17 })
end
HERRAMIENTAS.Francotirador = function()
	return rifleCerrojo({ madera = VERDE_OLIVA, mat = "SmoothPlastic", canon = 2.5, mira = 0.2, bipode = true })
end
HERRAMIENTAS.Molotov = function()
	return { partes = {
		C("Botella", 0.34, 0.62, "y", { 0, 0.05, 0 }, { 70, 100, 56 }, nil, { mat = "Glass", trans = 0.25 }),
		C("Liquido", 0.3, 0.42, "y", { 0, -0.04, 0 }, { 196, 140, 60 }, nil, { trans = 0.3 }),
		C("Gollete", 0.14, 0.3, "y", { 0, 0.5, 0 }, { 70, 100, 56 }, nil, { mat = "Glass", trans = 0.25 }),
		E("Trapo", { 0.16, 0.38, 0.16 }, { 0, 0.74, 0 }, { 196, 186, 166 }, { 0, 0, 12 }, { mat = "Fabric" }),
	}, mecha = { 0, 0.88, 0 } }
end
HERRAMIENTAS.Granada = function()
	return { partes = {
		E("Cuerpo", { 0.32, 0.44, 0.32 }, { 0, 0.04, 0 }, VERDE_OLIVA, nil, { mat = "Metal" }),
		C("Espoleta", 0.14, 0.14, "y", { 0, 0.32, 0 }, { 120, 120, 110 }, nil, { mat = "Metal" }),
		B("Cuchara", { 0.05, 0.36, 0.08 }, { 0.16, 0.16, 0 }, { 120, 120, 110 }, { 0, 0, -8 }, { mat = "Metal" }),
		C("Anilla", 0.16, 0.03, "x", { -0.1, 0.38, 0 }, { 150, 150, 140 }, nil, { mat = "Metal" }),
	} }
end

-- Caña: mango de corcho, carrete debajo, tramos cada vez más finos y anillas; "Punta" al final
local function cana(cfg, op)
	local color = cfg.color
	local metal = op.dorado and { 200, 160, 70 } or { 150, 150, 156 }
	local partes = {
		C("Mango", 0.2, 0.95, "z", { 0, 0, 0.1 }, { 176, 140, 100 }, nil, { mat = "Sand" }),
		C("Portacarrete", 0.16, 0.35, "z", { 0, 0, -0.5 }, metal, nil, { mat = "Metal" }),
		B("Pie", { 0.06, 0.28, 0.1 }, { 0, -0.18, -0.5 }, metal, nil, { mat = "Metal" }),
		C("Carrete", op.carrete, 0.26, "z", { 0, -0.32 - op.carrete / 2, -0.5 }, metal, nil, { mat = "Metal" }),
		C("Bobina", op.carrete * 0.75, 0.2, "z", { 0, -0.32 - op.carrete / 2, -0.66 }, { 220, 220, 210 }),
		R("Manivela", { 0.15, -0.32 - op.carrete / 2, -0.5 }, { 0.32, -0.42 - op.carrete / 2, -0.5 }, 0.04, metal, { mat = "Metal" }),
	}
	-- La caña sale hacia delante y arriba
	local dir = Vector3.new(0, math.sin(math.rad(op.angulo)), -math.cos(math.rad(op.angulo)))
	local base = Vector3.new(0, 0, -0.65)
	local tramos = { { 0, 0.34, 0.13 }, { 0.34, 0.68, 0.09 }, { 0.68, 1, 0.055 } }
	for _, t in ipairs(tramos) do
		local a, b = base + dir * (op.largo * t[1]), base + dir * (op.largo * t[2])
		table.insert(partes, R("Tramo", { a.X, a.Y, a.Z }, { b.X, b.Y, b.Z }, t[3], color, { mat = op.mat or "SmoothPlastic" }))
	end
	for i = 1, 4 do
		local p = base + dir * (op.largo * (0.22 + i * 0.18))
		table.insert(partes, C("Anilla", 0.12 - i * 0.015, 0.02, "z", { p.X, p.Y - 0.08, p.Z }, metal, { op.angulo, 0, 0 }, { mat = "Metal" }))
	end
	local punta = base + dir * op.largo
	return { partes = partes, punta = { punta.X, punta.Y, punta.Z } }
end
local CANAS = {
	CanaBambu = { largo = 7.5, angulo = 26, carrete = 0, mat = "Wood" },
	CanaMadera = { largo = 6.5, angulo = 26, carrete = 0.32, mat = "Wood" },
	CanaFibra = { largo = 6.8, angulo = 26, carrete = 0.36 },
	CanaCarbono = { largo = 7, angulo = 26, carrete = 0.38 },
	CanaMar = { largo = 11, angulo = 30, carrete = 0.5 },
	CanaCurrican = { largo = 5.6, angulo = 24, carrete = 0.62, dorado = true },
}

-- Construye la herramienta (Tool) de un arma o una caña con sus datos de CazaConfig
function Modelos.herramienta(id, cfg, esCana)
	local def
	if esCana then
		local op = CANAS[id]
		def = cana(cfg, op)
		if op.carrete == 0 then
			-- La de bambú no lleva carrete: el sedal va atado a la punta
			for i = #def.partes, 1, -1 do
				local n = def.partes[i].nombre
				if n == "Carrete" or n == "Bobina" or n == "Manivela" or n == "Portacarrete" or n == "Pie" then
					table.remove(def.partes, i)
				end
			end
		end
	else
		def = HERRAMIENTAS[id]()
	end
	local tool = Instance.new("Tool")
	tool.Name = cfg.nombre
	tool.ToolTip = cfg.desc or ""
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute(esCana and "Cana" or "Arma", id)
	tool:SetAttribute("CazaPesca", true)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.2, 0.2, 0.2)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.CanQuery = false
	handle.CanTouch = false
	handle.Massless = true
	handle.CFrame = ZERO
	handle.Parent = tool
	for _, sp in ipairs(def.partes) do
		local p = fabricar(sp, 1)
		p.CanQuery = false
		p.Parent = tool
		soldar(handle, p)
	end
	for nombre, pos in pairs({ Boca = def.boca, Punta = def.punta, Mecha = def.mecha }) do
		local a = Instance.new("Attachment")
		a.Name = nombre
		a.Position = Vector3.new(pos[1], pos[2], pos[3])
		a.Parent = handle
	end
	if def.mecha then
		local fuego = Instance.new("Fire")
		fuego.Size = 1.2
		fuego.Heat = 4
		fuego.Parent = handle.Mecha
	end
	return tool
end

-- =====================================================================
--  Corcho de pesca y rastro de sangre
-- =====================================================================
function Modelos.corcho()
	local m = Instance.new("Model")
	m.Name = "Corcho"
	local raiz = Instance.new("Part")
	raiz.Name = "Raiz"
	raiz.Shape = Enum.PartType.Ball
	raiz.Size = Vector3.new(0.36, 0.36, 0.36)
	raiz.Color = Color3.fromRGB(214, 40, 34)
	raiz.Material = Enum.Material.SmoothPlastic
	raiz.Anchored = true
	raiz.CanCollide = false
	raiz.CanQuery = false
	raiz.CanTouch = false
	raiz.Parent = m
	m.PrimaryPart = raiz
	local franja = fabricar(C("Franja", 0.37, 0.12, "y", { 0, -0.08, 0 }, { 240, 240, 236 }), 1)
	franja.CanQuery = false
	franja.Parent = m
	soldar(raiz, franja)
	local antena = fabricar(C("Antena", 0.05, 0.36, "y", { 0, 0.32, 0 }, { 250, 210, 60 }), 1)
	antena.CanQuery = false
	antena.Parent = m
	soldar(raiz, antena)
	local a = Instance.new("Attachment")
	a.Name = "Linea"
	a.Position = Vector3.new(0, 0.5, 0)
	a.Parent = raiz
	return m
end

function Modelos.manchaSangre(cf, tam)
	local p = Instance.new("Part")
	p.Name = "RastroSangre"
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(0.05, tam, tam * (0.6 + math.random() * 0.5))
	p.CFrame = cf * CFrame.Angles(0, 0, math.rad(90))
	p.Color = Color3.fromRGB(92 + math.random(0, 20), 14, 12)
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

Modelos.especies = ANIMALES
return Modelos
]=]
CAZA_SERVIDOR_MODULOS["Animales"] = [=[
--[[
	Animales del mundo abierto (servidor): dónde aparecen, cómo se comportan, cómo se hieren y qué se saca de ellos.

	Comportamiento:
	  · Pastan, descansan y pasean cerca de su zona; los patos nadan y los cangrejos van por la arena.
	  · Las presas huyen cuando te detectan. La distancia depende de si vas agachado o corriendo y del viento:
	    si el viento sopla de ti hacia ellas te huelen desde mucho más lejos.
	  · Los disparos espantan a las presas que los oyen (cada arma hace más o menos ruido).
	  · Los depredadores (lobos, osos) te cazan si te acercas; el jabalí solo ataca si le hieres o le agobias.
	  · Un animal herido sangra (más con flechas), huye dejando un rastro de sangre en el suelo y cae cuando se desangra.
	Al morir se queda tumbado y se puede despellejar (mantén E): carne según su peso y piel según el daño recibido.
]]
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local Animales = {}
local Config, Modelos, W, M
local carpeta, rastros
local lista = {}
local porModelo = {}
local params
local ctx

local LIMITE = 1950
local AGUA = Enum.Material.Water
local PRADO = { [Enum.Material.Grass] = true, [Enum.Material.LeafyGrass] = true }
local NORTE = { [Enum.Material.Grass] = true, [Enum.Material.LeafyGrass] = true, [Enum.Material.Ground] = true, [Enum.Material.Snow] = true }

local function ahora()
	return os.clock()
end

-- Altura y material del terreno (o del agua) en un punto
local function suelo(x, z)
	local r = workspace:Raycast(Vector3.new(x, 600, z), Vector3.new(0, -1200, 0), params)
	if r then
		return r.Position.Y, r.Material
	end
	return nil, nil
end
Animales.suelo = suelo

local function enZona(x, z, margen)
	return W ~= nil and W.inZone(x, z, margen)
end

-- =====================================================================
--  Dónde puede vivir cada especie
-- =====================================================================
local function apto(donde, x, z)
	if math.abs(x) > LIMITE or math.abs(z) > LIMITE or enZona(x, z, 30) then
		return nil
	end
	local y, mat = suelo(x, z)
	if not y then
		return nil
	end
	if donde == "agua" then
		if mat == AGUA and (not W or W.inLandPoly(x, z)) then
			return y
		end
		return nil
	end
	if mat == AGUA then
		return nil
	end
	if donde == "playa" then
		return (mat == Enum.Material.Sand and y > -5 and y < 5) and y or nil
	elseif donde == "prado" then
		return (PRADO[mat] and y < 70) and y or nil
	elseif donde == "bosque" then
		return ((mat == Enum.Material.LeafyGrass or (mat == Enum.Material.Grass and math.random() < 0.25)) and y < 130) and y or nil
	elseif donde == "norte" then
		return (NORTE[mat] and (z < -700 or y > 60) and y < 170) and y or nil
	elseif donde == "montana" then
		return (y > 45 and y < 200 and mat ~= Enum.Material.Sand) and y or nil
	elseif donde == "granja" then
		return PRADO[mat] and y or nil
	end
	return y
end

local function buscarSitio(donde, lejosDe)
	for intento = 1, 500 do
		local x, z
		if donde == "granja" and W and W.zones.Granjas and intento < 300 then
			local r = W.zones.Granjas
			x, z = math.random(r[1] - 260, r[2] + 260), math.random(r[3] - 260, r[4] + 260)
		else
			x, z = math.random(-LIMITE, LIMITE), math.random(-LIMITE, LIMITE)
		end
		local y = apto(donde, x, z)
		local lejos = true
		if y and lejosDe then
			for _, p in ipairs(lejosDe) do
				if (Vector3.new(x, 0, z) - Vector3.new(p.X, 0, p.Z)).Magnitude < 150 then
					lejos = false
				end
			end
		end
		if y and lejos then
			return Vector3.new(x, y, z)
		end
	end
	return nil
end

-- =====================================================================
--  Crear un animal
-- =====================================================================
local function sonido(a, nombre)
	local id = Config.Sonidos[nombre or a.especie]
	if id and id ~= "" and ahora() - (a.ultimoSonido or 0) > 5 then
		a.ultimoSonido = ahora()
		local s = Instance.new("Sound")
		s.SoundId = id
		s.RollOffMaxDistance = 220
		s.Volume = 0.8
		s.Parent = a.raiz
		s:Play()
		Debris:AddItem(s, 8)
	end
end

local function crear(especie, punto, casa)
	local def = Config.Animales[especie]
	local macho = (especie == "Ciervo" or especie == "Pato" or especie == "Pavo") and math.random() < 0.5
	local medio = (def.peso[1] + def.peso[2]) / 2
	local peso = def.peso[1] + (def.peso[2] - def.peso[1]) * math.random() ^ 1.3
	if macho and especie == "Ciervo" then
		peso = math.min(def.peso[2], peso * 1.2)
	end
	local escala = (peso / medio) ^ (1 / 3)
	local modelo, altura = Modelos.animal(especie, { escala = escala, macho = macho, variante = math.random(1, 2) })
	local vida = math.floor(def.vida * escala ^ 2 + 0.5)
	modelo:SetAttribute("Nombre", def.nombre)
	modelo:SetAttribute("Peso", math.floor(peso * 10 + 0.5) / 10)
	modelo:SetAttribute("Macho", macho)
	modelo:SetAttribute("Vida", vida)
	modelo:SetAttribute("VidaMax", vida)
	modelo:SetAttribute("Mov", "quieto")
	modelo:SetAttribute("Vel", 0)
	local raiz = modelo.PrimaryPart
	local yaw = math.random() * math.pi * 2
	modelo.Parent = carpeta
	raiz.CFrame = CFrame.new(punto.X, punto.Y + altura, punto.Z) * CFrame.Angles(0, yaw, 0)
	-- Gotas de sangre (solo cuando está herido)
	local gotas = Instance.new("ParticleEmitter")
	gotas.Name = "Sangre"
	gotas.Color = ColorSequence.new(Color3.fromRGB(110, 10, 8))
	gotas.Size = NumberSequence.new(0.08 * escala)
	gotas.Lifetime = NumberRange.new(0.6, 1)
	gotas.Speed = NumberRange.new(0.5, 1.5)
	gotas.Acceleration = Vector3.new(0, -30, 0)
	gotas.Rate = 8
	gotas.Enabled = false
	gotas.Parent = raiz
	CollectionService:AddTag(modelo, "Animal")
	local a = {
		especie = especie, def = def, modelo = modelo, raiz = raiz, altura = altura, escala = escala, peso = peso,
		vida = vida, vidaMax = vida, macho = macho, casa = casa or punto, pos = punto, yaw = yaw,
		hasta = 0, pausa = ahora() + math.random() * 4, secuencia = 0, sangrado = 0, sangradoHasta = 0, manchaEn = 0,
		asustadoHasta = 0, agresivoHasta = 0, ultimoAtaque = 0, golpes = 0, danoPiel = 0,
		nada = def.donde == "agua", playa = def.donde == "playa",
	}
	table.insert(lista, a)
	porModelo[modelo] = a
	return a
end

local function aparecerGrupo(especie, lejosDe)
	local def = Config.Animales[especie]
	local centro = buscarSitio(def.donde, lejosDe)
	if not centro then
		return 0
	end
	local n = 0
	for i = 1, def.grupo or 1 do
		local p = centro
		if i > 1 then
			for _ = 1, 12 do
				local x, z = centro.X + math.random(-10, 10), centro.Z + math.random(-10, 10)
				local y = apto(def.donde, x, z)
				if y then
					p = Vector3.new(x, y, z)
					break
				end
			end
		end
		crear(especie, p, centro)
		n = n + 1
	end
	return n
end

-- =====================================================================
--  Movimiento: gira hacia el destino y anda o corre en línea recta (Tween de la raíz)
-- =====================================================================
local function poner(a, mov, vel)
	if a.modelo:GetAttribute("Mov") ~= mov then
		a.modelo:SetAttribute("Mov", mov)
	end
	a.modelo:SetAttribute("Vel", vel or 0)
end

local function moverA(a, x, z, velocidad, mov)
	local y, mat = suelo(x, z)
	if not y then
		return false
	end
	if a.nada then
		if mat ~= AGUA then
			return false
		end
	elseif mat == AGUA or (a.playa and mat ~= Enum.Material.Sand) then
		return false
	end
	if enZona(x, z, 12) or math.abs(x) > LIMITE + 40 or math.abs(z) > LIMITE + 40 then
		return false
	end
	local dx, dz = x - a.pos.X, z - a.pos.Z
	local d = math.sqrt(dx * dx + dz * dz)
	if d < 0.3 then
		return false
	end
	if not a.nada and math.abs(y - a.pos.Y) > d * 1.1 + 1 then
		return false -- demasiado empinado
	end
	local yaw = math.atan2(-dx, -dz)
	local pitch = a.nada and 0 or math.atan2(y - a.pos.Y, d) * 0.6
	local destino = CFrame.new(x, y + a.altura, z) * CFrame.fromEulerAnglesYXZ(pitch, yaw, 0)
	local giro = math.abs(((yaw - a.yaw + math.pi) % (2 * math.pi)) - math.pi)
	a.secuencia = a.secuencia + 1
	local sec = a.secuencia
	if a.tween then
		a.tween:Cancel()
	end
	local t = d / velocidad
	local function andar()
		if sec ~= a.secuencia or a.muerto then
			return
		end
		a.tween = TweenService:Create(a.raiz, TweenInfo.new(t, Enum.EasingStyle.Linear), { CFrame = destino })
		a.tween:Play()
	end
	local tGiro = 0
	if giro > math.rad(35) and mov ~= "correr" then
		-- Primero se gira en el sitio (como un animal de verdad) y luego echa a andar
		tGiro = math.min(0.8, giro / math.rad(160))
		local actual = a.raiz.CFrame
		local girado = CFrame.new(actual.Position) * CFrame.fromEulerAnglesYXZ(0, yaw, 0)
		a.tween = TweenService:Create(a.raiz, TweenInfo.new(tGiro, Enum.EasingStyle.Sine), { CFrame = girado })
		a.tween.Completed:Connect(andar)
		a.tween:Play()
	else
		andar()
	end
	a.yaw = yaw
	a.pos = Vector3.new(x, y, z)
	a.hasta = ahora() + tGiro + t
	poner(a, mov, velocidad)
	return true
end

-- Intenta moverse en una dirección (radianes) probando a girar un poco si no se puede
local function irHacia(a, angulo, distancia, velocidad, mov)
	for i = 0, 7 do
		local desvio = ((i % 2 == 0) and 1 or -1) * math.ceil(i / 2) * math.rad(28)
		local ang = angulo + desvio
		if moverA(a, a.pos.X + math.cos(ang) * distancia, a.pos.Z + math.sin(ang) * distancia, velocidad, mov) then
			return true
		end
	end
	return false
end

-- =====================================================================
--  Detección: distancia, agachado o corriendo, y el viento (olfato)
-- =====================================================================
local function factorDeteccion(a, jugador, hrp)
	local f = 1
	if jugador:GetAttribute("Agachado") then
		f = f * Config.Deteccion.Agachado
	elseif hrp.AssemblyLinearVelocity.Magnitude > 18 then
		f = f * Config.Deteccion.Corriendo
	end
	local viento = workspace.GlobalWind
	local horiz = Vector3.new(viento.X, 0, viento.Z)
	if horiz.Magnitude > 2 then
		local haciaAnimal = Vector3.new(a.pos.X - hrp.Position.X, 0, a.pos.Z - hrp.Position.Z)
		if haciaAnimal.Magnitude > 0.1 then
			local d = horiz.Unit:Dot(haciaAnimal.Unit)
			if d > 0.5 then
				f = f * Config.Deteccion.VientoAFavor
			elseif d < -0.5 then
				f = f * Config.Deteccion.VientoEnContra
			end
		end
	end
	return f
end

local function masCercano(a)
	local mejor, dist, factor = nil, math.huge, 1
	for _, jugador in ipairs(Players:GetPlayers()) do
		local char = jugador.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hrp and hum and hum.Health > 0 then
			local d = (hrp.Position - a.raiz.Position).Magnitude
			if d < dist then
				mejor, dist, factor = jugador, d, factorDeteccion(a, jugador, hrp)
			end
		end
	end
	return mejor, dist, factor
end

-- =====================================================================
--  Muerte y despiece
-- =====================================================================
local despellejar

local function morir(a, jugador)
	if a.muerto then
		return
	end
	a.muerto = true
	a.secuencia = a.secuencia + 1
	if a.tween then
		a.tween:Cancel()
	end
	a.vida = 0
	a.modelo:SetAttribute("Vida", 0)
	poner(a, "muerto", 0)
	a.raiz.Sangre.Enabled = false
	-- Cae de lado (el cangrejo panza arriba)
	local caida
	if a.especie == "Cangrejo" then
		caida = CFrame.new(a.pos.X, a.pos.Y + a.altura, a.pos.Z) * CFrame.Angles(0, a.yaw, math.pi)
	elseif a.nada then
		caida = CFrame.new(a.pos.X, a.pos.Y + a.altura * 0.6, a.pos.Z) * CFrame.Angles(0, a.yaw, math.rad(80))
	else
		caida = CFrame.new(a.pos.X, a.pos.Y + a.altura * 0.42, a.pos.Z) * CFrame.Angles(0, a.yaw, math.rad(88))
	end
	TweenService:Create(a.raiz, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = caida }):Play()
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Despellejar"
	prompt.ActionText = (a.especie == "Cangrejo" or a.especie == "Pato" or a.especie == "Pavo") and "Recoger" or "Despellejar"
	prompt.ObjectText = string.format("%s · %s kg", a.def.nombre, (string.format("%.1f", a.peso):gsub("%.", ",")))
	prompt.HoldDuration = math.clamp(a.peso / 45, 0.8, 4)
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = a.raiz
	prompt.Triggered:Connect(function(quien)
		despellejar(a, quien)
	end)
	a.desaparece = ahora() + 300
	if ctx.alMatar then
		ctx.alMatar(jugador, a)
	end
end

local function quitar(a)
	a.quitado = true
	a.secuencia = a.secuencia + 1
	if a.tween then
		a.tween:Cancel()
	end
	porModelo[a.modelo] = nil
	a.modelo:Destroy()
	for i, b in ipairs(lista) do
		if b == a then
			table.remove(lista, i)
			break
		end
	end
	-- Sale otro de la misma especie más adelante, lejos de los jugadores
	task.delay(a.def.reaparicion, function()
		local lejos = {}
		for _, p in ipairs(Players:GetPlayers()) do
			local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				table.insert(lejos, hrp.Position)
			end
		end
		local punto = buscarSitio(a.def.donde, lejos)
		if punto then
			crear(a.especie, punto, punto)
		end
	end)
end

function despellejar(a, jugador)
	if a.quitado or not a.muerto then
		return
	end
	local hrp = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart")
	if not hrp or (hrp.Position - a.raiz.Position).Magnitude > 14 then
		return
	end
	local def = a.def
	local botin = {}
	-- Carne según el peso (los disparos y las explosiones estropean parte)
	if def.carne and def.rendimiento > 0 then
		local perdida = math.min(0.6, math.max(0, a.golpes - 1) * 0.05 + (a.explosion and 0.4 or 0))
		local kg = math.floor(a.peso * def.rendimiento * (1 - perdida) * 10 + 0.5) / 10
		if kg > 0 then
			local obj = Config.Objetos[def.carne]
			table.insert(botin, { id = def.carne, nombre = obj.nombre, cantidad = kg, unidad = "kg", valor = math.floor(kg * obj.porKg + 0.5) })
		end
	end
	-- Piel y trofeos: valen más cuanto más grande es el animal y menos daño tiene la piel
	local calidad, mult = "Buena", 1
	for _, c in ipairs(Config.CalidadPiel) do
		if a.danoPiel <= c[1] then
			calidad, mult = c[2], c[3]
			break
		end
	end
	local extra = {}
	for id, n in pairs(def.botin or {}) do
		extra[id] = n
	end
	if a.macho and def.macho then
		for id, n in pairs(def.macho) do
			extra[id] = n
		end
	end
	for id, n in pairs(extra) do
		local obj = Config.Objetos[id]
		local esPiel = string.sub(id, 1, 4) == "Piel"
		local m = esPiel and mult or 1
		local tam = (id == "Cornamenta") and a.escala ^ 3 or a.escala ^ 2
		if m > 0 then
			table.insert(botin, {
				id = id, nombre = obj.nombre, cantidad = n, unidad = "", calidad = esPiel and calidad or nil,
				valor = math.floor(obj.precio * n * m * tam + 0.5),
			})
		end
	end
	if ctx.darBotin then
		ctx.darBotin(jugador, botin, a)
	end
	quitar(a)
end

-- =====================================================================
--  Daño (lo llaman las armas)
-- =====================================================================
-- Devuelve el animal al que pertenece una pieza (o nil)
function Animales.de(parte)
	local m = parte
	while m and m ~= carpeta do
		if porModelo[m] then
			return porModelo[m]
		end
		m = m.Parent
	end
	return nil
end

-- dano ya multiplicado o no según "zona"; arma: datos de CazaConfig.Armas; desde: posición del atacante
function Animales.danar(a, dano, zona, jugador, arma, desde, explosion)
	if not a or a.muerto then
		return nil
	end
	local mult = Config.Zonas[zona] or 1
	local total = dano * mult
	a.vida = a.vida - total
	a.golpes = a.golpes + 1
	a.danoPiel = a.danoPiel + (arma.piel or 0.2) * ((zona == "Cabeza" or zona == "Cuello") and 0.3 or 1) + ((a.golpes > 1) and 0.1 or 0)
	if explosion then
		a.explosion = true
	end
	a.ultimoAtacante = jugador
	a.modelo:SetAttribute("Vida", math.max(0, math.floor(a.vida)))
	if (arma.sangrado or 0) > 0 and zona ~= "Cola" then
		a.sangrado = math.max(a.sangrado, total * arma.sangrado * 0.06)
		a.sangradoHasta = ahora() + 14
		a.raiz.Sangre.Enabled = true
	end
	a.asustadoHasta = ahora() + 12
	a.amenaza = desde
	if a.def.tipo ~= "presa" then
		a.agresivoHasta = ahora() + 25
		a.objetivo = jugador
	end
	if a.vida <= 0 then
		morir(a, jugador)
		return "muerto", total
	end
	a.hasta = 0 -- reacciona ya
	return "herido", total
end

-- Animales a menos de "radio" studs de un punto (para explosiones y fuego)
function Animales.cerca(pos, radio)
	local out = {}
	for _, a in ipairs(lista) do
		if not a.muerto and (a.raiz.Position - pos).Magnitude < radio then
			table.insert(out, a)
		end
	end
	return out
end

-- Un ruido (disparo, explosión): las presas que lo oyen huyen de él
function Animales.ruido(pos, radio)
	if radio <= 0 then
		return
	end
	for _, a in ipairs(lista) do
		if not a.muerto and a.def.tipo ~= "depredador" and (a.raiz.Position - pos).Magnitude < radio then
			a.asustadoHasta = ahora() + 8
			a.amenaza = pos
			a.hasta = 0
			sonido(a)
		end
	end
end

-- =====================================================================
--  Cerebro de cada animal
-- =====================================================================
local function huir(a, desde)
	local ang
	if desde then
		ang = math.atan2(a.pos.Z - desde.Z, a.pos.X - desde.X) + math.rad(math.random(-30, 30))
	else
		ang = math.random() * math.pi * 2
	end
	local v = a.def.correr * M * (a.vida < a.vidaMax * 0.5 and 0.8 or 1)
	irHacia(a, ang, v * 1.1, v, "correr")
end

local function pasear(a)
	local dCasa = Vector3.new(a.casa.X - a.pos.X, 0, a.casa.Z - a.pos.Z)
	local ang
	if dCasa.Magnitude > 25 * M then
		ang = math.atan2(dCasa.Z, dCasa.X) + math.rad(math.random(-40, 40))
	else
		ang = math.random() * math.pi * 2
	end
	local dist = math.random(4, 18) * M * (a.nada and 1.5 or 1) * math.max(0.3, a.escala)
	if irHacia(a, ang, dist, a.def.andar * M, "andar") then
		a.pausa = a.hasta + math.random(1, 4)
	end
end

local function atacar(a, jugador, dist)
	local char = jugador.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or hum.Health <= 0 then
		a.objetivo = nil
		return
	end
	local alcance = (1.1 + a.escala * 0.9) * M * (a.especie == "Oso" and 1.25 or 1)
	if dist <= alcance then
		if ahora() - a.ultimoAtaque >= a.def.espera then
			a.ultimoAtaque = ahora()
			-- Mira a la presa y muerde o zarpea
			local d = hrp.Position - a.raiz.Position
			a.yaw = math.atan2(-d.X, -d.Z)
			a.raiz.CFrame = CFrame.new(a.raiz.Position) * CFrame.Angles(0, a.yaw, 0)
			poner(a, "atacar", 0)
			hum:TakeDamage(a.def.dano)
			sonido(a)
			if ctx.alAtacar then
				ctx.alAtacar(jugador, a)
			end
		end
		return
	end
	local v = a.def.correr * M * 0.9
	local dir = Vector3.new(hrp.Position.X - a.pos.X, 0, hrp.Position.Z - a.pos.Z)
	local paso = math.min(dist - alcance * 0.6, v * 0.5)
	if paso > 0.5 then
		local u = dir.Unit
		if not moverA(a, a.pos.X + u.X * paso, a.pos.Z + u.Z * paso, v, "correr") then
			irHacia(a, math.atan2(dir.Z, dir.X), paso, v, "correr")
		end
	end
end

local function pensar(a, dt)
	local t = ahora()
	if a.muerto then
		if a.desaparece and t > a.desaparece and not a.quitado then
			quitar(a)
		end
		return
	end
	-- Desangrarse
	if a.sangrado > 0 then
		if t < a.sangradoHasta then
			a.vida = a.vida - a.sangrado * dt
			a.modelo:SetAttribute("Vida", math.max(0, math.floor(a.vida)))
			if t > a.manchaEn and not a.nada then
				a.manchaEn = t + 1.6
				local y = suelo(a.raiz.Position.X, a.raiz.Position.Z)
				if y and #rastros:GetChildren() < 500 then
					local m = Modelos.manchaSangre(CFrame.new(a.raiz.Position.X, y + 0.03, a.raiz.Position.Z), (0.35 + math.random() * 0.4) * a.escala)
					m.Parent = rastros
					Debris:AddItem(m, 240)
				end
			end
			if a.vida <= 0 then
				morir(a, a.ultimoAtacante)
				return
			end
		else
			a.sangrado = 0
			a.raiz.Sangre.Enabled = false
		end
	end
	local jugador, dist, factor = masCercano(a)
	if dist > Config.DistanciaActiva * M and t > a.asustadoHasta then
		if t >= a.hasta and a.modelo:GetAttribute("Mov") ~= "quieto" then
			poner(a, "quieto", 0)
		end
		return -- nadie cerca: el animal "duerme" para no gastar servidor
	end
	local def = a.def
	local hrp = jugador and jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart")
	local tipo = def.tipo
	if tipo ~= "presa" and a.vida < a.vidaMax * 0.25 then
		tipo = "presa" -- muy herido: huye
	end
	if tipo == "depredador" or tipo == "neutral" then
		local agresion = (def.agresion or 0) * M * factor
		if t < a.agresivoHasta and a.objetivo then
			local thrp = a.objetivo.Character and a.objetivo.Character:FindFirstChild("HumanoidRootPart")
			if thrp and (thrp.Position - a.raiz.Position).Magnitude < 160 * M then
				if t >= a.hasta - 0.05 then
					atacar(a, a.objetivo, (thrp.Position - a.raiz.Position).Magnitude)
				end
				return
			end
			a.objetivo = nil
		end
		if jugador and dist < agresion then
			if a.objetivo ~= jugador then
				sonido(a)
			end
			a.objetivo = jugador
			a.agresivoHasta = t + 12
			if t >= a.hasta - 0.05 then
				atacar(a, jugador, dist)
			end
			return
		end
	end
	if tipo == "presa" then
		local huida = (def.huida or 0) * M * factor
		if jugador and dist < huida then
			if t > a.asustadoHasta then
				sonido(a)
			end
			a.asustadoHasta = t + 6
			a.amenaza = hrp and hrp.Position or a.amenaza
		end
		if t < a.asustadoHasta then
			if t >= a.hasta - 0.1 then
				huir(a, a.amenaza)
			end
			return
		end
	end
	-- Tranquilo: pasta, descansa o pasea
	if t >= a.hasta and t >= a.pausa then
		local r = math.random()
		if r < 0.45 and not a.nada then
			poner(a, "pastar", 0)
			a.pausa = t + math.random(3, 9)
		elseif r < 0.6 then
			poner(a, "quieto", 0)
			a.pausa = t + math.random(2, 6)
		else
			pasear(a)
		end
	elseif t >= a.hasta and a.modelo:GetAttribute("Mov") == "andar" then
		poner(a, "quieto", 0)
	end
end

-- =====================================================================
--  Arranque
-- =====================================================================
function Animales.iniciar(contexto)
	ctx = contexto
	Config, Modelos, W = ctx.Config, ctx.Modelos, ctx.W
	M = Config.StudsPorMetro
	params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	params.IgnoreWater = false
	carpeta = workspace:FindFirstChild("Animales") or Instance.new("Folder")
	carpeta.Name = "Animales"
	carpeta.Parent = workspace
	rastros = workspace:FindFirstChild("RastrosSangre") or Instance.new("Folder")
	rastros.Name = "RastrosSangre"
	rastros.Parent = workspace
	local total = 0
	local especies = {}
	for especie in pairs(Config.Animales) do
		table.insert(especies, especie)
	end
	table.sort(especies)
	for _, especie in ipairs(especies) do
		local def = Config.Animales[especie]
		local hechos = 0
		local intentos = 0
		while hechos < def.cantidad and intentos < def.cantidad * 2 do
			intentos = intentos + 1
			hechos = hechos + aparecerGrupo(especie)
		end
		total = total + hechos
		task.wait()
	end
	task.spawn(function()
		local antes = ahora()
		while true do
			task.wait(0.2)
			local t = ahora()
			local dt = t - antes
			antes = t
			for i = #lista, 1, -1 do
				local a = lista[i]
				if a then
					local ok, err = pcall(pensar, a, dt)
					if not ok then
						warn("[Caza] animal", a.especie, err)
					end
				end
			end
		end
	end)
	return total
end

function Animales.lista()
	return lista
end

return Animales
]=]
CAZA_SERVIDOR_MODULOS["Armas"] = [=[
--[[
	Armas (servidor). El servidor decide si un disparo acierta para que nadie pueda hacer trampas:
	  · Las balas, flechas y lanzables vuelan con su velocidad real y caen por la gravedad. Se simulan
	    paso a paso, así que una flecha tarda en llegar y un ciervo que corre puede esquivarla.
	  · El daño depende de dónde acierta (cabeza, cuello, pecho...) y de la distancia (las balas pierden fuerza).
	  · La dispersión aumenta al moverte y baja agachado o apuntando. Cada disparo hace ruido y espanta animales.
	  · Recarga real: gasta cartuchos de la mochila y tarda lo que tarda cada arma.
	  · La granada explota a los 3 segundos y el molotov incendia el suelo. Las dos hacen daño también a quien
	    las lanza si está cerca.
]]
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")

local Armas = {}
local Config, Animales, Economia, Efectos, Aviso, M
local ctx
local ultimo = {}
local siguienteId = 0
local efectos

local function ahora()
	return os.clock()
end

local function herramienta(jugador, id)
	local char = jugador.Character
	if not char then
		return nil
	end
	local tool = char:FindFirstChildOfClass("Tool")
	if tool and tool:GetAttribute("Arma") == id then
		local hum = char:FindFirstChildOfClass("Humanoid")
		local hrp = char:FindFirstChild("HumanoidRootPart")
		local head = char:FindFirstChild("Head")
		if hum and hum.Health > 0 and hrp and head then
			return tool, char, hrp, head
		end
	end
	return nil
end

local function puede(jugador, id, cadencia)
	ultimo[jugador] = ultimo[jugador] or {}
	if ahora() - (ultimo[jugador][id] or -math.huge) < cadencia * 0.85 then
		return false
	end
	ultimo[jugador][id] = ahora()
	return true
end

local function parametros(char)
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	local excluir = { char, efectos }
	for _, n in ipairs({ "RastrosSangre", "Corchos" }) do
		local f = workspace:FindFirstChild(n)
		if f then
			table.insert(excluir, f)
		end
	end
	p.FilterDescendantsInstances = excluir
	p.IgnoreWater = false
	return p
end

-- Desvía una dirección un ángulo al azar dentro de un cono
local function desviar(dir, grados)
	if grados <= 0 then
		return dir
	end
	local r = math.rad(grados) * math.sqrt(math.random())
	local giro = math.random() * math.pi * 2
	return (CFrame.lookAt(Vector3.new(0, 0, 0), dir) * CFrame.Angles(0, 0, giro) * CFrame.Angles(r, 0, 0)).LookVector
end

local function jugadorDe(parte)
	local modelo = parte:FindFirstAncestorOfClass("Model")
	while modelo do
		local p = Players:GetPlayerFromCharacter(modelo)
		if p then
			return p, modelo
		end
		modelo = modelo.Parent and modelo.Parent:FindFirstAncestorOfClass("Model")
	end
	return nil
end

-- Aplica un impacto. Devuelve qué ha tocado ("animal", "jugador", "agua", "suelo") y el resultado
local function impacto(jugador, cfg, res, distancia, desde)
	local parte = res.Instance
	local caida = 1
	if cfg.tipo == "bala" and cfg.alcance then
		caida = math.clamp(1 - (distancia / (cfg.alcance * M)) ^ 2 * 0.5, 0.5, 1)
	end
	local a = Animales.de(parte)
	if a then
		local zona = parte:GetAttribute("Zona") or "Cuerpo"
		local estado = Animales.danar(a, cfg.dano * caida, zona, jugador, cfg, desde)
		return "animal", estado, zona
	end
	local otro, modelo = jugadorDe(parte)
	if otro and otro ~= jugador and Config.DanoEntreJugadores then
		local hum = modelo:FindFirstChildOfClass("Humanoid")
		if hum then
			hum:TakeDamage(cfg.dano * caida * ((parte.Name == "Head") and 2 or 1))
			return "jugador", (hum.Health <= 0) and "muerto" or "herido", (parte.Name == "Head") and "Cabeza" or "Cuerpo"
		end
	end
	if res.Material == Enum.Material.Water then
		return "agua"
	end
	return "suelo"
end

-- Simula un proyectil (bala, flecha o lanzable) paso a paso con gravedad
-- "origen" es desde donde vuela de verdad; "visual" desde donde lo dibujan los clientes (la boca del arma)
local function simular(jugador, char, id, alcance, origen, velocidad, alImpactar, visual)
	siguienteId = siguienteId + 1
	local pid = siguienteId
	local g = Vector3.new(0, -Config.Gravedad * M, 0)
	local params = parametros(char)
	Efectos:FireAllClients("disparo", { id = pid, arma = id, desde = visual or origen, v = velocidad, g = g.Y, jugador = jugador.UserId })
	task.spawn(function()
		local p, v = origen, velocidad
		local recorrido, t = 0, 0
		while recorrido < alcance and t < 15 do
			local dt = math.min(RunService.Heartbeat:Wait(), 0.05)
			local nueva = p + v * dt + g * (0.5 * dt * dt)
			local paso = nueva - p
			local res = workspace:Raycast(p, paso, params)
			if res then
				alImpactar(res, recorrido + (res.Position - p).Magnitude, pid, v)
				return
			end
			recorrido = recorrido + paso.Magnitude
			v = v + g * dt
			p = nueva
			t = t + dt
		end
		Efectos:FireAllClients("fin", { id = pid, pos = p })
	end)
	return pid
end

-- =====================================================================
--  Disparar (armas de fuego, arco y ballesta)
-- =====================================================================
function Armas.disparar(jugador, id, apunta, apuntando)
	local cfg = Config.Armas[id]
	if not cfg or (cfg.tipo ~= "bala" and cfg.tipo ~= "proyectil") or typeof(apunta) ~= "Vector3" then
		return
	end
	local tool, char, hrp, head = herramienta(jugador, id)
	if not tool or tool:GetAttribute("Recargando") then
		return
	end
	local carga = tool:GetAttribute("Cargador") or 0
	if carga <= 0 then
		Aviso:FireClient(jugador, "vacio", { arma = id })
		return
	end
	if not puede(jugador, id, cfg.cadencia) then
		return
	end
	tool:SetAttribute("Cargador", carga - 1)
	-- La bala sale desde la cabeza (donde está la vista del jugador) para que acierte donde apunta incluso
	-- a bocajarro; los clientes la dibujan saliendo de la boca del arma
	local origen = head.Position
	local boca = tool:FindFirstChild("Handle") and tool.Handle:FindFirstChild("Boca")
	local visual = boca and boca.WorldPosition or origen
	if (visual - origen).Magnitude > 10 then
		visual = origen
	end
	local dir = apunta - origen
	if dir.Magnitude < 0.5 then
		return
	end
	dir = dir.Unit
	local disp = cfg.dispersion or 0
	if hrp.AssemblyLinearVelocity.Magnitude > 3 then
		disp = disp * 2
	end
	if jugador:GetAttribute("Agachado") then
		disp = disp * 0.6
	end
	if apuntando == true then
		disp = disp * 0.5
	end
	for _ = 1, cfg.perdigones or 1 do
		simular(jugador, char, id, cfg.alcance * M, origen, desviar(dir, disp) * (cfg.velocidad * M), function(res, distancia, pid)
			local tipo, estado, zona = impacto(jugador, cfg, res, distancia, origen)
			Efectos:FireAllClients("impacto", {
				id = pid, pos = res.Position, normal = res.Normal, tipo = tipo, arma = id,
				parte = (cfg.tipo == "proyectil" and tipo == "animal") and res.Instance or nil,
			})
			if estado then
				Aviso:FireClient(jugador, "acierto", { estado = estado, zona = zona, tipo = tipo })
			end
		end, visual)
	end
	Animales.ruido(origen, (cfg.ruido or 0) * M)
	-- El arco y la ballesta se cargan solos si quedan flechas
	if cfg.tipo == "proyectil" then
		task.delay(0.15, function()
			Armas.recargar(jugador, id)
		end)
	end
end

-- =====================================================================
--  Recargar
-- =====================================================================
function Armas.recargar(jugador, id)
	local cfg = Config.Armas[id]
	if not cfg or not cfg.cargador then
		return
	end
	local tool = herramienta(jugador, id)
	if not tool or tool:GetAttribute("Recargando") then
		return
	end
	local carga = tool:GetAttribute("Cargador") or 0
	if carga >= cfg.cargador then
		return
	end
	if Economia.municion(jugador, cfg.municion) <= 0 then
		Aviso:FireClient(jugador, "sinMunicion", { arma = id, municion = cfg.municion })
		return
	end
	tool:SetAttribute("Recargando", true)
	Efectos:FireAllClients("recarga", { jugador = jugador.UserId, arma = id, tiempo = cfg.recarga })
	task.delay(cfg.recarga, function()
		tool:SetAttribute("Recargando", false)
		-- Si guardas el arma a medio recargar, la recarga se pierde
		if tool.Parent ~= jugador.Character then
			return
		end
		local actual = tool:GetAttribute("Cargador") or 0
		local n = math.min(cfg.cargador - actual, Economia.municion(jugador, cfg.municion))
		if n > 0 then
			Economia.gastar(jugador, cfg.municion, n)
			tool:SetAttribute("Cargador", actual + n)
		end
	end)
end

-- =====================================================================
--  Cuerpo a cuerpo
-- =====================================================================
local function balancear(tool)
	-- Golpe visible para todos: el arma sube y baja de golpe
	tool.Grip = CFrame.Angles(math.rad(-55), 0, 0)
	task.delay(0.12, function()
		tool.Grip = CFrame.Angles(math.rad(65), 0, 0)
		task.delay(0.16, function()
			tool.Grip = CFrame.new()
		end)
	end)
end

function Armas.golpear(jugador, id, mirada)
	local cfg = Config.Armas[id]
	if not cfg or cfg.tipo ~= "cuerpo" then
		return
	end
	local tool, char, hrp, head = herramienta(jugador, id)
	if not tool or not puede(jugador, id, cfg.cadencia) then
		return
	end
	local dir = hrp.CFrame.LookVector
	if typeof(mirada) == "Vector3" and mirada.Magnitude > 0.1 then
		local u = mirada.Unit
		dir = Vector3.new(u.X, math.clamp(u.Y, -0.7, 0.7), u.Z).Unit
	end
	balancear(tool)
	Efectos:FireAllClients("golpe", { jugador = jugador.UserId, arma = id })
	local res = workspace:Spherecast(head.Position, 1.1, dir * (cfg.alcance * M + 1), parametros(char))
	if res then
		local tipo, estado, zona = impacto(jugador, cfg, res, 0, head.Position)
		Efectos:FireAllClients("impacto", { id = 0, pos = res.Position, normal = res.Normal, tipo = tipo, arma = id })
		if estado then
			Aviso:FireClient(jugador, "acierto", { estado = estado, zona = zona, tipo = tipo })
		end
	end
	Animales.ruido(head.Position, 5 * M)
end

-- =====================================================================
--  Lanzables: granada y molotov
-- =====================================================================
local function danarPersonas(jugador, pos, radio, dano)
	for _, p in ipairs(Players:GetPlayers()) do
		if p == jugador or Config.DanoEntreJugadores then
			local char = p.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hrp and hum then
				local d = (hrp.Position - pos).Magnitude
				if d < radio then
					hum:TakeDamage(dano * (1 - d / radio))
				end
			end
		end
	end
end

local function explosion(jugador, cfg, pos)
	local R = cfg.radio * M
	local e = Instance.new("Explosion")
	e.Position = pos
	e.BlastRadius = R
	e.BlastPressure = 0
	e.DestroyJointRadiusPercent = 0
	e.ExplosionType = Enum.ExplosionType.NoCraters
	e.Parent = workspace
	Efectos:FireAllClients("explosion", { pos = pos, radio = R })
	for _, a in ipairs(Animales.cerca(pos, R * 1.4)) do
		local d = (a.raiz.Position - pos).Magnitude
		Animales.danar(a, cfg.dano * math.max(0, 1 - d / (R * 1.4)) ^ 1.2, "Cuerpo", jugador, cfg, pos, true)
	end
	danarPersonas(jugador, pos, R * 1.4, cfg.dano * 0.8)
	Animales.ruido(pos, cfg.ruido * M)
end

local function incendio(jugador, cfg, pos)
	local R = cfg.radio * M
	-- Llamas: una grande en el centro y cinco más pequeñas alrededor
	local function llama(posicion, tam)
		local p = Instance.new("Part")
		p.Name = "Incendio"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 1
		p.Size = Vector3.new(1, 0.4, 1)
		p.Position = posicion
		p.Parent = efectos
		local f = Instance.new("Fire")
		f.Size = tam
		f.Heat = 12
		f.Color = Color3.fromRGB(255, 140, 50)
		f.SecondaryColor = Color3.fromRGB(255, 60, 15)
		f.Parent = p
		Debris:AddItem(p, cfg.duracion)
		return p
	end
	local base = llama(pos, 9)
	for i = 1, 5 do
		local ang = i / 5 * math.pi * 2
		llama(pos + Vector3.new(math.cos(ang) * R * 0.6, 0, math.sin(ang) * R * 0.6), 5)
	end
	local humo = Instance.new("Smoke")
	humo.Color = Color3.fromRGB(40, 36, 34)
	humo.Opacity = 0.3
	humo.RiseVelocity = 7
	humo.Size = 8
	humo.Parent = base
	local luz = Instance.new("PointLight")
	luz.Color = Color3.fromRGB(255, 140, 60)
	luz.Brightness = 3
	luz.Range = R * 3
	luz:SetAttribute("Base", 3)
	luz.Parent = base
	CollectionService:AddTag(luz, "LuzFuego")
	Efectos:FireAllClients("explosion", { pos = pos, radio = R, fuego = true })
	Animales.ruido(pos, cfg.ruido * M)
	task.spawn(function()
		local fin = ahora() + cfg.duracion
		while ahora() < fin do
			task.wait(0.5)
			for _, a in ipairs(Animales.cerca(pos, R)) do
				Animales.danar(a, cfg.dano, "Cuerpo", jugador, cfg, pos, true)
			end
			danarPersonas(jugador, pos, R, cfg.dano * 0.6)
		end
	end)
end

function Armas.lanzar(jugador, id, apunta)
	local cfg = Config.Armas[id]
	if not cfg or cfg.tipo ~= "lanzable" or typeof(apunta) ~= "Vector3" then
		return
	end
	local tool, char, hrp, head = herramienta(jugador, id)
	if not tool or not puede(jugador, id, cfg.cadencia) then
		return
	end
	if Economia.municion(jugador, cfg.municion) <= 0 then
		return
	end
	Economia.gastar(jugador, cfg.municion, 1)
	local origen = head.Position + hrp.CFrame.LookVector * 1.5 + Vector3.new(0, 0.4, 0)
	local dir = apunta - origen
	if dir.Magnitude < 0.5 then
		dir = hrp.CFrame.LookVector
	end
	-- Se lanza en parábola: un poco hacia arriba y más fuerte cuanto más lejos apuntas (hasta su máximo)
	local distancia = math.min(dir.Magnitude, 40 * M)
	dir = (dir.Unit + Vector3.new(0, 0.3, 0)).Unit
	local fuerza = math.clamp(math.sqrt(distancia * Config.Gravedad * M), 8 * M, cfg.velocidad * M)
	local lanzado = ahora()
	Efectos:FireAllClients("golpe", { jugador = jugador.UserId, arma = id })
	simular(jugador, char, id, 200 * M, origen, dir * fuerza, function(res, _, pid)
		Efectos:FireAllClients("impacto", { id = pid, pos = res.Position, normal = res.Normal, tipo = "lanzable", arma = id })
		if id == "Molotov" then
			incendio(jugador, cfg, res.Position)
		else
			local espera = math.max(0, (cfg.espoleta or 0) - (ahora() - lanzado))
			task.delay(espera, function()
				explosion(jugador, cfg, res.Position + res.Normal * 0.4)
			end)
		end
	end)
	if Economia.municion(jugador, cfg.municion) <= 0 then
		tool:Destroy()
	end
end

function Armas.iniciar(contexto)
	ctx = contexto
	Config, Animales, Economia = ctx.Config, ctx.Animales, ctx.Economia
	Efectos, Aviso = ctx.remotos.Efectos, ctx.remotos.Aviso
	M = Config.StudsPorMetro
	efectos = workspace:FindFirstChild("EfectosCaza") or Instance.new("Folder")
	efectos.Name = "EfectosCaza"
	efectos.Parent = workspace
	Players.PlayerRemoving:Connect(function(p)
		ultimo[p] = nil
	end)
end

return Armas
]=]
CAZA_SERVIDOR_MODULOS["Pesca"] = [=[
--[[
	Pesca (servidor):
	  1. Lanzas (clic con la caña): el corcho cae al agua donde apuntas, hasta la distancia de tu caña.
	  2. Esperas: con lluvia o nublado pican antes, con sol o nieve tardan más. Las cañas buenas también ayudan.
	  3. Picada: el corcho se hunde de golpe y tienes poco más de un segundo para clavar (clic).
	  4. Pelea: el pez tira en arrancadas y se va cansando. Recoges manteniendo pulsado; si tiras con el
	     sedal muy tenso se rompe, y si le das demasiado sedal se escapa. Un pez mucho más pesado de lo que
	     aguanta tu caña rompe el sedal nada más clavarlo.
	El pez depende del agua (río, lago o mar) y su peso real se decide aquí, en el servidor.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Pesca = {}
local Config, Modelos, W, Economia, Remoto, Efectos, M
local estados = {}
local carpeta
local params

local function ahora()
	return os.clock()
end

-- "mar", "lago" o "rio" según dónde cae el corcho
local function tipoAgua(x, z)
	if not W then
		return "lago"
	end
	if not W.inLandPoly(x, z) then
		return "mar"
	end
	for _, l in ipairs(W.lakes) do
		if math.sqrt((x - l[1]) ^ 2 + (z - l[2]) ^ 2) < l[3] + 15 then
			return "lago"
		end
	end
	return "rio"
end
Pesca.tipoAgua = tipoAgua

local function elegirPez(agua, cana)
	local opciones, total = {}, 0
	for id, pez in pairs(Config.Peces) do
		if pez.aguas[agua] then
			local w = pez.prob
			if pez.prob < 8 then
				w = w * (1 + cana.suerte * 4)
			end
			if pez.basura then
				w = w * (1 - cana.suerte)
			end
			table.insert(opciones, { id, w })
			total = total + w
		end
	end
	table.sort(opciones, function(a, b)
		return a[1] < b[1]
	end)
	local r = math.random() * total
	local id = opciones[#opciones][1]
	for _, o in ipairs(opciones) do
		r = r - o[2]
		if r <= 0 then
			id = o[1]
			break
		end
	end
	local pez = Config.Peces[id]
	-- La mayoría de los peces salen pequeños; los grandes son raros (la suerte de la caña ayuda un poco)
	local f = math.random() ^ (2.6 - cana.suerte * 2)
	local peso = pez.peso[1] + (pez.peso[2] - pez.peso[1]) * f
	return id, math.floor(peso * 100 + 0.5) / 100
end
Pesca.elegirPez = elegirPez

local function limpiar(jugador, motivo, info)
	local s = estados[jugador]
	if not s then
		return
	end
	estados[jugador] = nil
	s.fin = true
	if s.conexion then
		s.conexion:Disconnect()
	end
	if s.flote then
		s.flote:Cancel()
	end
	if s.corcho then
		s.corcho:Destroy()
	end
	if motivo then
		Remoto:FireClient(jugador, motivo, info or {})
	end
end

local function flotar(s)
	local raiz = s.corcho.PrimaryPart
	local base = CFrame.new(s.punto + Vector3.new(0, 0.05, 0))
	raiz.CFrame = base
	s.flote = TweenService:Create(raiz, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { CFrame = base + Vector3.new(0, 0.07, 0) })
	s.flote:Play()
end

local function hundir(s, cuanto, tiempo)
	if s.flote then
		s.flote:Cancel()
	end
	local raiz = s.corcho.PrimaryPart
	TweenService:Create(raiz, TweenInfo.new(tiempo, Enum.EasingStyle.Quad), { CFrame = CFrame.new(s.punto - Vector3.new(0, cuanto, 0)) }):Play()
end

local function esperarPicada(jugador, s)
	while not s.fin do
		local clima = ReplicatedStorage:GetAttribute("Clima")
		local factor = (Config.ClimaPesca[clima] or 1) * s.cana.rapidez
		local e = Config.EsperaPicada
		task.wait((e[1] + math.random() * (e[2] - e[1])) * factor)
		if s.fin or s.estado ~= "esperando" then
			return
		end
		s.pez, s.peso = elegirPez(s.agua, s.cana)
		s.estado = "picando"
		s.picada = ahora()
		-- Un par de toques y luego se hunde de golpe
		hundir(s, 0.5, 0.12)
		Remoto:FireClient(jugador, "picada", {})
		task.wait(Config.TiempoClavar + 0.3)
		if s.fin or s.estado ~= "picando" then
			return
		end
		s.estado = "esperando"
		flotar(s)
		Remoto:FireClient(jugador, "escapado", { motivo = "tarde" })
	end
end

function Pesca.lanzar(jugador, punto)
	if typeof(punto) ~= "Vector3" then
		return
	end
	local char = jugador.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	local id = tool and tool:GetAttribute("Cana")
	local cana = id and Config.Canas[id]
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not cana or not hrp then
		return
	end
	limpiar(jugador)
	-- No se puede lanzar más lejos de lo que da la caña
	local plano = Vector3.new(punto.X - hrp.Position.X, 0, punto.Z - hrp.Position.Z)
	local maximo = cana.distancia * M
	if plano.Magnitude > maximo then
		plano = plano.Unit * maximo
	end
	local x, z = hrp.Position.X + plano.X, hrp.Position.Z + plano.Z
	local res = workspace:Raycast(Vector3.new(x, hrp.Position.Y + 60, z), Vector3.new(0, -300, 0), params)
	if not res or res.Material ~= Enum.Material.Water then
		Remoto:FireClient(jugador, "sinAgua", {})
		return
	end
	local corcho = Modelos.corcho()
	corcho.Parent = carpeta
	local s = {
		tool = tool, id = id, cana = cana, corcho = corcho, punto = res.Position, agua = tipoAgua(x, z),
		estado = "esperando", inicio = ahora(),
	}
	estados[jugador] = s
	flotar(s)
	-- El sedal: de la punta de la caña al corcho, con algo de comba
	local punta = tool:FindFirstChild("Handle") and tool.Handle:FindFirstChild("Punta")
	if punta then
		local sedal = Instance.new("Beam")
		sedal.Name = "Sedal"
		sedal.Attachment0 = punta
		sedal.Attachment1 = corcho.PrimaryPart.Linea
		sedal.Width0 = 0.03
		sedal.Width1 = 0.03
		sedal.Color = ColorSequence.new(Color3.fromRGB(235, 235, 230))
		sedal.Transparency = NumberSequence.new(0.25)
		sedal.FaceCamera = true
		sedal.Segments = 14
		sedal.CurveSize0 = -1.5
		sedal.CurveSize1 = 0.5
		sedal.Parent = corcho
	end
	s.conexion = tool.Unequipped:Connect(function()
		limpiar(jugador, "recogido")
	end)
	Efectos:FireAllClients("chapoteo", { pos = res.Position, jugador = jugador.UserId })
	Remoto:FireClient(jugador, "esperando", { agua = s.agua })
	task.spawn(esperarPicada, jugador, s)
end

function Pesca.clavar(jugador)
	local s = estados[jugador]
	if not s or s.estado ~= "picando" or ahora() - s.picada > Config.TiempoClavar + 0.25 then
		return
	end
	local pez = Config.Peces[s.pez]
	local ratio = s.peso / s.cana.resistencia
	if ratio > 3 then
		limpiar(jugador, "sedalRoto", { motivo = "grande" })
		return
	end
	local hrp = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart")
	local distancia = hrp and Vector3.new(s.punto.X - hrp.Position.X, 0, s.punto.Z - hrp.Position.Z).Magnitude or 20
	s.estado = "luchando"
	s.inicioPelea = ahora()
	s.distancia = distancia
	hundir(s, 0.9, 0.2)
	Remoto:FireClient(jugador, "pelea", {
		fuerza = pez.fuerza, aguante = pez.aguante, ratio = ratio, distancia = distancia,
		recogida = s.cana.recogida * M, basura = pez.basura == true, grande = s.peso >= pez.peso[1] + (pez.peso[2] - pez.peso[1]) * 0.5,
	})
	task.delay(120, function()
		if estados[jugador] == s and s.estado == "luchando" then
			limpiar(jugador, "escapado", { motivo = "cansado" })
		end
	end)
end

function Pesca.resultado(jugador, ok, motivo)
	local s = estados[jugador]
	if not s or s.estado ~= "luchando" then
		return
	end
	if ok ~= true then
		limpiar(jugador, (motivo == "sedal") and "sedalRoto" or "escapado", { motivo = motivo })
		return
	end
	-- El carrete no recoge más rápido de lo que da de sí: tiempo mínimo de la pelea
	local minimo = 1.2 + s.distancia / (s.cana.recogida * M) * 0.7
	if ahora() - s.inicioPelea < minimo then
		limpiar(jugador, "escapado", { motivo = "rapido" })
		return
	end
	local pez = Config.Peces[s.pez]
	local valor = pez.basura and 1 or math.floor(s.peso * pez.precioKg + 0.5)
	local info = { id = s.pez, nombre = pez.nombre, peso = s.peso, valor = valor, agua = s.agua }
	info.record = Economia.darPez(jugador, info)
	limpiar(jugador)
	Remoto:FireClient(jugador, "capturado", info)
	Efectos:FireAllClients("pez", { jugador = jugador.UserId, id = info.id, peso = info.peso })
end

function Pesca.recoger(jugador)
	limpiar(jugador, "recogido")
end

function Pesca.iniciar(ctx)
	Config, Modelos, W, Economia = ctx.Config, ctx.Modelos, ctx.W, ctx.Economia
	Remoto, Efectos = ctx.remotos.Pesca, ctx.remotos.Efectos
	M = Config.StudsPorMetro
	carpeta = workspace:FindFirstChild("Corchos") or Instance.new("Folder")
	carpeta.Name = "Corchos"
	carpeta.Parent = workspace
	params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	params.IgnoreWater = false
	Players.PlayerRemoving:Connect(function(p)
		limpiar(p)
	end)
end

return Pesca
]=]
CAZA_SERVIDOR_MODULOS["Economia"] = [=[
--[[
	Dinero, mochila y equipo de cada jugador (servidor):
	  · Lo que cazas y pescas va a la mochila; se vende en las tiendas de caza y pesca.
	  · En la tienda se compran armas (cada arma de fuego trae una caja de su munición), cañas y munición.
	  · Las armas y cañas que tienes se te dan al aparecer; las balas que quedan en cada cargador se recuerdan.
	  · Se guarda todo entre partidas con DataStore (si el juego lo permite).
]]
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")

local Economia = {}
local Config, Modelos, remotos
local datos = {}
local plantillas
local almacen
local avisadoGuardado = false

local MAX_PECES = 150

local function nuevo()
	local e = { dinero = Config.DineroInicial, armas = {}, canas = {}, municion = {}, cargadores = {}, objetos = {}, peces = {}, records = {}, capturas = {}, caza = {} }
	for _, id in ipairs(Config.KitInicial.armas) do
		e.armas[id] = true
	end
	for _, id in ipairs(Config.KitInicial.canas) do
		e.canas[id] = true
	end
	for tipo, n in pairs(Config.KitInicial.municion) do
		e.municion[tipo] = n
	end
	-- Las armas del equipo inicial empiezan cargadas (el arco con una flecha montada)
	for _, id in ipairs(Config.KitInicial.armas) do
		local cfg = Config.Armas[id]
		if cfg and cfg.cargador then
			e.cargadores[id] = cfg.cargador
		end
	end
	return e
end

local function valorMochila(e)
	local total = 0
	for _, o in ipairs(e.objetos) do
		total = total + o.valor
	end
	for _, p in ipairs(e.peces) do
		total = total + p.valor
	end
	return total
end

local function lista(t)
	local out = {}
	for id, v in pairs(t) do
		if v then
			table.insert(out, id)
		end
	end
	table.sort(out)
	return out
end

-- Manda al jugador un resumen de su dinero, equipo y mochila (para la pantalla y la tienda)
local function enviar(jugador)
	local e = datos[jugador]
	if not e then
		return
	end
	local ls = jugador:FindFirstChild("leaderstats")
	if ls and ls:FindFirstChild("Dinero") then
		ls.Dinero.Value = e.dinero
	end
	jugador:SetAttribute("Dinero", e.dinero)
	for tipo in pairs(Config.Municion) do
		jugador:SetAttribute("Municion_" .. tipo, e.municion[tipo] or 0)
	end
	remotos.Estado:FireClient(jugador, {
		dinero = e.dinero, armas = lista(e.armas), canas = lista(e.canas), municion = e.municion,
		objetos = e.objetos, peces = e.peces, records = e.records, capturas = e.capturas, caza = e.caza, valor = valorMochila(e),
	})
end
Economia.enviar = enviar

-- =====================================================================
--  Herramientas en la mochila de Roblox
-- =====================================================================
local function darHerramienta(jugador, id, esCana)
	local e = datos[jugador]
	local plantilla = plantillas:FindFirstChild((esCana and "Cana_" or "Arma_") .. id)
	local mochila = jugador:FindFirstChild("Backpack")
	if not plantilla or not mochila or not e then
		return
	end
	local tool = plantilla:Clone()
	tool.Name = plantilla:GetAttribute("Nombre") -- en la mochila se ve el nombre real
	if not esCana then
		local cfg = Config.Armas[id]
		if cfg.cargador then
			tool:SetAttribute("Cargador", e.cargadores[id] or 0)
			tool:GetAttributeChangedSignal("Cargador"):Connect(function()
				e.cargadores[id] = tool:GetAttribute("Cargador")
			end)
		end
	end
	tool.Parent = mochila
	return tool
end

local function tieneHerramienta(jugador, id)
	for _, donde in ipairs({ jugador:FindFirstChild("Backpack"), jugador.Character }) do
		if donde then
			for _, t in ipairs(donde:GetChildren()) do
				if t:IsA("Tool") and (t:GetAttribute("Arma") == id or t:GetAttribute("Cana") == id) then
					return true
				end
			end
		end
	end
	return false
end

local function ordenadas(t, cfgs)
	local ids = lista(t)
	table.sort(ids, function(a, b)
		return (cfgs[a] and cfgs[a].orden or 99) < (cfgs[b] and cfgs[b].orden or 99)
	end)
	return ids
end

local function equipar(jugador)
	local e = datos[jugador]
	local mochila = jugador:WaitForChild("Backpack", 10)
	if not e or not mochila then
		return
	end
	for _, t in ipairs(mochila:GetChildren()) do
		if t:IsA("Tool") and t:GetAttribute("CazaPesca") then
			t:Destroy()
		end
	end
	for _, id in ipairs(ordenadas(e.armas, Config.Armas)) do
		if Config.Armas[id] then
			darHerramienta(jugador, id, false)
		end
	end
	for _, id in ipairs(ordenadas(e.canas, Config.Canas)) do
		if Config.Canas[id] then
			darHerramienta(jugador, id, true)
		end
	end
	for id, cfg in pairs(Config.Armas) do
		if cfg.tipo == "lanzable" and (e.municion[cfg.municion] or 0) > 0 then
			darHerramienta(jugador, id, false)
		end
	end
end

-- =====================================================================
--  Munición
-- =====================================================================
function Economia.municion(jugador, tipo)
	local e = datos[jugador]
	return e and (e.municion[tipo] or 0) or 0
end

function Economia.gastar(jugador, tipo, n)
	local e = datos[jugador]
	if e then
		e.municion[tipo] = math.max(0, (e.municion[tipo] or 0) - n)
		jugador:SetAttribute("Municion_" .. tipo, e.municion[tipo])
	end
end

-- =====================================================================
--  Botín de caza y pesca
-- =====================================================================
function Economia.darBotin(jugador, botin, animal)
	local e = datos[jugador]
	if not e then
		return
	end
	for _, b in ipairs(botin) do
		local junto = false
		for _, o in ipairs(e.objetos) do
			if o.id == b.id and o.calidad == b.calidad then
				o.cantidad = math.floor((o.cantidad + b.cantidad) * 10 + 0.5) / 10
				o.valor = o.valor + b.valor
				junto = true
				break
			end
		end
		if not junto then
			table.insert(e.objetos, { id = b.id, nombre = b.nombre, cantidad = b.cantidad, unidad = b.unidad, valor = b.valor, calidad = b.calidad })
		end
	end
	e.caza[animal.especie] = (e.caza[animal.especie] or 0) + 1
	remotos.Aviso:FireClient(jugador, "botin", { nombre = animal.def.nombre, peso = animal.peso, botin = botin })
	enviar(jugador)
end

-- Devuelve true si es el pez más grande de su especie que ha pescado el jugador
function Economia.darPez(jugador, pez)
	local e = datos[jugador]
	if not e then
		return false
	end
	table.insert(e.peces, { id = pez.id, nombre = pez.nombre, peso = pez.peso, valor = pez.valor })
	while #e.peces > MAX_PECES do
		table.remove(e.peces, 1)
	end
	e.capturas[pez.id] = (e.capturas[pez.id] or 0) + 1
	local record = pez.peso > (e.records[pez.id] or 0)
	if record then
		e.records[pez.id] = pez.peso
	end
	enviar(jugador)
	return record
end

-- =====================================================================
--  Tienda
-- =====================================================================
local function cercaDeTienda(jugador)
	local hrp = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false
	end
	for _, prompt in ipairs(CollectionService:GetTagged("TiendaCaza")) do
		local parte = prompt.Parent
		if parte and parte:IsA("BasePart") and (parte.Position - hrp.Position).Magnitude < 30 then
			return true
		end
	end
	return false
end

function Economia.vender(jugador)
	local e = datos[jugador]
	if not e or not cercaDeTienda(jugador) then
		return
	end
	local total = valorMochila(e)
	local n = #e.objetos + #e.peces
	if n == 0 then
		remotos.Aviso:FireClient(jugador, "mensaje", { texto = "No llevas nada que vender." })
		return
	end
	e.dinero = e.dinero + total
	e.objetos = {}
	e.peces = {}
	remotos.Aviso:FireClient(jugador, "venta", { total = total, n = n })
	enviar(jugador)
end

-- tipo: "arma", "cana" o "municion"
function Economia.comprar(jugador, tipo, id)
	local e = datos[jugador]
	if not e or type(id) ~= "string" then
		return
	end
	local function mensaje(texto)
		remotos.Aviso:FireClient(jugador, "mensaje", { texto = texto })
	end
	if not cercaDeTienda(jugador) then
		return mensaje("Tienes que estar en una tienda de caza y pesca.")
	end
	local cfg, precio
	if tipo == "arma" then
		cfg = Config.Armas[id]
		if not cfg or cfg.tipo == "lanzable" then
			return
		end
		if e.armas[id] then
			return mensaje("Ya tienes " .. cfg.nombre .. ".")
		end
		precio = cfg.precio
	elseif tipo == "cana" then
		cfg = Config.Canas[id]
		if not cfg then
			return
		end
		if e.canas[id] then
			return mensaje("Ya tienes " .. cfg.nombre .. ".")
		end
		precio = cfg.precio
	elseif tipo == "municion" then
		cfg = Config.Municion[id]
		if not cfg then
			return
		end
		precio = cfg.precio
	else
		return
	end
	if e.dinero < precio then
		return mensaje("No tienes dinero suficiente.")
	end
	e.dinero = e.dinero - precio
	if tipo == "arma" then
		e.armas[id] = true
		-- Cada arma trae una caja de su munición
		if cfg.municion and Config.Municion[cfg.municion] then
			e.municion[cfg.municion] = (e.municion[cfg.municion] or 0) + Config.Municion[cfg.municion].paquete
		end
		darHerramienta(jugador, id, false)
	elseif tipo == "cana" then
		e.canas[id] = true
		darHerramienta(jugador, id, true)
	else
		e.municion[id] = (e.municion[id] or 0) + cfg.paquete
		-- Molotov y granada son herramientas que aparecen cuando tienes alguna
		for armaId, a in pairs(Config.Armas) do
			if a.tipo == "lanzable" and a.municion == id and not tieneHerramienta(jugador, armaId) then
				darHerramienta(jugador, armaId, false)
			end
		end
	end
	remotos.Aviso:FireClient(jugador, "compra", { nombre = cfg.nombre, precio = precio })
	enviar(jugador)
end

-- =====================================================================
--  Guardar y cargar
-- =====================================================================
local CAMPOS = { "dinero", "armas", "canas", "municion", "cargadores", "objetos", "peces", "records", "capturas", "caza" }

local function cargar(jugador)
	local e = nuevo()
	if almacen then
		local ok, guardado = pcall(function()
			return almacen:GetAsync("j_" .. jugador.UserId)
		end)
		if ok and type(guardado) == "table" then
			for _, campo in ipairs(CAMPOS) do
				if guardado[campo] ~= nil then
					e[campo] = guardado[campo]
				end
			end
		elseif not ok and not avisadoGuardado then
			avisadoGuardado = true
			warn("[Caza] No se pueden cargar los datos guardados (en Studio activa el acceso a los servicios de API):", guardado)
		end
	end
	return e
end

local function guardar(jugador)
	local e = datos[jugador]
	if not almacen or not e then
		return
	end
	local copia = {}
	for _, campo in ipairs(CAMPOS) do
		copia[campo] = e[campo]
	end
	local ok, err = pcall(function()
		almacen:SetAsync("j_" .. jugador.UserId, copia)
	end)
	if not ok and not avisadoGuardado then
		avisadoGuardado = true
		warn("[Caza] No se pudo guardar:", err)
	end
end

local function entrar(jugador)
	local ls = jugador:FindFirstChild("leaderstats") or Instance.new("Folder")
	ls.Name = "leaderstats"
	ls.Parent = jugador
	local dinero = ls:FindFirstChild("Dinero") or Instance.new("IntValue")
	dinero.Name = "Dinero"
	dinero.Parent = ls
	datos[jugador] = cargar(jugador)
	jugador.CharacterAdded:Connect(function()
		task.wait(0.2)
		equipar(jugador)
		enviar(jugador)
	end)
	if jugador.Character then
		equipar(jugador)
	end
	enviar(jugador)
end

function Economia.iniciar(ctx)
	Config, Modelos, remotos = ctx.Config, ctx.Modelos, ctx.remotos
	-- Plantillas de todas las armas y cañas (se copian a la mochila de cada jugador)
	plantillas = ServerStorage:FindFirstChild("CazaHerramientas") or Instance.new("Folder")
	plantillas.Name = "CazaHerramientas"
	plantillas:ClearAllChildren()
	plantillas.Parent = ServerStorage
	for id, cfg in pairs(Config.Armas) do
		local t = Modelos.herramienta(id, cfg, false)
		t.Name = "Arma_" .. id
		t:SetAttribute("Nombre", cfg.nombre)
		t.Parent = plantillas
	end
	for id, cfg in pairs(Config.Canas) do
		local t = Modelos.herramienta(id, cfg, true)
		t.Name = "Cana_" .. id
		t:SetAttribute("Nombre", cfg.nombre)
		t.Parent = plantillas
	end
	if Config.GuardarDatos then
		local ok, ds = pcall(function()
			return DataStoreService:GetDataStore("CazaPesca_v1")
		end)
		if ok then
			almacen = ds
		end
	end
	local function conectarTienda(prompt)
		if not prompt:IsA("ProximityPrompt") then
			return
		end
		prompt.Triggered:Connect(function(jugador)
			if prompt:GetAttribute("Accion") == "Vender" then
				Economia.vender(jugador)
			else
				remotos.Tienda:FireClient(jugador, "abrir", { nombre = prompt:GetAttribute("Tienda") or "Tienda de caza y pesca" })
				enviar(jugador)
			end
		end)
	end
	for _, prompt in ipairs(CollectionService:GetTagged("TiendaCaza")) do
		conectarTienda(prompt)
	end
	CollectionService:GetInstanceAddedSignal("TiendaCaza"):Connect(conectarTienda)
	Players.PlayerAdded:Connect(entrar)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(entrar, p)
	end
	Players.PlayerRemoving:Connect(function(jugador)
		guardar(jugador)
		datos[jugador] = nil
	end)
	game:BindToClose(function()
		for _, p in ipairs(Players:GetPlayers()) do
			guardar(p)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(300)
			for _, p in ipairs(Players:GetPlayers()) do
				guardar(p)
			end
		end
	end)
end

function Economia.datos(jugador)
	return datos[jugador]
end

return Economia
]=]
CAZA_CLIENTE_MODULOS["Pantalla"] = [=[
--[[
	Pantalla de la caza y la pesca (cliente): dinero, munición, mira, avisos, mochila, tienda y la barra
	de tensión del sedal. Todo se crea por código en PlayerGui.
]]
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Pantalla = {}
local Config
local gui
local refs = {}

local BLANCO = Color3.fromRGB(240, 236, 226)
local GRIS = Color3.fromRGB(170, 166, 156)
local FONDO = Color3.fromRGB(22, 24, 22)
local VERDE = Color3.fromRGB(120, 200, 110)
local ROJO = Color3.fromRGB(220, 70, 60)
local DORADO = Color3.fromRGB(236, 196, 90)

local function nuevo(clase, props, padre)
	local o = Instance.new(clase)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = padre
	return o
end

local function redondear(o, r)
	nuevo("UICorner", { CornerRadius = UDim.new(0, r or 8) }, o)
	return o
end

local function texto(props, padre)
	local t = nuevo("TextLabel", {
		BackgroundTransparency = 1, TextColor3 = BLANCO, Font = Enum.Font.GothamMedium, TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
	}, padre)
	for k, v in pairs(props) do
		t[k] = v
	end
	return t
end

local function boton(props, padre, alPulsar)
	local b = nuevo("TextButton", {
		BackgroundColor3 = Color3.fromRGB(60, 74, 52), TextColor3 = BLANCO, Font = Enum.Font.GothamBold, TextSize = 15,
		AutoButtonColor = true,
	}, padre)
	for k, v in pairs(props) do
		b[k] = v
	end
	redondear(b, 6)
	if alPulsar then
		b.MouseButton1Click:Connect(alPulsar)
	end
	return b
end

-- Números a la española: 1,8 kg · 1.250 $
local function kg(n)
	local s = (n >= 10) and string.format("%.1f", n) or string.format("%.2f", n)
	return (s:gsub("%.", ",")) .. " kg"
end
Pantalla.kg = kg
local function dinero(n)
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
	if out:sub(1, 1) == "." then
		out = out:sub(2)
	end
	return out .. " $"
end
Pantalla.dineroTexto = dinero

function Pantalla.crear(config)
	Config = config
	local jugador = Players.LocalPlayer
	gui = nuevo("ScreenGui", { Name = "CazaPantalla", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, jugador:WaitForChild("PlayerGui"))

	-- Dinero (arriba a la derecha)
	local caja = redondear(nuevo("Frame", { Size = UDim2.fromOffset(210, 54), Position = UDim2.new(1, -226, 0, 60), BackgroundColor3 = FONDO, BackgroundTransparency = 0.35 }, gui))
	refs.dinero = texto({ Name = "Dinero", Size = UDim2.new(1, -20, 0, 28), Position = UDim2.fromOffset(12, 4), Text = dinero(0), TextSize = 22, Font = Enum.Font.GothamBold, TextColor3 = DORADO }, caja)
	refs.mochilaValor = texto({ Size = UDim2.new(1, -20, 0, 18), Position = UDim2.fromOffset(12, 31), Text = "Mochila: 0 $  ·  B", TextSize = 13, TextColor3 = GRIS }, caja)

	-- Arma (abajo a la derecha)
	local arma = redondear(nuevo("Frame", { Size = UDim2.fromOffset(250, 74), Position = UDim2.new(1, -266, 1, -170), BackgroundColor3 = FONDO, BackgroundTransparency = 0.35, Visible = false }, gui))
	refs.armaCaja = arma
	refs.armaNombre = texto({ Size = UDim2.new(1, -20, 0, 20), Position = UDim2.fromOffset(12, 6), Text = "", TextSize = 14, TextColor3 = GRIS }, arma)
	refs.armaBalas = texto({ Name = "Balas", Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(12, 24), Text = "", TextSize = 28, Font = Enum.Font.GothamBold }, arma)
	refs.armaAyuda = texto({ Size = UDim2.new(1, -20, 0, 16), Position = UDim2.fromOffset(12, 54), Text = "", TextSize = 12, TextColor3 = GRIS }, arma)

	-- Mira (cuatro rayitas que se separan con la dispersión) y marca de acierto
	local mira = nuevo("Frame", { Size = UDim2.fromOffset(2, 2), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Visible = false }, gui)
	refs.mira = mira
	refs.rayas = {}
	for i, d in ipairs({ { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } }) do
		local vertical = d[1] == 0
		refs.rayas[i] = { nuevo("Frame", { Size = vertical and UDim2.fromOffset(2, 9) or UDim2.fromOffset(9, 2), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = BLANCO, BorderSizePixel = 0 }, mira), d }
	end
	nuevo("Frame", { Size = UDim2.fromOffset(2, 2), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = BLANCO, BorderSizePixel = 0 }, mira)
	refs.acierto = texto({ Size = UDim2.fromOffset(40, 40), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Text = "✕", TextSize = 30, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center, TextTransparency = 1 }, gui)

	-- Mira telescópica: todo negro salvo un círculo central con retícula
	local tele = nuevo("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, gui)
	refs.tele = tele
	local hueco = nuevo("Frame", { Size = UDim2.fromScale(0.62, 0.62), SizeConstraint = Enum.SizeConstraint.RelativeYY, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1 }, tele)
	nuevo("UIStroke", { Thickness = 900, Color = Color3.new(0, 0, 0) }, redondear(hueco, 2000))
	nuevo("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0 }, hueco)
	nuevo("Frame", { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.fromScale(0.5, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0 }, hueco)
	for _, y in ipairs({ 0.58, 0.64, 0.7 }) do
		nuevo("Frame", { Size = UDim2.new(0.04, 0, 0, 1), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, y), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0 }, hueco)
	end

	-- Avisos (arriba en el centro)
	refs.avisos = nuevo("Frame", { Name = "Avisos", Size = UDim2.fromOffset(560, 200), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 70), BackgroundTransparency = 1 }, gui)
	nuevo("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, refs.avisos)

	-- Pesca (abajo en el centro)
	local pesca = redondear(nuevo("Frame", { Size = UDim2.fromOffset(380, 96), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -110), BackgroundColor3 = FONDO, BackgroundTransparency = 0.3, Visible = false }, gui))
	refs.pesca = pesca
	refs.pescaTexto = texto({ Name = "PescaTexto", Size = UDim2.new(1, -24, 0, 24), Position = UDim2.fromOffset(12, 6), Text = "", TextSize = 17, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center }, pesca)
	local barra = redondear(nuevo("Frame", { Size = UDim2.new(1, -24, 0, 16), Position = UDim2.fromOffset(12, 40), BackgroundColor3 = Color3.fromRGB(50, 52, 48) }, pesca), 5)
	refs.tension = redondear(nuevo("Frame", { Name = "Tension", Size = UDim2.fromScale(0.2, 1), BackgroundColor3 = VERDE, BorderSizePixel = 0 }, barra), 5)
	nuevo("Frame", { Size = UDim2.new(0, 2, 1, 4), Position = UDim2.new(0.82, 0, 0, -2), BackgroundColor3 = ROJO, BorderSizePixel = 0 }, barra)
	refs.barraPesca = barra
	refs.pescaInfo = texto({ Name = "PescaInfo", Size = UDim2.new(1, -24, 0, 20), Position = UDim2.fromOffset(12, 64), Text = "", TextSize = 13, TextColor3 = GRIS, TextXAlignment = Enum.TextXAlignment.Center }, pesca)

	-- Destello rojo al recibir un mordisco
	refs.herido = nuevo("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(150, 0, 0), BackgroundTransparency = 1, ZIndex = 0 }, gui)

	-- Mochila (B)
	local mochila = redondear(nuevo("Frame", { Size = UDim2.fromOffset(360, 440), Position = UDim2.new(1, -376, 0, 124), BackgroundColor3 = FONDO, BackgroundTransparency = 0.12, Visible = false }, gui), 10)
	refs.mochila = mochila
	texto({ Size = UDim2.new(1, -24, 0, 30), Position = UDim2.fromOffset(12, 8), Text = "Mochila", TextSize = 20, Font = Enum.Font.GothamBold }, mochila)
	refs.mochilaLista = nuevo("ScrollingFrame", { Size = UDim2.new(1, -24, 1, -86), Position = UDim2.fromOffset(12, 42), BackgroundTransparency = 1, ScrollBarThickness = 5, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, BorderSizePixel = 0 }, mochila)
	nuevo("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, refs.mochilaLista)
	refs.mochilaTotal = texto({ Size = UDim2.new(1, -24, 0, 30), Position = UDim2.new(0, 12, 1, -38), Text = "", TextSize = 16, Font = Enum.Font.GothamBold, TextColor3 = DORADO }, mochila)

	-- Tienda
	local tienda = redondear(nuevo("Frame", { Size = UDim2.fromOffset(680, 480), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = FONDO, BackgroundTransparency = 0.05, Visible = false }, gui), 12)
	refs.tienda = tienda
	refs.tiendaTitulo = texto({ Size = UDim2.new(1, -120, 0, 34), Position = UDim2.fromOffset(18, 10), Text = "Tienda de caza y pesca", TextSize = 22, Font = Enum.Font.GothamBold }, tienda)
	boton({ Size = UDim2.fromOffset(36, 32), Position = UDim2.new(1, -50, 0, 10), Text = "✕", BackgroundColor3 = Color3.fromRGB(110, 50, 44) }, tienda, function()
		tienda.Visible = false
	end)
	refs.pestanas = {}
	for i, p in ipairs({ { "arma", "Armas" }, { "cana", "Cañas" }, { "municion", "Munición" } }) do
		refs.pestanas[p[1]] = boton({ Size = UDim2.fromOffset(130, 32), Position = UDim2.fromOffset(18 + (i - 1) * 138, 52), Text = p[2] }, tienda, function()
			refs.pestana = p[1]
			Pantalla.refrescarTienda()
		end)
	end
	refs.pestana = "arma"
	refs.tiendaLista = nuevo("ScrollingFrame", { Size = UDim2.new(1, -36, 1, -150), Position = UDim2.fromOffset(18, 94), BackgroundTransparency = 1, ScrollBarThickness = 6, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, BorderSizePixel = 0 }, tienda)
	nuevo("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, refs.tiendaLista)
	refs.tiendaDinero = texto({ Size = UDim2.fromOffset(260, 30), Position = UDim2.new(0, 18, 1, -46), Text = "", TextSize = 18, Font = Enum.Font.GothamBold, TextColor3 = DORADO }, tienda)
	refs.vender = boton({ Size = UDim2.fromOffset(260, 36), Position = UDim2.new(1, -278, 1, -50), Text = "Vender la mochila", BackgroundColor3 = Color3.fromRGB(150, 116, 40) }, tienda, function()
		if refs.alVender then
			refs.alVender()
		end
	end)

	-- Botones para móvil y tableta
	refs.movil = nuevo("Frame", { Size = UDim2.fromOffset(200, 200), Position = UDim2.new(1, -230, 1, -420), BackgroundTransparency = 1, Visible = false }, gui)
	return gui
end

-- =====================================================================
--  Actualizaciones
-- =====================================================================
function Pantalla.estado(e)
	refs.e = e
	refs.dinero.Text = dinero(e.dinero)
	refs.mochilaValor.Text = string.format("Mochila: %s  ·  B", dinero(e.valor))
	if refs.mochila.Visible then
		Pantalla.refrescarMochila()
	end
	if refs.tienda.Visible then
		Pantalla.refrescarTienda()
	end
end

function Pantalla.arma(nombre, linea, ayuda)
	refs.armaCaja.Visible = nombre ~= nil
	if nombre then
		refs.armaNombre.Text = nombre
		refs.armaBalas.Text = linea or ""
		refs.armaAyuda.Text = ayuda or ""
	end
end

function Pantalla.mira(visible, separacion)
	refs.mira.Visible = visible
	if visible then
		for _, r in ipairs(refs.rayas) do
			local d = r[2]
			r[1].Position = UDim2.fromOffset(1 + d[1] * (separacion + 5), 1 + d[2] * (separacion + 5))
		end
	end
end

function Pantalla.telescopica(visible)
	refs.tele.Visible = visible
end

function Pantalla.acierto(muerto, cabeza)
	local a = refs.acierto
	a.TextColor3 = muerto and ROJO or BLANCO
	a.TextSize = cabeza and 38 or 30
	a.TextTransparency = 0
	TweenService:Create(a, TweenInfo.new(0.45), { TextTransparency = 1 }):Play()
end

function Pantalla.herido()
	refs.herido.BackgroundTransparency = 0.55
	TweenService:Create(refs.herido, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
end

local orden = 0
function Pantalla.aviso(txt, color, segundos)
	orden = orden + 1
	local hijos = {}
	for _, c in ipairs(refs.avisos:GetChildren()) do
		if c:IsA("TextLabel") then
			table.insert(hijos, c)
		end
	end
	if #hijos >= 4 then
		hijos[1]:Destroy()
	end
	local t = texto({
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = txt, TextSize = 17, Font = Enum.Font.GothamBold,
		TextColor3 = color or BLANCO, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.4, LayoutOrder = orden,
	}, refs.avisos)
	task.delay(segundos or 4, function()
		if t.Parent then
			TweenService:Create(t, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
			task.delay(0.55, function()
				t:Destroy()
			end)
		end
	end)
	return t
end

-- Pesca: texto arriba y barra de tensión
function Pantalla.pesca(visible, txt, info)
	refs.pesca.Visible = visible
	if visible then
		refs.pescaTexto.Text = txt or ""
		refs.pescaInfo.Text = info or ""
	end
end

function Pantalla.tension(t, info, aviso)
	refs.barraPesca.Visible = t ~= nil
	if t then
		refs.tension.Size = UDim2.fromScale(math.clamp(t, 0, 1), 1)
		refs.tension.BackgroundColor3 = (t < 0.55) and VERDE or ((t < 0.82) and Color3.fromRGB(230, 190, 70) or ROJO)
	end
	if info then
		refs.pescaInfo.Text = info
	end
	if aviso then
		refs.pescaTexto.Text = aviso
	end
end

-- =====================================================================
--  Mochila
-- =====================================================================
function Pantalla.alternarMochila()
	refs.mochila.Visible = not refs.mochila.Visible
	if refs.mochila.Visible then
		Pantalla.refrescarMochila()
	end
end

function Pantalla.refrescarMochila()
	local e = refs.e
	local lista = refs.mochilaLista
	for _, c in ipairs(lista:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	if not e then
		return
	end
	local n = 0
	local function fila(izq, der, color)
		n = n + 1
		local f = nuevo("Frame", { Size = UDim2.new(1, -8, 0, 24), BackgroundTransparency = 1, LayoutOrder = n }, lista)
		texto({ Size = UDim2.new(0.72, 0, 1, 0), Text = izq, TextSize = 14, TextColor3 = color or BLANCO, TextTruncate = Enum.TextTruncate.AtEnd }, f)
		texto({ Size = UDim2.new(0.28, 0, 1, 0), Position = UDim2.fromScale(0.72, 0), Text = der or "", TextSize = 14, TextColor3 = DORADO, TextXAlignment = Enum.TextXAlignment.Right }, f)
	end
	if #e.objetos == 0 and #e.peces == 0 then
		fila("Vacía. Caza o pesca algo.", "", GRIS)
	end
	for _, o in ipairs(e.objetos) do
		local cant = (o.unidad == "kg") and kg(o.cantidad) or ("x" .. o.cantidad)
		fila(string.format("%s %s%s", o.nombre, cant, o.calidad and (" · " .. o.calidad) or ""), dinero(o.valor))
	end
	-- Peces agrupados por especie
	local grupos, ordenG = {}, {}
	for _, p in ipairs(e.peces) do
		local g = grupos[p.id]
		if not g then
			g = { nombre = p.nombre, n = 0, kg = 0, valor = 0 }
			grupos[p.id] = g
			table.insert(ordenG, p.id)
		end
		g.n, g.kg, g.valor = g.n + 1, g.kg + p.peso, g.valor + p.valor
	end
	for _, id in ipairs(ordenG) do
		local g = grupos[id]
		fila(string.format("%s x%d (%s)", g.nombre, g.n, kg(g.kg)), dinero(g.valor), Color3.fromRGB(150, 200, 230))
	end
	-- Récords de pesca
	local recs = {}
	for id, peso in pairs(e.records or {}) do
		table.insert(recs, { id, peso })
	end
	table.sort(recs, function(a, b)
		return a[2] > b[2]
	end)
	if #recs > 0 then
		fila("Récords de pesca", "", GRIS)
		for _, r in ipairs(recs) do
			local pez = Config.Peces[r[1]]
			fila("  " .. (pez and pez.nombre or r[1]), kg(r[2]), GRIS)
		end
	end
	refs.mochilaTotal.Text = "Valor total: " .. dinero(e.valor)
end

-- =====================================================================
--  Tienda
-- =====================================================================
function Pantalla.abrirTienda(nombre, alComprar, alVender)
	refs.alComprar, refs.alVender = alComprar, alVender
	refs.tiendaTitulo.Text = nombre or "Tienda de caza y pesca"
	refs.tienda.Visible = true
	Pantalla.refrescarTienda()
end

function Pantalla.tiendaAbierta()
	return refs.tienda.Visible
end

function Pantalla.cerrarTienda()
	refs.tienda.Visible = false
end

local function tiene(lista, id)
	for _, v in ipairs(lista or {}) do
		if v == id then
			return true
		end
	end
	return false
end

function Pantalla.refrescarTienda()
	local e = refs.e or { dinero = 0, armas = {}, canas = {}, municion = {}, valor = 0 }
	for clave, b in pairs(refs.pestanas) do
		b.BackgroundColor3 = (clave == refs.pestana) and Color3.fromRGB(96, 120, 70) or Color3.fromRGB(56, 62, 50)
	end
	refs.tiendaDinero.Text = "Tienes " .. dinero(e.dinero)
	refs.vender.Text = "Vender la mochila (" .. dinero(e.valor or 0) .. ")"
	local lista = refs.tiendaLista
	for _, c in ipairs(lista:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local items = {}
	if refs.pestana == "arma" then
		for id, cfg in pairs(Config.Armas) do
			if cfg.tipo ~= "lanzable" then
				local extra = cfg.municion and Config.Municion[cfg.municion] and (" · usa " .. Config.Municion[cfg.municion].nombre:lower()) or ""
				table.insert(items, { id = id, nombre = cfg.nombre, desc = (cfg.desc or "") .. extra, precio = cfg.precio, orden = cfg.orden, tengo = tiene(e.armas, id) })
			end
		end
	elseif refs.pestana == "cana" then
		for id, cfg in pairs(Config.Canas) do
			local desc = string.format("%s Lanza %d m · aguanta %s", cfg.desc or "", cfg.distancia, kg(cfg.resistencia))
			table.insert(items, { id = id, nombre = cfg.nombre, desc = desc, precio = cfg.precio, orden = cfg.orden, tengo = tiene(e.canas, id) })
		end
	else
		for id, cfg in pairs(Config.Municion) do
			table.insert(items, { id = id, nombre = string.format("%s (x%d)", cfg.nombre, cfg.paquete), desc = "Tienes " .. ((e.municion or {})[id] or 0),
				precio = cfg.precio, orden = cfg.orden, tengo = false })
		end
	end
	table.sort(items, function(a, b)
		return a.orden < b.orden
	end)
	for i, it in ipairs(items) do
		local f = redondear(nuevo("Frame", { Size = UDim2.new(1, -10, 0, 58), BackgroundColor3 = Color3.fromRGB(38, 42, 36), LayoutOrder = i }, lista), 8)
		texto({ Size = UDim2.new(1, -190, 0, 22), Position = UDim2.fromOffset(12, 6), Text = it.nombre, TextSize = 16, Font = Enum.Font.GothamBold }, f)
		texto({ Size = UDim2.new(1, -190, 0, 26), Position = UDim2.fromOffset(12, 28), Text = it.desc, TextSize = 12, TextColor3 = GRIS }, f)
		texto({ Size = UDim2.fromOffset(80, 22), Position = UDim2.new(1, -176, 0, 18), Text = (it.precio > 0) and dinero(it.precio) or "Gratis", TextSize = 15, Font = Enum.Font.GothamBold, TextColor3 = DORADO, TextXAlignment = Enum.TextXAlignment.Right }, f)
		local puede = (not it.tengo) and e.dinero >= it.precio
		boton({ Size = UDim2.fromOffset(84, 34), Position = UDim2.new(1, -92, 0, 12), Text = it.tengo and "Lo tienes" or "Comprar",
			BackgroundColor3 = puede and Color3.fromRGB(70, 120, 60) or Color3.fromRGB(70, 70, 66), AutoButtonColor = puede }, f, function()
			if puede and refs.alComprar then
				refs.alComprar(refs.pestana, it.id)
			end
		end)
	end
end

-- =====================================================================
--  Móvil: botones en pantalla
-- =====================================================================
function Pantalla.botonesMovil(acciones)
	local m = refs.movil
	m.Visible = true
	local botones = {}
	for i, a in ipairs(acciones) do
		local fila, col = math.floor((i - 1) / 2), (i - 1) % 2
		botones[a[1]] = boton({ Size = UDim2.fromOffset(92, 46), Position = UDim2.fromOffset(col * 100, fila * 54), Text = a[2], BackgroundTransparency = 0.25 }, m, a[3])
	end
	return botones
end

return Pantalla
]=]
CAZA_CLIENTE_MODULOS["Efectos"] = [=[
--[[
	Efectos de la caza y la pesca (cliente, solo se ven en tu pantalla):
	  · Balas (trazadora), flechas y lanzables que siguen la misma trayectoria que calcula el servidor.
	    Las flechas se quedan clavadas en el suelo o en el animal (y se mueven con él).
	  · Fogonazo, sonidos, sangre, polvo, salpicaduras y temblor de cámara con las explosiones.
	  · Animación de los animales: patas al andar, al trotar y al galopar, cabeza baja al pastar,
	    mirar alrededor, cola levantada al huir (como hacen los ciervos)...
	  · Peces nadando bajo el agua cerca de ti y el pez en la mano cuando pescas uno.
]]
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local Efectos = {}
local Config, M
local carpeta, animales
local proyectiles = {}
local cache = setmetatable({}, { __mode = "k" })
local cardumenes = {}
local sacudida = 0
local paramsAgua

local function pieza(props, padre)
	local p = Instance.new(props.clase or "Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material[props.mat or "SmoothPlastic"]
	for k, v in pairs(props) do
		if k ~= "clase" and k ~= "mat" and k ~= "elipse" then
			p[k] = v
		end
	end
	if props.elipse then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	p.Parent = padre or carpeta
	return p
end

local function sonido(id, pos, volumen)
	if not id or id == "" then
		return
	end
	local p = pieza({ Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, Position = pos })
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volumen or 1
	s.RollOffMaxDistance = 600
	s.Parent = p
	s:Play()
	Debris:AddItem(p, 6)
end
Efectos.sonido = sonido

local function particulas(pos, color, n, velocidad, tam, gravedad)
	local p = pieza({ Size = Vector3.new(0.3, 0.3, 0.3), Transparency = 1, Position = pos })
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color)
	e.Size = NumberSequence.new(tam or 0.25, 0)
	e.Lifetime = NumberRange.new(0.4, 0.9)
	e.Speed = NumberRange.new(velocidad * 0.5, velocidad)
	e.SpreadAngle = Vector2.new(60, 60)
	e.Acceleration = Vector3.new(0, -(gravedad or 40), 0)
	e.Rate = 0
	e.Parent = p
	e:Emit(n)
	Debris:AddItem(p, 2)
end

-- =====================================================================
--  Proyectiles
-- =====================================================================
local function modeloFlecha(ballesta)
	local largo = ballesta and 1.2 or 2.4
	local m = Instance.new("Model")
	m.Name = "Flecha"
	local asta = pieza({ Name = "Asta", Size = Vector3.new(0.06, 0.06, largo), Color = Color3.fromRGB(34, 34, 36), CFrame = CFrame.new() }, m)
	pieza({ Size = Vector3.new(0.03, 0.14, 0.24), Color = Color3.fromRGB(200, 200, 206), Material = Enum.Material.Metal, CFrame = CFrame.new(0, 0, -largo / 2 - 0.1) }, m)
	for i = 0, 2 do
		local ang = math.rad(i * 120)
		pieza({ Size = Vector3.new(0.02, 0.16, 0.36), Color = (i == 0) and Color3.fromRGB(230, 110, 30) or Color3.fromRGB(236, 236, 230),
			CFrame = CFrame.new(0, 0, largo / 2 - 0.25) * CFrame.Angles(0, 0, ang) * CFrame.new(0, 0.08, 0) }, m)
	end
	m.PrimaryPart = asta
	m.Parent = carpeta
	return m, largo
end

local function modeloLanzable(arma)
	local m = Instance.new("Model")
	if arma == "Molotov" then
		local b = pieza({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.62, 0.34, 0.34), Color = Color3.fromRGB(70, 100, 56), Material = Enum.Material.Glass, Transparency = 0.25, CFrame = CFrame.new() }, m)
		local trapo = pieza({ Size = Vector3.new(0.3, 0.14, 0.14), Color = Color3.fromRGB(196, 186, 166), CFrame = CFrame.new(0.42, 0, 0) }, m)
		local f = Instance.new("Fire")
		f.Size = 1.5
		f.Heat = 3
		f.Parent = trapo
		m.PrimaryPart = b
	else
		m.PrimaryPart = pieza({ Size = Vector3.new(0.32, 0.44, 0.32), Color = Color3.fromRGB(76, 80, 62), Material = Enum.Material.Metal, elipse = true, CFrame = CFrame.new() }, m)
	end
	m.Parent = carpeta
	return m
end

function Efectos.disparo(d)
	local cfg = Config.Armas[d.arma]
	if not cfg then
		return
	end
	local p = { desde = d.desde, v = d.v, g = d.g, t = 0, tipo = cfg.tipo, arma = d.arma }
	if cfg.tipo == "bala" then
		p.visual = pieza({ Size = Vector3.new(0.05, 0.05, 2), Color = Color3.fromRGB(255, 226, 150), Material = Enum.Material.Neon, Transparency = 0.25, CFrame = CFrame.new(d.desde) })
		-- Fogonazo (una vez por disparo, no por perdigón)
		if d.id % (cfg.perdigones or 1) == 0 then
			local f = pieza({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.5, 0.5), Color = Color3.fromRGB(255, 200, 120), Material = Enum.Material.Neon, Position = d.desde })
			local luz = Instance.new("PointLight")
			luz.Color = Color3.fromRGB(255, 190, 110)
			luz.Brightness = 4
			luz.Range = 14
			luz.Parent = f
			Debris:AddItem(f, 0.06)
			sonido(Config.Sonidos[d.arma], d.desde, 1)
		end
	elseif cfg.tipo == "proyectil" then
		p.visual, p.largo = modeloFlecha(d.arma == "Ballesta")
		sonido(Config.Sonidos[d.arma], d.desde, 0.8)
	else
		p.visual = modeloLanzable(d.arma)
		sonido(Config.Sonidos.Lanzar, d.desde, 0.8)
	end
	proyectiles[d.id] = p
end

local function quitar(id)
	local p = proyectiles[id]
	proyectiles[id] = nil
	return p
end

function Efectos.impacto(d)
	local p = d.id and quitar(d.id)
	if p then
		if p.tipo == "proyectil" then
			-- La flecha se queda clavada (y unida al animal si le ha dado)
			local vel = p.v + Vector3.new(0, p.g * p.t, 0)
			local dir = (vel.Magnitude > 0) and vel.Unit or Vector3.new(0, 0, -1)
			local cf = CFrame.lookAt(d.pos - dir * (p.largo * 0.2), d.pos - dir * (p.largo * 0.2) + dir)
			p.visual:PivotTo(cf)
			if d.parte and d.parte.Parent then
				for _, parte in ipairs(p.visual:GetChildren()) do
					if parte:IsA("BasePart") then
						parte.Anchored = false
						parte.Massless = true
						local w = Instance.new("WeldConstraint")
						w.Part0 = d.parte
						w.Part1 = parte
						w.Parent = parte
					end
				end
			end
			Debris:AddItem(p.visual, 30)
		else
			p.visual:Destroy()
		end
	end
	if d.tipo == "animal" or d.tipo == "jugador" then
		particulas(d.pos, Color3.fromRGB(120, 10, 8), 16, 8, 0.18, 30)
	elseif d.tipo == "agua" then
		particulas(d.pos, Color3.fromRGB(220, 230, 235), 20, 12, 0.3, 50)
	elseif d.tipo == "suelo" then
		particulas(d.pos, Color3.fromRGB(120, 108, 90), 10, 6, 0.3, 20)
	end
	if d.tipo ~= "lanzable" then
		sonido(Config.Sonidos.Impacto, d.pos, 0.6)
	end
end

function Efectos.fin(d)
	local p = quitar(d.id)
	if p then
		p.visual:Destroy()
	end
end

function Efectos.explosion(d, posCamara)
	local dist = (d.pos - posCamara).Magnitude
	if not d.fuego then
		sacudida = math.max(sacudida, math.clamp(1 - dist / 220, 0, 1) * 1.6)
		particulas(d.pos, Color3.fromRGB(70, 66, 60), 30, 25, 0.8, 10)
	end
end

local function sonidoEn(jugadorId, id, volumen)
	local p = Players:GetPlayerByUserId(jugadorId)
	local hrp = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	if hrp then
		sonido(id, hrp.Position, volumen)
	end
end

function Efectos.golpe(d)
	sonidoEn(d.jugador, Config.Sonidos.Cuerpo, 0.7)
end

function Efectos.recarga(d)
	sonidoEn(d.jugador, Config.Sonidos.Recarga, 0.8)
end

function Efectos.chapoteo(d)
	particulas(d.pos, Color3.fromRGB(220, 232, 236), 14, 6, 0.25, 30)
	sonido(Config.Sonidos.Chapoteo, d.pos, 0.7)
end

function Efectos.sacudir(n)
	sacudida = math.max(sacudida, n)
end

-- Temblor de cámara (se aplica después de que Roblox coloca la cámara)
function Efectos.camara(dt, camara)
	if sacudida > 0.01 then
		local a = sacudida
		camara.CFrame = camara.CFrame * CFrame.Angles(math.rad((math.random() - 0.5) * a * 2), math.rad((math.random() - 0.5) * a * 2), 0)
		sacudida = sacudida * math.exp(-dt * 6)
	end
end

-- =====================================================================
--  Peces: el de la mano al pescar y los que nadan bajo el agua
-- =====================================================================
-- Largo de un pez según su peso (la relación real peso-talla: W ≈ 0,01·L³ en gramos y cm)
local function largoPez(peso)
	return ((peso * 1000) / 0.01) ^ (1 / 3) / 100 * M
end

local function modeloPez(color, largo, transparencia)
	local m = Instance.new("Model")
	m.Name = "Pez"
	local c = Color3.fromRGB(color[1], color[2], color[3])
	local cuerpo = pieza({ Size = Vector3.new(largo * 0.2, largo * 0.28, largo), Color = c, elipse = true, Transparency = transparencia or 0, CFrame = CFrame.new() }, m)
	pieza({ Size = Vector3.new(largo * 0.16, largo * 0.14, largo * 0.8), Color = c:Lerp(Color3.new(1, 1, 1), 0.5), elipse = true,
		Transparency = transparencia or 0, CFrame = CFrame.new(0, -largo * 0.06, 0) }, m)
	for _, k in ipairs({ 1, -1 }) do
		pieza({ clase = "WedgePart", Size = Vector3.new(largo * 0.03, largo * 0.2, largo * 0.22), Color = c:Lerp(Color3.new(0, 0, 0), 0.2), Transparency = transparencia or 0,
			CFrame = CFrame.new(0, k * largo * 0.08, largo * 0.55) * CFrame.Angles(math.rad(k * 35), 0, 0) }, m)
	end
	pieza({ clase = "WedgePart", Size = Vector3.new(largo * 0.03, largo * 0.12, largo * 0.3), Color = c:Lerp(Color3.new(0, 0, 0), 0.25), Transparency = transparencia or 0,
		CFrame = CFrame.new(0, largo * 0.16, 0.02 * largo) }, m)
	if not transparencia then
		for _, k in ipairs({ 1, -1 }) do
			pieza({ Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1) * largo * 0.05, Color = Color3.new(0.05, 0.05, 0.05), CFrame = CFrame.new(k * largo * 0.08, largo * 0.04, -largo * 0.36) }, m)
		end
	end
	m.PrimaryPart = cuerpo
	m.Parent = carpeta
	return m
end

function Efectos.pez(d)
	local p = Players:GetPlayerByUserId(d.jugador)
	local char = p and p.Character
	local mano = char and (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm"))
	local pez = Config.Peces[d.id]
	if not mano or not pez then
		return
	end
	local largo = math.clamp(largoPez(d.peso), 0.6, 9)
	local m = modeloPez(pez.color, largo)
	local t0 = os.clock()
	task.spawn(function()
		while os.clock() - t0 < 3 and m.Parent and mano.Parent do
			-- Colgando de la mano, coleteando
			m:PivotTo(mano.CFrame * CFrame.new(0, -largo * 0.5 - 0.4, 0) * CFrame.Angles(math.rad(90), math.rad(math.sin(os.clock() * 14) * 15), 0))
			task.wait()
		end
		m:Destroy()
	end)
end

local function nuevoCardumen(centro, superficie)
	local c = { centro = centro, y = superficie - 1.4, peces = {}, nace = os.clock(), rumbo = math.random() * math.pi * 2 }
	for i = 1, math.random(4, 7) do
		local largo = (0.25 + math.random() * 0.35) * M
		table.insert(c.peces, { m = modeloPez({ 50, 62, 56 }, largo, 0.35), r = 1.5 + math.random() * 3, a = math.random() * math.pi * 2, v = 0.6 + math.random() * 0.6, h = (math.random() - 0.5) * 0.8 })
	end
	table.insert(cardumenes, c)
end

local siguienteBusqueda = 0
function Efectos.peces(dt, posCamara)
	local ahora = os.clock()
	if ahora > siguienteBusqueda and #cardumenes < 3 then
		siguienteBusqueda = ahora + 1.5
		local ang, r = math.random() * math.pi * 2, 12 + math.random() * 35
		local x, z = posCamara.X + math.cos(ang) * r, posCamara.Z + math.sin(ang) * r
		local agua = workspace:Raycast(Vector3.new(x, posCamara.Y + 80, z), Vector3.new(0, -260, 0), paramsAgua)
		if agua and agua.Material == Enum.Material.Water then
			nuevoCardumen(Vector3.new(x, 0, z), agua.Position.Y)
		end
	end
	for i = #cardumenes, 1, -1 do
		local c = cardumenes[i]
		local lejos = (Vector3.new(c.centro.X, c.y, c.centro.Z) - posCamara).Magnitude > 110
		if lejos or ahora - c.nace > 45 then
			for _, p in ipairs(c.peces) do
				p.m:Destroy()
			end
			table.remove(cardumenes, i)
		else
			c.rumbo = c.rumbo + (math.random() - 0.5) * dt
			c.centro = c.centro + Vector3.new(math.cos(c.rumbo), 0, math.sin(c.rumbo)) * dt * 0.8
			for _, p in ipairs(c.peces) do
				p.a = p.a + p.v * dt
				local pos = Vector3.new(c.centro.X + math.cos(p.a) * p.r, c.y + p.h, c.centro.Z + math.sin(p.a) * p.r)
				local tangente = Vector3.new(-math.sin(p.a), 0, math.cos(p.a))
				p.m:PivotTo(CFrame.lookAt(pos, pos + tangente) * CFrame.Angles(0, math.rad(math.sin(ahora * 9 + p.a) * 10), 0))
			end
		end
	end
end

-- =====================================================================
--  Animación de los animales (Motor6D.Transform; cada cliente anima los que tiene cerca)
-- =====================================================================
local function juntas(modelo)
	local c = cache[modelo]
	if c then
		return c
	end
	c = { m = {}, fase = math.random() * 6.28, semilla = math.random() * 100, cuello = 0, cola = 0, mira = 0 }
	for _, d in ipairs(modelo:GetDescendants()) do
		if d:IsA("Motor6D") then
			c.m[d.Name] = d
		end
	end
	cache[modelo] = c
	return c
end

local PASO = { DI = 0, TD = 0, DD = math.pi, TI = math.pi }
local GALOPE = { DI = 0, DD = 0.5, TI = math.pi, TD = math.pi + 0.5 }
local SALTO = { DI = 0, DD = 0.2, TI = math.pi * 0.8, TD = math.pi * 0.8 + 0.2 }
local ID = CFrame.new()

function Efectos.animar(dt, posCamara)
	local t = os.clock()
	for _, modelo in ipairs(animales:GetChildren()) do
		local raiz = modelo.PrimaryPart
		if raiz and (raiz.Position - posCamara).Magnitude < 230 then
			local c = juntas(modelo)
			local mov = modelo:GetAttribute("Mov") or "quieto"
			if mov == "muerto" then
				if not c.muerto then
					c.muerto = true
					for _, m in pairs(c.m) do
						m.Transform = ID
					end
				end
			else
				c.muerto = false
				local escala = modelo:GetAttribute("Escala") or 1
				local especie = modelo:GetAttribute("Especie")
				local corre = mov == "correr"
				local anda = corre or mov == "andar"
				local freq = (corre and 2.3 or 1.3) / math.sqrt(math.max(escala, 0.3))
				if especie == "Conejo" then
					freq = corre and 3.2 or 1.6
				end
				if anda then
					c.fase = c.fase + dt * freq * math.pi * 2
				end
				local f = c.fase
				local amp = anda and (corre and 34 or 18) or 0
				local flex = anda and (corre and 55 or 30) or 0
				local patron = corre and GALOPE or PASO
				if modelo:GetAttribute("Salta") and anda then
					patron, amp = SALTO, 42
				end
				for lado, off in pairs(patron) do
					local cadera, rodilla = c.m["Cadera" .. lado], c.m["Rodilla" .. lado]
					if cadera then
						cadera.Transform = CFrame.Angles(math.rad(amp * math.sin(f + off)), 0, 0)
					end
					if rodilla then
						rodilla.Transform = CFrame.Angles(math.rad(-flex * math.max(0, math.cos(f + off))), 0, 0)
					end
				end
				-- Aves (pavo)
				for lado, off in pairs({ I = 0, D = math.pi }) do
					local p = c.m["Pierna" .. lado]
					if p then
						p.Transform = CFrame.Angles(math.rad((anda and (corre and 40 or 26) or 0) * math.sin(f + off)), 0, 0)
					end
				end
				-- Cangrejo
				for i = 1, 8 do
					local p = c.m["Pata" .. i]
					if p then
						p.Transform = anda and CFrame.Angles(0, math.rad(18 * math.sin(f * 2 + i)), math.rad(10 * math.cos(f * 2 + i))) or ID
					end
				end
				-- Cuello: baja la cabeza al pastar, cabecea al andar, mira alrededor parado
				local objetivo = (mov == "pastar") and -55 or (corre and -6 or ((mov == "atacar") and -20 or 0))
				if especie == "Pavo" or especie == "Pato" then
					objetivo = (mov == "pastar") and -40 or 0
				end
				c.cuello = c.cuello + (objetivo - c.cuello) * math.min(1, dt * 3)
				local cabeceo = anda and math.sin(f * 2) * ((especie == "Pavo") and 12 or 4) or 0
				local mirar = (mov == "quieto") and math.sin(t * 0.45 + c.semilla) * 28 or 0
				c.mira = c.mira + (mirar - c.mira) * math.min(1, dt * 2)
				if c.m.Cuello then
					c.m.Cuello.Transform = CFrame.Angles(math.rad(c.cuello + cabeceo), math.rad(c.mira), 0)
				end
				-- Cola: el ciervo la levanta al huir (la "bandera" blanca)
				local cola = (corre and especie == "Ciervo") and -60 or 0
				c.cola = c.cola + (cola - c.cola) * math.min(1, dt * 4)
				if c.m.Cola then
					c.m.Cola.Transform = CFrame.Angles(math.rad(c.cola), math.rad(12 * math.sin(t * 2.4 + c.semilla)), 0)
				end
			end
		end
	end
end

-- =====================================================================
--  Bucle de proyectiles
-- =====================================================================
function Efectos.actualizar(dt)
	for id, p in pairs(proyectiles) do
		p.t = p.t + dt
		if p.t > 15 or not p.visual.Parent then
			quitar(id)
			p.visual:Destroy()
		else
			local t = p.t
			local pos = p.desde + p.v * t + Vector3.new(0, 0.5 * p.g * t * t, 0)
			local vel = p.v + Vector3.new(0, p.g * t, 0)
			local dir = (vel.Magnitude > 0) and vel.Unit or Vector3.new(0, 0, -1)
			if p.tipo == "bala" then
				local largo = math.clamp(vel.Magnitude * dt * 0.8, 1, 12)
				p.visual.Size = Vector3.new(0.05, 0.05, largo)
				p.visual.CFrame = CFrame.lookAt(pos - dir * largo / 2, pos)
			elseif p.tipo == "proyectil" then
				p.visual:PivotTo(CFrame.lookAt(pos, pos + dir))
			else
				p.visual:PivotTo(CFrame.new(pos) * CFrame.Angles(t * 9, t * 4, 0))
			end
		end
	end
end

function Efectos.iniciar(config)
	Config = config
	M = Config.StudsPorMetro
	carpeta = Instance.new("Folder")
	carpeta.Name = "EfectosLocales"
	carpeta.Parent = workspace
	animales = workspace:WaitForChild("Animales", 30) or Instance.new("Folder")
	paramsAgua = RaycastParams.new()
	paramsAgua.FilterType = Enum.RaycastFilterType.Include
	paramsAgua.FilterDescendantsInstances = { workspace.Terrain }
	paramsAgua.IgnoreWater = false
end

return Efectos
]=]

local function crear(padre, clase, nombre, fuente)
	local viejo = padre:FindFirstChild(nombre)
	if viejo then viejo:Destroy() end
	local s = Instance.new(clase)
	s.Name = nombre
	s.Source = fuente
	s.Parent = padre
	return s
end

-- Módulo del mundo con sus partes y sus zonas
local mundo = crear(ServerStorage, "ModuleScript", "MundoAbierto", FUENTE_MUNDO)
for nombre, fuente in pairs(FUENTES) do
	crear(mundo, "ModuleScript", nombre, fuente)
end
local carpeta = Instance.new("Folder")
carpeta.Name = "Zonas"
carpeta.Parent = mundo
for nombre, fuente in pairs(ZONAS) do
	crear(carpeta, "ModuleScript", nombre, fuente)
end

-- Clima
local config = crear(ReplicatedStorage, "ModuleScript", "ClimaConfig", CLIMA_CONFIG)
crear(ServerScriptService, "Script", "ClimaServidor", CLIMA_SERVIDOR)
local jugadorScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts") or Instance.new("StarterPlayerScripts", StarterPlayer)
crear(jugadorScripts, "LocalScript", "ClimaCliente", CLIMA_CLIENTE)

-- Caza, pesca y armas
crear(ReplicatedStorage, "ModuleScript", "CazaConfig", CAZA_CONFIG)
local cazaServidor = crear(ServerScriptService, "Script", "CazaServidor", CAZA_SERVIDOR)
for nombre, fuente in pairs(CAZA_SERVIDOR_MODULOS) do
	crear(cazaServidor, "ModuleScript", nombre, fuente)
end
local cazaCliente = crear(jugadorScripts, "LocalScript", "CazaCliente", CAZA_CLIENTE)
for nombre, fuente in pairs(CAZA_CLIENTE_MODULOS) do
	crear(cazaCliente, "ModuleScript", nombre, fuente)
end

-- Carpeta para tus propios modelos 3D (árboles de la Toolbox...). Si ya existe no se toca
local modelos = ServerStorage:FindFirstChild("ModelosMundo")
if not modelos then
	modelos = Instance.new("Folder")
	modelos.Name = "ModelosMundo"
	modelos.Parent = ServerStorage
end
for _, tipo in ipairs({ "Pino", "Roble", "Abedul", "Muerto", "Arbusto" }) do
	if not modelos:FindFirstChild(tipo) then
		local f = Instance.new("Folder")
		f.Name = tipo
		f.Parent = modelos
	end
end

-- Ajustes para que se vea y vaya bien
pcall(function() game:GetService("Lighting").Technology = Enum.Technology.Future end)
pcall(function() game:GetService("MaterialService").Use2022Materials = true end)
pcall(function() workspace.StreamingEnabled = true end)
for _, nombre in ipairs({ "Baseplate", "SpawnLocation" }) do
	local obj = workspace:FindFirstChild(nombre)
	if obj and obj:IsA("BasePart") then obj:Destroy() end
end

local Mundo = require(mundo)
local inicio = os.clock()
print("[Mundo] 1/3 Construyendo las piezas...")
local viejo = workspace:FindFirstChild("Mundo")
if viejo then viejo:Destroy() end
local modelo = Mundo.construir()
modelo.Parent = workspace
print("[Mundo] 2/3 Generando el terreno...")
Mundo.generarTerreno(function(hechos, total)
	if hechos % 32 == 0 then
		print(string.format("[Mundo]     terreno %d%%", math.floor(hechos / total * 100)))
	end
end)
print("[Mundo] 3/3 Aplicando el clima inicial...")
local Clima = require(config)
Clima.aplicar(Clima.ClimaInicial or "Nublado")
game:GetService("Lighting").ClockTime = Clima.HoraFija
print(string.format("[Mundo] Listo en %.0f segundos. Guarda el lugar para conservarlo.", os.clock() - inicio))
