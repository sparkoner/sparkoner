-- Pega TODO este texto en la barra de comandos de Roblox Studio (Ver > Barra de comandos) y pulsa Enter.
-- Crea ServerStorage.MapBuilder y los mapas en ServerStorage.MapasDuelo.
-- Archivo generado por build_bundle.py: edita los .luau de MapBuilder/ y vuelve a generarlo.

local VER_MAPA = "Gasolinera" -- mapa que se coloca en Workspace para verlo (pon nil para ninguno)

local ServerStorage = game:GetService("ServerStorage")
local FUENTE_MAPBUILDER = [=[
--[[
	MapBuilder: construye mapas de duelo con piezas simples (Parts).

	Uso desde la barra de comandos de Studio (con el módulo en ServerStorage):
		require(game.ServerStorage.MapBuilder).buildAll()

	En el juego, para cargar un mapa:
		local MapBuilder = require(game.ServerStorage.MapBuilder)
		local mapa, spawns = MapBuilder.load("Gasolinera")
		-- spawns.A y spawns.B son listas de CFrames
]]

local MapBuilder = {}
MapBuilder.Props = {}

local CONTAINER_NAME = "MapasDuelo"

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
MapBuilder.rgb = rgb

-- =====================================================================
--  Constructor
-- =====================================================================
local Builder = {}
Builder.__index = Builder

local Group = {}
Group.__index = Group

function MapBuilder.new(name)
	local model = Instance.new("Model")
	model.Name = name
	local self = setmetatable({ model = model, mirrored = false, folders = {} }, Builder)
	self:folder("Mapa")
	self:folder("Decoracion")
	self:folder("Spawns")
	return self
end

local TOP_LEVEL = { Spawns = true, Terreno = true, Limites = true }

function Builder:folder(name)
	-- Con zone() las piezas van a Zonas/<zona>/<carpeta>; spawns, terreno y límites siempre arriba
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

-- Posición en grados. Con symmetric() todo se repite reflejado en X (x -> -x).
function Builder:cframe(pos, rot)
	local x, y, z = pos[1], pos[2], pos[3]
	local rx, ry, rz = 0, 0, 0
	if rot then
		rx, ry, rz = rot[1] or 0, rot[2] or 0, rot[3] or 0
	end
	if self.mirrored then
		x, ry, rz = -x, -ry, -rz
	end
	return CFrame.new(x, y, z) * CFrame.fromEulerAnglesYXZ(math.rad(rx), math.rad(ry), math.rad(rz))
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
function Builder:symmetric(fn)
	fn(self)
	self.mirrored = true
	fn(self)
	self.mirrored = false
end

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

for _, method in ipairs({ "box", "wedge", "truss", "ball", "cylinder" }) do
	Group[method] = function(self, p)
		return self.b[method](self.b, self:transform(p))
	end
end

-- =====================================================================
--  Spawns, límites, carteles, luces e iluminación
-- =====================================================================
-- yaw en grados: 0 mira hacia -Z, -90 mira hacia +X
function Builder:spawn(team, pos, yaw)
	if self.mirrored then
		team = (team == "A") and "B" or "A"
	end
	local part = self:part("Part", {
		name = "Spawn" .. team,
		size = { 4, 1, 4 },
		pos = pos,
		rot = { 0, yaw or 0, 0 },
		color = team == "A" and { 60, 120, 255 } or { 255, 70, 70 },
		transparency = 1,
		collide = false,
		shadow = false,
		folder = "Spawns",
	})
	part.CanQuery = false
	part.CanTouch = false
	part:SetAttribute("Team", team)
	return part
end

-- Paredes invisibles alrededor de la zona de juego (y techo)
function Builder:bounds(minX, maxX, minZ, maxZ, height)
	local w = 2
	local cx, cz = (minX + maxX) / 2, (minZ + maxZ) / 2
	local sx, sz = maxX - minX, maxZ - minZ
	local walls = {
		{ { sx + 2 * w, height, w }, { cx, height / 2, minZ - w / 2 } },
		{ { sx + 2 * w, height, w }, { cx, height / 2, maxZ + w / 2 } },
		{ { w, height, sz }, { minX - w / 2, height / 2, cz } },
		{ { w, height, sz }, { maxX + w / 2, height / 2, cz } },
		{ { sx + 2 * w, w, sz + 2 * w }, { cx, height + w / 2, cz } },
	}
	for _, wall in ipairs(walls) do
		self:part("Part", { name = "Limite", size = wall[1], pos = wall[2], transparency = 1, shadow = false, folder = "Limites" })
	end
end

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

-- =====================================================================
--  Terreno
--  Se guarda como piezas invisibles en la carpeta "Terreno" y se convierte en terreno de verdad
--  (hierba, agua, roca...) al cargar el mapa. Se aplica en orden: lo de después pisa lo de antes,
--  así que Air sirve para excavar (ríos, lagos, canteras).
--  op = { shape = "Block" | "Ball" | "Cylinder" | "Wedge", mat = "Grass", pos = { x, y, z },
--         size = { x, y, z } (Block/Wedge), radius (Ball/Cylinder), height (Cylinder), rot = { 0, giro, 0 } }
-- =====================================================================
local TERRAIN_CHUNK = 512

function Builder:terrainPiece(shape, mat, size, pos, rot)
	self.terrainCount = (self.terrainCount or 0) + 1
	local part = self:part("Part", { name = "Terreno", size = size, pos = pos, rot = rot, transparency = 1, collide = false, shadow = false, folder = "Terreno" })
	part.CanQuery = false
	part.CanTouch = false
	part:SetAttribute("Material", mat)
	part:SetAttribute("Forma", shape)
	part:SetAttribute("Orden", self.terrainCount)
	return part
end

function Builder:terrain(op)
	local shape = op.shape or "Block"
	if shape == "Ball" then
		return self:terrainPiece(shape, op.mat, { op.radius * 2, op.radius * 2, op.radius * 2 }, op.pos)
	elseif shape == "Cylinder" then
		return self:terrainPiece(shape, op.mat, { op.radius * 2, op.height, op.radius * 2 }, op.pos, op.rot)
	end
	-- Bloques y cuñas grandes se trocean (una pieza no puede medir más de 2048 y el terreno se rellena mejor por partes)
	local sx, sy, sz = op.size[1], op.size[2], op.size[3]
	local nx = math.ceil(sx / TERRAIN_CHUNK)
	local nz = (shape == "Block") and math.ceil(sz / TERRAIN_CHUNK) or 1
	local yaw = op.rot and op.rot[2] or 0
	for i = 1, nx do
		for k = 1, nz do
			local px, pz = sx / nx, sz / nz
			local ox, oz = -sx / 2 + (i - 0.5) * px, -sz / 2 + (k - 0.5) * pz
			local wx, wz = rotateY(ox, oz, yaw)
			self:terrainPiece(shape, op.mat, { px, sy, pz }, { op.pos[1] + wx, op.pos[2], op.pos[3] + wz }, op.rot)
		end
	end
end

-- Colores de los materiales del terreno y aspecto del agua
-- settings = { colors = { Grass = { r, g, b }, ... }, water = { color, transparency, waveSize, waveSpeed, reflectance } }
function Builder:terrainSettings(settings)
	local folder = self:folder("Terreno")
	for mat, color in pairs(settings.colors or {}) do
		folder:SetAttribute("Color_" .. mat, rgb(color))
	end
	local w = settings.water
	if w then
		folder:SetAttribute("AguaColor", rgb(w.color or { 40, 70, 80 }))
		folder:SetAttribute("AguaTransparencia", w.transparency or 0.3)
		folder:SetAttribute("AguaOlas", w.waveSize or 0.15)
		folder:SetAttribute("AguaVelocidad", w.waveSpeed or 8)
		folder:SetAttribute("AguaReflejo", w.reflectance or 0.3)
	end
end

-- Cartel con texto en una cara de la pieza (SurfaceGui)
function MapBuilder.sign(part, text, opts)
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
function MapBuilder.light(part, kind, opts)
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

-- Guarda la iluminación del mapa (se aplica con MapBuilder.applyLighting)
function Builder:lighting(settings)
	local config = Instance.new("Configuration")
	config.Name = "Iluminacion"
	config.Parent = self.model
	for name, value in pairs(settings.lighting or {}) do
		if type(value) == "table" then
			value = rgb(value)
		end
		config:SetAttribute(name, value)
	end
	if settings.atmosphere then
		local a = settings.atmosphere
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = a.density or 0.3
		atmosphere.Offset = a.offset or 0
		atmosphere.Color = rgb(a.color or { 200, 170, 160 })
		atmosphere.Decay = rgb(a.decay or { 110, 90, 90 })
		atmosphere.Glare = a.glare or 0
		atmosphere.Haze = a.haze or 1
		atmosphere.Parent = config
	end
	if settings.colorCorrection then
		local c = settings.colorCorrection
		local effect = Instance.new("ColorCorrectionEffect")
		effect.Brightness = c.brightness or 0
		effect.Contrast = c.contrast or 0
		effect.Saturation = c.saturation or 0
		effect.TintColor = rgb(c.tint or { 255, 255, 255 })
		effect.Parent = config
	end
	if settings.clouds then
		local c = settings.clouds
		local clouds = Instance.new("Clouds")
		clouds.Cover = c.cover or 0.5
		clouds.Density = c.density or 0.5
		clouds.Color = rgb(c.color or { 255, 255, 255 })
		clouds.Parent = config
	end
	if settings.bloom then
		local b = settings.bloom
		local bloom = Instance.new("BloomEffect")
		bloom.Intensity = b.intensity or 0.6
		bloom.Size = b.size or 24
		bloom.Threshold = b.threshold or 0.9
		bloom.Parent = config
	end
	if settings.sunRays then
		local r = settings.sunRays
		local rays = Instance.new("SunRaysEffect")
		rays.Intensity = r.intensity or 0.08
		rays.Spread = r.spread or 0.6
		rays.Parent = config
	end
	if settings.technology then
		config:SetAttribute("Tecnologia", settings.technology)
	end
	return config
end

-- =====================================================================
--  Piezas reutilizables (Props.luau)
-- =====================================================================
require(script:WaitForChild("Props"))(MapBuilder)

-- =====================================================================
--  Construir, cargar e iluminar
-- =====================================================================
local function getMaps(maps)
	if maps then
		return maps
	end
	local list = {}
	for _, module in ipairs(script:WaitForChild("Mapas"):GetChildren()) do
		if module:IsA("ModuleScript") then
			list[module.Name] = require(module)
		end
	end
	return list
end

-- Construye un mapa y devuelve su Model (en el origen)
function MapBuilder.build(name, buildFn)
	local b = MapBuilder.new(name)
	buildFn(b, MapBuilder)
	b.model.WorldPivot = CFrame.new(0, 0, 0)
	return b.model
end

-- Construye todos los mapas dentro de ServerStorage.MapasDuelo (o en parent)
function MapBuilder.buildAll(parent, maps)
	parent = parent or game:GetService("ServerStorage")
	local folder = parent:FindFirstChild(CONTAINER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = CONTAINER_NAME
		folder.Parent = parent
	end
	for name, buildFn in pairs(getMaps(maps)) do
		local old = folder:FindFirstChild(name)
		if old then
			old:Destroy()
		end
		MapBuilder.build(name, buildFn).Parent = folder
	end
	return folder
end

-- Aplica la iluminación guardada en el mapa a Lighting
function MapBuilder.applyLighting(map)
	local Lighting = game:GetService("Lighting")
	local config = map:FindFirstChild("Iluminacion")
	if not config then
		return
	end
	for name, value in pairs(config:GetAttributes()) do
		if name == "Tecnologia" then
			-- Future da sombras a las luces y brillo al neón (solo se puede cambiar desde Studio)
			pcall(function()
				Lighting.Technology = Enum.Technology[value]
			end)
		else
			Lighting[name] = value
		end
	end
	-- Quita los efectos del mapa anterior y los del mismo tipo que trae este mapa
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:GetAttribute("DeMapa") or config:FindFirstChildOfClass(child.ClassName) then
			child:Destroy()
		end
	end
	local terrain = workspace.Terrain
	for _, child in ipairs(terrain:GetChildren()) do
		if child:IsA("Clouds") then
			child:Destroy()
		end
	end
	for _, child in ipairs(config:GetChildren()) do
		local clone = child:Clone()
		clone:SetAttribute("DeMapa", true)
		clone.Parent = child:IsA("Clouds") and terrain or Lighting
	end
end

-- Convierte la carpeta "Terreno" del mapa en terreno de verdad. Devuelve true si el mapa tenía terreno.
function MapBuilder.applyTerrain(map)
	local folder = map:FindFirstChild("Terreno")
	if not folder then
		return false
	end
	local terrain = workspace.Terrain
	terrain:Clear()
	for name, value in pairs(folder:GetAttributes()) do
		local mat = name:match("^Color_(.+)$")
		if mat then
			terrain:SetMaterialColor(Enum.Material[mat], value)
		elseif name == "AguaColor" then
			terrain.WaterColor = value
		elseif name == "AguaTransparencia" then
			terrain.WaterTransparency = value
		elseif name == "AguaOlas" then
			terrain.WaterWaveSize = value
		elseif name == "AguaVelocidad" then
			terrain.WaterWaveSpeed = value
		elseif name == "AguaReflejo" then
			terrain.WaterReflectance = value
		end
	end
	local pieces = folder:GetChildren()
	table.sort(pieces, function(a, c)
		return (a:GetAttribute("Orden") or 0) < (c:GetAttribute("Orden") or 0)
	end)
	for i, part in ipairs(pieces) do
		local mat = Enum.Material[part:GetAttribute("Material")]
		local shape = part:GetAttribute("Forma")
		if shape == "Ball" then
			terrain:FillBall(part.Position, part.Size.X / 2, mat)
		elseif shape == "Cylinder" then
			terrain:FillCylinder(part.CFrame, part.Size.Y, part.Size.X / 2, mat)
		elseif shape == "Wedge" then
			terrain:FillWedge(part.CFrame, part.Size, mat)
		else
			terrain:FillBlock(part.CFrame, part.Size, mat)
		end
		if i % 20 == 0 then
			task.wait()
		end
	end
	folder:Destroy()
	return true
end

-- Devuelve { A = { CFrame, ... }, B = { CFrame, ... } } (y otras listas si hay más equipos, como "Mundo")
function MapBuilder.getSpawns(map)
	local spawns = { A = {}, B = {} }
	local folder = map:FindFirstChild("Spawns")
	if folder then
		for _, part in ipairs(folder:GetChildren()) do
			local team = part:GetAttribute("Team")
			if team then
				spawns[team] = spawns[team] or {}
				table.insert(spawns[team], part.CFrame + Vector3.new(0, 3, 0))
			end
		end
	end
	return spawns
end

-- Pone en Workspace un mapa ya construido (quitando el anterior) y aplica su iluminación y su terreno
function MapBuilder.show(map, name)
	local current = workspace:FindFirstChild("MapaActual")
	if current then
		if current:GetAttribute("ConTerreno") then
			workspace.Terrain:Clear()
		end
		current:Destroy()
	end
	map.Name = "MapaActual"
	map:SetAttribute("Mapa", name)
	map.Parent = workspace
	MapBuilder.applyLighting(map)
	if MapBuilder.applyTerrain(map) then
		map:SetAttribute("ConTerreno", true)
	end
	return map, MapBuilder.getSpawns(map)
end

-- Pone un mapa guardado en ServerStorage en Workspace (quitando el anterior) y aplica su iluminación
function MapBuilder.load(name, position)
	local folder = game:GetService("ServerStorage"):FindFirstChild(CONTAINER_NAME)
	local template = folder and folder:FindFirstChild(name)
	assert(template, "No existe el mapa " .. tostring(name) .. ". Ejecuta MapBuilder.buildAll() primero.")
	local map = template:Clone()
	if position then
		map:PivotTo(CFrame.new(position))
	end
	return MapBuilder.show(map, name)
end

return MapBuilder
]=]
local FUENTE_PROPS = [=[
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

	-- Hoguera con luz
	function P.campfire(g, pos, withLight)
		local f = g:at(pos, 0)
		for i = 0, 5 do
			local a = math.rad(i * 60)
			f:ball({ name = "Piedra", diameter = 1.1, pos = { math.cos(a) * 1.6, 0.4, math.sin(a) * 1.6 }, color = { 110, 108, 104 }, mat = "Slate", folder = "Decoracion" })
		end
		for _, r in ipairs({ 0, 60, 120 }) do
			f:box({ name = "Lena", size = { 2.6, 0.5, 0.5 }, pos = { 0, 0.5, 0 }, rot = { 0, r, 18 }, color = { 80, 58, 40 }, mat = "Wood", folder = "Decoracion" })
		end
		local fire = f:ball({ name = "Fuego", diameter = 1.4, pos = { 0, 1.2, 0 }, color = { 255, 140, 40 }, mat = "Neon", transparency = 0.15, folder = "Decoracion", shadow = false })
		if withLight ~= false then
			MB.light(fire, "Point", { color = { 255, 150, 70 }, brightness = 1.8, range = 18, shadows = true })
		end
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
		hcp:ball({ name = "Humo", diameter = 6, pos = { 0, 11, -2 }, color = { 60, 60, 60 }, transparency = 0.5, folder = "Decoracion", shadow = false })
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
end
]=]
local FUENTES_MAPAS = {}
FUENTES_MAPAS["Azotea"] = [=[
-- Azotea Neón: tejado de noche con un gran cartel luminoso. Equipo A en -X, B en +X.
return function(b, MB)
	local P = MB.Props
	local ROOF = { 84, 82, 94 }
	local PARAPET = { 106, 104, 118 }
	local HUT = { 96, 90, 108 }
	local PINK = { 255, 60, 180 }
	local CYAN = { 40, 230, 255 }
	local PURPLE = { 160, 90, 255 }
	local DARK = { 34, 33, 44 }
	local METAL = { 150, 156, 166 }
	local WINDOWS = { { 196, 146, 88 }, { 38, 38, 50 }, { 170, 150, 118 }, { 38, 38, 50 }, { 96, 136, 186 }, { 38, 38, 50 }, { 38, 38, 50 } }

	b.model:SetAttribute("Nombre", "Azotea Neón")

	-- =================================================================
	--  Ciudad de fondo
	-- =================================================================
	b:box({ name = "Calle", size = { 900, 1, 900 }, pos = { 0, -80.5, 0 }, color = { 26, 26, 32 }, mat = "Asphalt", folder = "Decoracion" })
	b:box({ name = "Edificio", size = { 124, 80, 84 }, pos = { 0, -40.5, 0 }, color = { 50, 48, 62 }, mat = "Concrete" })
	local city = {
		{ -120, -90, 40, 40, 150, "HOTEL", PINK }, { -60, -125, 50, 30, 120 }, { 10, -132, 40, 40, 170, "RAMEN", CYAN }, { 80, -112, 40, 40, 130 },
		{ 132, -40, 40, 50, 160, "24H", PURPLE }, { 136, 50, 40, 40, 110 }, { 72, 120, 50, 40, 140, "BAR", PINK }, { -10, 132, 40, 40, 125 },
		{ -82, 116, 40, 40, 160, "CLUB", CYAN }, { -136, 30, 40, 50, 130 }, { -142, -32, 30, 30, 100 },
	}
	local seed = 0
	for _, c in ipairs(city) do
		local x, z, w, d, h = c[1], c[2], c[3], c[4], c[5]
		b:box({ name = "Rascacielos", size = { w, h, d }, pos = { x, -80 + h / 2, z }, color = { 42, 40, 54 }, mat = "Concrete", folder = "Decoracion" })
		b:box({ name = "Remate", size = { w + 1, 1.5, d + 1 }, pos = { x, -80 + h + 0.75, z }, color = { 60, 58, 72 }, mat = "Concrete", folder = "Decoracion" })
		local alongX = math.abs(x) > math.abs(z)
		local facing = alongX and (x > 0 and -1 or 1) or (z > 0 and -1 or 1)
		local faceOffset = alongX and (w / 2 + 0.1) or (d / 2 + 0.1)
		local span = alongX and d or w
		-- Plantas con ventanas de distintos colores y montantes verticales
		for y = -72, -80 + h - 6, 6 do
			seed = seed + 1
			local color = WINDOWS[(seed * 7) % #WINDOWS + 1]
			local size = alongX and { 0.2, 1.6, span - 4 } or { span - 4, 1.6, 0.2 }
			local pos = alongX and { x + facing * faceOffset, y, z } or { x, y, z + facing * faceOffset }
			local lit = color[1] > 60
			b:box({ name = "Ventanas", size = size, pos = pos, color = color, mat = lit and "Neon" or "Glass", transparency = lit and 0.35 or 0, folder = "Decoracion", shadow = false })
		end
		for i = 1, math.floor(span / 5) - 1 do
			local o = -span / 2 + i * 5
			local size = alongX and { 0.4, h - 10, 0.6 } or { 0.6, h - 10, 0.4 }
			local pos = alongX and { x + facing * (faceOffset + 0.1), -80 + h / 2, z + o } or { x + o, -80 + h / 2, z + facing * (faceOffset + 0.1) }
			b:box({ name = "Montante", size = size, pos = pos, color = { 30, 30, 40 }, folder = "Decoracion", shadow = false })
		end
		-- Antena con luz roja en lo alto
		b:cylinder({ name = "Antena", length = 14, diameter = 0.6, pos = { x + w / 4, -80 + h + 8, z }, color = METAL, folder = "Decoracion" })
		b:ball({ name = "Baliza", diameter = 1.2, pos = { x + w / 4, -80 + h + 15.2, z }, color = { 255, 40, 40 }, mat = "Neon", folder = "Decoracion" })
		if c[6] then
			local signPos = alongX and { x + facing * (faceOffset + 0.6), -80 + h - 14, z } or { x, -80 + h - 14, z + facing * (faceOffset + 0.6) }
			local yaw = alongX and (facing > 0 and -90 or 90) or (facing > 0 and 180 or 0)
			P.neonSign(b, signPos, yaw, { span * 0.6, 8 }, c[6], c[7], "Michroma")
		end
	end

	-- =================================================================
	--  Tejado
	-- =================================================================
	b:box({ name = "Tejado", size = { 124, 1, 84 }, pos = { 0, -0.5, 0 }, color = ROOF, mat = "Concrete" })
	for _, g in ipairs({ { -30, -14, 22, 16 }, { 30, -14, 22, 16 }, { 0, 18, 26, 14 } }) do
		b:box({ name = "Grava", size = { g[3], 0.12, g[4] }, pos = { g[1], 0.06, g[2] }, color = { 112, 108, 116 }, mat = "Pebble", folder = "Decoracion" })
	end
	for _, z in ipairs({ -20, 0, 20 }) do
		b:box({ name = "Junta", size = { 120, 0.08, 0.6 }, pos = { 0, 0.04, z }, color = { 40, 38, 46 }, folder = "Decoracion" })
	end
	for _, z in ipairs({ -41.25, 41.25 }) do
		b:box({ name = "Pretil", size = { 124, 3.5, 1.5 }, pos = { 0, 1.75, z }, color = PARAPET, mat = "Concrete" })
		b:box({ name = "Albardilla", size = { 124.4, 0.4, 2 }, pos = { 0, 3.7, z }, color = { 130, 128, 140 }, mat = "Concrete" })
		b:box({ name = "Neon", size = { 124, 0.3, 0.3 }, pos = { 0, 3.95, z + (z > 0 and -0.8 or 0.8) }, color = PINK, mat = "Neon", folder = "Decoracion" })
		P.railing(b, { -60, 3.9, z }, { 60, 3.9, z }, 2.6, { 120, 124, 134 })
	end

	-- Zona chill en el centro delantero: tarima, sofá, mesa y guirnalda de luces
	b:box({ name = "Tarima", size = { 22, 0.5, 9 }, pos = { 0, 0.25, -34 }, color = { 140, 100, 70 }, mat = "WoodPlanks" })
	b:box({ name = "Sofa", size = { 10, 1.4, 3 }, pos = { 0, 1.2, -37 }, color = { 120, 60, 140 }, mat = "Fabric" })
	b:box({ name = "Respaldo", size = { 10, 2, 0.9 }, pos = { 0, 2.4, -38.2 }, color = { 120, 60, 140 }, mat = "Fabric" })
	b:box({ name = "Mesa", size = { 4, 1.4, 2.4 }, pos = { 0, 1.2, -32.4 }, color = { 60, 50, 46 }, mat = "Wood" })
	for _, x in ipairs({ -11, 11 }) do
		b:cylinder({ name = "Poste", length = 7, diameter = 0.35, pos = { x, 4, -38.5 }, color = METAL, mat = "Metal" })
	end
	P.stringLights(b, { -11, 7.3, -38.5 }, { 11, 7.3, -38.5 }, 14, 1.4, { { 255, 214, 120 }, { 255, 120, 200 }, { 120, 220, 255 } })
	P.stringLights(b, { -11, 7.3, -38.5 }, { 0, 16, 0 }, 16, 2.4, { { 255, 214, 120 }, { 255, 120, 200 } })
	P.stringLights(b, { 11, 7.3, -38.5 }, { 0, 16, 0 }, 16, 2.4, { { 255, 214, 120 }, { 120, 220, 255 } })
	local chill = b:box({ name = "Luz", size = { 0.4, 0.4, 0.4 }, pos = { 0, 6, -35 }, color = { 255, 214, 120 }, mat = "Neon", transparency = 1, folder = "Decoracion" })
	MB.light(chill, "Point", { color = { 255, 200, 140 }, brightness = 1.2, range = 18 })

	-- =================================================================
	--  Centro: valla publicitaria sobre una pasarela
	-- =================================================================
	b:box({ name = "Pasarela", size = { 28, 0.6, 4 }, pos = { 0, 8, 0 }, color = METAL, mat = "DiamondPlate" })
	P.railing(b, { -14, 8.3, -2 }, { 14, 8.3, -2 }, 3, METAL)
	P.railing(b, { -14, 8.3, 2 }, { 14, 8.3, 2 }, 3, METAL)
	local board = b:box({ name = "Valla", size = { 30, 11, 1 }, pos = { 0, 16.5, 0 }, color = DARK })
	MB.sign(board, "NEO CITY", { face = "Front", font = "Michroma", color = PINK, glow = true, width = 0.88, height = 0.6 })
	MB.sign(board, "MOTEL 24/7", { face = "Back", font = "Michroma", color = CYAN, glow = true, width = 0.88, height = 0.6 })
	for _, y in ipairs({ 10.85, 22.15 }) do
		b:box({ name = "Neon", size = { 30.4, 0.3, 1.2 }, pos = { 0, y, 0 }, color = PINK, mat = "Neon", folder = "Decoracion" })
	end
	local glowFront = b:box({ name = "Foco", size = { 2, 0.4, 0.6 }, pos = { 0, 8.5, -1.5 }, color = PINK, mat = "Neon", folder = "Decoracion" })
	MB.light(glowFront, "Point", { color = PINK, brightness = 2.2, range = 28 })
	local glowBack = b:box({ name = "Foco", size = { 2, 0.4, 0.6 }, pos = { 0, 8.5, 1.5 }, color = CYAN, mat = "Neon", folder = "Decoracion" })
	MB.light(glowBack, "Point", { color = CYAN, brightness = 2.2, range = 28 })

	b:symmetric(function(b)
		b:box({ name = "Pretil", size = { 1.5, 3.5, 81 }, pos = { -61.25, 1.75, 0 }, color = PARAPET, mat = "Concrete" })
		b:box({ name = "Albardilla", size = { 2, 0.4, 81 }, pos = { -61.25, 3.7, 0 }, color = { 130, 128, 140 }, mat = "Concrete" })
		b:box({ name = "Neon", size = { 0.3, 0.3, 81 }, pos = { -60.45, 3.95, 0 }, color = CYAN, mat = "Neon", folder = "Decoracion" })

		-- Caseta de acceso (sala de spawn con puerta hacia el centro)
		b:box({ name = "Caseta", size = { 1, 10, 14 }, pos = { -57.5, 5, 0 }, color = HUT, mat = "Brick" })
		for _, z in ipairs({ -6.5, 6.5 }) do
			b:box({ name = "Caseta", size = { 11, 10, 1 }, pos = { -52.5, 5, z }, color = HUT, mat = "Brick" })
		end
		for _, z in ipairs({ -4.75, 4.75 }) do
			b:box({ name = "Caseta", size = { 1, 10, 4.5 }, pos = { -47.5, 5, z }, color = HUT, mat = "Brick" })
		end
		b:box({ name = "Dintel", size = { 1, 2.5, 5 }, pos = { -47.5, 8.75, 0 }, color = HUT, mat = "Brick" })
		b:box({ name = "Marco", size = { 1.3, 0.4, 5.6 }, pos = { -47.4, 7.5, 0 }, color = DARK, mat = "Metal", folder = "Decoracion" })
		b:box({ name = "TechoCaseta", size = { 12, 1, 15 }, pos = { -52.5, 10.5, 0 }, color = DARK })
		P.vent(b, { -55, 11, -4 })
		P.vent(b, { -55, 11, 4 })
		local hutColor = b.mirrored and PINK or CYAN
		local hutLight = b:box({ name = "Lampara", size = { 2, 0.3, 2 }, pos = { -52.5, 9.8, 0 }, color = hutColor, mat = "Neon", folder = "Decoracion" })
		MB.light(hutLight, "Point", { color = hutColor, brightness = 1.5, range = 14 })
		P.neonSign(b, { -46.8, 9.2, 0 }, -90, { 4.6, 1.4 }, "ROOF", hutColor, "Michroma")

		-- Soportes de la valla y escaleras de mano
		b:box({ name = "Poste", size = { 1, 22, 1 }, pos = { -12, 11, 0 }, color = METAL, mat = "Metal" })
		for _, z in ipairs({ -1.6, 1.6 }) do
			b:box({ name = "Pata", size = { 0.8, 8, 0.8 }, pos = { -8, 4, z }, color = METAL, mat = "Metal" })
			P.segment(b, { -8, 0.5, z }, { -12, 7.6, z }, 0.3, METAL, "Metal", "Decoracion")
		end
		b:truss({ name = "Escalera", size = { 2, 8, 2 }, pos = { -15, 4, 0 }, color = METAL })
		b:box({ name = "Neon", size = { 0.3, 11, 1.2 }, pos = { -15.15, 16.5, 0 }, color = PINK, mat = "Neon", folder = "Decoracion" })

		-- Cobertura
		P.acUnit(b, { -24, 0, -22 }, 0)
		P.acUnit(b, { -40, 0, -26 }, 90)
		P.acUnit(b, { -22, 0, 14 }, 0)
		P.waterTank(b, { -36, 0, 26 })
		b:box({ name = "Tragaluz", size = { 8.6, 1, 8.6 }, pos = { -12, 0.5, -26 }, color = DARK })
		b:box({ name = "Cristal", size = { 8, 0.6, 8 }, pos = { -12, 1.3, -26 }, color = { 150, 180, 230 }, mat = "Glass", transparency = 0.3 })
		P.planter(b, { -28, 0, -4 }, { 10, 3 }, 0)
		P.crate(b, { -8, 0, 22 }, 4.5)
		P.crate(b, { -8, 0, 27 }, 4.5, 12)
		P.crate(b, { -8, 4.5, 24.5 }, 4)
		P.pottedPlant(b, { -13, 0, -31 }, 1.1)

		-- Generador, paneles solares y antena con baliza
		b:box({ name = "Generador", size = { 6, 3.6, 3.4 }, pos = { -50, 1.8, 20 }, color = { 70, 110, 80 }, mat = "Metal" })
		b:box({ name = "Rejilla", size = { 4, 2, 0.2 }, pos = { -50, 1.9, 18.2 }, color = { 40, 50, 44 }, mat = "DiamondPlate", folder = "Decoracion" })
		b:cylinder({ name = "Escape", length = 3, diameter = 0.6, pos = { -52, 5, 21 }, color = { 60, 60, 66 }, mat = "Metal", folder = "Decoracion" })
		for i = 0, 1 do
			local z = -32 + i * 5.5
			b:box({ name = "PanelSolar", size = { 8, 0.3, 4.4 }, pos = { -46, 1.9, z }, rot = { -25, 0, 0 }, color = { 30, 50, 100 }, mat = "Glass", reflectance = 0.2 })
			for _, x in ipairs({ -49.5, -42.5 }) do
				b:box({ name = "Soporte", size = { 0.3, 1.8, 0.3 }, pos = { x, 0.9, z - 1.2 }, color = METAL, mat = "Metal", folder = "Decoracion" })
			end
		end
		b:cylinder({ name = "Antena", length = 14, diameter = 0.5, pos = { -56, 7, -34 }, color = METAL, mat = "Metal" })
		b:ball({ name = "Baliza", diameter = 1, pos = { -56, 14.4, -34 }, color = { 255, 40, 40 }, mat = "Neon", folder = "Decoracion" })
		P.satelliteDish(b, { -55, 0, 33 }, 30)
		P.vent(b, { -30, 0, 34 })
		P.vent(b, { -18, 0, -36 })

		-- Tuberías
		P.rod(b, { -44, 0.9, -24 }, { -44, 0.9, 36 }, 1.4, { 120, 124, 132 }, "Metal")
		P.rod(b, { -44, 0.9, 36 }, { -44, 5, 36 }, 1.4, { 120, 124, 132 }, "Metal")
		b:ball({ name = "Codo", diameter = 1.6, pos = { -44, 0.9, 36 }, color = { 120, 124, 132 }, mat = "Metal", folder = "Decoracion" })
		for z = -20, 32, 8 do
			b:box({ name = "Soporte", size = { 2, 0.4, 0.6 }, pos = { -44, 0.2, z }, color = DARK, folder = "Decoracion" })
		end

		for _, z in ipairs({ -3, 0, 3 }) do
			b:spawn("A", { -54, 0.5, z }, -90)
		end
	end)

	b:bounds(-60, 60, -40, 40, 30)

	b:lighting({
		technology = "Future",
		lighting = {
			ClockTime = 0.2,
			Brightness = 1.3,
			Ambient = { 76, 66, 108 },
			OutdoorAmbient = { 86, 76, 128 },
			ExposureCompensation = 0.4,
			EnvironmentDiffuseScale = 0.5,
			EnvironmentSpecularScale = 0.6,
		},
		atmosphere = { density = 0.32, color = { 112, 82, 162 }, decay = { 62, 42, 112 }, haze = 1.6, glare = 0 },
		colorCorrection = { contrast = 0.12, saturation = 0.25, tint = { 236, 226, 255 } },
		bloom = { intensity = 1, size = 32, threshold = 0.8 },
	})
end
]=]
FUENTES_MAPAS["Cargamento"] = [=[
-- Cargamento (estilo Shipment de Call of Duty): patio de contenedores muy pequeño para duelos rápidos
-- y caóticos, al amanecer con lluvia. Equipo A en -X, equipo B en +X.
return function(b, MB)
	local P = MB.Props
	local FLOOR = { 112, 112, 116 }
	local YELLOW = { 236, 190, 40 }
	local COLORS = { { 176, 60, 46 }, { 46, 96, 150 }, { 70, 120, 80 }, { 200, 130, 40 }, { 120, 120, 128 }, { 150, 70, 110 } }

	b.model:SetAttribute("Nombre", "Cargamento")

	-- =================================================================
	--  Puerto al fondo: agua, grúas y barco
	-- =================================================================
	b:box({ name = "Agua", size = { 900, 1, 900 }, pos = { 0, -3, 0 }, color = { 50, 80, 96 }, mat = "Glass", reflectance = 0.2, folder = "Decoracion" })
	b:box({ name = "Muelle", size = { 260, 3, 200 }, pos = { 0, -1.5, 20 }, color = { 96, 96, 100 }, mat = "Concrete", folder = "Decoracion" })
	for _, x in ipairs({ -90, -30, 30, 90 }) do
		for _, z in ipairs({ 110, 140 }) do
			b:box({ name = "Grua", size = { 3, 60, 3 }, pos = { x, 30, z }, color = { 210, 80, 50 }, mat = "Metal", folder = "Decoracion" })
		end
		b:box({ name = "Grua", size = { 4, 4, 90 }, pos = { x, 62, 120 }, color = { 210, 80, 50 }, mat = "Metal", folder = "Decoracion" })
		b:box({ name = "Cabina", size = { 6, 5, 6 }, pos = { x, 57, 126 }, color = { 230, 230, 226 }, mat = "Metal", folder = "Decoracion" })
	end
	b:box({ name = "Barco", size = { 220, 18, 36 }, pos = { 0, 6, 150 }, color = { 40, 50, 66 }, mat = "Metal", folder = "Decoracion" })
	b:box({ name = "Puente", size = { 24, 26, 30 }, pos = { 90, 28, 150 }, color = { 236, 236, 232 }, mat = "Metal", folder = "Decoracion" })

	-- =================================================================
	--  Suelo del patio y contenedor central
	-- =================================================================
	b:box({ name = "Suelo", size = { 76, 1, 64 }, pos = { 0, -0.5, 0 }, color = FLOOR, mat = "Concrete" })
	for _, z in ipairs({ -14, 14 }) do
		b:box({ name = "Linea", size = { 76, 0.12, 0.6 }, pos = { 0, 0.06, z }, color = YELLOW, folder = "Decoracion" })
	end
	P.container(b, { 0, 0, 0 }, 90, { 176, 60, 46 }, false, "CARGO 07")

	b:symmetric(function(b)
		-- Contenedores del patio (uno abierto se puede atravesar)
		P.container(b, { -14, 0, -21 }, 0, COLORS[2], false, "NAVIERA")
		P.container(b, { -14, 0, 21 }, 0, COLORS[3], true, "TUNEL")
		P.container(b, { -25, 0, 0 }, 90, COLORS[4], false, "EXPORT")

		-- Cobertura pequeña
		P.crate(b, { -13, 0, -6 }, 4.5, 15)
		P.crate(b, { -10, 0, 8 }, 4, -20)
		P.crate(b, { -10, 4, 8 }, 3, 10)
		P.drum(b, { -6, 0, -13 }, { 46, 96, 150 })
		P.drum(b, { -3.6, 0, -12.2 }, { 200, 60, 50 })
		P.pallet(b, { -18, 0, 12 }, 20)
		P.cardboard(b, { -18, 0.6, 12 }, { 3, 2.4, 2.6 }, 20)
		P.puddle(b, { -20, 0, -8 }, 5)
		P.puddle(b, { -6, 0, 18 }, 4)
		P.manhole(b, { -30, 0, -20 })

		-- Muro de contenedores apilados alrededor (fuera de los límites)
		for i, x in ipairs({ -31.5, -10.5 }) do
			for _, z in ipairs({ -36.5, 36.5 }) do
				P.container(b, { x, 0, z }, 0, COLORS[(i + (z > 0 and 2 or 0)) % 6 + 1], false)
				P.container(b, { x + 6, 9, z }, 0, COLORS[(i + (z > 0 and 3 or 1)) % 6 + 1], false)
			end
		end
		for i, z in ipairs({ -21, 0, 21 }) do
			P.container(b, { -42.5, 0, z }, 90, COLORS[(i + 3) % 6 + 1], false)
		end
		for i, z in ipairs({ -10.5, 10.5 }) do
			P.container(b, { -42.5, 9, z }, 90, COLORS[(i + 1) % 6 + 1], false)
		end

		-- Focos en las esquinas
		P.floodLight(b, { -36, 0, -31 }, 45, 18)
		P.floodLight(b, { -36, 0, 31 }, 135, 18)

		for _, z in ipairs({ -5, 0, 5 }) do
			b:spawn("A", { -33, 0.5, z }, -90)
		end
	end)

	b:bounds(-37, 37, -31, 31, 30)

	b:lighting({
		technology = "Future",
		lighting = {
			ClockTime = 6.3,
			Brightness = 1.4,
			Ambient = { 92, 98, 112 },
			OutdoorAmbient = { 120, 128, 146 },
			ExposureCompensation = 0.3,
			ShadowSoftness = 0.5,
			EnvironmentDiffuseScale = 0.6,
			EnvironmentSpecularScale = 0.7,
		},
		atmosphere = { density = 0.4, offset = 0.15, color = { 170, 180, 196 }, decay = { 100, 110, 130 }, glare = 0.3, haze = 2.4 },
		colorCorrection = { contrast = 0.1, saturation = -0.1, tint = { 236, 242, 255 } },
		clouds = { cover = 0.9, density = 0.75, color = { 170, 176, 190 } },
		bloom = { intensity = 0.5, size = 24, threshold = 0.88 },
		sunRays = { intensity = 0.04, spread = 0.4 },
	})
end
]=]
FUENTES_MAPAS["Ciudad"] = [=[
-- Gran Ciudad: mapa inmenso para hasta 50 jugadores (25 contra 25). Cada equipo tiene una base
-- con 25 spawns; entre las dos bases hay una ciudad con oficinas, tiendas, gasolinera, parque,
-- casas en las que se puede entrar, una obra con pisos, un aparcamiento de dos plantas,
-- una zona industrial, una gran plaza, el ayuntamiento y la estación de autobuses.
-- Equipo A en -X, equipo B en +X.
return function(b, MB)
	local P = MB.Props
	local SIDEWALK = { 170, 166, 160 }
	local PLAZA = { 198, 192, 182 }
	local LINE = { 236, 232, 220 }
	local GRASS = { 108, 150, 76 }
	local TREES = { { 86, 140, 66 }, { 100, 156, 74 }, { 76, 126, 60 } }
	local OFFICES = {
		{ h = 56, color = { 150, 166, 186 }, mat = "Concrete", trim = { 90, 100, 116 }, glass = { 90, 130, 170 } },
		{ h = 44, color = { 206, 196, 180 }, mat = "Concrete", trim = { 140, 130, 116 }, glass = { 80, 110, 140 } },
		{ h = 64, color = { 120, 130, 146 }, mat = "Concrete", trim = { 70, 76, 90 }, glass = { 110, 150, 190 } },
		{ h = 38, color = { 176, 120, 96 }, mat = "Brick", trim = { 230, 224, 210 } },
	}
	local SHOPS = {
		{ h = 16, color = { 236, 226, 206 }, trim = { 120, 90, 70 }, shop = "PIZZERÍA", shopColor = { 200, 50, 40 }, lit = true },
		{ h = 18, color = { 160, 90, 70 }, mat = "Brick", trim = { 236, 230, 220 }, shop = "CAFÉ", shopColor = { 110, 70, 40 }, lit = true },
		{ h = 14, color = { 120, 170, 200 }, trim = { 245, 245, 240 }, shop = "MODA", shopColor = { 210, 70, 140 }, lit = true },
		{ h = 16, color = { 230, 200, 120 }, trim = { 120, 90, 50 }, shop = "FARMACIA", shopColor = { 40, 150, 80 }, lit = true },
	}

	b.model:SetAttribute("Nombre", "Gran Ciudad")
	b.model:SetAttribute("Jugadores", 50)

	local function copy(t)
		local out = {}
		for k, v in pairs(t) do
			out[k] = v
		end
		return out
	end

	local function slab(x0, x1, z0, z1, color, mat)
		return b:box({ name = "Manzana", size = { x1 - x0, 0.4, z1 - z0 }, pos = { (x0 + x1) / 2, 0.2, (z0 + z1) / 2 }, color = color or SIDEWALK, mat = mat or "Pavement" })
	end

	-- Edificios alrededor de una manzana, con un callejón en el centro de cada lado
	local function perimeter(x0, x1, z0, z1, d, sides, styles)
		local i = 0
		local function row(a0, a1, place)
			local mid = (a0 + a1) / 2
			for _, seg in ipairs({ { a0, mid - 4 }, { mid + 4, a1 } }) do
				i = i + 1
				local o = copy(styles[(i - 1) % #styles + 1])
				o.w, o.d = seg[2] - seg[1], d
				place((seg[1] + seg[2]) / 2, o)
			end
		end
		local zs, ze = z0 + (sides.S and d or 0), z1 - (sides.N and d or 0)
		if sides.N then
			row(x0, x1, function(c, o)
				P.house(b, { c, 0.4, z1 - d / 2 }, 180, o)
			end)
		end
		if sides.S then
			row(x0, x1, function(c, o)
				P.house(b, { c, 0.4, z0 + d / 2 }, 0, o)
			end)
		end
		if sides.W then
			row(zs, ze, function(c, o)
				P.house(b, { x0 + d / 2, 0.4, c }, 90, o)
			end)
		end
		if sides.E then
			row(zs, ze, function(c, o)
				P.house(b, { x1 - d / 2, 0.4, c }, -90, o)
			end)
		end
	end

	-- =================================================================
	--  Suelo, calles y ciudad de fondo
	-- =================================================================
	b:box({ name = "Fondo", size = { 2000, 1, 2000 }, pos = { 0, -1.2, 0 }, color = { 120, 120, 118 }, mat = "Concrete", folder = "Decoracion" })
	b:box({ name = "Asfalto", size = { 620, 1, 420 }, pos = { 0, -0.5, 0 }, color = { 68, 68, 72 }, mat = "Asphalt" })
	for i = 0, 23 do
		for _, side in ipairs({ -1, 1 }) do
			local x = -345 + i * 30
			local h = 60 + (i * 41 + (side > 0 and 0 or 23)) % 110
			local w = 22 + (i % 3) * 6
			b:box({ name = "Rascacielos", size = { w, h, w }, pos = { x, h / 2, side * (240 + (i % 2) * 26) }, color = (i % 3 == 0) and { 110, 130, 156 } or { 176, 170, 160 }, mat = (i % 3 == 0) and "Glass" or "Concrete", folder = "Decoracion" })
		end
	end
	for i = 0, 7 do
		for _, side in ipairs({ -1, 1 }) do
			local h = 70 + (i * 37) % 90
			b:box({ name = "Rascacielos", size = { 30, h, 34 }, pos = { side * (340 + (i % 2) * 24), h / 2, -175 + i * 50 }, color = (i % 2 == 0) and { 150, 160, 176 } or { 190, 182, 170 }, mat = "Concrete", folder = "Decoracion" })
		end
	end
	-- Líneas de las avenidas (eje X) y de las calles (eje Z)
	for _, z in ipairs({ -100, 0, 100 }) do
		for x = -296, 296, 16 do
			if z ~= 0 or math.abs(x) > 70 then
				b:box({ name = "Linea", size = { 7, 0.12, 0.5 }, pos = { x, 0.06, z }, color = LINE, folder = "Decoracion" })
			end
		end
	end

	-- =================================================================
	--  Centro: gran plaza, ayuntamiento y estación de autobuses
	-- =================================================================
	slab(-65, 65, -88, 88, PLAZA, "Pavement")
	b:cylinder({ name = "Rosa", length = 0.1, diameter = 60, pos = { 0, 0.45, 0 }, color = { 176, 150, 120 }, mat = "Cobblestone", folder = "Decoracion" })
	P.fountain(b, { 0, 0.4, 0 }, 10)
	P.obelisk(b, { 0, 7.4, 0 }, 16, 2)

	slab(-65, 65, 112, 196)
	P.house(b, { 0, 0.4, 140 }, 0, { w = 90, h = 30, d = 40, color = { 236, 228, 210 }, mat = "Limestone", trim = { 180, 168, 150 }, floors = 3, cols = 12, door = false })
	for x = -20, 20, 8 do
		P.column(b, { x, 0.4, 116 }, 14, 2.2, { 240, 234, 220 }, "Limestone")
	end
	b:box({ name = "Friso", size = { 48, 2.4, 6 }, pos = { 0, 18.8, 117 }, color = { 230, 222, 204 }, mat = "Limestone" })
	b:wedge({ name = "Fronton", size = { 48, 5, 3 }, pos = { 0, 22.5, 115.5 }, color = { 230, 222, 204 }, mat = "Limestone" })
	b:cylinder({ name = "Tambor", length = 8, diameter = 18, pos = { 0, 34.4, 140 }, color = { 236, 228, 210 }, mat = "Limestone", folder = "Decoracion" })
	b:ball({ name = "Cupula", diameter = 18, pos = { 0, 38.4, 140 }, color = { 90, 140, 120 }, mat = "Metal", folder = "Decoracion" })
	local cityHall = b:box({ name = "Rotulo", size = { 30, 2.4, 0.3 }, pos = { 0, 26.5, 119.8 }, color = { 236, 228, 210 }, folder = "Decoracion" })
	MB.sign(cityHall, "AYUNTAMIENTO", { font = "Garamond", color = { 90, 70, 50 } })

	slab(-65, 65, -196, -112)
	P.house(b, { 0, 0.4, -186 }, 180, { w = 110, h = 16, d = 20, color = { 200, 204, 210 }, mat = "Concrete", trim = { 60, 90, 140 }, floors = 2, shop = "ESTACIÓN DE AUTOBUSES", shopColor = { 40, 90, 160 }, lit = true })
	b:box({ name = "Marquesina", size = { 104, 1, 44 }, pos = { 0, 12.5, -148 }, color = { 220, 224, 230 }, mat = "Metal" })

	b:symmetric(function(b)
		local mine = not b.mirrored

		-- =============================================================
		--  Base del equipo: muro con dos puertas, torres, tiendas y 25 spawns
		-- =============================================================
		slab(-300, -235, -196, 196, { 150, 146, 136 }, "Concrete")
		local wallColor = { 120, 124, 112 }
		P.wall(b, { -240, 0.4, 0 }, 90, { 80, 12, 2 }, wallColor)
		P.wall(b, { -240, 0.4, -63 }, 90, { 14, 12, 2 }, wallColor)
		P.wall(b, { -240, 0.4, 63 }, 90, { 14, 12, 2 }, wallColor)
		P.wall(b, { -270, 0.4, -70 }, 0, { 60, 12, 2 }, wallColor)
		P.wall(b, { -270, 0.4, 70 }, 0, { 60, 12, 2 }, wallColor)
		P.poster(b, { -238.8, 8, 0 }, -90, { 30, 4 }, mine and { 50, 100, 200 } or { 200, 50, 50 }, mine and "BASE AZUL" or "BASE ROJA", { 255, 255, 255 }, "GothamBlack")
		for _, z in ipairs({ -48, 48 }) do
			P.sandbags(b, { -230, 0.4, z }, 90, 12, 3)
		end
		P.watchTower(b, { -248, 0.4, -62 }, 90, 16)
		P.watchTower(b, { -248, 0.4, 62 }, 90, 16)
		for _, z in ipairs({ -52, 52 }) do
			b:wedge({ name = "Tienda", size = { 14, 6, 5 }, pos = { -288, 3.4, z - 2.5 }, color = { 92, 110, 70 }, mat = "Fabric" })
			b:wedge({ name = "Tienda", size = { 14, 6, 5 }, pos = { -288, 3.4, z + 2.5 }, rot = { 0, 180, 0 }, color = { 92, 110, 70 }, mat = "Fabric" })
		end
		P.truck(b, { -262, 0.4, 44 }, 0, { 92, 110, 70 })
		b:cylinder({ name = "Helipuerto", length = 0.1, diameter = 20, pos = { -272, 0.45, -48 }, color = { 60, 62, 66 }, mat = "Concrete", folder = "Decoracion" })
		local pad = b:box({ name = "H", size = { 8, 0.1, 8 }, pos = { -272, 0.5, -48 }, color = { 60, 62, 66 }, transparency = 1, folder = "Decoracion" })
		MB.sign(pad, "H", { face = "Top", font = "GothamBlack", color = { 245, 245, 240 } })
		b:cylinder({ name = "Mastil", length = 20, diameter = 0.5, pos = { -297, 10.4, 0 }, color = { 200, 200, 206 }, mat = "Metal" })
		b:box({ name = "Bandera", size = { 0.2, 4, 6 }, pos = { -297, 18, 3.2 }, color = mine and { 50, 100, 200 } or { 200, 50, 50 }, mat = "Fabric", folder = "Decoracion" })
		for _, z in ipairs({ -36, 36 }) do
			P.crate(b, { -262, 0.4, z }, 4, 0, { 90, 110, 70 })
			P.crate(b, { -257, 0.4, z }, 4, 15, { 90, 110, 70 })
		end
		for _, x in ipairs({ -290, -282, -274, -266, -258 }) do
			for _, z in ipairs({ -24, -12, 0, 12, 24 }) do
				b:spawn("A", { x, 0.9, z }, -90)
			end
		end
		-- Fuera de la base: contenedores y barreras
		P.container(b, { -268, 0.4, -110 }, 0, { 46, 96, 150 }, false)
		P.container(b, { -268, 0.4, 120 }, 0, { 176, 60, 46 }, true)
		P.barrier(b, { -258, 0.4, -150 }, 90)
		P.barrier(b, { -258, 0.4, 160 }, 90)

		-- =============================================================
		--  Oficinas (x -140..-85, z -196..-112)
		-- =============================================================
		slab(-140, -85, -196, -112)
		perimeter(-140, -85, -196, -112, 18, { N = true, W = true, E = true }, OFFICES)
		P.dumpster(b, { -112, 0.4, -170 }, 0, { 60, 110, 80 })
		P.dumpster(b, { -112, 0.4, -186 }, 0, { 60, 110, 80 })
		P.crate(b, { -116, 0.4, -150 }, 4)

		-- =============================================================
		--  Gasolinera (x -140..-85, z -88..-12)
		-- =============================================================
		slab(-140, -85, -88, -12)
		for _, x in ipairs({ -126, -98 }) do
			for _, z in ipairs({ -60, -40 }) do
				b:box({ name = "Pilar", size = { 1.6, 11, 1.6 }, pos = { x, 5.9, z }, color = { 220, 220, 226 }, mat = "Metal" })
			end
		end
		b:box({ name = "Marquesina", size = { 36, 1.6, 26 }, pos = { -112, 12.2, -50 }, color = { 236, 236, 240 }, mat = "Metal" })
		local band = b:box({ name = "Franja", size = { 36.2, 1, 26.2 }, pos = { -112, 12.2, -50 }, color = { 200, 50, 50 }, folder = "Decoracion" })
		MB.sign(band, "GAS 24H", { face = "Front", font = "GothamBlack" })
		for _, x in ipairs({ -120, -112, -104 }) do
			P.pump(b, { x, 0.4, -50 }, 0)
		end
		P.house(b, { -112, 0.4, -20 }, 180, { w = 30, h = 10, d = 14, color = { 236, 236, 230 }, trim = { 200, 50, 50 }, floors = 1, shop = "MINI MARKET", shopColor = { 200, 50, 50 }, lit = true })
		P.pricePylon(b, { -90, 0.4, -80 }, -90, "GAS", { 200, 50, 50 })
		P.car(b, { -116, 0.4, -64 }, 0, { 60, 120, 200 })
		P.car(b, { -100, 0.4, -36 }, 180, { 230, 230, 226 })

		-- =============================================================
		--  Tiendas y mercadillo (x -140..-85, z 12..88)
		-- =============================================================
		slab(-140, -85, 12, 88)
		perimeter(-140, -85, 12, 88, 14, { N = true, S = true }, SHOPS)
		P.marketStall(b, { -124, 0.4, 44 }, 0, { 200, 60, 80 }, "FRUTA")
		P.marketStall(b, { -100, 0.4, 56 }, 180, { 60, 140, 200 }, "FLORES", { { 240, 80, 120 }, { 250, 220, 80 }, { 160, 90, 220 } })
		P.umbrellaTable(b, { -110, 0.4, 40 }, { 220, 80, 60 })
		P.umbrellaTable(b, { -114, 0.4, 60 }, { 60, 150, 200 })
		P.tree(b, { -132, 0.4, 50 }, 1, TREES)
		P.tree(b, { -92, 0.4, 50 }, 1, TREES)

		-- =============================================================
		--  Parque con estanque y templete (x -140..-85, z 112..196)
		-- =============================================================
		slab(-140, -85, 112, 196, GRASS, "Grass")
		b:cylinder({ name = "Estanque", length = 0.12, diameter = 26, pos = { -112, 0.46, 166 }, color = { 70, 140, 170 }, mat = "Glass", reflectance = 0.2, folder = "Decoracion" })
		P.kiosk(b, { -122, 0.4, 132 }, 7, { 240, 240, 236 }, { 70, 110, 90 })
		for i, t in ipairs({ { -134, 120 }, { -96, 124 }, { -132, 150 }, { -92, 146 }, { -134, 186 }, { -96, 188 }, { -112, 140 } }) do
			P.tree(b, { t[1], 0.4, t[2] }, 1 + (i % 3) * 0.2, TREES)
		end
		for _, z in ipairs({ 130, 154, 180 }) do
			P.bench(b, { -100, 0.4, z }, 90, { 120, 90, 60 })
		end
		for z = 116, 192, 6 do
			P.bush(b, { -88, 0.4, z }, 0.9)
		end

		-- =============================================================
		--  Zona industrial (x -215..-160, z -196..-112)
		-- =============================================================
		slab(-215, -160, -196, -112, { 140, 138, 134 }, "Concrete")
		b:box({ name = "Nave", size = { 40, 20, 30 }, pos = { -192, 10.4, -176 }, color = { 176, 186, 196 }, mat = "Metal" })
		b:box({ name = "Tejado", size = { 41, 1, 31 }, pos = { -192, 20.9, -176 }, color = { 120, 130, 140 }, mat = "CorrodedMetal" })
		for _, x in ipairs({ -202, -182 }) do
			b:box({ name = "Persiana", size = { 9, 10, 0.3 }, pos = { x, 5.4, -160.8 }, color = { 140, 146, 156 }, mat = "DiamondPlate", folder = "Decoracion" })
		end
		P.container(b, { -200, 0.4, -128 }, 0, { 176, 60, 46 }, false, "CARGA")
		P.container(b, { -200, 9.4, -128 }, 0, { 46, 96, 150 }, false)
		P.container(b, { -174, 0.4, -140 }, 90, { 70, 120, 80 }, true)
		P.forklift(b, { -182, 0.4, -126 }, 90, { 240, 190, 40 })
		P.pallet(b, { -166, 0.4, -122 }, 10)
		P.drum(b, { -170, 0.4, -150 }, { 46, 96, 150 })
		P.drum(b, { -167.6, 0.4, -151 }, { 200, 60, 50 })

		-- =============================================================
		--  Casas en las que se puede entrar (x -215..-160, z -88..-12)
		-- =============================================================
		slab(-215, -160, -88, -12, GRASS, "Grass")
		P.openHouse(b, { -198, 0.4, -30 }, 180, { color = { 236, 214, 170 }, trim = { 250, 250, 246 }, roofColor = { 130, 70, 56 } })
		P.openHouse(b, { -177, 0.4, -70 }, 0, { color = { 150, 190, 210 }, trim = { 250, 250, 246 }, roofColor = { 70, 80, 100 }, sofa = { 60, 110, 170 } })
		P.woodFence(b, { -214, 0.4, -50 }, { -190, 0.4, -50 }, 4, { 244, 244, 238 })
		P.car(b, { -170, 0.4, -36 }, 0, { 200, 60, 60 })
		P.tree(b, { -208, 0.4, -76 }, 1.1, TREES)
		P.tree(b, { -166, 0.4, -20 }, 1, TREES)

		-- =============================================================
		--  Obra con un edificio a medio construir (x -215..-160, z 12..88)
		-- =============================================================
		slab(-215, -160, 12, 88, { 150, 120, 90 }, "Ground")
		b:box({ name = "Forjado", size = { 30, 0.8, 24 }, pos = { -195, 10.4, 40 }, color = { 176, 174, 168 }, mat = "Concrete" })
		b:box({ name = "Forjado", size = { 22, 0.8, 24 }, pos = { -199, 20.4, 40 }, color = { 176, 174, 168 }, mat = "Concrete" })
		for _, x in ipairs({ -209, -195, -181 }) do
			for _, z in ipairs({ 29, 51 }) do
				b:box({ name = "Pilar", size = { 1.6, 10, 1.6 }, pos = { x, 5.4, z }, color = { 186, 184, 178 }, mat = "Concrete" })
				if x < -185 then
					b:box({ name = "Pilar", size = { 1.6, 9.2, 1.6 }, pos = { x, 15.4, z }, color = { 186, 184, 178 }, mat = "Concrete" })
				end
			end
		end
		P.stairs(b, { -207, 0.4, 15 }, 0, 10, 1.04, 1.3, 4, { 170, 168, 162 })
		P.stairs(b, { -186, 10.8, 51 }, 180, 10, 1, 1.3, 4, { 170, 168, 162 })
		P.railing(b, { -210, 20.8, 52 }, { -188, 20.8, 52 }, 3, { 240, 190, 40 })
		b:box({ name = "Grua", size = { 3, 64, 3 }, pos = { -170, 32.4, 76 }, color = { 240, 190, 40 }, mat = "Metal" })
		b:box({ name = "Pluma", size = { 50, 2.4, 2.4 }, pos = { -180, 64, 76 }, color = { 240, 190, 40 }, mat = "Metal", folder = "Decoracion" })
		b:box({ name = "Contrapeso", size = { 6, 4, 4 }, pos = { -150, 62, 76 }, color = { 120, 120, 126 }, mat = "Concrete", folder = "Decoracion" })
		for i = 0, 2 do
			b:cylinder({ name = "Tubo", axis = "x", length = 9, diameter = 4, pos = { -172, 2.4 + (i == 2 and 3.4 or 0), 22 + (i == 2 and 2.2 or i * 4.4) }, color = { 170, 168, 160 }, mat = "Concrete" })
		end
		for i = 0, 3 do
			b:box({ name = "Viga", size = { 16, 0.8, 1 }, pos = { -196, 0.8 + i * 0.8, 70 + (i % 2) * 0.5 }, color = { 170, 70, 50 }, mat = "Metal" })
		end
		P.container(b, { -200, 0.4, 82 }, 0, { 240, 240, 236 }, false, "OBRA")
		P.cone(b, { -166, 0.4, 40 })
		P.cone(b, { -166, 0.4, 46 })
		P.barrier(b, { -162, 0.4, 60 }, 90)

		-- =============================================================
		--  Aparcamiento de dos plantas con rampa (x -215..-160, z 112..196)
		-- =============================================================
		slab(-215, -160, 112, 196, { 150, 150, 150 }, "Concrete")
		b:box({ name = "Planta", size = { 50, 1, 50 }, pos = { -187.5, 12, 160 }, color = { 160, 160, 160 }, mat = "Concrete" })
		for _, x in ipairs({ -210, -187.5, -165 }) do
			for _, z in ipairs({ 138, 160, 182 }) do
				b:box({ name = "Pilar", size = { 2, 11.2, 2 }, pos = { x, 6, z }, color = { 186, 186, 186 }, mat = "Concrete" })
			end
		end
		b:wedge({ name = "Rampa", size = { 10, 12, 22 }, pos = { -175, 6.4, 124 }, color = { 150, 150, 150 }, mat = "Concrete" })
		P.wall(b, { -187.5, 12.5, 184.5 }, 0, { 50, 3, 1 }, { 200, 200, 196 })
		P.wall(b, { -212, 12.5, 160 }, 90, { 50, 3, 1 }, { 200, 200, 196 })
		P.wall(b, { -163, 12.5, 166 }, 90, { 38, 3, 1 }, { 200, 200, 196 })
		P.wall(b, { -196, 12.5, 135.5 }, 0, { 32, 3, 1 }, { 200, 200, 196 })
		P.car(b, { -200, 12.5, 170 }, 0, { 230, 230, 226 })
		P.car(b, { -180, 12.5, 150 }, 180, { 40, 40, 46 })
		P.car(b, { -200, 0.4, 150 }, 0, { 200, 160, 40 })
		P.car(b, { -176, 0.4, 176 }, 180, { 120, 40, 40 })

		-- =============================================================
		--  Plaza: árboles, fuentes, bancos, quioscos y paradas de autobús
		-- =============================================================
		for z = -72, 72, 24 do
			if math.abs(z) > 20 then
				b:box({ name = "Alcorque", size = { 5, 0.8, 5 }, pos = { -54, 0.8, z }, color = { 170, 164, 154 }, mat = "Concrete" })
				P.tree(b, { -54, 1.2, z }, 0.9, TREES)
			end
		end
		P.fountain(b, { -32, 0.4, -54 }, 6)
		P.fountain(b, { -32, 0.4, 54 }, 6)
		P.planter(b, { -36, 0.4, -20 }, { 3, 12 }, 0)
		P.planter(b, { -36, 0.4, 20 }, { 3, 12 }, 0)
		P.bench(b, { -20, 0.4, -30 }, 0, { 120, 90, 60 })
		P.bench(b, { -20, 0.4, 30 }, 180, { 120, 90, 60 })
		P.newspaperBox(b, { -60, 0.4, -6 }, -90, { 40, 90, 170 })
		P.marketStall(b, { -46, 0.4, -82 }, 0, { 230, 120, 40 }, "CHURROS")
		P.hotdogCart(b, { -44, 0.4, 80 }, 180)
		P.mannequin(b, { -14, 7.4, -48 }, 30, { 200, 170, 80 })
		b:box({ name = "Pedestal", size = { 4, 7, 4 }, pos = { -14, 3.9, -48 }, color = { 200, 196, 186 }, mat = "Marble" })

		-- =============================================================
		--  Tráfico en las calles: coches, taxis, autobuses y barreras
		-- =============================================================
		P.taxi(b, { -150, 0, -40 }, 0)
		P.car(b, { -75, 0, 30 }, 180, { 60, 120, 200 })
		P.car(b, { -225, 0, 100 }, 0, { 90, 90, 96 })
		P.taxi(b, { -190, 0, 104 }, 90)
		P.car(b, { -120, 0, -96 }, 92, { 230, 230, 226 })
		P.bus(b, { -100, 0, 4 }, 90, { 200, 50, 50 }, "LÍNEA 50")
		P.truck(b, { -40, 0, -104 }, 90, { 236, 236, 232 })
		P.car(b, { -170, 0, -4 }, 75, { 200, 160, 40 })
		P.barrier(b, { -150, 0, 60 }, 0)
		P.barrier(b, { -75, 0, -60 }, 0)
		P.barrier(b, { -225, 0, -100 }, 90)
		for _, p in ipairs({ { -150, 140 }, { -75, 150 }, { -225, 30 } }) do
			P.cone(b, { p[1] - 3, 0, p[2] })
			P.cone(b, { p[1] + 3, 0, p[2] })
		end
		for _, z in ipairs({ -36, -24 }) do
			P.bus(b, { z, 0.4, -150 }, 0, { 240, 240, 236 }, "TERMINAL")
		end
		for x = -48, -8, 20 do
			b:box({ name = "Pilar", size = { 1.4, 11.6, 1.4 }, pos = { x, 6.2, -128 }, color = { 200, 204, 210 }, mat = "Metal" })
			b:box({ name = "Pilar", size = { 1.4, 11.6, 1.4 }, pos = { x, 6.2, -168 }, color = { 200, 204, 210 }, mat = "Metal" })
		end

		-- Farolas a lo largo de las avenidas
		for _, x in ipairs({ -260, -190, -120, -45 }) do
			P.streetLight(b, { x, 0.4, 87 }, 0, 18)
			P.streetLight(b, { x + 30, 0.4, -87 }, 180, 18)
		end
	end)

	b:bounds(-300, 300, -200, 200, 150)

	b:lighting({
		technology = "Future",
		lighting = {
			ClockTime = 15.2,
			Brightness = 3,
			Ambient = { 120, 118, 116 },
			OutdoorAmbient = { 164, 160, 156 },
			ExposureCompensation = 0,
			ShadowSoftness = 0.2,
			EnvironmentDiffuseScale = 0.6,
			EnvironmentSpecularScale = 0.6,
		},
		atmosphere = { density = 0.3, offset = 0.05, color = { 214, 214, 220 }, decay = { 150, 156, 170 }, glare = 0.5, haze = 1.6 },
		colorCorrection = { contrast = 0.08, saturation = 0.1, tint = { 255, 252, 246 } },
		clouds = { cover = 0.45, density = 0.45, color = { 255, 255, 255 } },
		bloom = { intensity = 0.3, size = 24, threshold = 0.95 },
		sunRays = { intensity = 0.08, spread = 0.6 },
	})
end
]=]
FUENTES_MAPAS["Egipto"] = [=[
-- Egipto: ruinas de un templo en el desierto con pirámides al fondo. Equipo A en -X, equipo B en +X.
return function(b, MB)
	local P = MB.Props
	local SAND = { 226, 196, 146 }
	local STONE = { 214, 186, 136 }
	local STONE_DARK = { 186, 156, 110 }
	local BLUE = { 40, 90, 160 }
	local GOLD = { 226, 182, 80 }
	local RED = { 170, 64, 44 }

	b.model:SetAttribute("Nombre", "Egipto")

	-- Estatua sentada de faraón (mira hacia -Z local)
	local function pharaoh(pos, rotY)
		local s = b:at(pos, rotY)
		s:box({ name = "Pedestal", size = { 7, 2, 9 }, pos = { 0, 1, 0 }, color = STONE_DARK, mat = "Sandstone" })
		s:box({ name = "Trono", size = { 6, 9, 4 }, pos = { 0, 6.5, 2 }, color = STONE, mat = "Sandstone" })
		s:box({ name = "Piernas", size = { 4.6, 2.4, 5 }, pos = { 0, 6.2, -1.8 }, color = STONE, mat = "Sandstone" })
		for _, x in ipairs({ -1.2, 1.2 }) do
			s:box({ name = "Pierna", size = { 1.8, 5, 1.8 }, pos = { x, 4.5, -3.4 }, color = STONE, mat = "Sandstone" })
			s:box({ name = "Brazo", size = { 1.3, 1.1, 4 }, pos = { x * 1.75, 7.9, -1.6 }, color = STONE, mat = "Sandstone", folder = "Decoracion" })
		end
		s:box({ name = "Torso", size = { 4.4, 6, 2.6 }, pos = { 0, 10.4, 0.8 }, color = STONE, mat = "Sandstone" })
		s:box({ name = "Cabeza", size = { 2.4, 2.8, 2.4 }, pos = { 0, 14.8, 0.6 }, color = STONE, mat = "Sandstone" })
		s:box({ name = "Nemes", size = { 3.6, 3.4, 2.6 }, pos = { 0, 15.2, 1.2 }, color = GOLD, mat = "Sandstone", folder = "Decoracion" })
		for i = 0, 2 do
			s:box({ name = "Franja", size = { 3.7, 0.4, 2.7 }, pos = { 0, 14 + i, 1.2 }, color = BLUE, folder = "Decoracion" })
		end
		for _, x in ipairs({ -1.5, 1.5 }) do
			s:box({ name = "Nemes", size = { 1, 3.4, 1.2 }, pos = { x, 12.4, -0.2 }, color = GOLD, folder = "Decoracion" })
		end
		s:box({ name = "Barba", size = { 0.7, 1.6, 0.7 }, pos = { 0, 12.6, -0.4 }, color = STONE_DARK, folder = "Decoracion" })
		s:box({ name = "Cobra", size = { 0.5, 0.8, 0.4 }, pos = { 0, 16.8, -0.6 }, color = GOLD, mat = "Metal", folder = "Decoracion" })
	end

	-- Relieves pintados en una pared (figuras de colores sobre la cara -Z local)
	local function reliefs(g, x0, count, y, z)
		local colors = { BLUE, RED, GOLD }
		for k = 0, count - 1 do
			local x = x0 + k * 3
			g:box({ name = "Relieve", size = { 1.4, 4.4, 0.2 }, pos = { x, y, z }, color = colors[(k % 3) + 1], folder = "Decoracion" })
			g:box({ name = "Relieve", size = { 1.2, 1.2, 0.2 }, pos = { x, y + 3, z }, color = (k % 2 == 0) and GOLD or BLUE, folder = "Decoracion" })
		end
	end

	-- =================================================================
	--  Desierto, dunas y pirámides
	-- =================================================================
	b:box({ name = "Desierto", size = { 1000, 1, 1000 }, pos = { 0, -1.2, 0 }, color = SAND, mat = "Sand", folder = "Decoracion" })
	for _, d in ipairs({ { -190, 120, 120 }, { 200, 110, 140 }, { -190, -100, 150 }, { 180, -120, 130 }, { 0, -170, 160 } }) do
		b:ball({ name = "Duna", diameter = d[3], pos = { d[1], -d[3] * 0.36, d[2] }, color = { 222, 188, 136 }, mat = "Sand", folder = "Decoracion" })
	end
	P.pyramid(b, { -120, 0, 300 }, 220, 140, 20, { 214, 184, 128 })
	P.pyramid(b, { 80, 0, 360 }, 260, 166, 24, { 206, 176, 122 })
	P.pyramid(b, { 250, 0, 260 }, 140, 90, 14, { 214, 186, 132 })

	-- =================================================================
	--  Suelo del templo, obelisco y puerta monumental
	-- =================================================================
	b:box({ name = "Suelo", size = { 164, 1, 108 }, pos = { 0, -0.5, 0 }, color = SAND, mat = "Sand" })
	b:box({ name = "Losas", size = { 70, 0.4, 44 }, pos = { 0, 0.2, 0 }, color = { 200, 176, 132 }, mat = "Sandstone" })
	P.obelisk(b, { 0, 0.4, 0 }, 28, 3.2)
	b:box({ name = "Dintel", size = { 12, 6, 9 }, pos = { 0, 23, 58 }, color = STONE, mat = "Sandstone" })
	b:box({ name = "Portal", size = { 12, 20, 0.4 }, pos = { 0, 10, 57 }, color = { 70, 54, 40 }, folder = "Decoracion" })
	b:cylinder({ name = "Disco", axis = "z", length = 0.4, diameter = 4, pos = { 0, 23, 53.4 }, color = GOLD, mat = "Metal", folder = "Decoracion" })
	for _, x in ipairs({ -1, 1 }) do
		b:box({ name = "Ala", size = { 4, 1, 0.3 }, pos = { x * 4, 23, 53.4 }, color = BLUE, folder = "Decoracion" })
	end

	-- Esfinge entre el obelisco y el templo (mira hacia el centro)
	b:box({ name = "Pedestal", size = { 12, 2, 24 }, pos = { 0, 1, 36 }, color = STONE_DARK, mat = "Sandstone" })
	b:box({ name = "Cuerpo", size = { 7, 6, 14 }, pos = { 0, 5, 40 }, color = STONE, mat = "Sandstone" })
	b:box({ name = "Patas", size = { 8, 4, 6 }, pos = { 0, 4, 45 }, color = STONE, mat = "Sandstone" })
	b:box({ name = "Pecho", size = { 6, 6, 3 }, pos = { 0, 5, 32.4 }, color = STONE, mat = "Sandstone" })
	for _, x in ipairs({ -2.2, 2.2 }) do
		b:box({ name = "Garra", size = { 2, 1.6, 7 }, pos = { x, 2.8, 28.4 }, color = STONE, mat = "Sandstone" })
		b:box({ name = "Nemes", size = { 1.2, 4, 1.4 }, pos = { x * 1.1, 9, 31.8 }, color = GOLD, folder = "Decoracion" })
	end
	b:box({ name = "Cabeza", size = { 4, 4.4, 4 }, pos = { 0, 11, 32.4 }, color = STONE, mat = "Sandstone" })
	b:box({ name = "Nemes", size = { 5.6, 5, 3.6 }, pos = { 0, 11.6, 33.6 }, color = GOLD, mat = "Sandstone", folder = "Decoracion" })
	for i = 0, 3 do
		b:box({ name = "Franja", size = { 5.7, 0.45, 3.7 }, pos = { 0, 9.8 + i * 1.2, 33.6 }, color = BLUE, folder = "Decoracion" })
	end
	b:box({ name = "Barba", size = { 0.8, 2, 0.8 }, pos = { 0, 8, 30.6 }, color = STONE_DARK, folder = "Decoracion" })

	b:symmetric(function(b)
		-- Estandartes delante del pilono
		for i, x in ipairs({ -23, -7 }) do
			b:cylinder({ name = "Mastil", length = 32, diameter = 0.6, pos = { x, 16, 52.6 }, color = { 120, 90, 60 }, mat = "Wood" })
			b:box({ name = "Estandarte", size = { 3, 8, 0.15 }, pos = { x + 1.7, 27, 52.6 }, color = (i == 1) and BLUE or RED, mat = "Fabric", folder = "Decoracion" })
		end

		-- Braseros con fuego
		for _, z in ipairs({ -20, 20 }) do
			b:cylinder({ name = "Pie", length = 3.6, diameter = 0.6, pos = { -33, 2.2, z }, color = { 70, 60, 50 }, mat = "Metal" })
			b:cylinder({ name = "Cuenco", length = 0.8, diameter = 2.4, pos = { -33, 4.2, z }, color = { 120, 90, 50 }, mat = "Metal" })
			local fire = b:ball({ name = "Fuego", diameter = 1.6, pos = { -33, 4.9, z }, color = { 255, 140, 40 }, mat = "Neon", folder = "Decoracion" })
			MB.light(fire, "Point", { color = { 255, 150, 70 }, brightness = 1.6, range = 16 })
		end

		-- Tienda de campaña del bazar
		for _, x in ipairs({ -42, -34 }) do
			for _, z in ipairs({ -50, -42 }) do
				b:cylinder({ name = "Poste", length = 4, diameter = 0.4, pos = { x, 2, z }, color = { 120, 90, 60 }, mat = "Wood" })
			end
		end
		b:wedge({ name = "Lona", size = { 9, 3, 4.4 }, pos = { -38, 5.5, -48.2 }, color = RED, mat = "Fabric" })
		b:wedge({ name = "Lona", size = { 9, 3, 4.4 }, pos = { -38, 5.5, -43.8 }, rot = { 0, 180, 0 }, color = { 236, 220, 190 }, mat = "Fabric" })
		b:box({ name = "Alfombra", size = { 7, 0.08, 7 }, pos = { -38, 0.04, -46 }, color = BLUE, mat = "Fabric", folder = "Decoracion" })
		b:box({ name = "Cojin", size = { 2, 0.8, 1.4 }, pos = { -36, 0.4, -48 }, color = GOLD, mat = "Fabric", folder = "Decoracion" })

		-- Pilono del templo al fondo
		b:box({ name = "Pilono", size = { 18, 26, 9 }, pos = { -15, 13, 58 }, color = STONE, mat = "Sandstone" })
		b:box({ name = "Cornisa", size = { 19, 1.6, 10 }, pos = { -15, 26.8, 58 }, color = STONE_DARK, mat = "Sandstone" })
		reliefs(b, -21, 5, 9, 53.4)
		b:cylinder({ name = "Disco", axis = "z", length = 0.4, diameter = 4, pos = { -15, 20, 53.4 }, color = GOLD, mat = "Metal", folder = "Decoracion" })

		-- Muralla en ruinas al sur
		for i, h in ipairs({ 9, 6, 11, 5, 8, 12, 7 }) do
			b:box({ name = "Muralla", size = { 12, h, 4 }, pos = { -82 + i * 12, h / 2, -56 }, color = (i % 2 == 0) and STONE or STONE_DARK, mat = "Sandstone" })
		end

		-- Columnata norte con dintel
		for _, x in ipairs({ -40, -32, -24, -16 }) do
			P.column(b, { x, 0, 26 }, 16, 3, STONE, "Sandstone")
			for k, y in ipairs({ 13.6, 14.6, 15.6 }) do
				b:cylinder({ name = "Pintura", length = 0.5, diameter = 3.1, pos = { x, y, 26 }, color = (k == 2) and GOLD or BLUE, folder = "Decoracion" })
			end
		end
		b:box({ name = "Dintel", size = { 29, 2.4, 4.4 }, pos = { -28, 19.4, 26 }, color = STONE_DARK, mat = "Sandstone" })
		for k = 0, 8 do
			b:box({ name = "Friso", size = { 1.4, 1, 0.2 }, pos = { -40 + k * 3, 19.4, 23.7 }, color = (k % 2 == 0) and BLUE or GOLD, folder = "Decoracion" })
		end

		-- Columnata sur en ruinas y columna caída
		P.column(b, { -40, 0, -26 }, 16, 3, STONE, "Sandstone")
		P.column(b, { -32, 0, -26 }, 7, 3, STONE, "Sandstone", true)
		P.column(b, { -24, 0, -26 }, 16, 3, STONE, "Sandstone")
		P.column(b, { -16, 0, -26 }, 4, 3, STONE, "Sandstone", true)
		b:cylinder({ name = "Columna", axis = "x", length = 10, diameter = 3, pos = { -28, 1.5, -16 }, rot = { 0, 25, 0 }, color = STONE, mat = "Sandstone" })

		-- Bloques de piedra sueltos
		for _, k in ipairs({ { -48, -10, 5, 5, 5, 10 }, { -44, -4, 4, 3, 4, 30 }, { -20, 12, 6, 3.5, 4, -15 }, { -56, 14, 6, 4, 5, 5 }, { -12, -38, 5, 4, 5, 20 } }) do
			b:box({ name = "Bloque", size = { k[3], k[4], k[5] }, pos = { k[1], k[4] / 2, k[2] }, rot = { 0, k[6], 0 }, color = STONE_DARK, mat = "Sandstone" })
		end

		-- Pared con jeroglíficos
		b:box({ name = "Pared", size = { 14, 8, 2.4 }, pos = { -36, 4, -42 }, color = STONE, mat = "Sandstone" })
		reliefs(b, -42, 5, 3.6, -40.7)

		-- Oasis con palmeras
		b:cylinder({ name = "Agua", length = 0.12, diameter = 16, pos = { -56, 0.06, 34 }, color = { 60, 150, 170 }, mat = "Glass", transparency = 0.2, reflectance = 0.25, folder = "Decoracion" })
		b:cylinder({ name = "Orilla", length = 0.1, diameter = 18, pos = { -56, 0.04, 34 }, color = { 150, 150, 90 }, mat = "Grass", folder = "Decoracion" })
		P.palmTree(b, { -62, 0, 40 }, 1.1)
		P.palmTree(b, { -50, 0, 42 }, 0.9)
		P.palmTree(b, { -64, 0, 27 }, 1)
		P.palmTree(b, { -10, 0, 42 }, 1)
		for i = 0, 5 do
			b:cylinder({ name = "Junco", length = 3, diameter = 0.3, pos = { -48.5 + (i % 3) * 0.6, 1.5, 30 + i * 0.7 }, color = { 110, 140, 70 }, mat = "Grass", folder = "Decoracion" })
		end

		-- Bazar con alfombras y ánforas
		P.marketStall(b, { -50, 0, -38 }, 180, BLUE, "BAZAR", { { 200, 80, 40 }, { 230, 180, 60 }, { 160, 60, 40 }, { 220, 140, 60 } })
		b:box({ name = "Alfombra", size = { 6, 0.08, 4 }, pos = { -50, 0.04, -31 }, color = RED, mat = "Fabric", folder = "Decoracion" })
		b:box({ name = "Alfombra", size = { 4.4, 0.1, 2.6 }, pos = { -50, 0.06, -31 }, color = GOLD, mat = "Fabric", folder = "Decoracion" })
		for _, p in ipairs({ { -57, -40 }, { -58.4, -37.6 }, { -56, -35.8 } }) do
			b:ball({ name = "Anfora", diameter = 2, pos = { p[1], 1.1, p[2] }, color = { 190, 110, 70 }, mat = "Plaster" })
			b:cylinder({ name = "Cuello", length = 1, diameter = 0.8, pos = { p[1], 2.4, p[2] }, color = { 190, 110, 70 }, mat = "Plaster", folder = "Decoracion" })
		end

		-- Estatuas de faraón junto al spawn
		pharaoh({ -68, 0, 34 }, -90)
		pharaoh({ -68, 0, -34 }, -90)

		-- Muro del templo que protege el spawn
		P.wall(b, { -60, 0, 0 }, 90, { 34, 11, 2.6 }, STONE, STONE_DARK, STONE_DARK, "Sandstone")
		b:box({ name = "Franja", size = { 0.2, 1.2, 30 }, pos = { -58.6, 8.6, 0 }, color = BLUE, folder = "Decoracion" })
		b:cylinder({ name = "Disco", axis = "x", length = 0.4, diameter = 3.4, pos = { -58.5, 5.6, 0 }, color = GOLD, mat = "Metal", folder = "Decoracion" })
		for _, z in ipairs({ -1, 1 }) do
			b:box({ name = "Ala", size = { 0.3, 0.9, 4 }, pos = { -58.5, 5.6, z * 3.6 }, color = BLUE, folder = "Decoracion" })
		end
		for _, z in ipairs({ -8, 0, 8 }) do
			b:spawn("A", { -70, 0.5, z }, -90)
		end
	end)

	b:bounds(-80, 80, -52, 52, 40)

	b:lighting({
		technology = "Future",
		lighting = {
			ClockTime = 16.9,
			Brightness = 3,
			Ambient = { 130, 104, 80 },
			OutdoorAmbient = { 176, 140, 104 },
			ExposureCompensation = 0.1,
			ShadowSoftness = 0.2,
			EnvironmentDiffuseScale = 0.5,
			EnvironmentSpecularScale = 0.4,
		},
		atmosphere = { density = 0.34, offset = 0.1, color = { 244, 206, 156 }, decay = { 190, 130, 80 }, glare = 1.2, haze = 2.4 },
		colorCorrection = { contrast = 0.1, saturation = 0.12, tint = { 255, 240, 220 } },
		clouds = { cover = 0.2, density = 0.3, color = { 255, 230, 200 } },
		bloom = { intensity = 0.4, size = 26, threshold = 0.92 },
		sunRays = { intensity = 0.14, spread = 0.7 },
	})
end
]=]
FUENTES_MAPAS["Espana"] = [=[
-- España: plaza andaluza con casas encaladas, fuente, naranjos y terrazas. Equipo A en -X, equipo B en +X.
return function(b, MB)
	local P = MB.Props
	local WHITE = { 246, 244, 238 }
	local TEJA = { 186, 94, 62 }
	local ALBERO = { 214, 186, 140 }
	local NARANJO = { { 64, 116, 60 }, { 82, 132, 66 }, { 56, 104, 54 } }
	local OLIVO = { { 120, 130, 90 }, { 136, 146, 104 }, { 106, 118, 82 } }
	local CASAS = {
		{ w = 13, h = 13, color = WHITE, trim = { 214, 170, 90 }, roof = "gable", roofColor = TEJA, shutters = { 52, 112, 76 }, balcony = true, flowers = { 220, 50, 70 } },
		{ w = 12, h = 12, color = WHITE, trim = { 60, 100, 170 }, roof = "gable", roofColor = TEJA, shop = "BAR PACO · TAPAS", shopColor = { 150, 30, 40 } },
		{ w = 14, h = 14, color = { 250, 236, 200 }, trim = { 190, 140, 70 }, roof = "gable", roofColor = TEJA, shutters = { 60, 96, 160 }, balcony = true, flowers = { 240, 120, 160 } },
		{ w = 12, h = 12, color = WHITE, trim = { 214, 170, 90 }, roof = "gable", roofColor = TEJA, shop = "PANADERÍA", shopColor = { 196, 130, 50 } },
		{ w = 13, h = 13, color = { 248, 222, 160 }, trim = WHITE, roof = "gable", roofColor = TEJA, shutters = { 110, 70, 44 }, balcony = true, flowers = { 220, 50, 70 } },
	}

	b.model:SetAttribute("Nombre", "España")

	-- =================================================================
	--  Paisaje: colinas secas con olivos
	-- =================================================================
	b:box({ name = "Campo", size = { 900, 1, 900 }, pos = { 0, -1.2, 0 }, color = { 178, 160, 108 }, mat = "Grass", folder = "Decoracion" })
	for _, h in ipairs({ { -170, 150, 170 }, { 170, 150, 170 }, { 0, 210, 190 }, { -160, -150, 160 }, { 160, -150, 160 } }) do
		b:ball({ name = "Colina", diameter = h[3], pos = { h[1], -h[3] * 0.32, h[2] }, color = { 160, 146, 98 }, mat = "Grass", folder = "Decoracion" })
	end
	for i = 0, 11 do
		local x = -110 + (i % 6) * 44
		local z = (i < 6) and 92 or -92
		P.tree(b, { x, 0, z + (i % 2) * 10 }, 0.9, OLIVO)
	end

	-- =================================================================
	--  Plaza empedrada, fuente e iglesia
	-- =================================================================
	b:box({ name = "Suelo", size = { 164, 1, 108 }, pos = { 0, -0.5, 0 }, color = { 206, 190, 166 }, mat = "Cobblestone" })
	b:cylinder({ name = "Albero", length = 0.1, diameter = 30, pos = { 0, 0.05, 0 }, color = ALBERO, mat = "Sand", folder = "Decoracion" })
	P.fountain(b, { 0, 0, 0 }, 7)

	P.house(b, { 0, 0, 61 }, 0, { w = 26, h = 18, d = 18, color = WHITE, trim = { 214, 190, 150 }, roof = "gable", roofColor = TEJA, floors = 1, cols = 3, doorColor = { 100, 60, 36 } })
	P.bellTower(b, { 0, 0, 68 }, 0, 38, WHITE, TEJA)
	b:box({ name = "Portada", size = { 9, 12, 0.6 }, pos = { 0, 6, 51.9 }, color = { 214, 190, 150 }, mat = "Limestone" })
	b:box({ name = "Puerta", size = { 4.4, 7.6, 0.4 }, pos = { 0, 3.8, 51.5 }, color = { 100, 60, 36 }, mat = "WoodPlanks", folder = "Decoracion" })
	b:cylinder({ name = "Arco", axis = "z", length = 0.4, diameter = 4.4, pos = { 0, 7.6, 51.5 }, color = { 100, 60, 36 }, mat = "WoodPlanks", folder = "Decoracion" })
	P.poster(b, { 0, 14.4, 51.8 }, 0, { 13, 1.8 }, { 40, 80, 170 }, "IGLESIA DE SANTA ANA", WHITE, "Garamond")

	b:symmetric(function(b)
		-- Casas encaladas con balcones y flores
		P.houseRow(b, 57, 0, -84, -13, CASAS, 10)
		P.houseRow(b, -57, 180, -84, 0, CASAS, 10)

		-- Naranjos en alcorques
		for _, t in ipairs({ { -22, -20 }, { -24, 22 }, { -52, -28 }, { -50, 34 } }) do
			b:box({ name = "Alcorque", size = { 5, 0.8, 5 }, pos = { t[1], 0.4, t[2] }, color = { 170, 150, 120 }, mat = "Limestone" })
			P.tree(b, { t[1], 0.4, t[2] }, 0.85, NARANJO)
			for k = 0, 5 do
				local a = k * 1.05
				b:ball({ name = "Naranja", diameter = 0.8, pos = { t[1] + math.cos(a) * 3.2, 9.6 + (k % 2) * 1.4, t[2] + math.sin(a) * 3.2 }, color = { 250, 140, 30 }, folder = "Decoracion" })
			end
		end

		-- Terrazas del bar
		for _, t in ipairs({ { -66, -43 }, { -56, -41 }, { -38, 42 }, { -48, 40 } }) do
			P.umbrellaTable(b, { t[1], 0, t[2] }, { 200, 40, 40 })
		end

		-- Soportales con columnas
		for _, x in ipairs({ -44, -38, -32 }) do
			for _, z in ipairs({ -29.6, -35.2 }) do
				P.column(b, { x, 0, z }, 8, 1.4, WHITE, "Plaster")
			end
		end
		b:box({ name = "Soportal", size = { 14.4, 1.2, 7.2 }, pos = { -38, 10.8, -32.4 }, color = WHITE, mat = "Plaster" })
		b:box({ name = "Tejadillo", size = { 15.4, 0.8, 8.2 }, pos = { -38, 11.8, -32.4 }, color = TEJA, mat = "ClayRoofTiles" })

		-- Seiscientos aparcado, jardinera y barriles de vino
		P.car(b, { -44, 0, 8 }, 90, { 210, 40, 40 })
		P.planter(b, { -20, 0, 0 }, { 3, 10 }, 0)
		for _, p in ipairs({ { -70, -34 }, { -67.4, -35.2 }, { -69, -37.6 } }) do
			P.drum(b, { p[1], 0, p[2] }, { 120, 70, 40 })
		end
		P.bench(b, { -12, 0, -10 }, 0, { 120, 80, 50 })
		P.bench(b, { -12, 0, 10 }, 180, { 120, 80, 50 })
		P.pottedPlant(b, { -30, 0, 44 }, 1.2)
		P.pottedPlant(b, { -26, 0, -44 }, 1.2)

		-- Muro encalado que protege el spawn, con macetas de geranios
		P.wall(b, { -60, 0, 0 }, 90, { 34, 10, 2 }, WHITE, { 196, 170, 130 }, TEJA, "Plaster")
		P.poster(b, { -58.9, 7, 0 }, -90, { 11, 2.6 }, { 40, 80, 170 }, "PLAZA MAYOR", WHITE, "Garamond")
		for _, z in ipairs({ -14, -10, 10, 14 }) do
			b:box({ name = "Maceta", size = { 0.8, 1, 1.2 }, pos = { -58.6, 5.6, z }, color = { 40, 90, 170 }, folder = "Decoracion" })
			b:ball({ name = "Geranio", diameter = 1.3, pos = { -58.6, 6.4, z }, color = { 220, 40, 60 }, mat = "LeafyGrass", folder = "Decoracion" })
		end
		for _, z in ipairs({ -8, 0, 8 }) do
			b:spawn("A", { -70, 0.5, z }, -90)
		end
	end)

	b:bounds(-80, 80, -52, 52, 40)

	b:lighting({
		technology = "Future",
		lighting = {
			ClockTime = 13.4,
			Brightness = 3.4,
			Ambient = { 130, 120, 110 },
			OutdoorAmbient = { 170, 160, 146 },
			ExposureCompensation = 0,
			ShadowSoftness = 0.12,
			EnvironmentDiffuseScale = 0.6,
			EnvironmentSpecularScale = 0.5,
		},
		atmosphere = { density = 0.22, offset = 0.05, color = { 240, 226, 200 }, decay = { 170, 150, 130 }, glare = 0.4, haze = 1.2 },
		colorCorrection = { contrast = 0.1, saturation = 0.2, tint = { 255, 250, 240 } },
		clouds = { cover = 0.25, density = 0.35, color = { 255, 255, 255 } },
		bloom = { intensity = 0.3, size = 24, threshold = 0.95 },
		sunRays = { intensity = 0.08, spread = 0.6 },
	})
end
]=]
FUENTES_MAPAS["Gasolinera"] = [=[
-- Gasolinera al atardecer. Equipo A en -X, equipo B en +X.
return function(b, MB)
	local P = MB.Props
	local ASPHALT = { 98, 86, 88 }
	local ROAD = { 70, 62, 66 }
	local LINE = { 236, 230, 220 }
	local STORE = { 62, 94, 76 }
	local BRICK = { 150, 82, 68 }
	local TRIM = { 40, 44, 48 }
	local WHITE = { 240, 238, 234 }
	local RED = { 205, 45, 45 }
	local YELLOW = { 245, 200, 40 }
	local AUTUMN = {
		{ { 198, 122, 60 }, { 170, 108, 52 }, { 136, 128, 62 } },
		{ { 176, 132, 58 }, { 204, 150, 72 }, { 122, 120, 58 } },
		{ { 150, 104, 50 }, { 188, 112, 56 }, { 146, 138, 70 } },
	}

	b.model:SetAttribute("Nombre", "Gasolinera")

	-- =================================================================
	--  Paisaje: césped, colinas, árboles de otoño y valla publicitaria
	-- =================================================================
	b:box({ name = "Cesped", size = { 700, 1, 700 }, pos = { 0, -1.2, 0 }, color = { 112, 148, 72 }, mat = "Grass", folder = "Decoracion" })
	local hills = { { 0, -40, 140, 150 }, { -115, -32, 100, 120 }, { 115, -32, 100, 120 }, { -160, -42, 0, 140 }, { 160, -42, 0, 140 }, { -70, -48, -128, 130 }, { 70, -48, -128, 130 } }
	for _, h in ipairs(hills) do
		b:ball({ name = "Colina", diameter = h[4], pos = { h[1], h[2], h[3] }, color = { 114, 152, 76 }, mat = "Grass", folder = "Decoracion" })
	end
	local trees = {
		{ -70, 70, 1.4 }, { -42, 78, 1.6 }, { -14, 72, 1.3 }, { 16, 80, 1.7 }, { 46, 70, 1.4 }, { 74, 78, 1.5 },
		{ -100, 40, 1.5 }, { -104, 4, 1.7 }, { -98, -34, 1.4 }, { 100, 34, 1.6 }, { 104, -2, 1.4 }, { 98, -38, 1.7 },
		{ -62, -76, 1.5 }, { -22, -82, 1.3 }, { 24, -80, 1.6 }, { 62, -74, 1.4 }, { -88, 62, 1.2 }, { 90, 60, 1.3 },
	}
	for i, t in ipairs(trees) do
		P.tree(b, { t[1], -0.7, t[2] }, t[3], AUTUMN[(i % 3) + 1])
	end
	for x = -70, 70, 14 do
		P.bush(b, { x, -0.7, 61 }, 1.2, { 98, 128, 64 })
	end
	-- Valla publicitaria en la colina
	for _, x in ipairs({ -10, 10 }) do
		b:box({ name = "Poste", size = { 1.2, 22, 1.2 }, pos = { x, 11, 96 }, color = { 80, 70, 64 }, mat = "Wood", folder = "Decoracion" })
	end
	local billboard = b:box({ name = "Valla", size = { 34, 12, 1 }, pos = { 0, 24, 96 }, color = { 250, 240, 220 }, folder = "Decoracion" })
	MB.sign(billboard, "MOTEL EL OASIS · 5 KM", { font = "LuckiestGuy", color = { 210, 70, 50 }, bg = { 250, 236, 206 }, width = 0.9, height = 0.6 })

	-- =================================================================
	--  Carretera y acera
	-- =================================================================
	b:box({ name = "Asfalto", size = { 164, 1, 116 }, pos = { 0, -0.5, 0 }, color = ASPHALT, mat = "Asphalt" })
	b:box({ name = "Carretera", size = { 164, 0.1, 22 }, pos = { 0, 0.05, -44 }, color = ROAD, mat = "Asphalt", folder = "Decoracion" })
	for x = -78, 78, 12 do
		b:box({ name = "Linea", size = { 6, 0.12, 0.6 }, pos = { x, 0.07, -44 }, color = LINE, folder = "Decoracion" })
	end
	b:box({ name = "Linea", size = { 164, 0.12, 0.5 }, pos = { 0, 0.07, -54 }, color = LINE, folder = "Decoracion" })
	P.sidewalk(b, { 0, 0, -30.8 }, { 164, 4.4 })
	P.guardrail(b, { -82, 0, -55.6 }, { 82, 0, -55.6 })
	P.woodFence(b, { -80, 0, 55.6 }, { 80, 0, 55.6 }, 4)

	-- Poste de precios en el centro
	P.pricePylon(b, { 0, 0, -25 }, 0, "GASOLINA 24H", RED)

	-- =================================================================
	--  Tienda (centro, con puerta delantera y dos laterales)
	-- =================================================================
	b:box({ name = "ParedTrasera", size = { 36, 14, 1.5 }, pos = { 0, 7, 39.25 }, color = STORE, mat = "Slate" })
	b:box({ name = "Zocalo", size = { 36.4, 3, 1.8 }, pos = { 0, 1.5, 39.25 }, color = BRICK, mat = "Brick" })
	b:box({ name = "Zocalo", size = { 36, 2, 1.2 }, pos = { 0, 1, 20.6 }, color = BRICK, mat = "Brick" })
	b:box({ name = "Fachada", size = { 36, 4, 1.5 }, pos = { 0, 12, 20.75 }, color = STORE, mat = "Slate" })
	b:box({ name = "Cornisa", size = { 38.4, 0.8, 23.4 }, pos = { 0, 14.4, 30 }, color = TRIM, mat = "Concrete" })
	b:box({ name = "Tejado", size = { 37, 0.6, 21 }, pos = { 0, 14.9, 30 }, color = { 70, 70, 76 }, mat = "Concrete" })
	P.neonSign(b, { 0, 12.7, 19.7 }, 0, { 22, 2.4 }, "MINI MARKET 24H", { 255, 214, 90 }, "GothamBlack")
	b:box({ name = "SueloTienda", size = { 34, 0.1, 18 }, pos = { 0, 0.06, 30 }, color = { 226, 224, 218 }, mat = "CeramicTiles", folder = "Decoracion" })
	b:box({ name = "Mostrador", size = { 8, 3.5, 2.4 }, pos = { 0, 1.75, 35 }, color = { 120, 80, 56 }, mat = "WoodPlanks" })
	b:box({ name = "Encimera", size = { 8.4, 0.3, 2.8 }, pos = { 0, 3.6, 35 }, color = { 230, 228, 222 }, mat = "Marble" })
	b:box({ name = "Cafetera", size = { 1.4, 1.6, 1.2 }, pos = { 2.6, 4.5, 35 }, color = { 40, 40, 44 }, mat = "Metal", folder = "Decoracion" })
	local lamp = b:box({ name = "LuzTienda", size = { 10, 0.2, 2 }, pos = { 0, 13.9, 30 }, color = { 255, 244, 220 }, mat = "Neon", folder = "Decoracion" })
	MB.light(lamp, "Surface", { face = "Bottom", brightness = 1.4, range = 20, angle = 120 })
	-- Carteles de los escaparates
	P.poster(b, { -11, 8, 19.85 }, 0, { 5, 2.2 }, { 214, 120, 40 }, "CAFÉ")
	P.poster(b, { -5.5, 6, 19.85 }, 0, { 5, 2.2 }, { 245, 245, 245 }, "HELADO", { 40, 110, 200 })
	P.poster(b, { 9, 7, 19.85 }, 0, { 5, 3 }, YELLOW, "OFERTA 2x1", { 200, 30, 30 })
	P.neonSign(b, { 13.5, 4, 19.9 }, 0, { 4, 1.4 }, "ABIERTO", { 90, 255, 120 })
	-- Toldo a rayas sobre el escaparate
	for i = 0, 8 do
		b:wedge({ name = "Toldo", size = { 4, 1.6, 3 }, pos = { -16 + i * 4, 10.6, 18.6 }, color = (i % 2 == 0) and RED or WHITE, mat = "Fabric" })
	end

	-- =================================================================
	--  Marquesina con surtidores
	-- =================================================================
	b:box({ name = "Marquesina", size = { 44, 1.6, 18 }, pos = { 0, 16.8, -7 }, color = WHITE })
	b:box({ name = "FranjaRoja", size = { 44.6, 1.1, 18.6 }, pos = { 0, 15.9, -7 }, color = RED, folder = "Decoracion" })
	b:box({ name = "Filete", size = { 44.7, 0.2, 18.7 }, pos = { 0, 16.6, -7 }, color = WHITE, folder = "Decoracion" })
	local canopySign = b:box({ name = "Rotulo", size = { 20, 1.4, 0.2 }, pos = { 0, 16.8, -16.15 }, color = WHITE, folder = "Decoracion" })
	MB.sign(canopySign, "GASOLINA 24H", { font = "GothamBlack", color = RED })

	-- Cables entre postes
	b:box({ name = "Cable", size = { 132, 0.15, 0.15 }, pos = { 0, 27.2, -30.6 }, color = { 30, 30, 30 }, folder = "Decoracion", shadow = false })
	b:box({ name = "Cable", size = { 132, 0.15, 0.15 }, pos = { 0, 27.2, -29.4 }, color = { 30, 30, 30 }, folder = "Decoracion", shadow = false })

	b:symmetric(function(b)
		-- Paredes laterales de la tienda con puerta
		b:box({ name = "Pared", size = { 1.5, 14, 6 }, pos = { -17.25, 7, 23 }, color = STORE, mat = "Slate" })
		b:box({ name = "Pared", size = { 1.5, 14, 8 }, pos = { -17.25, 7, 36 }, color = STORE, mat = "Slate" })
		b:box({ name = "Dintel", size = { 1.5, 5, 6 }, pos = { -17.25, 11.5, 29 }, color = STORE, mat = "Slate" })
		for _, z in ipairs({ 23, 36 }) do
			b:box({ name = "Zocalo", size = { 1.9, 3, z == 23 and 6 or 8 }, pos = { -17.25, 1.5, z }, color = BRICK, mat = "Brick" })
		end
		-- Escaparate y marcos
		b:box({ name = "Escaparate", size = { 13.4, 8, 0.4 }, pos = { -10.2, 6, 20.4 }, color = { 170, 200, 210 }, mat = "Glass", transparency = 0.45 })
		for _, x in ipairs({ -3.6, -10.2, -16.9 }) do
			b:box({ name = "Marco", size = { 1, 10, 1 }, pos = { x, 5, 20.6 }, color = TRIM, mat = "Metal" })
		end
		-- Interior
		for _, x in ipairs({ -12.5, -7 }) do
			b:box({ name = "Estanteria", size = { 1.6, 5, 9 }, pos = { x, 2.5, 29.5 }, color = { 210, 210, 214 }, mat = "Metal" })
			local colors = { { 220, 60, 60 }, { 60, 140, 220 }, { 250, 200, 60 }, { 90, 190, 110 } }
			for i = 0, 3 do
				b:box({ name = "Productos", size = { 1.9, 0.8, 8.2 }, pos = { x, 0.9 + i * 1.2, 29.5 }, color = colors[((i + (x < -10 and 1 or 0)) % 4) + 1], folder = "Decoracion" })
			end
		end
		local fridge = b:box({ name = "Nevera", size = { 9, 8, 1.6 }, pos = { -11, 4, 37.6 }, color = { 205, 225, 238 }, mat = "Glass", transparency = 0.2 })
		MB.light(fridge, "Surface", { face = "Front", brightness = 0.7, range = 10, color = { 200, 230, 255 } })
		P.acUnit(b, { -9, 15.2, 33 }, 0)
		P.vent(b, { -14, 15.2, 25 })

		-- Entrada: cajero, banco, periódicos, hielo y papelera
		P.atm(b, { -15.5, 0, 18.4 }, 0)
		P.bench(b, { -9.5, 0, 16.8 }, 0)
		P.newspaperBox(b, { -5.2, 0, 17.8 }, 0)
		local iceBox = b:box({ name = "Hielo", size = { 4.4, 3.6, 2.4 }, pos = { -21.5, 1.8, 18 }, color = { 240, 244, 248 } })
		MB.sign(iceBox, "HIELO", { color = { 40, 110, 200 }, font = "GothamBlack" })
		P.trashCan(b, { -26.2, 0, 18 })
		P.propaneCage(b, { -19.8, 0, 36.5 }, 90)
		P.dumpster(b, { -25, 0, 45 }, 0)
		P.pallet(b, { -32, 0, 46 }, 15)
		P.cardboard(b, { -32, 0.8, 46 }, { 3, 2.4, 2.6 }, 10)

		-- Pilares de la marquesina, luces, isla y surtidores
		for _, z in ipairs({ -14, 0 }) do
			b:box({ name = "Pilar", size = { 2, 15, 2 }, pos = { -18, 7.5, z }, color = BRICK, mat = "Brick" })
			b:box({ name = "Peana", size = { 3, 1, 3 }, pos = { -18, 0.5, z }, color = { 190, 186, 180 }, mat = "Concrete" })
		end
		b:cylinder({ name = "Extintor", length = 1.6, diameter = 0.7, pos = { -16.7, 2, 0 }, color = RED, mat = "Metal" })
		for _, z in ipairs({ -12, -2 }) do
			local panel = b:box({ name = "LuzMarquesina", size = { 8, 0.2, 3 }, pos = { -9, 15.9, z }, color = { 255, 246, 226 }, mat = "Neon", folder = "Decoracion" })
			if z == -12 then
				MB.light(panel, "Surface", { face = "Bottom", brightness = 1.4, range = 24, angle = 120 })
			end
		end
		b:box({ name = "Isla", size = { 3.4, 0.6, 14 }, pos = { -8, 0.3, -7 }, color = YELLOW, mat = "Concrete" })
		for i = 0, 6 do
			b:box({ name = "Raya", size = { 3.45, 0.62, 0.8 }, pos = { -8, 0.3, -13.4 + i * 2.1 }, color = { 30, 30, 32 }, folder = "Decoracion" })
		end
		P.pump(b, { -8, 0.6, -10.5 }, 0)
		P.pump(b, { -8, 0.6, -3.5 }, 0)
		for _, z in ipairs({ -14.6, 0.6 }) do
			b:cylinder({ name = "Bolardo", length = 3, diameter = 1, pos = { -8, 1.5, z }, color = YELLOW, mat = "Metal" })
		end
		P.stain(b, { -13, 0, -8 }, 5)
		P.stain(b, { -3.5, 0, -5 }, 3.6)

		-- Taller mecánico (se puede entrar por el portón)
		local SHOP = { 176, 112, 92 }
		b:box({ name = "Taller", size = { 18, 12, 1 }, pos = { -53, 6, 47.5 }, color = SHOP, mat = "Brick" })
		b:box({ name = "Taller", size = { 1, 12, 18 }, pos = { -61.5, 6, 39 }, color = SHOP, mat = "Brick" })
		b:box({ name = "Taller", size = { 1, 12, 18 }, pos = { -44.5, 6, 39 }, color = SHOP, mat = "Brick" })
		b:box({ name = "Taller", size = { 4, 12, 1 }, pos = { -60, 6, 30.5 }, color = SHOP, mat = "Brick" })
		b:box({ name = "Taller", size = { 4, 12, 1 }, pos = { -46, 6, 30.5 }, color = SHOP, mat = "Brick" })
		b:box({ name = "Dintel", size = { 10, 3, 1 }, pos = { -53, 10.5, 30.5 }, color = SHOP, mat = "Brick" })
		b:box({ name = "Porton", size = { 10, 2.6, 0.4 }, pos = { -53, 7.7, 30.6 }, color = { 150, 156, 164 }, mat = "DiamondPlate" })
		b:box({ name = "TechoTaller", size = { 19, 0.8, 19 }, pos = { -53, 12.4, 39 }, color = { 70, 70, 76 }, mat = "Concrete" })
		P.poster(b, { -53, 10.6, 29.95 }, 0, { 9, 2 }, { 30, 34, 40 }, "TALLER", YELLOW, "GothamBlack")
		P.car(b, { -53, 0, 40 }, 0, b.mirrored and { 60, 120, 90 } or { 220, 160, 40 })
		b:box({ name = "Banco", size = { 2.4, 3.6, 5 }, pos = { -59.6, 1.8, 43 }, color = { 190, 50, 46 }, mat = "Metal" })
		P.tires(b, { -46.6, 0, 45.4 }, 4)
		P.drum(b, { -59.4, 0, 34 }, { 60, 90, 160 })
		local shopLamp = b:box({ name = "Lampara", size = { 6, 0.2, 1 }, pos = { -53, 11.8, 39 }, color = { 255, 244, 220 }, mat = "Neon", folder = "Decoracion" })
		MB.light(shopLamp, "Point", { brightness = 1, range = 16 })

		-- Coches
		P.car(b, { -40, 0, 30 }, 0, b.mirrored and { 50, 100, 190 } or { 190, 50, 50 })
		P.car(b, { -29, 0, -44 }, 70, b.mirrored and { 220, 220, 220 } or { 90, 90, 96 })
		P.cone(b, { -21, 0, -40 })
		P.cone(b, { -22.5, 0, -47 })

		-- Barreras, jardineras y cajas
		P.barrier(b, { -50, 0, -22 }, 0)
		P.barrier(b, { -30, 0, -18 }, 20)
		P.barrier(b, { -50, 0, 14 }, 90)
		P.barrier(b, { -38, 0, 6 }, 90)
		P.planter(b, { -34, 0, -26 }, { 10, 3 }, 0)
		P.crate(b, { -32, 0, 21 }, 4)
		P.crate(b, { -60, 0, -37 }, 4.5, 25)
		P.puddle(b, { -44, 0, -10 }, 6)
		P.manhole(b, { -20, 0.1, -44 })

		-- Plazas de aparcamiento
		for _, x in ipairs({ -43, -37, -31 }) do
			b:box({ name = "Plaza", size = { 0.4, 0.12, 10 }, pos = { x, 0.07, 29 }, color = LINE, folder = "Decoracion" })
		end
		-- Paso de cebra
		for z = -52, -36, 2.4 do
			b:box({ name = "Cebra", size = { 6, 0.12, 1.2 }, pos = { -42, 0.08, z }, color = LINE, folder = "Decoracion" })
		end

		-- Farolas, postes eléctricos y valla lateral
		P.streetLight(b, { -50, 0.6, -29.4 }, 0, 18)
		P.streetLight(b, { -22, 0.6, -29.4 }, 0, 18)
		P.pole(b, { -66, 0, -30 }, 28)
		P.pole(b, { -66, 0, 50 }, 28)
		b:box({ name = "Cable", size = { 0.15, 0.15, 80 }, pos = { -66.6, 27.2, 10 }, color = { 30, 30, 30 }, folder = "Decoracion", shadow = false })
		P.chainFence(b, { -80.6, 0, -28 }, { -80.6, 0, 55 }, 7)

		-- Camión de reparto que tapa la visión de los spawns
		local cargo = P.truck(b, { -63, 0, 4 }, 0, b.mirrored and { 236, 236, 232 } or { 250, 214, 90 })
		for _, face in ipairs({ "Left", "Right" }) do
			MB.sign(cargo, "REPARTO 24H", { face = face, font = "GothamBlack", color = { 200, 40, 40 }, height = 0.4 })
		end

		for _, z in ipairs({ 0, 6, 12 }) do
			b:spawn("A", { -72, 0.5, z }, -90)
		end
	end)

	b:bounds(-80, 80, -56, 56, 45)

	b:lighting({
		technology = "Future",
		lighting = {
			ClockTime = 17.7,
			Brightness = 2.8,
			Ambient = { 112, 82, 82 },
			OutdoorAmbient = { 156, 108, 104 },
			ExposureCompensation = 0.15,
			ShadowSoftness = 0.25,
			EnvironmentDiffuseScale = 0.6,
			EnvironmentSpecularScale = 0.5,
		},
		atmosphere = { density = 0.32, offset = 0.1, color = { 255, 162, 142 }, decay = { 152, 82, 92 }, glare = 1.4, haze = 2.2 },
		colorCorrection = { contrast = 0.08, saturation = 0.18, tint = { 255, 236, 228 } },
		clouds = { cover = 0.72, density = 0.6, color = { 255, 132, 122 } },
		bloom = { intensity = 0.45, size = 28, threshold = 0.9 },
		sunRays = { intensity = 0.12, spread = 0.7 },
	})
end
]=]
FUENTES_MAPAS["Japon"] = [=[
-- Japón: calle de Kioto al anochecer con torii, santuario y cerezos. Equipo A en -X, equipo B en +X.
return function(b, MB)
	local P = MB.Props
	local STONE = { 128, 124, 118 }
	local PATH = { 178, 170, 154 }
	local WOOD = { 92, 58, 40 }
	local DARK = { 40, 36, 34 }
	local RED = { 196, 48, 38 }
	local PLASTER = { 236, 226, 206 }
	local TILE = { 58, 60, 68 }
	local SAKURA = {
		{ { 255, 183, 197 }, { 246, 160, 184 }, { 255, 208, 218 } },
		{ { 250, 170, 190 }, { 255, 196, 208 }, { 236, 150, 176 } },
	}
	local MACHIYA = {
		{ w = 14, h = 13, color = WOOD, mat = "WoodPlanks", trim = DARK, roof = "gable", roofColor = TILE, roofMat = "Slate", lit = true, shop = "ラーメン RAMEN", shopColor = { 176, 40, 34 } },
		{ w = 12, h = 12, color = PLASTER, trim = WOOD, roof = "gable", roofColor = TILE, roofMat = "Slate", lit = true, shutters = DARK },
		{ w = 14, h = 14, color = { 112, 72, 48 }, mat = "WoodPlanks", trim = DARK, roof = "gable", roofColor = TILE, roofMat = "Slate", lit = true, shop = "寿司 SUSHI", shopColor = { 36, 66, 128 } },
		{ w = 12, h = 12, color = { 226, 212, 186 }, trim = WOOD, roof = "gable", roofColor = TILE, roofMat = "Slate", lit = true, shop = "お茶 TEA", shopColor = { 66, 108, 58 } },
	}

	b.model:SetAttribute("Nombre", "Japón")

	-- Cuerda con farolillos de papel entre dos puntos
	local function lanternLine(a, c, count, sag)
		local prev
		for i = 0, count do
			local t = i / count
			local p = { a[1] + (c[1] - a[1]) * t, a[2] + (c[2] - a[2]) * t - sag * 4 * t * (1 - t), a[3] + (c[3] - a[3]) * t }
			if prev then
				P.segment(b, prev, p, 0.1, { 30, 28, 26 }, "Plastic", "Decoracion")
			end
			if i > 0 and i < count then
				P.lantern(b, { p[1], p[2] - 1.1, p[3] }, (i % 2 == 0) and { 236, 70, 44 } or { 250, 220, 160 }, i % 4 == 2)
			end
			prev = p
		end
	end

	-- =================================================================
	--  Paisaje: césped, monte Fuji y colinas
	-- =================================================================
	b:box({ name = "Cesped", size = { 900, 1, 900 }, pos = { 0, -1.2, 0 }, color = { 86, 112, 70 }, mat = "Grass", folder = "Decoracion" })
	for i = 0, 11 do
		b:cylinder({ name = "Fuji", length = 20, diameter = 640 - i * 50, pos = { 0, 8 + i * 20, 560 }, color = (i >= 9) and { 244, 246, 252 } or { 88, 100, 128 }, mat = (i >= 9) and "Snow" or "Rock", folder = "Decoracion" })
	end
	for _, h in ipairs({ { -170, 0, 150 }, { 170, 0, 150 }, { -150, -150, 160 }, { 150, -150, 160 }, { 0, -190, 170 } }) do
		b:ball({ name = "Colina", diameter = h[3], pos = { h[1], -h[3] * 0.3, h[2] }, color = { 70, 104, 66 }, mat = "Grass", folder = "Decoracion" })
	end

	-- =================================================================
	--  Calle empedrada, torii y santuario
	-- =================================================================
	b:box({ name = "Suelo", size = { 164, 1, 108 }, pos = { 0, -0.5, 0 }, color = STONE, mat = "Slate" })
	b:box({ name = "Camino", size = { 164, 0.1, 16 }, pos = { 0, 0.05, 0 }, color = PATH, mat = "Pavement", folder = "Decoracion" })
	P.torii(b, { 0, 0, 0 }, 0, 14, 16)

	b:box({ name = "Plataforma", size = { 34, 2, 20 }, pos = { 0, 1, 42 }, color = { 150, 146, 138 }, mat = "Slate" })
	P.stairs(b, { 0, 0, 30 }, 0, 2, 1, 1, 12, { 150, 146, 138 }, { 110, 106, 100 })
	P.house(b, { 0, 2, 45 }, 0, { w = 26, h = 10, d = 14, color = PLASTER, trim = WOOD, roof = "pagoda", roofColor = TILE, roofMat = "Slate", roofHeight = 5, cols = 5, floors = 1, doorColor = RED, lit = true })
	b:box({ name = "Cumbrera", size = { 30, 1, 1 }, pos = { 0, 17.4, 45 }, color = DARK, folder = "Decoracion" })
	b:box({ name = "Ofrendas", size = { 6, 2.4, 3 }, pos = { 0, 3.2, 35.6 }, color = WOOD, mat = "WoodPlanks" })
	b:cylinder({ name = "Shimenawa", axis = "x", length = 16, diameter = 0.9, pos = { 0, 11.2, 37.4 }, color = { 214, 190, 130 }, mat = "Fabric", folder = "Decoracion" })
	local banner = b:box({ name = "Placa", size = { 8, 2, 0.3 }, pos = { 0, 9.6, 37.6 }, color = DARK, folder = "Decoracion" })
	MB.sign(banner, "稲荷神社", { face = "Front", color = { 240, 200, 90 } })

	b:symmetric(function(b)
		-- Casas tradicionales (machiya) a los dos lados de la calle
		P.houseRow(b, 57, 0, -84, -18, MACHIYA, 10)
		P.houseRow(b, -57, 180, -84, 0, MACHIYA, 10)
		for x = -74, -6, 8 do
			P.lantern(b, { x, 10.6, -50.6 }, { 230, 60, 40 }, (x + 74) % 24 == 0)
		end
		lanternLine({ -40, 15, 51.5 }, { -40, 15, -51.5 }, 12, 3)

		-- Farolillos de piedra y cerezos junto al torii
		P.stoneLantern(b, { -10, 0, 12 })
		P.stoneLantern(b, { -10, 0, -12 })
		P.stoneLantern(b, { -12, 2, 40 })
		for i, t in ipairs({ { -28, 28, 1.3 }, { -56, -34, 1.4 }, { -22, -38, 1.2 }, { -66, 34, 1.3 } }) do
			P.tree(b, { t[1], 0, t[2] }, t[3], SAKURA[(i % 2) + 1])
		end
		for i = 1, 14 do
			b:box({ name = "Petalos", size = { 0.6, 0.06, 0.5 }, pos = { -8 - (i * 37) % 64, 0.13, -40 + (i * 23) % 78 }, rot = { 0, i * 33, 0 }, color = { 255, 196, 210 }, folder = "Decoracion", shadow = false })
		end

		-- Puesto de ramen (yatai) y cajas
		P.marketStall(b, { -28, 0, -20 }, 180, { 176, 40, 34 }, "ラーメン", { { 250, 236, 200 }, { 230, 180, 90 }, { 120, 170, 90 } })
		P.lantern(b, { -32, 7.2, -22.6 }, { 236, 70, 44 }, true)
		P.crate(b, { -15, 0, 17 }, 5, 10, { 170, 128, 84 })
		P.crate(b, { -18, 0, 23 }, 4, -8, { 170, 128, 84 })
		P.crate(b, { -15, 5, 17 }, 3.4, 30, { 170, 128, 84 })

		-- Furgoneta kei aparcada
		P.car(b, { -44, 0, 18 }, 90, { 236, 236, 228 })

		-- Barriles de sake apilados
		for _, p in ipairs({ { -58, 1.6, -28 }, { -54.6, 1.6, -28 }, { -56.3, 4.6, -28 } }) do
			b:cylinder({ name = "Sake", axis = "z", length = 3.6, diameter = 3.2, pos = p, color = { 236, 228, 210 }, mat = "WoodPlanks" })
			b:cylinder({ name = "Etiqueta", axis = "z", length = 3.7, diameter = 2, pos = p, color = { 196, 48, 38 }, folder = "Decoracion" })
		end

		-- Muretes de jardín con tejas
		for _, w in ipairs({ { -46, -14, 12 }, { -30, 10, 10 } }) do
			b:box({ name = "Murete", size = { w[3], 4, 1.6 }, pos = { w[1], 2, w[2] }, color = PLASTER, mat = "Plaster" })
			b:box({ name = "Teja", size = { w[3] + 0.8, 0.6, 2.4 }, pos = { w[1], 4.3, w[2] }, color = TILE, mat = "Slate" })
			b:box({ name = "Zocalo", size = { w[3] + 0.1, 1, 1.8 }, pos = { w[1], 0.5, w[2] }, color = { 110, 106, 100 }, mat = "Slate", folder = "Decoracion" })
		end

		-- Máquinas expendedoras
		P.vending(b, { -66, 0, -49.6 }, 180, { 40, 110, 200 }, "お茶 TEA")
		P.vending(b, { -61.6, 0, -49.6 }, 180, { 214, 56, 56 }, "COLA")

		-- Bambú
		for i = 0, 7 do
			local h = 16 + (i % 3) * 3
			b:cylinder({ name = "Bambu", length = h, diameter = 0.7, pos = { -52 - (i % 4) * 1.6, h / 2, 38 + math.floor(i / 4) * 1.8 + (i % 2) * 0.6 }, color = { 122, 164, 76 }, mat = "Wood" })
			b:ball({ name = "Hojas", diameter = 3.4, pos = { -52 - (i % 4) * 1.6, h, 38 + math.floor(i / 4) * 1.8 }, color = { 92, 140, 64 }, mat = "LeafyGrass", folder = "Decoracion" })
		end

		-- Muro de yeso con tejado que protege el spawn
		b:box({ name = "Muro", size = { 2, 10, 34 }, pos = { -60, 5, 0 }, color = PLASTER, mat = "Plaster" })
		b:box({ name = "Zocalo", size = { 2.4, 2.4, 34.4 }, pos = { -60, 1.2, 0 }, color = { 96, 92, 88 }, mat = "Slate" })
		b:wedge({ name = "Tejado", size = { 35, 1.8, 2.6 }, pos = { -61.3, 10.9, 0 }, rot = { 0, 90, 0 }, color = TILE, mat = "Slate" })
		b:wedge({ name = "Tejado", size = { 35, 1.8, 2.6 }, pos = { -58.7, 10.9, 0 }, rot = { 0, -90, 0 }, color = TILE, mat = "Slate" })
		P.poster(b, { -58.9, 7, 0 }, -90, { 10, 2.6 }, RED, "祭り MATSURI", { 255, 240, 220 }, "GothamBlack")
		for _, z in ipairs({ -12, 12 }) do
			P.lantern(b, { -58.4, 8.4, z }, { 236, 70, 44 }, true)
		end
		for _, z in ipairs({ -8, 0, 8 }) do
			b:spawn("A", { -70, 0.5, z }, -90)
		end
	end)

	b:bounds(-80, 80, -52, 52, 40)

	b:lighting({
		technology = "Future",
		lighting = {
			ClockTime = 18.3,
			Brightness = 2.2,
			Ambient = { 96, 80, 104 },
			OutdoorAmbient = { 134, 112, 142 },
			ExposureCompensation = 0.2,
			ShadowSoftness = 0.3,
			EnvironmentDiffuseScale = 0.5,
			EnvironmentSpecularScale = 0.5,
		},
		atmosphere = { density = 0.28, offset = 0.15, color = { 236, 172, 190 }, decay = { 122, 92, 150 }, glare = 1, haze = 1.8 },
		colorCorrection = { contrast = 0.1, saturation = 0.15, tint = { 255, 240, 246 } },
		clouds = { cover = 0.55, density = 0.5, color = { 255, 186, 200 } },
		bloom = { intensity = 0.55, size = 26, threshold = 0.85 },
		sunRays = { intensity = 0.1, spread = 0.6 },
	})
end
]=]
FUENTES_MAPAS["Mexico"] = [=[
-- México: plaza de pueblo con quiosco, iglesia, casas de colores y papel picado. Equipo A en -X, equipo B en +X.
return function(b, MB)
	local P = MB.Props
	local PLAZA = { 182, 156, 128 }
	local ADOBE = { 210, 150, 104 }
	local IGLESIA = { 236, 214, 172 }
	local PICADO = { { 236, 64, 122 }, { 255, 196, 40 }, { 56, 190, 180 }, { 140, 80, 200 }, { 250, 120, 40 }, { 90, 190, 90 } }
	local CASAS = {
		{ w = 12, h = 11, color = { 236, 116, 160 }, trim = { 255, 236, 200 }, shop = "TACOS EL GÜERO", shopColor = { 200, 40, 60 }, shopFont = "LuckiestGuy" },
		{ w = 14, h = 13, color = { 250, 200, 70 }, trim = { 200, 80, 60 }, shutters = { 40, 120, 160 }, balcony = true, flowers = { 230, 60, 90 } },
		{ w = 12, h = 10, color = { 64, 186, 178 }, trim = { 255, 244, 220 }, shop = "PANADERÍA", shopColor = { 210, 120, 40 }, shopFont = "LuckiestGuy" },
		{ w = 13, h = 13, color = { 240, 132, 62 }, trim = { 255, 236, 200 }, shutters = { 30, 90, 150 }, balcony = true, flowers = { 250, 220, 80 } },
		{ w = 12, h = 11, color = { 128, 100, 204 }, trim = { 255, 236, 200 }, shop = "ABARROTES", shopColor = { 40, 140, 70 }, shopFont = "LuckiestGuy" },
	}

	b.model:SetAttribute("Nombre", "México")

	-- =================================================================
	--  Paisaje: desierto y mesetas rojizas
	-- =================================================================
	b:box({ name = "Desierto", size = { 900, 1, 900 }, pos = { 0, -1.2, 0 }, color = { 212, 178, 128 }, mat = "Sand", folder = "Decoracion" })
	for _, m in ipairs({ { -210, 230, 120, 34 }, { 160, 260, 160, 40 }, { 300, 110, 100, 28 }, { -320, 60, 110, 36 }, { 40, -260, 140, 30 }, { -230, -220, 100, 26 } }) do
		b:box({ name = "Meseta", size = { m[3], m[4], m[3] * 0.7 }, pos = { m[1], m[4] / 2 - 1, m[2] }, color = { 196, 104, 70 }, mat = "Sandstone", folder = "Decoracion" })
		b:box({ name = "Meseta", size = { m[3] * 0.7, 6, m[3] * 0.5 }, pos = { m[1], m[4] + 2, m[2] }, color = { 176, 98, 66 }, mat = "Sandstone", folder = "Decoracion" })
	end

	-- =================================================================
	--  Plaza, quiosco e iglesia
	-- =================================================================
	b:box({ name = "Suelo", size = { 164, 1, 108 }, pos = { 0, -0.5, 0 }, color = PLAZA, mat = "Cobblestone" })
	b:cylinder({ name = "Glorieta", length = 0.1, diameter = 34, pos = { 0, 0.05, 0 }, color = { 206, 180, 146 }, mat = "Pavement", folder = "Decoracion" })
	P.kiosk(b, { 0, 0, 0 }, 9, { 46, 120, 84 }, { 200, 56, 46 })

	b:box({ name = "Iglesia", size = { 30, 20, 18 }, pos = { 0, 10, 61 }, color = IGLESIA, mat = "Plaster" })
	b:box({ name = "Zocalo", size = { 30.2, 1.6, 18.2 }, pos = { 0, 0.8, 61 }, color = { 176, 140, 104 }, mat = "Sandstone" })
	b:box({ name = "Portada", size = { 12, 16, 1 }, pos = { 0, 8, 51.6 }, color = { 214, 186, 140 }, mat = "Sandstone" })
	b:box({ name = "Puerta", size = { 5, 8, 0.4 }, pos = { 0, 4, 51 }, color = { 110, 66, 40 }, mat = "WoodPlanks", folder = "Decoracion" })
	b:cylinder({ name = "Arco", axis = "z", length = 0.4, diameter = 5, pos = { 0, 8, 51 }, color = { 110, 66, 40 }, mat = "WoodPlanks", folder = "Decoracion" })
	b:cylinder({ name = "Roseton", axis = "z", length = 0.4, diameter = 3.6, pos = { 0, 13.4, 51 }, color = { 80, 150, 210 }, mat = "Glass", folder = "Decoracion" })
	b:box({ name = "Espadana", size = { 12, 6, 1.6 }, pos = { 0, 23, 52.6 }, color = IGLESIA, mat = "Plaster" })
	b:box({ name = "Hueco", size = { 3, 3.4, 1.7 }, pos = { 0, 23, 52.6 }, color = { 40, 30, 26 }, folder = "Decoracion" })
	b:ball({ name = "Campana", diameter = 2, pos = { 0, 22.8, 52.6 }, color = { 190, 150, 60 }, mat = "Metal", folder = "Decoracion" })
	b:box({ name = "Cruz", size = { 0.5, 3, 0.5 }, pos = { 0, 27.5, 52.6 }, color = { 80, 70, 60 }, mat = "Metal", folder = "Decoracion" })
	b:box({ name = "Cruz", size = { 1.8, 0.5, 0.5 }, pos = { 0, 28.2, 52.6 }, color = { 80, 70, 60 }, mat = "Metal", folder = "Decoracion" })
	local cartel = b:box({ name = "Cartel", size = { 10, 1.4, 0.3 }, pos = { 0, 17.2, 51 }, color = IGLESIA, folder = "Decoracion" })
	MB.sign(cartel, "PARROQUIA SAN JUAN", { font = "Garamond", color = { 120, 80, 50 } })

	b:symmetric(function(b)
		-- Casas de colores y campanarios
		P.houseRow(b, 57, 0, -84, -23, CASAS, 10)
		P.houseRow(b, -57, 180, -84, 0, CASAS, 10)
		P.bellTower(b, { -19, 0, 60 }, 0, 30, IGLESIA, { 200, 90, 56 })

		-- Papel picado desde el quiosco y cruzando la plaza
		P.bunting(b, { -5, 12.6, 3 }, { -46, 12, 51.6 }, 18, 1.4, PICADO)
		P.bunting(b, { -5, 12.6, -3 }, { -46, 12, -51.6 }, 18, 1.4, PICADO)
		P.bunting(b, { -28, 12, 51.6 }, { -28, 12, -51.6 }, 26, 2, PICADO)

		-- Piñata colgada
		P.segment(b, { -28, 10, 0 }, { -28, 9.6, 0 }, 0.08, { 40, 40, 40 }, "Plastic", "Decoracion")
		b:ball({ name = "Pinata", diameter = 2.4, pos = { -28, 8.4, 0 }, color = { 240, 80, 150 }, mat = "Fabric", folder = "Decoracion" })
		for i, d in ipairs({ { 1.7, 0, 0 }, { -1.7, 0, 0 }, { 0, 1.7, 0 }, { 0, -1.7, 0 }, { 0, 0, 1.7 }, { 0, 0, -1.7 } }) do
			P.rod(b, { -28, 8.4, 0 }, { -28 + d[1], 8.4 + d[2], d[3] }, 0.7, PICADO[i], "Fabric", "Decoracion")
		end

		-- Puestos del mercado
		P.marketStall(b, { -30, 0, -22 }, 180, { 220, 50, 90 }, "TACOS", { { 240, 200, 120 }, { 120, 170, 70 }, { 200, 60, 40 } })
		P.marketStall(b, { -36, 0, 26 }, 0, { 40, 150, 170 }, "ELOTES", { { 250, 210, 80 }, { 240, 190, 60 }, { 120, 170, 70 } })

		-- Vocho aparcado
		P.car(b, { -46, 0, 4 }, 90, { 70, 170, 200 })

		-- Muretes de adobe
		P.wall(b, { -16, 0, -15 }, 0, { 10, 4, 1.6 }, ADOBE, { 150, 100, 70 }, { 196, 90, 60 }, "Plaster")
		P.wall(b, { -18, 0, 16 }, 0, { 10, 4, 1.6 }, ADOBE, { 150, 100, 70 }, { 196, 90, 60 }, "Plaster")

		-- Barriles, nopales, macetas y árboles
		for _, p in ipairs({ { -52, -32 }, { -49.4, -33.4 }, { -51, -35.6 } }) do
			P.drum(b, { p[1], 0, p[2] }, { 150, 96, 56 })
		end
		P.cactus(b, { -60, 0, -44 }, 1.1)
		P.cactus(b, { -22, 0, 42 }, 0.9)
		P.cactus(b, { -68, 0, 36 }, 1.2)
		P.pottedPlant(b, { -40, 0, -42 }, 1.3)
		P.pottedPlant(b, { -12, 0, 30 }, 1.3)
		P.palmTree(b, { -40, 0, 44 }, 1)
		P.tree(b, { -58, 0, 22 }, 1.2, { { 150, 110, 210 }, { 170, 130, 225 }, { 130, 96, 190 } })
		P.bench(b, { -14, 0, -8 }, 0, { 46, 120, 84 })
		P.bench(b, { -14, 0, 8 }, 180, { 46, 120, 84 })

		-- Muro de adobe que protege el spawn
		P.wall(b, { -60, 0, 0 }, 90, { 34, 10, 2 }, { 200, 118, 80 }, { 150, 86, 60 }, IGLESIA, "Plaster")
		P.poster(b, { -58.9, 7, 0 }, -90, { 12, 2.6 }, IGLESIA, "¡BIENVENIDOS!", { 200, 50, 70 }, "LuckiestGuy")
		P.bunting(b, { -58.8, 9.6, -16 }, { -58.8, 9.6, 16 }, 14, 1.2, PICADO)
		for _, z in ipairs({ -8, 0, 8 }) do
			b:spawn("A", { -70, 0.5, z }, -90)
		end
	end)

	b:bounds(-80, 80, -52, 52, 40)

	b:lighting({
		technology = "Future",
		lighting = {
			ClockTime = 15.6,
			Brightness = 3.2,
			Ambient = { 124, 104, 92 },
			OutdoorAmbient = { 168, 140, 118 },
			ExposureCompensation = 0.05,
			ShadowSoftness = 0.15,
			EnvironmentDiffuseScale = 0.6,
			EnvironmentSpecularScale = 0.5,
		},
		atmosphere = { density = 0.26, offset = 0.05, color = { 240, 210, 170 }, decay = { 170, 120, 90 }, glare = 0.6, haze = 1.4 },
		colorCorrection = { contrast = 0.08, saturation = 0.25, tint = { 255, 246, 232 } },
		clouds = { cover = 0.35, density = 0.4, color = { 255, 250, 240 } },
		bloom = { intensity = 0.35, size = 24, threshold = 0.95 },
		sunRays = { intensity = 0.1, spread = 0.6 },
	})
end
]=]
FUENTES_MAPAS["Muelle"] = [=[
-- Muelle (estilo GTA V): muelle de madera sobre el mar al atardecer, con noria, tiovivo, puestos
-- y la ciudad al fondo. Equipo A en -X, equipo B en +X.
return function(b, MB)
	local P = MB.Props
	local DECK = 8
	local WOOD = { 150, 116, 84 }
	local WHITE = { 244, 242, 236 }
	local PALMS = { { 260, 1.2 }, { 300, 1.4 } }

	b.model:SetAttribute("Nombre", "Muelle")

	-- =================================================================
	--  Mar, playa, ciudad y colina con letrero
	-- =================================================================
	b:box({ name = "Mar", size = { 1600, 2, 1600 }, pos = { 0, 0, 0 }, color = { 40, 112, 150 }, mat = "Glass", reflectance = 0.25, folder = "Decoracion" })
	b:box({ name = "Playa", size = { 1600, 4, 300 }, pos = { 0, 0, 230 }, color = { 232, 212, 160 }, mat = "Sand", folder = "Decoracion" })
	for i = 0, 15 do
		local x = -300 + i * 40
		P.palmTree(b, { x, 2, 120 + (i % 2) * 18 }, PALMS[(i % 2) + 1][2])
	end
	for i = 0, 19 do
		local x = -380 + i * 40
		local h = 50 + (i * 53) % 120
		local w = 26 + (i % 3) * 8
		b:box({ name = "Edificio", size = { w, h, w }, pos = { x, 2 + h / 2, 300 + (i % 3) * 30 }, color = (i % 2 == 0) and { 220, 210, 196 } or { 120, 150, 176 }, mat = (i % 2 == 0) and "Concrete" or "Glass", folder = "Decoracion" })
	end
	b:ball({ name = "Colina", diameter = 360, pos = { -120, -40, 560 }, color = { 140, 140, 90 }, mat = "Grass", folder = "Decoracion" })
	b:ball({ name = "Colina", diameter = 320, pos = { 180, -50, 580 }, color = { 130, 132, 86 }, mat = "Grass", folder = "Decoracion" })
	for i, letter in ipairs({ "P", "L", "A", "Y", "A", " ", "D", "E", "L", " ", "S", "O", "L" }) do
		if letter ~= " " then
			local panel = b:box({ name = "Letra", size = { 9, 14, 1 }, pos = { -190 + i * 11, 118, 420 }, rot = { -12, 0, 0 }, color = WHITE, folder = "Decoracion" })
			MB.sign(panel, letter, { font = "GothamBlack", color = { 40, 40, 40 }, bg = WHITE })
		end
	end

	-- =================================================================
	--  Tablero del muelle, pilotes, barandillas y zona de feria
	-- =================================================================
	b:box({ name = "Tablero", size = { 152, 1, 62 }, pos = { 0, DECK - 0.5, 0 }, color = WOOD, mat = "WoodPlanks" })
	b:box({ name = "Feria", size = { 84, 1, 34 }, pos = { 0, DECK - 0.5, 47 }, color = WOOD, mat = "WoodPlanks", folder = "Decoracion" })
	b:box({ name = "Pasarela", size = { 24, 1, 120 }, pos = { 0, DECK - 0.5, 120 }, color = WOOD, mat = "WoodPlanks", folder = "Decoracion" })
	P.ferrisWheel(b, { 0, DECK, 38 }, 0, 24, { 255, 90, 170 })
	local arch = b:box({ name = "Arco", size = { 26, 4, 1 }, pos = { 0, DECK + 14, 62 }, color = { 30, 30, 40 }, folder = "Decoracion" })
	MB.sign(arch, "MUELLE DEL SOL", { font = "LuckiestGuy", color = { 255, 120, 200 }, glow = true })
	for _, x in ipairs({ -12, 12 }) do
		b:box({ name = "Poste", size = { 1, 14, 1 }, pos = { x, DECK + 7, 62 }, color = { 30, 30, 40 }, folder = "Decoracion" })
	end

	-- Tiovivo en el centro
	b:cylinder({ name = "Plataforma", length = 1.2, diameter = 18, pos = { 0, DECK + 0.6, 0 }, color = { 240, 232, 220 }, mat = "WoodPlanks" })
	b:cylinder({ name = "Columna", length = 10, diameter = 3, pos = { 0, DECK + 6, 0 }, color = { 230, 190, 80 }, mat = "Metal" })
	for i, d in ipairs({ 21, 17, 12, 7, 2.6 }) do
		b:cylinder({ name = "Toldo", length = 1, diameter = d, pos = { 0, DECK + 10.6 + i, 0 }, color = (i % 2 == 1) and { 220, 50, 60 } or WHITE, mat = "Fabric" })
	end
	local crown = b:ball({ name = "Remate", diameter = 1.6, pos = { 0, DECK + 16.6, 0 }, color = { 250, 210, 80 }, mat = "Neon", folder = "Decoracion" })
	MB.light(crown, "Point", { color = { 255, 210, 140 }, brightness = 1.4, range = 24 })
	for i = 0, 7 do
		local a = math.rad(i * 45 + 22.5)
		local x, z = math.cos(a) * 6.5, math.sin(a) * 6.5
		b:cylinder({ name = "Barra", length = 10, diameter = 0.35, pos = { x, DECK + 6.2, z }, color = { 230, 190, 80 }, mat = "Metal", folder = "Decoracion" })
		b:box({ name = "Caballo", size = { 1.2, 2.2, 3.6 }, pos = { x, DECK + 3.4, z }, rot = { 0, -i * 45 - 22.5, 0 }, color = ({ { 250, 250, 246 }, { 120, 80, 50 }, { 60, 60, 66 }, { 220, 170, 90 } })[(i % 4) + 1] })
	end

	b:symmetric(function(b)
		-- Pilotes y barandillas
		for x = -72, -6, 11 do
			for _, z in ipairs({ -30, 30 }) do
				b:cylinder({ name = "Pilote", length = 10, diameter = 1.6, pos = { x, 2.5, z }, color = { 96, 76, 58 }, mat = "Wood", folder = "Decoracion" })
			end
		end
		P.railing(b, { -76, DECK, -30.4 }, { 0, DECK, -30.4 }, 3.5, WHITE)
		P.railing(b, { -76, DECK, 30.4 }, { -42, DECK, 30.4 }, 3.5, WHITE)
		for x = -60, -10, 25 do
			b:cylinder({ name = "Salvavidas", axis = "z", length = 0.5, diameter = 2.4, pos = { x, DECK + 2.2, -30.8 }, color = { 240, 100, 40 }, folder = "Decoracion" })
		end

		-- Bar del muelle que protege el spawn
		P.house(b, { -60, DECK, 0 }, -90, { w = 30, h = 12, d = 10, color = { 60, 140, 160 }, trim = WHITE, floors = 1, cols = 4, shop = "BAR DEL MUELLE", shopColor = { 230, 70, 120 }, lit = true })
		P.neonSign(b, { -54.6, DECK + 15, 0 }, -90, { 14, 3 }, "COCTELES", { 120, 255, 230 }, "LuckiestGuy")

		-- Puestos, carrito, mesas y bancos mirando al mar
		P.marketStall(b, { -36, DECK, -20 }, 180, { 230, 70, 120 }, "HOT DOGS", { { 200, 120, 60 }, { 240, 200, 80 }, { 200, 60, 50 } })
		P.marketStall(b, { -22, DECK, 20 }, 0, { 60, 150, 220 }, "HELADOS", { { 250, 200, 220 }, { 240, 240, 230 }, { 140, 90, 60 } })
		P.hotdogCart(b, { -44, DECK, 14 }, 90)
		P.umbrellaTable(b, { -30, DECK, -6 }, { 230, 70, 120 })
		P.umbrellaTable(b, { -46, DECK, -10 }, { 60, 150, 220 })
		for _, x in ipairs({ -66, -24 }) do
			P.bench(b, { x, DECK, -27 }, 180, { 120, 90, 60 })
		end
		local truck = P.truck(b, { -18, DECK, -14 }, 90, { 250, 200, 70 })
		for _, face in ipairs({ "Left", "Right" }) do
			MB.sign(truck, "TACOS · FOOD TRUCK", { face = face, font = "LuckiestGuy", color = { 200, 50, 60 }, height = 0.35 })
		end
		P.crate(b, { -50, DECK, 22 }, 4.5, 10)
		P.crate(b, { -54, DECK, 25 }, 3.5, -15)
		P.mannequin(b, { -40, DECK, -28.6 }, 180, { 80, 120, 200 })
		P.segment(b, { -40, DECK + 4.6, -29 }, { -40, DECK + 8, -36 }, 0.15, { 60, 50, 40 }, "Wood", "Decoracion")

		-- Farolas
		for _, x in ipairs({ -64, -34, -8 }) do
			P.streetLight(b, { x, DECK, 28.6 }, 0, 14)
		end
		P.streetLight(b, { -50, DECK, -28.6 }, 180, 14)

		for _, z in ipairs({ -8, 0, 8 }) do
			b:spawn("A", { -70, DECK + 0.5, z }, -90)
		end
	end)

	b:bounds(-76, 76, -30, 30, 60)

	b:lighting({
		technology = "Future",
		lighting = {
			ClockTime = 17.9,
			Brightness = 2.4,
			Ambient = { 120, 92, 96 },
			OutdoorAmbient = { 160, 120, 120 },
			ExposureCompensation = 0.15,
			ShadowSoftness = 0.25,
			EnvironmentDiffuseScale = 0.6,
			EnvironmentSpecularScale = 0.7,
		},
		atmosphere = { density = 0.3, offset = 0.1, color = { 255, 176, 140 }, decay = { 170, 96, 110 }, glare = 1.6, haze = 2 },
		colorCorrection = { contrast = 0.1, saturation = 0.22, tint = { 255, 236, 226 } },
		clouds = { cover = 0.5, density = 0.5, color = { 255, 150, 130 } },
		bloom = { intensity = 0.55, size = 28, threshold = 0.86 },
		sunRays = { intensity = 0.14, spread = 0.7 },
	})
end
]=]
FUENTES_MAPAS["NuevaYork"] = [=[
-- Nueva York: avenida al anochecer con edificios de ladrillo, taxis amarillos y metro. Equipo A en -X, equipo B en +X.
return function(b, MB)
	local P = MB.Props
	local ROAD = { 62, 62, 66 }
	local LINE = { 236, 232, 220 }
	local YELLOW = { 246, 196, 40 }
	local CREAM = { 230, 224, 210 }
	local LADRILLO = { { 150, 70, 56 }, { 122, 64, 52 }, { 176, 112, 82 }, { 104, 96, 92 }, { 160, 86, 64 } }
	-- x, ancho, alto, color, tienda norte, tienda sur
	local EDIFICIOS = {
		{ -76, 16, 34, 1, { "PIZZA", { 200, 40, 40 } }, { "LAUNDRY", { 60, 120, 200 } } },
		{ -61, 14, 40, 2, nil, { "NAILS", { 220, 80, 150 } } },
		{ -45, 18, 30, 3, { "DELI 24H", { 40, 120, 70 } }, nil },
		{ -29, 14, 38, 4, nil, { "COFFEE", { 120, 76, 46 } } },
		{ -11, 22, 32, 5, { "BODEGA", { 230, 160, 30 } }, { "BAGELS", { 200, 60, 40 } } },
	}

	b.model:SetAttribute("Nombre", "Nueva York")

	-- =================================================================
	--  Fondo: rascacielos y Empire State
	-- =================================================================
	b:box({ name = "Ciudad", size = { 1000, 1, 1000 }, pos = { 0, -1.2, 0 }, color = { 70, 72, 78 }, mat = "Concrete", folder = "Decoracion" })
	for i = 0, 13 do
		for _, side in ipairs({ 1, -1 }) do
			local w = 24 + (i % 4) * 5
			local h = 70 + (i * 37 + (side > 0 and 0 or 19)) % 80
			local x = -200 + i * 31
			local z = side * (100 + ((i + (side > 0 and 0 or 1)) % 3) * 22)
			local glass = (i % 3 == 0)
			b:box({ name = "Rascacielos", size = { w, h, w }, pos = { x, h / 2, z }, color = glass and { 96, 116, 146 } or { 120, 116, 112 }, mat = glass and "Glass" or "Concrete", reflectance = glass and 0.15 or nil, folder = "Decoracion" })
			b:box({ name = "Remate", size = { w * 0.7, 6, w * 0.7 }, pos = { x, h + 3, z }, color = { 90, 92, 100 }, mat = "Concrete", folder = "Decoracion" })
			for k = 1, 3 do
				b:box({ name = "Planta", size = { w + 0.2, 1.2, w + 0.2 }, pos = { x, h * k / 4, z }, color = { 64, 72, 92 }, folder = "Decoracion", shadow = false })
			end
		end
	end
	local EMPIRE = { 176, 172, 160 }
	for _, s in ipairs({ { 50, 140, 70 }, { 36, 40, 160 }, { 26, 30, 195 }, { 16, 20, 220 } }) do
		b:box({ name = "EmpireState", size = { s[1], s[2], s[1] }, pos = { 40, s[3], 260 }, color = EMPIRE, mat = "Limestone", folder = "Decoracion" })
	end
	b:cylinder({ name = "Aguja", length = 34, diameter = 3, pos = { 40, 247, 260 }, color = { 200, 200, 210 }, mat = "Metal", folder = "Decoracion" })
	local beacon = b:ball({ name = "Baliza", diameter = 3, pos = { 40, 265, 260 }, color = { 255, 80, 80 }, mat = "Neon", folder = "Decoracion" })
	MB.light(beacon, "Point", { color = { 255, 80, 80 }, brightness = 3, range = 30 })

	-- =================================================================
	--  Avenida, aceras y obras en el centro
	-- =================================================================
	b:box({ name = "Asfalto", size = { 164, 1, 84 }, pos = { 0, -0.5, 0 }, color = ROAD, mat = "Asphalt" })
	for _, z in ipairs({ -0.4, 0.4 }) do
		b:box({ name = "Linea", size = { 164, 0.12, 0.35 }, pos = { 0, 0.06, z }, color = YELLOW, folder = "Decoracion" })
	end
	P.sidewalk(b, { 0, 0, 35 }, { 164, 10 })
	P.sidewalk(b, { 0, 0, -35 }, { 164, 10 }, 180)
	for _, p in ipairs({ { 0, -7, 0 }, { 0, 7, 0 }, { -7, 0, 90 }, { 7, 0, 90 } }) do
		P.barrier(b, { p[1], 0, p[2] }, p[3])
	end
	for i = 0, 7 do
		b:cylinder({ name = "Chimenea", length = 1, diameter = 2.6, pos = { 0, 0.5 + i, 0 }, color = (i % 2 == 0) and { 240, 110, 30 } or { 245, 245, 240 } })
	end
	for _, s in ipairs({ { 0, 9.6, 0, 3 }, { 0.6, 11.8, 0.3, 4 }, { -0.4, 14.4, -0.2, 5.2 } }) do
		b:ball({ name = "Vapor", diameter = s[4], pos = { s[1], s[2], s[3] }, color = { 236, 236, 240 }, transparency = 0.45, folder = "Decoracion", shadow = false })
	end

	b:symmetric(function(b)
		-- Edificios de ladrillo con escaleras de incendios y tiendas
		for i, e in ipairs(EDIFICIOS) do
			for _, side in ipairs({ 1, -1 }) do
				local shop = (side > 0) and e[5] or e[6]
				P.house(b, { e[1], 0, side * 47 }, side > 0 and 0 or 180, {
					w = e[2], h = e[3], d = 14, color = LADRILLO[side > 0 and e[4] or (e[4] % 5) + 1], mat = "Brick", trim = CREAM,
					floors = math.floor(e[3] / 6.5), fireEscape = true, lit = true, shop = shop and shop[1], shopColor = shop and shop[2],
				})
			end
			if i == 2 or i == 4 then
				P.waterTank(b, { e[1], e[3] + 0.8, 49 })
				P.acUnit(b, { e[1] - 3, e[3] + 0.8, -50 }, 0)
			end
		end

		-- Líneas de carril y paso de cebra
		for x = -74, -6, 12 do
			for _, z in ipairs({ -15, 15 }) do
				b:box({ name = "Linea", size = { 6, 0.12, 0.4 }, pos = { x, 0.06, z }, color = LINE, folder = "Decoracion" })
			end
		end
		for z = -28, 28, 2.4 do
			b:box({ name = "Cebra", size = { 6, 0.12, 1.2 }, pos = { -34, 0.08, z }, color = LINE, folder = "Decoracion" })
		end

		-- Mobiliario urbano
		P.streetLight(b, { -50, 0.6, 31.4 }, 0, 18)
		P.streetLight(b, { -18, 0.6, -31.4 }, 180, 18)
		P.trafficLight(b, { -38, 0.6, 31 }, 0)
		P.trafficLight(b, { -30, 0.6, -31 }, 180)
		P.hydrant(b, { -44, 0.6, 32 })
		P.hydrant(b, { -24, 0.6, -32 })
		P.newspaperBox(b, { -22, 0.6, 32 }, 0, { 40, 90, 170 })
		P.newspaperBox(b, { -19.6, 0.6, 32 }, 0, { 200, 40, 40 })
		P.trashCan(b, { -64, 0.6, -32 }, { 60, 66, 60 })
		P.trashCan(b, { -8, 0.6, 33 }, { 60, 66, 60 })
		P.hotdogCart(b, { -12, 0.6, -34 }, 180)
		P.subwayEntrance(b, { -56, 0.6, 35 }, 90)
		P.manhole(b, { -48, 0, -8 })
		P.manhole(b, { -16, 0, 14 })

		-- Taxis y camión de reparto
		P.taxi(b, { -22, 0, -6 }, 90)
		P.taxi(b, { -46, 0, 14 }, 80)
		local truck = P.truck(b, { -40, 0, -21 }, 90, { 240, 240, 236 })
		for _, face in ipairs({ "Left", "Right" }) do
			MB.sign(truck, "NYC DELIVERY", { face = face, font = "GothamBlack", color = { 40, 90, 170 }, height = 0.4 })
		end
		for _, x in ipairs({ -54, -26 }) do
			P.cone(b, { x, 0, -26 })
		end

		-- Valla de obra con carteles que protege el spawn
		b:box({ name = "Valla", size = { 1, 9, 34 }, pos = { -60, 4.5, 0 }, color = { 150, 116, 80 }, mat = "WoodPlanks" })
		for z = -16, 16, 4 do
			b:box({ name = "Poste", size = { 1.4, 9.4, 0.6 }, pos = { -60, 4.7, z }, color = { 110, 84, 58 }, mat = "Wood", folder = "Decoracion" })
		end
		P.poster(b, { -59.4, 5, -11 }, -90, { 6, 7 }, { 226, 60, 60 }, "ROCK\nNIGHT", { 255, 240, 200 }, "LuckiestGuy")
		P.poster(b, { -59.4, 6, -3.5 }, -90, { 6, 3 }, { 40, 40, 46 }, "POST NO BILLS", { 240, 240, 240 }, "GothamBlack")
		P.poster(b, { -59.4, 5, 4 }, -90, { 6, 7 }, { 60, 120, 220 }, "I LOVE\nNY", { 255, 255, 255 }, "GothamBlack")
		P.poster(b, { -59.4, 5.5, 11.5 }, -90, { 6, 6 }, YELLOW, "BROAD\nWAY", { 30, 30, 34 }, "LuckiestGuy")
		for _, z in ipairs({ -8, 0, 8 }) do
			b:spawn("A", { -70, 0.5, z }, -90)
		end
	end)

	b:bounds(-80, 80, -40, 40, 50)

	b:lighting({
		technology = "Future",
		lighting = {
			ClockTime = 18.7,
			Brightness = 1.8,
			Ambient = { 92, 96, 118 },
			OutdoorAmbient = { 120, 124, 150 },
			ExposureCompensation = 0.25,
			ShadowSoftness = 0.3,
			EnvironmentDiffuseScale = 0.5,
			EnvironmentSpecularScale = 0.6,
		},
		atmosphere = { density = 0.3, offset = 0.1, color = { 200, 180, 190 }, decay = { 110, 100, 130 }, glare = 0.8, haze = 2 },
		colorCorrection = { contrast = 0.12, saturation = 0.1, tint = { 246, 244, 255 } },
		clouds = { cover = 0.6, density = 0.5, color = { 230, 170, 160 } },
		bloom = { intensity = 0.55, size = 26, threshold = 0.85 },
		sunRays = { intensity = 0.06, spread = 0.5 },
	})
end
]=]
FUENTES_MAPAS["Oeste"] = [=[
-- Pueblo del Oeste (como en las películas de vaqueros): calle principal polvorienta a mediodía,
-- saloon, banco, sheriff y carretas. Equipo A en -X, equipo B en +X.
return function(b, MB)
	local P = MB.Props
	local DIRT = { 196, 160, 112 }
	local BOARD = { 140, 104, 70 }
	local DARK = { 90, 62, 42 }

	b.model:SetAttribute("Nombre", "Pueblo del Oeste")

	-- Edificio de madera con fachada falsa, rótulo y porche (side = 1 norte, -1 sur)
	local function building(x, side, w, h, color, sign, signColor)
		local z = side * 31
		local rot = side > 0 and 0 or 180
		P.house(b, { x, 0, z }, rot, { w = w, h = h, d = 14, color = color, mat = "WoodPlanks", trim = P.darker(color, 50), floors = h >= 14 and 2 or 1, balcony = h >= 14, shutters = h < 14 and P.darker(color, 40) or nil })
		local g = b:at({ x, 0, z }, rot)
		g:box({ name = "Fachada", size = { w, 5, 0.6 }, pos = { 0, h + 2.5, -6.9 }, color = color, mat = "WoodPlanks" })
		g:box({ name = "Remate", size = { w + 0.6, 0.6, 0.9 }, pos = { 0, h + 5.2, -6.9 }, color = P.darker(color, 50), mat = "Wood", folder = "Decoracion" })
		local panel = g:box({ name = "Rotulo", size = { w - 2, 3, 0.2 }, pos = { 0, h + 2.5, -7.3 }, color = signColor, folder = "Decoracion" })
		MB.sign(panel, sign, { font = "Fantasy", color = { 250, 236, 200 }, bg = signColor })
		g:box({ name = "Porche", size = { w, 0.5, 5.4 }, pos = { 0, 8.6, -9.7 }, color = DARK, mat = "WoodPlanks" })
		for _, px in ipairs({ -w / 2 + 0.6, w / 2 - 0.6 }) do
			g:box({ name = "Poste", size = { 0.6, 8.4, 0.6 }, pos = { px, 4.2, -12 }, color = DARK, mat = "Wood" })
		end
	end

	-- =================================================================
	--  Desierto con mesetas, cactus y cielo
	-- =================================================================
	b:box({ name = "Desierto", size = { 900, 1, 900 }, pos = { 0, -1.2, 0 }, color = { 212, 172, 120 }, mat = "Sand", folder = "Decoracion" })
	for _, m in ipairs({ { -200, 170, 130, 46 }, { 150, 220, 170, 60 }, { 300, 60, 110, 40 }, { -320, -40, 130, 50 }, { 20, -230, 160, 44 }, { -180, -200, 110, 36 } }) do
		b:box({ name = "Meseta", size = { m[3], m[4], m[3] * 0.7 }, pos = { m[1], m[4] / 2 - 1, m[2] }, color = { 186, 100, 66 }, mat = "Sandstone", folder = "Decoracion" })
		b:box({ name = "Meseta", size = { m[3] * 0.7, 6, m[3] * 0.5 }, pos = { m[1], m[4] + 2, m[2] }, color = { 170, 90, 60 }, mat = "Sandstone", folder = "Decoracion" })
	end
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		P.cactus(b, { math.cos(a) * 120, 0, math.sin(a) * 90 }, 1.4 + (i % 3) * 0.3)
	end

	-- =================================================================
	--  Calle principal, aceras de tablas y carreta central
	-- =================================================================
	b:box({ name = "Calle", size = { 164, 1, 72 }, pos = { 0, -0.5, 0 }, color = DIRT, mat = "Ground" })
	for _, z in ipairs({ -21, 21 }) do
		b:box({ name = "Acera", size = { 152, 0.6, 6 }, pos = { 0, 0.3, z }, color = BOARD, mat = "WoodPlanks" })
	end
	P.wagon(b, { 0, 0, 0 }, 0)
	P.hayBale(b, { -4.4, 0, 7 }, 90)
	P.hayBale(b, { 4.4, 0, -7 }, 90)
	P.waterTank(b, { 0, 0, 30 })
	P.bellTower(b, { 0, 0, -34 }, 180, 24, { 236, 226, 206 }, { 120, 80, 56 })

	b:symmetric(function(b)
		local m = b.mirrored
		-- Edificios: norte y sur
		building(-66, 1, 16, 12, { 150, 110, 80 }, m and "BARBERÍA" or "HOTEL", { 120, 50, 40 })
		building(-49, 1, 18, 16, { 170, 120, 76 }, "SALOON", { 140, 40, 36 })
		building(-31, 1, 14, 12, { 120, 130, 120 }, m and "TELÉGRAFO" or "BANCO", { 40, 80, 60 })
		building(-15, 1, 16, 14, { 160, 140, 110 }, m and "HERRERÍA" or "SHERIFF", { 60, 60, 90 })
		building(-66, -1, 16, 12, { 136, 100, 72 }, m and "ESTABLO" or "ALMACÉN", { 90, 60, 40 })
		building(-49, -1, 18, 14, { 176, 150, 116 }, m and "CORREOS" or "HOTEL", { 50, 70, 120 })
		building(-31, -1, 14, 12, { 150, 96, 70 }, m and "FUNERARIA" or "DOCTOR", { 40, 40, 40 })
		building(-15, -1, 16, 16, { 166, 126, 90 }, "SALOON", { 140, 40, 36 })

		-- Puertas batientes del saloon y carteles de "se busca"
		for _, side in ipairs({ -1, 1 }) do
			for _, dx in ipairs({ -0.9, 0.9 }) do
				b:box({ name = "PuertaBatiente", size = { 1.6, 3, 0.2 }, pos = { (side > 0 and -49 or -15) + dx, 3.5, side * 23.3 }, color = { 110, 70, 40 }, mat = "WoodPlanks", folder = "Decoracion" })
			end
		end
		for _, p in ipairs({ { -58, 23.7, 0 }, { -24, -23.7, 180 } }) do
			P.poster(b, { p[1], 5, p[2] }, p[3], { 3, 4 }, { 236, 220, 180 }, "SE BUSCA\n$500", { 60, 40, 30 }, "Fantasy")
		end

		-- Postes para atar caballos y abrevaderos
		for _, z in ipairs({ -17.4, 17.4 }) do
			for _, x in ipairs({ -60, -42, -24 }) do
				b:box({ name = "Poste", size = { 0.5, 3.6, 0.5 }, pos = { x - 2.5, 1.8, z }, color = DARK, mat = "Wood" })
				b:box({ name = "Poste", size = { 0.5, 3.6, 0.5 }, pos = { x + 2.5, 1.8, z }, color = DARK, mat = "Wood" })
				b:box({ name = "Barra", size = { 5.6, 0.4, 0.4 }, pos = { x, 3.3, z }, color = DARK, mat = "Wood", folder = "Decoracion" })
			end
		end
		b:box({ name = "Abrevadero", size = { 6, 2.4, 2.4 }, pos = { -34, 1.2, 14 }, color = { 110, 80, 54 }, mat = "WoodPlanks" })
		b:box({ name = "Agua", size = { 5.4, 0.1, 1.8 }, pos = { -34, 2.3, 14 }, color = { 80, 130, 150 }, mat = "Glass", folder = "Decoracion" })
		b:box({ name = "Abrevadero", size = { 6, 2.4, 2.4 }, pos = { -46, 1.2, -14 }, color = { 110, 80, 54 }, mat = "WoodPlanks" })

		-- Carreta, paja, barriles y cajas
		P.wagon(b, { -40, 0, 4 }, 70, { 230, 220, 196 })
		P.hayBale(b, { -24, 0, -8 }, 10)
		P.hayBale(b, { -22, 0, -5 }, -20)
		P.hayBale(b, { -23, 2.6, -6.4 }, 0)
		P.hayBale(b, { -54, 0, 10 }, 80)
		for _, p in ipairs({ { -12, -14 }, { -9.6, -15 }, { -11, 12.6 } }) do
			P.drum(b, { p[1], 0, p[2] }, { 120, 80, 50 })
		end
		P.crate(b, { -28, 0, 13 }, 4, 20, { 170, 130, 90 })
		b:ball({ name = "Rodamundos", diameter = 2.2, pos = { -36, 1.1, -4 }, color = { 170, 140, 90 }, mat = "Grass", transparency = 0.2, folder = "Decoracion" })
		b:ball({ name = "Rodamundos", diameter = 1.8, pos = { -18, 0.9, 9 }, color = { 160, 130, 84 }, mat = "Grass", transparency = 0.2, folder = "Decoracion" })

		-- Granero al final de la calle que protege el spawn
		b:box({ name = "Granero", size = { 8, 12, 30 }, pos = { -62, 6, 0 }, color = { 170, 50, 40 }, mat = "WoodPlanks" })
		b:wedge({ name = "Tejado", size = { 31, 3, 4.6 }, pos = { -64.3, 13.5, 0 }, rot = { 0, 90, 0 }, color = { 80, 60, 50 }, mat = "WoodPlanks" })
		b:wedge({ name = "Tejado", size = { 31, 3, 4.6 }, pos = { -59.7, 13.5, 0 }, rot = { 0, -90, 0 }, color = { 80, 60, 50 }, mat = "WoodPlanks" })
		for _, z in ipairs({ -5, 5 }) do
			b:box({ name = "Puerta", size = { 0.3, 9, 8 }, pos = { -57.9, 4.5, z }, color = { 150, 40, 32 }, mat = "WoodPlanks", folder = "Decoracion" })
			P.segment(b, { -57.7, 0.5, z - 3.6 }, { -57.7, 8.5, z + 3.6 }, 0.5, { 240, 236, 226 }, "WoodPlanks", "Decoracion")
			P.segment(b, { -57.7, 0.5, z + 3.6 }, { -57.7, 8.5, z - 3.6 }, 0.5, { 240, 236, 226 }, "WoodPlanks", "Decoracion")
		end
		P.cactus(b, { -74, 0, -26 }, 1)

		for _, z in ipairs({ -8, 0, 8 }) do
			b:spawn("A", { -71, 0.5, z }, -90)
		end
	end)

	b:bounds(-80, 80, -24, 24, 40)

	b:lighting({
		technology = "Future",
		lighting = {
			ClockTime = 12.4,
			Brightness = 3.6,
			Ambient = { 136, 116, 96 },
			OutdoorAmbient = { 180, 150, 120 },
			ExposureCompensation = 0,
			ShadowSoftness = 0.1,
			EnvironmentDiffuseScale = 0.5,
			EnvironmentSpecularScale = 0.4,
		},
		atmosphere = { density = 0.3, offset = 0.1, color = { 236, 206, 160 }, decay = { 190, 140, 90 }, glare = 0.5, haze = 2 },
		colorCorrection = { contrast = 0.12, saturation = 0.05, tint = { 255, 238, 214 } },
		clouds = { cover = 0.15, density = 0.3, color = { 255, 246, 230 } },
		bloom = { intensity = 0.3, size = 24, threshold = 0.95 },
		sunRays = { intensity = 0.1, spread = 0.6 },
	})
end
]=]
FUENTES_MAPAS["PuebloNuclear"] = [=[
-- Pueblo Nuclear (estilo Nuketown de Call of Duty): dos casas enfrentadas en un pueblo de pruebas
-- en el desierto. Se puede entrar en las casas y subir al balcón. Equipo A en -X, equipo B en +X.
return function(b, MB)
	local P = MB.Props
	local LAWN = { 118, 168, 80 }
	local WHITE = { 244, 244, 238 }
	local GREEN_TREES = { { 86, 140, 66 }, { 100, 156, 74 }, { 76, 126, 60 } }

	b.model:SetAttribute("Nombre", "Pueblo Nuclear")

	-- =================================================================
	--  Desierto, mesetas y torre de pruebas
	-- =================================================================
	b:box({ name = "Desierto", size = { 900, 1, 900 }, pos = { 0, -1.2, 0 }, color = { 214, 184, 134 }, mat = "Sand", folder = "Decoracion" })
	for _, m in ipairs({ { -220, 200, 140, 34 }, { 200, 240, 160, 40 }, { 320, 40, 110, 28 }, { -330, -40, 120, 36 }, { 60, -250, 150, 30 } }) do
		b:box({ name = "Meseta", size = { m[3], m[4], m[3] * 0.7 }, pos = { m[1], m[4] / 2 - 1, m[2] }, color = { 196, 120, 82 }, mat = "Sandstone", folder = "Decoracion" })
	end
	local steel = { 120, 124, 132 }
	for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		P.segment(b, { c[1] * 9, 0, 230 + c[2] * 9 }, { c[1] * 2.5, 90, 230 + c[2] * 2.5 }, 1.2, steel, "Metal", "Decoracion")
	end
	for _, y in ipairs({ 20, 40, 60, 80 }) do
		local half = 9 - (6.5 * y / 90)
		for _, c in ipairs({ { -1, -1, 1, -1 }, { 1, -1, 1, 1 }, { 1, 1, -1, 1 }, { -1, 1, -1, -1 } }) do
			P.segment(b, { c[1] * half, y, 230 + c[2] * half }, { c[3] * half, y, 230 + c[4] * half }, 0.6, steel, "Metal", "Decoracion")
		end
	end
	b:box({ name = "Cabina", size = { 9, 8, 9 }, pos = { 0, 94, 230 }, color = { 200, 196, 186 }, mat = "Metal", folder = "Decoracion" })
	local warn = b:box({ name = "Aviso", size = { 30, 8, 1 }, pos = { 40, 10, 190 }, color = { 250, 210, 40 }, folder = "Decoracion" })
	MB.sign(warn, "☢ ZONA DE PRUEBAS ☢", { font = "GothamBlack", color = { 30, 30, 30 }, bg = { 250, 210, 40 } })

	-- =================================================================
	--  Césped, calle, autobús, camión y cartel de bienvenida
	-- =================================================================
	b:box({ name = "Cesped", size = { 152, 1, 92 }, pos = { 0, -0.5, 0 }, color = LAWN, mat = "Grass" })
	b:box({ name = "Calle", size = { 34, 0.1, 92 }, pos = { 0, 0.05, 0 }, color = { 82, 82, 86 }, mat = "Asphalt", folder = "Decoracion" })
	for z = -42, 42, 8 do
		b:box({ name = "Linea", size = { 0.5, 0.12, 4 }, pos = { 0, 0.07, z }, color = { 246, 200, 50 }, folder = "Decoracion" })
	end
	P.bus(b, { 1.45, 0, 24 }, 90, { 246, 190, 30 }, "ESCUELA")
	local cargo = P.truck(b, { -2.4, 0, -24 }, 90, { 236, 236, 232 })
	for _, face in ipairs({ "Left", "Right" }) do
		MB.sign(cargo, "LECHE FRESCA", { face = face, font = "LuckiestGuy", color = { 60, 120, 200 }, height = 0.4 })
	end
	for _, x in ipairs({ -10, 10 }) do
		b:box({ name = "Poste", size = { 1, 14, 1 }, pos = { x, 7, 44 }, color = { 110, 84, 60 }, mat = "Wood", folder = "Decoracion" })
	end
	local welcome = b:box({ name = "Cartel", size = { 24, 6, 0.6 }, pos = { 0, 11, 44 }, color = { 240, 236, 220 }, folder = "Decoracion" })
	MB.sign(welcome, "PUEBLO NUCLEAR · POBLACIÓN 50", { font = "LuckiestGuy", color = { 200, 60, 50 }, bg = { 240, 236, 220 }, width = 0.9, height = 0.6 })
	P.mannequin(b, { -4, 0, 10 }, 30, { 220, 70, 70 })
	P.mannequin(b, { 6, 0, -12 }, -150, { 70, 150, 90 })

	b:symmetric(function(b)
		local mine = not b.mirrored
		-- Casa (se puede entrar, con escalera y balcón)
		P.openHouse(b, { -42, 0, 0 }, -90, {
			color = mine and { 112, 170, 210 } or { 236, 200, 96 },
			trim = WHITE,
			roofColor = mine and { 70, 90, 120 } or { 150, 70, 50 },
			sofa = mine and { 200, 80, 70 } or { 60, 110, 170 },
		})
		P.sidewalk(b, { -18.5, 0, 0 }, { 92, 3 }, -90)

		-- Entrada de coches con coche y caravana
		b:box({ name = "Entrada", size = { 30, 0.1, 10 }, pos = { -35, 0.06, 20 }, color = { 176, 172, 166 }, mat = "Concrete", folder = "Decoracion" })
		P.car(b, { -36, 0, 20 }, -90, mine and { 210, 60, 60 } or { 60, 160, 150 })
		b:box({ name = "Caravana", size = { 16, 7, 7 }, pos = { -48, 4.4, 36 }, color = { 240, 236, 226 }, mat = "Metal" })
		b:box({ name = "Franja", size = { 16.1, 1, 7.1 }, pos = { -48, 4.4, 36 }, color = mine and { 80, 140, 200 } or { 220, 150, 50 }, folder = "Decoracion" })
		for _, x in ipairs({ -52, -44 }) do
			b:cylinder({ name = "Rueda", axis = "z", length = 7.4, diameter = 2, pos = { x, 1, 36 }, color = { 30, 30, 32 }, mat = "Rubber" })
		end

		-- Cobertizo y cajas al sur
		b:box({ name = "Cobertizo", size = { 10, 8, 8 }, pos = { -48, 4, -36 }, color = { 150, 110, 76 }, mat = "WoodPlanks" })
		b:wedge({ name = "Tejado", size = { 11, 2, 4.6 }, pos = { -48, 9, -38.3 }, color = { 90, 70, 60 }, mat = "RoofShingles" })
		b:wedge({ name = "Tejado", size = { 11, 2, 4.6 }, pos = { -48, 9, -33.7 }, rot = { 0, 180, 0 }, color = { 90, 70, 60 }, mat = "RoofShingles" })
		P.crate(b, { -36, 0, -34 }, 4.5, 15)
		P.crate(b, { -33, 0, -40 }, 4, -10)

		-- Jardín delantero: maniquíes, buzón y árbol
		P.mannequin(b, { -24, 0, -8 }, -90, mine and { 60, 110, 180 } or { 220, 120, 40 })
		P.mannequin(b, { -26, 0, 7 }, -120, mine and { 230, 230, 230 } or { 170, 60, 140 })
		b:box({ name = "Buzon", size = { 0.4, 4, 0.4 }, pos = { -21, 2, -16 }, color = { 80, 80, 86 }, mat = "Metal" })
		b:box({ name = "Buzon", size = { 1.4, 1.2, 2.2 }, pos = { -21, 4.4, -16 }, color = mine and { 60, 110, 180 } or { 200, 60, 50 }, mat = "Metal" })
		P.tree(b, { -26, 0, -28 }, 1.1, GREEN_TREES)
		P.bush(b, { -30, 0, -14 }, 1.1)
		P.bush(b, { -30, 0, 14 }, 1.1)

		-- Patio trasero: valla blanca, columpio, barbacoa y caseta del perro
		P.woodFence(b, { -76, 0, -30 }, { -52, 0, -30 }, 4, WHITE)
		P.woodFence(b, { -76, 0, 30 }, { -54, 0, 30 }, 4, WHITE)
		for _, z in ipairs({ -24, -16 }) do
			P.segment(b, { -66, 0, z }, { -64, 9, z }, 0.4, { 200, 60, 60 }, "Metal")
			P.segment(b, { -62, 0, z }, { -64, 9, z }, 0.4, { 200, 60, 60 }, "Metal")
		end
		b:cylinder({ name = "Barra", axis = "z", length = 9, diameter = 0.4, pos = { -64, 9, -20 }, color = { 200, 60, 60 }, mat = "Metal", folder = "Decoracion" })
		b:box({ name = "Columpio", size = { 1.6, 0.3, 1 }, pos = { -64, 2.4, -20 }, color = { 60, 60, 66 }, folder = "Decoracion" })
		b:box({ name = "Barbacoa", size = { 3, 3, 2 }, pos = { -58, 1.5, 22 }, color = { 40, 40, 44 }, mat = "Metal" })
		b:box({ name = "Caseta", size = { 4, 3.6, 4 }, pos = { -70, 1.8, 22 }, color = { 180, 80, 60 }, mat = "WoodPlanks" })
		b:wedge({ name = "Tejado", size = { 4.6, 1.4, 2.3 }, pos = { -70, 4.3, 20.85 }, color = { 80, 60, 50 }, folder = "Decoracion" })
		b:wedge({ name = "Tejado", size = { 4.6, 1.4, 2.3 }, pos = { -70, 4.3, 23.15 }, rot = { 0, 180, 0 }, color = { 80, 60, 50 }, folder = "Decoracion" })

		for _, z in ipairs({ -3.5, 0, 3.5 }) do
			b:spawn("A", { -66, 0.5, z }, -90)
		end
	end)

	b:bounds(-76, 76, -46, 46, 45)

	b:lighting({
		technology = "Future",
		lighting = {
			ClockTime = 10.5,
			Brightness = 3,
			Ambient = { 128, 120, 110 },
			OutdoorAmbient = { 170, 160, 140 },
			ExposureCompensation = 0,
			ShadowSoftness = 0.15,
			EnvironmentDiffuseScale = 0.6,
			EnvironmentSpecularScale = 0.5,
		},
		atmosphere = { density = 0.25, offset = 0.05, color = { 232, 216, 190 }, decay = { 170, 140, 110 }, glare = 0.4, haze = 1.4 },
		colorCorrection = { contrast = 0.08, saturation = 0.2, tint = { 255, 250, 240 } },
		clouds = { cover = 0.3, density = 0.4, color = { 255, 255, 255 } },
		bloom = { intensity = 0.3, size = 24, threshold = 0.95 },
		sunRays = { intensity = 0.08, spread = 0.6 },
	})
end
]=]
FUENTES_MAPAS["Puerto"] = [=[
-- Puerto de contenedores a mediodía. Equipo A en -X, equipo B en +X.
return function(b, MB)
	local P = MB.Props
	local CONCRETE = { 164, 162, 156 }
	local LANE = { 236, 196, 40 }
	local RED = { 176, 58, 46 }
	local BLUE = { 48, 92, 150 }
	local GREEN = { 60, 120, 80 }
	local ORANGE = { 214, 120, 40 }
	local GREY = { 130, 134, 140 }
	local TEAL = { 40, 130, 140 }
	local CRANE = { 236, 186, 36 }
	local STACK_COLORS = { RED, BLUE, GREEN, ORANGE, GREY, TEAL, { 230, 230, 226 } }

	b.model:SetAttribute("Nombre", "Puerto de Contenedores")

	-- =================================================================
	--  Mar, barco atracado y grúas al fondo
	-- =================================================================
	b:box({ name = "Mar", size = { 900, 1, 900 }, pos = { 0, -8, 0 }, color = { 50, 96, 122 }, reflectance = 0.25, folder = "Decoracion" })
	-- Casco
	b:box({ name = "Casco", size = { 150, 20, 30 }, pos = { 0, -3, -84 }, color = { 40, 52, 70 }, mat = "Metal", folder = "Decoracion" })
	b:box({ name = "Linea", size = { 150.4, 3, 30.4 }, pos = { 0, -6, -84 }, color = { 170, 40, 36 }, mat = "Metal", folder = "Decoracion" })
	b:wedge({ name = "Proa", size = { 30, 20, 18 }, pos = { 84, -3, -84 }, rot = { 0, -90, 0 }, color = { 40, 52, 70 }, mat = "Metal", folder = "Decoracion" })
	local hull = b:box({ name = "Nombre", size = { 40, 4, 0.2 }, pos = { -20, 3, -68.9 }, color = { 40, 52, 70 }, transparency = 1, folder = "Decoracion" })
	MB.sign(hull, "OCEANIX", { face = "Back", font = "GothamBlack", color = { 240, 240, 236 } })
	b:box({ name = "Puente", size = { 16, 18, 22 }, pos = { -60, 16, -84 }, color = { 236, 236, 232 }, mat = "Metal", folder = "Decoracion" })
	for y = 10, 22, 4 do
		b:box({ name = "Ventanas", size = { 16.2, 1.4, 22.2 }, pos = { -60, y, -84 }, color = { 40, 60, 80 }, mat = "Glass", folder = "Decoracion" })
	end
	b:cylinder({ name = "Chimenea", length = 8, diameter = 5, pos = { -64, 29, -84 }, color = { 170, 40, 36 }, mat = "Metal", folder = "Decoracion" })
	local i = 0
	for x = -42, 66, 9 do
		for row = 0, 2 do
			local height = 1 + ((x + row) % 3)
			for level = 0, height - 1 do
				i = i + 1
				local c = STACK_COLORS[(i % #STACK_COLORS) + 1]
				b:box({ name = "Carga", size = { 8.5, 8.5, 9 }, pos = { x, 11.25 + level * 8.6, -94 + row * 9.4 }, color = c, mat = "Metal", folder = "Decoracion" })
			end
		end
	end
	-- Grúas portacontenedores (silueta)
	for _, x in ipairs({ -95, 95 }) do
		for _, z in ipairs({ -60, -40 }) do
			b:box({ name = "PataGrua", size = { 3, 60, 3 }, pos = { x - 10, 30, z }, color = { 220, 70, 50 }, mat = "Metal", folder = "Decoracion" })
			b:box({ name = "PataGrua", size = { 3, 60, 3 }, pos = { x + 10, 30, z }, color = { 220, 70, 50 }, mat = "Metal", folder = "Decoracion" })
		end
		b:box({ name = "Pluma", size = { 4, 4, 90 }, pos = { x, 62, -70 }, color = { 220, 70, 50 }, mat = "Metal", folder = "Decoracion" })
		b:box({ name = "Viga", size = { 24, 4, 4 }, pos = { x, 58, -50 }, color = { 220, 70, 50 }, mat = "Metal", folder = "Decoracion" })
	end
	-- Pilas de contenedores al norte (fuera del área de juego)
	for x = -70, 70, 22 do
		for level = 0, 2 do
			if not (level == 2 and x % 44 == 4) then
				i = i + 1
				b:box({ name = "Pila", size = { 21, 9, 8.5 }, pos = { x, 4.5 + level * 9, 62 }, color = STACK_COLORS[(i % #STACK_COLORS) + 1], mat = "Metal", folder = "Decoracion" })
			end
		end
	end

	-- =================================================================
	--  Muelle
	-- =================================================================
	b:box({ name = "Muelle", size = { 156, 1, 108 }, pos = { 0, -0.5, 0 }, color = CONCRETE, mat = "Concrete" })
	for _, z in ipairs({ -54.5, 54.5 }) do
		b:box({ name = "Borde", size = { 158, 8, 1 }, pos = { 0, -4, z }, color = { 118, 116, 112 }, mat = "Concrete", folder = "Decoracion" })
		b:box({ name = "Cantil", size = { 156, 0.5, 1.2 }, pos = { 0, 0.25, z > 0 and 53.6 or -53.6 }, color = LANE, mat = "Concrete", folder = "Decoracion" })
	end
	for _, z in ipairs({ -14, 14 }) do
		b:box({ name = "Linea", size = { 150, 0.12, 0.6 }, pos = { 0, 0.06, z }, color = LANE, folder = "Decoracion" })
	end

	-- Centro: contenedores rotulados y pila de cajas
	P.container(b, { 0, 0, 34 }, 0, GREY, false, "TRANSATLAS")
	P.container(b, { 0, 0, -34 }, 0, ORANGE, false, "OCEANIX")

	-- Grúa pórtico con celosía y contenedor colgando
	for _, x in ipairs({ -11, 11 }) do
		b:box({ name = "Viga", size = { 2.5, 3, 94.5 }, pos = { x, 35.5, 0 }, color = CRANE, mat = "Metal" })
	end
	for _, z in ipairs({ -46, 46 }) do
		b:box({ name = "Viga", size = { 24.5, 3, 2.5 }, pos = { 0, 35.5, z }, color = CRANE, mat = "Metal" })
		P.segment(b, { -11, 23, z }, { 0, 34, z }, 0.8, CRANE, "Metal", "Decoracion")
		P.segment(b, { 11, 23, z }, { 0, 34, z }, 0.8, CRANE, "Metal", "Decoracion")
	end
	b:box({ name = "Carro", size = { 24, 3, 6 }, pos = { 0, 32.5, -4 }, color = CRANE, mat = "Metal" })
	b:box({ name = "Cabina", size = { 5, 4, 5 }, pos = { 6, 29, -4 }, color = { 200, 205, 210 }, mat = "Metal" })
	b:box({ name = "Cristal", size = { 5.1, 1.6, 5.1 }, pos = { 6, 29.4, -4 }, color = { 40, 60, 80 }, mat = "Glass", folder = "Decoracion" })
	for _, x in ipairs({ -3, 3 }) do
		b:cylinder({ name = "Cable", length = 7, diameter = 0.3, pos = { x, 27.5, -4 }, color = { 30, 30, 30 }, folder = "Decoracion", shadow = false })
	end
	P.container(b, { 0, 15, -4 }, 0, BLUE, false, "NAVIERA SUR")

	b:symmetric(function(b)
		-- Patas de la grúa con franjas de peligro
		for _, z in ipairs({ -46, 46 }) do
			b:box({ name = "Pata", size = { 2.5, 34, 2.5 }, pos = { -11, 17, z }, color = CRANE, mat = "Metal" })
			b:box({ name = "Base", size = { 5, 1.4, 5 }, pos = { -11, 0.7, z }, color = { 70, 72, 78 }, mat = "Metal" })
			for k = 0, 4 do
				b:box({ name = "Peligro", size = { 1.1, 0.06, 7 }, pos = { -13.6 + k * 1.3, 0.04, z }, rot = { 0, 30, 0 }, color = (k % 2 == 0) and LANE or { 30, 30, 32 }, folder = "Decoracion" })
			end
			P.segment(b, { -11, 2, z }, { -11, 20, z > 0 and z - 10 or z + 10 }, 0.8, CRANE, "Metal", "Decoracion")
		end
		b:box({ name = "Borde", size = { 1, 8, 108 }, pos = { -78.5, -4, 0 }, color = { 118, 116, 112 }, mat = "Concrete", folder = "Decoracion" })
		b:box({ name = "Linea", size = { 0.6, 0.12, 100 }, pos = { -40, 0.06, 0 }, color = LANE, folder = "Decoracion" })

		-- Pila de cajas en el centro
		P.crate(b, { -3, 0, 1 }, 5)
		P.crate(b, { -3, 5, 1 }, 5, 10)

		-- Muro de contenedores que protege el spawn (se sale por los huecos)
		P.container(b, { -58, 0, -26 }, 90, BLUE, false, "OCEANIX")
		P.container(b, { -58, 0, 26 }, 90, RED, false, "TRANSATLAS")
		P.container(b, { -46, 0, 0 }, 90, b.mirrored and GREEN or ORANGE)

		-- Contenedor abierto (túnel) y pila de dos
		P.container(b, { -28, 0, 0 }, 0, GREEN, true)
		P.container(b, { -34, 0, -30 }, 0, RED)
		P.container(b, { -34, 9, -30 }, 0, b.mirrored and ORANGE or BLUE, false, "NAVIERA SUR")

		-- Contenedor con rampa para ganar altura
		P.container(b, { -34, 0, 30 }, 0, GREEN)
		b:wedge({ name = "Rampa", size = { 8.5, 9, 12 }, pos = { -17.5, 4.5, 30 }, rot = { 0, -90, 0 }, color = { 120, 116, 110 }, mat = "DiamondPlate" })
		for _, z in ipairs({ 25.6, 34.4 }) do
			b:wedge({ name = "Lateral", size = { 0.4, 9.2, 12 }, pos = { -17.5, 4.6, z }, rot = { 0, -90, 0 }, color = LANE, folder = "Decoracion" })
		end

		-- Contenedor a media distancia
		P.container(b, { -12, 0, -16 }, 90, GREY)

		-- Bidones, palés, bobinas y carretilla elevadora
		P.drum(b, { -24, 0, 12 }, BLUE)
		P.drum(b, { -21.4, 0, 12.6 }, RED)
		P.drum(b, { -23, 0, 14.9 }, BLUE)
		P.pallet(b, { -48, 0, 40 }, 0)
		P.crate(b, { -48, 0.8, 40 }, 3.5)
		P.pallet(b, { -42, 0, 42 }, 30)
		P.cardboard(b, { -42, 0.8, 42 }, { 3.4, 2.4, 3 }, 30)
		P.cableReel(b, { -22, 0, -40 }, 0)
		P.forklift(b, { -50, 0, -42 }, 0, b.mirrored and { 230, 160, 30 } or { 214, 120, 40 })
		P.cone(b, { -40, 0, -14 })
		P.cone(b, { -38, 0, -14.6 })
		P.barrier(b, { -30, 0, 14 }, 0)

		-- Caseta de control junto al spawn
		local booth = b:at({ -70, 0, -42 }, 0)
		booth:box({ name = "Caseta", size = { 7, 7, 6 }, pos = { 0, 3.5, 0 }, color = { 230, 230, 226 }, mat = "Plaster" })
		booth:box({ name = "Cristal", size = { 7.1, 2.2, 6.1 }, pos = { 0, 4.6, 0 }, color = { 60, 90, 120 }, mat = "Glass", transparency = 0.2, folder = "Decoracion" })
		booth:box({ name = "Tejado", size = { 8.4, 0.6, 7.4 }, pos = { 0, 7.3, 0 }, color = { 60, 62, 70 }, mat = "Metal" })
		P.poster(booth, { 0, 6.3, -3.06 }, 0, { 4, 0.9 }, { 40, 90, 160 }, "CONTROL", { 255, 255, 255 }, "GothamBlack")

		-- Torres de focos y bolardos con defensas en el borde del muelle
		P.floodLight(b, { -70, 0, 46 }, 180, 22)
		for x = -66, -6, 12 do
			b:cylinder({ name = "Bolardo", length = 1.6, diameter = 1.2, pos = { x, 0.8, -52.6 }, color = { 40, 40, 46 }, mat = "Metal" })
			b:ball({ name = "Cabeza", diameter = 1.5, pos = { x, 1.7, -52.6 }, color = { 40, 40, 46 }, mat = "Metal", folder = "Decoracion" })
			b:cylinder({ name = "Defensa", axis = "x", length = 1.2, diameter = 3, pos = { x + 6, -1.6, -54.7 }, color = { 30, 30, 32 }, mat = "Rubber", folder = "Decoracion" })
		end

		-- Números de las calles pintados en el suelo
		for k, pos in ipairs({ { -36, -14 }, { -36, 14 }, { -8, 8 } }) do
			local mark = b:box({ name = "Marca", size = { 6, 0.05, 3 }, pos = { pos[1], 0.03, pos[2] + 4 }, color = CONCRETE, transparency = 1, folder = "Decoracion" })
			MB.sign(mark, (b.mirrored and "B" or "A") .. k, { face = "Top", font = "GothamBlack", color = LANE })
		end
		P.stain(b, { -26, 0, -6 }, 5)
		P.puddle(b, { -48, 0, -20 }, 7)
		P.manhole(b, { -20, 0, 22 })

		for _, z in ipairs({ -8, 0, 8 }) do
			b:spawn("A", { -68, 0.5, z }, -90)
		end
	end)

	b:bounds(-76, 76, -52, 52, 40)

	b:lighting({
		technology = "Future",
		lighting = {
			ClockTime = 13.2,
			Brightness = 2.4,
			Ambient = { 122, 127, 132 },
			OutdoorAmbient = { 142, 147, 152 },
			ShadowSoftness = 0.25,
			EnvironmentDiffuseScale = 0.6,
			EnvironmentSpecularScale = 0.6,
		},
		atmosphere = { density = 0.3, color = { 200, 212, 222 }, decay = { 122, 132, 152 }, haze = 1.2, glare = 0.3 },
		colorCorrection = { contrast = 0.08, saturation = 0.02, tint = { 246, 248, 255 } },
		clouds = { cover = 0.7, density = 0.5, color = { 226, 230, 236 } },
		bloom = { intensity = 0.3, size = 24, threshold = 0.95 },
		sunRays = { intensity = 0.08, spread = 0.5 },
	})
end
]=]
FUENTES_MAPAS["Rusia"] = [=[
-- Rusia: aldea nevada con casas de troncos, iglesia de cúpulas y abetos. Equipo A en -X, equipo B en +X.
return function(b, MB)
	local P = MB.Props
	local SNOW = { 236, 240, 248 }
	local PATH = { 204, 208, 218 }
	local LOG = { 150, 104, 66 }
	local WHITE = { 244, 244, 240 }
	local BLUE = { 46, 92, 186 }
	local GOLD = { 226, 186, 72 }
	local IZBAS = {
		{ w = 13, h = 9, color = LOG, mat = "Wood", trim = WHITE, logs = true, roof = "gable", roofColor = SNOW, roofMat = "Snow", shutters = BLUE, floors = 1 },
		{ w = 12, h = 10, color = { 132, 92, 60 }, mat = "Wood", trim = { 220, 200, 120 }, logs = true, roof = "gable", roofColor = { 70, 120, 92 }, roofMat = "Metal", shutters = WHITE, floors = 1, shop = "ХЛЕБ", shopColor = { 170, 50, 40 } },
		{ w = 14, h = 9, color = { 160, 112, 72 }, mat = "Wood", trim = WHITE, logs = true, roof = "gable", roofColor = SNOW, roofMat = "Snow", shutters = { 60, 140, 110 }, floors = 1 },
		{ w = 12, h = 10, color = { 140, 98, 64 }, mat = "Wood", trim = { 230, 230, 240 }, logs = true, roof = "gable", roofColor = { 150, 56, 48 }, roofMat = "Metal", shutters = BLUE, floors = 1, shop = "ЧАЙ", shopColor = { 40, 90, 160 } },
	}

	b.model:SetAttribute("Nombre", "Rusia")

	-- =================================================================
	--  Paisaje nevado con bosque de abetos
	-- =================================================================
	b:box({ name = "Nieve", size = { 900, 1, 900 }, pos = { 0, -1.2, 0 }, color = SNOW, mat = "Snow", folder = "Decoracion" })
	for _, h in ipairs({ { -180, 160, 180 }, { 180, 160, 180 }, { 0, 230, 200 }, { -170, -160, 170 }, { 170, -160, 170 } }) do
		b:ball({ name = "Colina", diameter = h[3], pos = { h[1], -h[3] * 0.3, h[2] }, color = { 230, 236, 246 }, mat = "Snow", folder = "Decoracion" })
	end
	for i = 0, 17 do
		local a = i / 18 * math.pi * 2 + 0.17
		local r = 112 + (i % 3) * 16
		P.pineTree(b, { math.cos(a) * r * 1.25, 0, math.sin(a) * r }, 1.6 + (i % 4) * 0.25, true)
	end

	-- =================================================================
	--  Plaza nevada, abeto de Año Nuevo e iglesia
	-- =================================================================
	b:box({ name = "Suelo", size = { 164, 1, 108 }, pos = { 0, -0.5, 0 }, color = SNOW, mat = "Snow" })
	b:box({ name = "Camino", size = { 164, 0.1, 14 }, pos = { 0, 0.05, 0 }, color = PATH, mat = "Snow", folder = "Decoracion" })

	P.pineTree(b, { 0, 0, 0 }, 1.5, true)
	local tiers = { { 6, 13.5 }, { 9.9, 11.1 }, { 13.5, 8.7 }, { 16.8, 6 } }
	local balls = { { 220, 40, 40 }, { 240, 200, 60 }, { 60, 120, 230 }, { 230, 230, 240 } }
	for k, t in ipairs(tiers) do
		for i = 0, 3 do
			local a = math.rad(i * 90 + k * 30)
			local r = t[2] / 2 - 0.2
			b:ball({ name = "Bola", diameter = 1, pos = { math.cos(a) * r, t[1] - 0.6, math.sin(a) * r }, color = balls[((i + k) % 4) + 1], mat = (i % 2 == 0) and "Neon" or "Metal", folder = "Decoracion" })
		end
	end
	local star = b:ball({ name = "Estrella", diameter = 1.8, pos = { 0, 23, 0 }, color = { 255, 60, 60 }, mat = "Neon", folder = "Decoracion" })
	MB.light(star, "Point", { color = { 255, 120, 100 }, brightness = 2, range = 18 })
	for _, f in ipairs({ { { -9, 0, -5 }, { -9, 0, 5 } }, { { 9, 0, -5 }, { 9, 0, 5 } }, { { -5, 0, -9 }, { 5, 0, -9 } }, { { -5, 0, 9 }, { 5, 0, 9 } } }) do
		P.woodFence(b, f[1], f[2], 3, { 120, 86, 56 })
	end

	b:box({ name = "Iglesia", size = { 22, 16, 18 }, pos = { 0, 8, 62 }, color = WHITE, mat = "Plaster" })
	b:box({ name = "Zocalo", size = { 22.4, 1.6, 18.4 }, pos = { 0, 0.8, 62 }, color = { 200, 196, 186 }, mat = "Concrete" })
	b:box({ name = "Cornisa", size = { 23, 1, 19 }, pos = { 0, 16.5, 62 }, color = BLUE, mat = "Metal" })
	b:box({ name = "Portico", size = { 8, 10, 3 }, pos = { 0, 5, 51.8 }, color = WHITE, mat = "Plaster" })
	b:box({ name = "Tejadillo", size = { 9, 0.8, 4 }, pos = { 0, 10.4, 51.8 }, color = BLUE, mat = "Metal" })
	b:box({ name = "Puerta", size = { 4, 6.5, 0.4 }, pos = { 0, 3.25, 50.2 }, color = { 110, 70, 40 }, mat = "WoodPlanks", folder = "Decoracion" })
	b:cylinder({ name = "Arco", axis = "z", length = 0.4, diameter = 4, pos = { 0, 6.5, 50.2 }, color = { 110, 70, 40 }, mat = "WoodPlanks", folder = "Decoracion" })
	b:box({ name = "Icono", size = { 3, 3.6, 0.3 }, pos = { 0, 12.8, 52.9 }, color = GOLD, mat = "Metal", folder = "Decoracion" })
	b:box({ name = "Icono", size = { 2.2, 2.8, 0.35 }, pos = { 0, 12.8, 52.9 }, color = BLUE, folder = "Decoracion" })
	P.onionDome(b, { 0, 17, 62 }, 9, BLUE)

	-- Nevada
	P.snowfall(b, { 0, 60, 0 }, { 170, 120 }, 150)

	b:symmetric(function(b)
		-- Casas de troncos (izbas)
		P.houseRow(b, 57, 0, -84, -12, IZBAS, 10)
		P.houseRow(b, -57, 180, -84, 0, IZBAS, 10)

		-- Cúpulas doradas de la iglesia y ventanas
		P.onionDome(b, { -8, 17, 56 }, 4.4, GOLD)
		P.onionDome(b, { -8, 17, 68 }, 4.4, GOLD)
		for _, x in ipairs({ -8, -4.4 }) do
			b:box({ name = "Ventana", size = { 1.6, 4, 0.3 }, pos = { x, 9, 52.9 }, color = { 255, 214, 140 }, mat = "Neon", transparency = 0.3, folder = "Decoracion" })
		end

		-- Leña, montones de nieve y muñeco de nieve
		P.logPile(b, { -30, 0, -18 }, 0, 10)
		P.logPile(b, { -52, 0, 22 }, 90, 8)
		P.snowPile(b, { -20, 0, 14 }, 1.2)
		P.snowPile(b, { -42, 0, -34 }, 1.4)
		P.snowman(b, { -16, 0, -24 })

		-- Lada aparcado con nieve encima
		P.car(b, { -44, 0, 0 }, 80, { 196, 60, 50 })
		local lada = b:at({ -44, 0, 0 }, 80)
		lada:box({ name = "Nieve", size = { 4.8, 0.6, 3.4 }, pos = { 0, 5.55, 1.3 }, color = SNOW, mat = "Snow", folder = "Decoracion" })
		lada:box({ name = "Nieve", size = { 5, 0.4, 3.2 }, pos = { 0, 3.2, -3.7 }, color = SNOW, mat = "Snow", folder = "Decoracion" })

		-- Puestos del mercado
		P.marketStall(b, { -30, 0, 26 }, 0, { 180, 40, 40 }, "ЧАЙ", { { 200, 160, 90 }, { 230, 200, 140 }, { 160, 60, 40 } })
		P.marketStall(b, { -28, 0, -36 }, 180, { 40, 90, 170 }, "БЛИНЫ", { { 240, 200, 120 }, { 200, 60, 60 }, { 250, 240, 220 } })

		-- Abetos, valla y farolas
		P.pineTree(b, { -62, 0, -42 }, 1.2, true)
		P.pineTree(b, { -18, 0, 40 }, 1, true)
		P.pineTree(b, { -70, 0, 42 }, 1.3, true)
		P.woodFence(b, { -78, 0, 30 }, { -62, 0, 30 }, 4, { 120, 86, 56 })
		P.streetLight(b, { -20, 0, 10 }, 0, 16)
		P.streetLight(b, { -50, 0, -10 }, 180, 16)

		-- Empalizada que protege el spawn
		for i = 0, 28 do
			local z = -16.8 + i * 1.2
			local h = 10 + (i % 3) * 0.5
			b:cylinder({ name = "Empalizada", length = h, diameter = 1.25, pos = { -60, h / 2, z }, color = (i % 2 == 0) and { 126, 90, 58 } or { 112, 80, 52 }, mat = "Wood" })
			b:cylinder({ name = "Punta", length = 1, diameter = 0.7, pos = { -60, h + 0.5, z }, color = { 112, 80, 52 }, mat = "Wood", folder = "Decoracion" })
			b:ball({ name = "Nieve", diameter = 1.1, pos = { -60, h, z }, color = SNOW, mat = "Snow", folder = "Decoracion" })
		end
		for _, y in ipairs({ 3, 8 }) do
			b:box({ name = "Travesano", size = { 0.6, 0.8, 34 }, pos = { -59.3, y, 0 }, color = { 100, 72, 48 }, mat = "Wood", folder = "Decoracion" })
		end
		P.poster(b, { -58.9, 5.5, 0 }, -90, { 11, 2.2 }, { 170, 40, 40 }, "ДОБРО ПОЖАЛОВАТЬ", WHITE, "GothamBlack")
		for _, z in ipairs({ -8, 0, 8 }) do
			b:spawn("A", { -70, 0.5, z }, -90)
		end
	end)

	b:bounds(-80, 80, -52, 52, 40)

	b:lighting({
		technology = "Future",
		lighting = {
			ClockTime = 14,
			Brightness = 1.7,
			Ambient = { 120, 128, 146 },
			OutdoorAmbient = { 160, 170, 190 },
			ExposureCompensation = 0.15,
			ShadowSoftness = 0.6,
			EnvironmentDiffuseScale = 0.7,
			EnvironmentSpecularScale = 0.5,
		},
		atmosphere = { density = 0.42, offset = 0.2, color = { 214, 224, 240 }, decay = { 160, 172, 196 }, glare = 0, haze = 2.6 },
		colorCorrection = { contrast = 0.06, saturation = -0.05, tint = { 236, 244, 255 } },
		clouds = { cover = 0.88, density = 0.7, color = { 226, 230, 238 } },
		bloom = { intensity = 0.4, size = 24, threshold = 0.9 },
		sunRays = { intensity = 0.03, spread = 0.4 },
	})
end
]=]
FUENTES_MAPAS["Skatepark"] = [=[
-- SK8 OR DIE: skatepark cubierto. Equipo A en -X, equipo B en +X.
return function(b, MB)
	local P = MB.Props
	local FLOOR = { 204, 170, 200 }
	local FLOOR_DARK = { 186, 148, 184 }
	local TILE = { 238, 226, 224 }
	local YELLOW = { 242, 202, 66 }
	local WALL = { 240, 232, 230 }
	local SKIRT = { 232, 196, 206 }
	local PILLAR = { 62, 60, 76 }
	local BEAM = { 56, 54, 68 }
	local TEAL = { 112, 206, 186 }
	local WOOD = { 230, 196, 144 }
	local DARK = { 40, 38, 50 }
	local PINK = { 245, 122, 192 }
	local CEILING = { 182, 158, 180 }
	local LEDGE = { 244, 220, 204 }

	b.model:SetAttribute("Nombre", "Skatepark SK8 OR DIE")

	-- =================================================================
	--  Exterior (se ve por los ventanales)
	-- =================================================================
	b:box({ name = "Cesped", size = { 700, 1, 700 }, pos = { 0, -1.2, 0 }, color = { 108, 146, 78 }, mat = "Grass", folder = "Decoracion" })
	b:box({ name = "Acera", size = { 160, 0.6, 100 }, pos = { 0, -0.9, 0 }, color = { 190, 186, 180 }, mat = "Pavement", folder = "Decoracion" })
	local trees = { { -50, 64 }, { -18, 74 }, { 16, 66 }, { 48, 74 }, { 80, 62 }, { -82, 70 }, { -42, -68 }, { 6, -76 }, { 40, -66 }, { 76, -72 }, { -78, -64 } }
	for _, t in ipairs(trees) do
		P.tree(b, { t[1], -0.7, t[2] }, 1.25)
	end
	for _, z in ipairs({ -54, 54 }) do
		for x = -66, 66, 22 do
			P.bush(b, { x, -0.6, z }, 1.3)
		end
	end

	-- =================================================================
	--  Nave
	-- =================================================================
	b:box({ name = "Suelo", size = { 140, 1, 80 }, pos = { 0, -0.5, 0 }, color = FLOOR, mat = "SmoothPlastic" })
	b:box({ name = "Techo", size = { 144, 1, 84 }, pos = { 0, 26.5, 0 }, color = CEILING, mat = "Plaster" })
	for _, z in ipairs({ -41, 41 }) do
		b:box({ name = "Zocalo", size = { 144, 5, 2 }, pos = { 0, 2.5, z }, color = SKIRT, mat = "Plaster" })
		b:box({ name = "Muro", size = { 144, 6, 2 }, pos = { 0, 23, z }, color = WALL, mat = "Plaster" })
		b:box({ name = "Neon", size = { 140, 0.3, 0.3 }, pos = { 0, 5.15, z > 0 and 39.9 or -39.9 }, color = PINK, mat = "Neon", folder = "Decoracion" })
	end
	-- Ventanales con marco y travesaños
	for _, x in ipairs({ -56, -42, -28, -14, 0, 14, 28, 42, 56 }) do
		P.window(b, { x, 12.5, 41 }, 0, 11.2, 14.6, PILLAR, { 200, 222, 236 })
		P.window(b, { x, 12.5, -41 }, 180, 11.2, 14.6, PILLAR, { 200, 222, 236 })
	end

	-- Suelo: pasillos de baldosa, zonas y líneas amarillas
	for _, z in ipairs({ -34.5, 34.5 }) do
		b:box({ name = "Pasillo", size = { 140, 0.1, 9 }, pos = { 0, 0.05, z }, color = TILE, mat = "CeramicTiles", folder = "Decoracion" })
		b:box({ name = "Linea", size = { 140, 0.12, 0.5 }, pos = { 0, 0.06, z > 0 and 29.8 or -29.8 }, color = YELLOW, folder = "Decoracion" })
	end
	b:box({ name = "Zona", size = { 60, 0.1, 34 }, pos = { 0, 0.05, 0 }, color = FLOOR_DARK, folder = "Decoracion" })
	for _, x in ipairs({ -30, 30 }) do
		b:box({ name = "Linea", size = { 0.5, 0.12, 34 }, pos = { x, 0.07, 0 }, color = YELLOW, folder = "Decoracion" })
	end

	-- Techo: vigas, tragaluces, conductos y lámparas
	for _, z in ipairs({ -32, -16, 0, 16, 32 }) do
		b:box({ name = "Viga", size = { 140, 1.6, 1.2 }, pos = { 0, 24.6, z }, color = BEAM, mat = "Metal", folder = "Decoracion" })
	end
	for _, x in ipairs({ -60, -40, -20, 0, 20, 40, 60 }) do
		b:box({ name = "Viga", size = { 1.2, 1.4, 80 }, pos = { x, 23.6, 0 }, color = BEAM, mat = "Metal", folder = "Decoracion" })
	end
	for _, z in ipairs({ -24, -8, 8, 24 }) do
		b:box({ name = "Tubo", size = { 140, 0.7, 0.7 }, pos = { 0, 22.6, z }, color = TEAL, folder = "Decoracion" })
		b:box({ name = "Tragaluz", size = { 30, 0.3, 10 }, pos = { 0, 26, z }, color = { 220, 236, 248 }, mat = "Neon", transparency = 0.3, folder = "Decoracion" })
	end
	for _, x in ipairs({ -50, -30, -10, 10, 30, 50 }) do
		b:box({ name = "Tubo", size = { 0.7, 0.7, 80 }, pos = { x, 22, 0 }, color = TEAL, folder = "Decoracion" })
	end
	for _, z in ipairs({ -20, 20 }) do
		b:cylinder({ name = "Conducto", axis = "x", length = 140, diameter = 2.6, pos = { 0, 21, z }, color = { 200, 204, 212 }, mat = "Metal", folder = "Decoracion" })
	end
	for _, x in ipairs({ -45, -15, 15, 45 }) do
		for _, z in ipairs({ -12, 12 }) do
			P.ceilingLight(b, { x, 21.4, z }, true)
		end
	end

	-- =================================================================
	--  Centro: bloque SK8 OR DIE con plataforma alta
	-- =================================================================
	local block = b:box({ name = "Sk8OrDie", size = { 34, 8, 10 }, pos = { 0, 4, 0 }, color = DARK })
	local dots = {
		{ 0.08, 0.3, 0.55, PINK }, { 0.2, 0.8, 0.4, PINK }, { 0.36, 0.2, 0.3, PINK }, { 0.52, 0.85, 0.5, PINK },
		{ 0.66, 0.25, 0.45, PINK }, { 0.82, 0.7, 0.6, PINK }, { 0.94, 0.2, 0.35, PINK },
	}
	for _, face in ipairs({ "Front", "Back" }) do
		MB.sign(block, "SK8 OR DIE", { face = face, font = "LuckiestGuy", color = { 226, 244, 248 }, stroke = { 24, 40, 60 }, dots = dots, width = 0.9, height = 0.78 })
	end
	b:box({ name = "Cubierta", size = { 34, 0.3, 10 }, pos = { 0, 8.15, 0 }, color = { 88, 86, 100 }, mat = "DiamondPlate" })
	for _, z in ipairs({ -5, 5 }) do
		b:cylinder({ name = "Coping", axis = "x", length = 34, diameter = 0.5, pos = { 0, 8.1, z }, color = { 200, 202, 210 }, mat = "Metal" })
		b:box({ name = "Franja", size = { 34.1, 0.6, 0.1 }, pos = { 0, 0.3, z * 1.01 }, color = PINK, folder = "Decoracion" })
	end
	P.railing(b, { -16.5, 8.3, -4.6 }, { 16.5, 8.3, -4.6 }, 3)
	P.railing(b, { -16.5, 8.3, 4.6 }, { 16.5, 8.3, 4.6 }, 3)

	-- Fondo: cuarto de tubo, plataforma y letrero de neón
	P.quarterPipe(b, { 0, 0, 24 }, 0, 44, 10, WOOD, DARK)
	b:box({ name = "Plataforma", size = { 44, 10, 6 }, pos = { 0, 5, 37 }, color = DARK })
	b:box({ name = "Plataforma", size = { 44, 0.4, 6 }, pos = { 0, 10.2, 37 }, color = WOOD, mat = "WoodPlanks" })
	P.railing(b, { -22, 10.4, 39.6 }, { 22, 10.4, 39.6 }, 3)
	P.neonSign(b, { 0, 17.4, 39.4 }, 0, { 22, 4.6 }, "SK8 OR DIE", PINK, "LuckiestGuy")

	-- Frente: funbox con rail
	b:box({ name = "Funbox", size = { 14, 3, 8 }, pos = { 0, 1.5, -27 }, color = LEDGE })
	b:box({ name = "Borde", size = { 14, 0.2, 8 }, pos = { 0, 3.1, -27 }, color = YELLOW, folder = "Decoracion" })
	P.skateRail(b, { -6, 3, -27 }, { 6, 3, -27 }, 1.4)

	b:symmetric(function(b)
		-- Muro lateral con mural pintado
		b:box({ name = "Muro", size = { 2, 26, 84 }, pos = { -71, 13, 0 }, color = WALL, mat = "Plaster" })
		local mural = b:box({ name = "Mural", size = { 40, 12, 0.2 }, pos = { -69.85, 14, 0 }, rot = { 0, -90, 0 }, color = WALL, transparency = 1, folder = "Decoracion" })
		MB.sign(mural, b.mirrored and "SKATE · OR · DIE" or "NO RULES JUST SK8", {
			face = "Front", font = "LuckiestGuy", color = { 255, 255, 255 }, stroke = DARK, bg = { 112, 206, 186 },
			dots = { { 0.1, 0.25, 0.7, PINK }, { 0.3, 0.85, 0.5, YELLOW }, { 0.55, 0.15, 0.4, PINK }, { 0.75, 0.8, 0.6, { 120, 140, 240 } }, { 0.92, 0.3, 0.5, YELLOW } },
			width = 0.9, height = 0.6,
		})
		for x = -63, -7, 14 do
			for _, z in ipairs({ -40.2, 40.2 }) do
				b:box({ name = "Pilar", size = { 2.4, 26, 2.4 }, pos = { x, 13, z }, color = PILLAR, mat = "Metal" })
				b:box({ name = "Base", size = { 3, 1.2, 3 }, pos = { x, 0.6, z }, color = BEAM, mat = "Metal", folder = "Decoracion" })
			end
		end

		-- Rampa a la plataforma central, con rail
		b:wedge({ name = "Rampa", size = { 10, 8, 10 }, pos = { -22, 4, 0 }, rot = { 0, 90, 0 }, color = WOOD, mat = "WoodPlanks" })
		for _, z in ipairs({ -5, 5 }) do
			b:wedge({ name = "LateralRampa", size = { 0.4, 8, 10 }, pos = { -22, 4, z }, rot = { 0, 90, 0 }, color = DARK, folder = "Decoracion" })
		end

		-- Escaleras al fondo y lateral del tubo
		P.stairs(b, { -24.5, 0, 24 }, 0, 8, 1.25, 1.25, 5, LEDGE, YELLOW)
		b:box({ name = "Lateral", size = { 0.4, 10, 10 }, pos = { -22.2, 5, 29 }, color = DARK })
		P.poster(b, { -22.45, 5, 29 }, 90, { 8, 4 }, PINK, "SK8 JAM", { 255, 255, 255 }, "LuckiestGuy")
		P.speaker(b, { -18, 10.4, 38.2 }, 0)

		-- Rampas del funbox y conos
		b:wedge({ name = "Rampa", size = { 8, 3, 6 }, pos = { -10, 1.5, -27 }, rot = { 0, 90, 0 }, color = WOOD, mat = "WoodPlanks" })
		P.cone(b, { -16, 0, -31 })
		P.cone(b, { -17.5, 0, -29.5 })

		-- Cajas de madera (cobertura)
		P.crate(b, { -30, 0, -10 }, 5)
		P.crate(b, { -30, 0, -4.8 }, 5)
		P.crate(b, { -30, 5, -7.4 }, 5, 15)
		P.crate(b, { -42, 0, 14 }, 5, 10)
		P.crate(b, { -42, 0, 19.5 }, 4)
		P.cardboard(b, { -38.6, 0, 18 }, { 2.6, 2, 2.4 }, 20)

		-- Ledge con borde amarillo y kicker
		b:box({ name = "Ledge", size = { 14, 2, 4 }, pos = { -44, 1, -22 }, color = LEDGE })
		b:box({ name = "Borde", size = { 14, 0.2, 4 }, pos = { -44, 2.1, -22 }, color = YELLOW, folder = "Decoracion" })
		b:wedge({ name = "Kicker", size = { 4, 2, 4 }, pos = { -35, 1, -22 }, rot = { 0, -90, 0 }, color = WOOD, mat = "WoodPlanks" })

		-- Pirámide de escalones
		b:box({ name = "Escalon", size = { 12, 1.5, 10 }, pos = { -52, 0.75, 22 }, color = LEDGE })
		b:box({ name = "Escalon", size = { 8, 3, 10 }, pos = { -52, 1.5, 22 }, color = LEDGE })
		b:box({ name = "Escalon", size = { 4, 4.5, 10 }, pos = { -52, 2.25, 22 }, color = LEDGE })
		for _, d in ipairs({ { 12, 1.6 }, { 8, 3.1 }, { 4, 4.6 } }) do
			b:box({ name = "Borde", size = { d[1], 0.2, 10 }, pos = { -52, d[2], 22 }, color = YELLOW, folder = "Decoracion" })
		end

		-- Gradas frente a la pared delantera
		P.bleachers(b, { -46, 0, -31 }, 180, 3, 14, { PINK, TEAL, YELLOW })

		-- Zona de spawn: muro, taquillas, expositor de tablas y máquina de bebidas
		b:box({ name = "MuroSpawn", size = { 2, 7, 26 }, pos = { -58, 3.5, 0 }, color = DARK })
		b:box({ name = "MuroSpawn", size = { 2.4, 0.4, 26.4 }, pos = { -58, 7.2, 0 }, color = PINK, mat = "Neon", folder = "Decoracion" })
		b:box({ name = "Bloque", size = { 2, 3, 10 }, pos = { -55, 1.5, -20 }, color = LEDGE })
		b:box({ name = "Bloque", size = { 2, 3, 10 }, pos = { -55, 1.5, 20 }, color = LEDGE })
		P.lockers(b, { -68.6, 0, -26 }, -90, 4)
		P.skateboardRack(b, { -69.6, 0, 24 }, -90)
		P.vending(b, { -68.2, 0, 33 }, -90, { 210, 50, 60 }, "COLA")
		P.trashCan(b, { -66, 0, 36.5 }, { 64, 62, 76 })
		P.pottedPlant(b, { -66, 0, -36.5 }, 1.2)
		P.bench(b, { -33, 0, 37.4 }, 0)
		P.bench(b, { -33, 0, -37.4 }, 180)
		P.pottedPlant(b, { -24, 0, -37.6 }, 1)

		-- Luces de ambiente de colores
		local accent = b:box({ name = "Acento", size = { 0.4, 0.4, 0.4 }, pos = { -50, 6, 0 }, color = TEAL, mat = "Neon", folder = "Decoracion", transparency = 1 })
		MB.light(accent, "Point", { color = b.mirrored and PINK or TEAL, brightness = 1.2, range = 30 })

		for _, z in ipairs({ -10, 0, 10 }) do
			b:spawn("A", { -65, 0.5, z }, -90)
		end
	end)

	b:lighting({
		technology = "Future",
		lighting = {
			ClockTime = 14.5,
			Brightness = 2.2,
			Ambient = { 128, 112, 132 },
			OutdoorAmbient = { 156, 144, 166 },
			ExposureCompensation = 0.2,
			EnvironmentDiffuseScale = 0.6,
			EnvironmentSpecularScale = 0.4,
		},
		atmosphere = { density = 0.25, color = { 232, 204, 222 }, decay = { 150, 120, 150 }, haze = 0.6, glare = 0 },
		colorCorrection = { brightness = 0.02, contrast = 0.08, saturation = 0.14, tint = { 255, 242, 250 } },
		clouds = { cover = 0.5, density = 0.4, color = { 255, 236, 245 } },
		bloom = { intensity = 0.5, size = 24, threshold = 0.92 },
		sunRays = { intensity = 0.06, spread = 0.5 },
	})
end
]=]

local anterior = ServerStorage:FindFirstChild("MapBuilder")
if anterior then anterior:Destroy() end
local modulo = Instance.new("ModuleScript")
modulo.Name = "MapBuilder"
modulo.Source = FUENTE_MAPBUILDER
local props = Instance.new("ModuleScript")
props.Name = "Props"
props.Source = FUENTE_PROPS
props.Parent = modulo
local carpeta = Instance.new("Folder")
carpeta.Name = "Mapas"
carpeta.Parent = modulo
for nombre, fuente in pairs(FUENTES_MAPAS) do
	local mapa = Instance.new("ModuleScript")
	mapa.Name = nombre
	mapa.Source = fuente
	mapa.Parent = carpeta
end
modulo.Parent = ServerStorage

local MapBuilder = require(modulo)
-- La iluminación Future da sombras a las luces y brillo al neón
pcall(function() game:GetService("Lighting").Technology = Enum.Technology.Future end)
MapBuilder.buildAll()
if VER_MAPA then
	MapBuilder.load(VER_MAPA)
end
print("Mapas de duelo creados en ServerStorage.MapasDuelo. Mapa en Workspace: " .. tostring(VER_MAPA))
