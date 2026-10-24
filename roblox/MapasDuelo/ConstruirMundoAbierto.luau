-- Pega TODO este texto en la barra de comandos de Roblox Studio (Ver > Barra de comandos) y pulsa Enter.
-- Crea ServerStorage.MapBuilder y ServerStorage.MundoAbierto y pone el mundo abierto en Workspace.
-- OJO: borra el terreno que haya en este lugar. Úsalo mejor en un lugar nuevo.
-- Archivo generado por build_bundle.py: edita los .luau de MapBuilder/ y MundoAbierto/ y vuelve a generarlo.

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
local FUENTE_MUNDO = [=[
--[[
	Mundo abierto postapocalíptico (al estilo The Last of Us): unos 4 x 4 km de terreno con costa,
	ríos, lagos, montañas y bosques, y 16 zonas abandonadas unidas por carreteras.

	Va en su propio ModuleScript (ServerStorage.MundoAbierto) con dos hijos:
	  - Mundo: datos del mapa (costa, ríos, carreteras, zonas) y utilidades.
	  - Zonas: un ModuleScript por zona.
	ConstruirMundoAbierto.luau lo crea y lo pone en Workspace con su terreno.
]]
return function(b, MB)
	local W = require(script:WaitForChild("Mundo"))(b, MB)
	b.model:SetAttribute("Nombre", "Mundo Abierto")
	b.model:SetAttribute("Tipo", "MundoAbierto")
	b.model:SetAttribute("Jugadores", 100)

	W.buildTerrain()

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
	W.buildForest(2400)
	b:zone(nil)
	W.buildBounds()

	-- Tarde nublada con niebla: verde apagado y luz cálida entre las nubes
	b:lighting({
		technology = "Future",
		lighting = {
			ClockTime = 16.4,
			Brightness = 2.2,
			Ambient = { 96, 104, 92 },
			OutdoorAmbient = { 136, 144, 128 },
			ExposureCompensation = 0.1,
			ShadowSoftness = 0.35,
			EnvironmentDiffuseScale = 0.6,
			EnvironmentSpecularScale = 0.4,
		},
		atmosphere = { density = 0.38, offset = 0.12, color = { 200, 206, 190 }, decay = { 120, 130, 110 }, glare = 0.6, haze = 2.2 },
		colorCorrection = { contrast = 0.1, saturation = -0.15, tint = { 240, 248, 232 } },
		clouds = { cover = 0.72, density = 0.6, color = { 214, 218, 210 } },
		bloom = { intensity = 0.3, size = 24, threshold = 0.95 },
		sunRays = { intensity = 0.12, spread = 0.7 },
	})
end
]=]
local FUENTE_DATOS = [=[
-- Datos y utilidades del mundo abierto: costa, ríos, lagos, montañas, carreteras, vía del tren,
-- zonas, bosque y coches abandonados. X crece hacia el este y Z hacia el sur; el mundo va de -2048 a 2048.
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
	W.sea = { { 1150, 2048, -2048, 2048 }, { -2048, 2048, 1250, 2048 }, { 700, 2048, 650, 2048 } }
	W.land = { { -2048, 1150, -2048, 650 }, { -2048, 700, 650, 1250 }, { 700, 1100, 650, 950 } }

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

	-- Montañas de roca en los bordes norte y oeste, y colinas de hierba en el interior: { x, z, radio, cima }
	W.hills = {}
	for _, x in ipairs({ -1960, -1420, -1080, -760, 40, 380, 720, 1060 }) do
		table.insert(W.hills, { x, -2048, 180, 90, "Rock" })
	end
	for _, z in ipairs({ -1620, -1280, -940, -600, -260, 80, 420, 760, 1100, 1340 }) do
		table.insert(W.hills, { -2048, z, 180, 90, "Rock" })
	end
	for _, h in ipairs({
		{ -450, -1450, 180, 30 }, { 100, -750, 180, 30 }, { 600, -1000, 180, 30 }, { 700, 250, 220, 45 },
		{ -560, 330, 180, 30 }, { 300, 150, 180, 30 }, { 1200, -1100, 220, 40 }, { 60, -1700, 180, 30 },
		{ -760, 1240, 180, 25 }, { -1850, -1300, 180, 35 }, { -700, -1150, 180, 30 }, { -80, -20, 200, 35 },
		{ -1640, -300, 180, 30 }, { -1700, 880, 180, 30 },
	}) do
		table.insert(W.hills, { h[1], h[2], h[3], h[4], "Grass" })
	end
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
	function W.polylineDist(px, pz, pts)
		local best = math.huge
		for i = 1, #pts - 1 do
			best = math.min(best, segDist(px, pz, pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2]))
		end
		return best
	end

	-- Altura del suelo (colinas, montañas y meseta; el resto es llano a 0)
	function W.groundY(x, z)
		local y = 0
		for _, h in ipairs(W.hills) do
			local dx, dz = x - h[1], z - h[2]
			local d2 = dx * dx + dz * dz
			if d2 < h[3] * h[3] then
				y = math.max(y, h[4] - h[3] + math.sqrt(h[3] * h[3] - d2))
			end
		end
		local p = W.plateau
		local d = math.sqrt((x - p.x) ^ 2 + (z - p.z) ^ 2)
		if d < p.rBase then
			y = math.max(y, d <= p.rTop and p.top or p.top * (p.rBase - d) / (p.rBase - p.rTop))
		end
		return y
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
	--  Terreno: mar, tierra, costa, montañas, meseta, cantera, ríos y lagos
	-- =================================================================
	function W.buildTerrain()
		b:terrainSettings({
			colors = {
				Grass = { 74, 98, 58 }, LeafyGrass = { 64, 88, 50 }, Ground = { 96, 84, 66 }, Mud = { 76, 66, 52 },
				Rock = { 104, 104, 100 }, Sand = { 186, 174, 140 },
			},
			water = { color = { 44, 70, 68 }, transparency = 0.35, waveSize = 0.12, waveSpeed = 6, reflectance = 0.3 },
		})
		for _, r in ipairs(W.sea) do
			local cx, cz, sx, sz = (r[1] + r[2]) / 2, (r[3] + r[4]) / 2, r[2] - r[1], r[4] - r[3]
			b:terrain({ mat = "Sand", pos = { cx, -31, cz }, size = { sx, 6, sz } })
			b:terrain({ mat = "Water", pos = { cx, -16, cz }, size = { sx, 24, sz } })
		end
		for _, r in ipairs(W.land) do
			b:terrain({ mat = "Grass", pos = { (r[1] + r[2]) / 2, -12, (r[3] + r[4]) / 2 }, size = { r[2] - r[1], 24, r[4] - r[3] } })
		end
		-- Costa: tierra detrás de cada tramo, franja de arena y playa en cuesta hacia el mar
		eachSegment(W.coast, function(a, c, len, yaw, mx, mz, ux, uz)
			local nx, nz = uz, -ux
			if nx + nz < 0 then
				nx, nz = -nx, -nz
			end
			b:terrain({ mat = "Grass", pos = { mx - nx * 225, -12, mz - nz * 225 }, size = { len + 120, 24, 450 }, rot = { 0, yaw, 0 } })
			b:terrain({ mat = "Sand", pos = { mx - nx * 15, -2, mz - nz * 15 }, size = { len + 60, 4, 30 }, rot = { 0, yaw, 0 } })
			-- La cuña sube hacia +Z local: se gira para que la parte alta quede en tierra
			local wedgeYaw = yaw
			local lzx, lzz = math.sin(math.rad(yaw)), math.cos(math.rad(yaw))
			if lzx * nx + lzz * nz > 0 then
				wedgeYaw = yaw + 180
			end
			b:terrain({ shape = "Wedge", mat = "Sand", pos = { mx + nx * 120, -18, mz + nz * 120 }, size = { len + 60, 36, 240 }, rot = { 0, wedgeYaw, 0 } })
		end)
		for i = 2, #W.coast - 1 do
			b:terrain({ shape = "Ball", mat = "Sand", pos = { W.coast[i][1], -70, W.coast[i][2] }, radius = 70 })
		end
		for _, h in ipairs(W.hills) do
			b:terrain({ shape = "Ball", mat = h[5], pos = { h[1], h[4] - h[3], h[2] }, radius = h[3] })
		end
		local p = W.plateau
		for i = 1, 8 do
			b:terrain({ shape = "Cylinder", mat = "Grass", pos = { p.x, 2 * i - 1, p.z }, radius = p.rBase - (i - 1) * 20, height = 2 })
		end
		-- Cantera: roca y terrazas excavadas con una charca en el fondo
		local q = W.quarry
		b:terrain({ shape = "Cylinder", mat = "Rock", pos = { q.x, -30, q.z }, radius = 190, height = 60 })
		for i, t in ipairs({ { 170, -12 }, { 130, -24 }, { 90, -36 }, { 55, -48 } }) do
			b:terrain({ shape = "Cylinder", mat = "Air", pos = { q.x, (t[2] + 40) / 2, q.z }, radius = t[1], height = 40 - t[2] })
			-- Rampa de roca para bajar a cada terraza
			local a = math.rad(i * 95)
			local r = t[1] + 10
			b:terrain({ shape = "Wedge", mat = "Rock", pos = { q.x + math.cos(a) * r, t[2] + 6, q.z + math.sin(a) * r }, size = { 14, 12, 36 }, rot = { 0, -math.deg(a), 0 } })
		end
		b:terrain({ shape = "Cylinder", mat = "Water", pos = { q.x, -51, q.z }, radius = 38, height = 10 })

		-- Ríos: orillas de barro, cauce excavado y agua
		for _, river in ipairs(W.rivers) do
			eachSegment(river.points, function(a, c, len, yaw, mx, mz)
				b:terrain({ mat = "Mud", pos = { mx, -2, mz }, size = { len + 6, 4, river.width + 20 }, rot = { 0, yaw, 0 } })
			end)
			for i = 2, #river.points - 1 do
				local pt = river.points[i]
				b:terrain({ shape = "Cylinder", mat = "Mud", pos = { pt[1], -2, pt[2] }, radius = river.width / 2 + 10, height = 4 })
			end
		end
		for _, l in ipairs(W.lakes) do
			b:terrain({ shape = "Cylinder", mat = "Mud", pos = { l[1], -2, l[2] }, radius = l[3] + 12, height = 4 })
		end
		for _, mat in ipairs({ "Air", "Water" }) do
			local y, h = (mat == "Air") and 18 or -10, (mat == "Air") and 44 or 12
			for _, river in ipairs(W.rivers) do
				local n = #river.points
				eachSegment(river.points, function(a, c, len, yaw, mx, mz, ux, uz, i)
					local extra = (river.mouth and i == n - 1) and 70 or 0
					b:terrain({ mat = mat, pos = { mx + ux * extra / 2, y, mz + uz * extra / 2 }, size = { len + extra, h, river.width }, rot = { 0, yaw, 0 } })
				end)
				for i = 2, n - 1 do
					local pt = river.points[i]
					b:terrain({ shape = "Cylinder", mat = mat, pos = { pt[1], y, pt[2] }, radius = river.width / 2, height = h })
				end
			end
			for _, l in ipairs(W.lakes) do
				b:terrain({ shape = "Cylinder", mat = mat, pos = { l[1], (mat == "Air") and 18 or -11, l[2] }, radius = l[3], height = (mat == "Air") and 44 or 14 })
			end
		end
	end

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
	--  Bosque, rocas y coches abandonados
	-- =================================================================
	local OAK = { { 72, 100, 56 }, { 86, 114, 62 }, { 64, 90, 50 }, { 98, 112, 60 }, { 120, 110, 62 } }
	local PINE = { { 48, 82, 56 }, { 56, 90, 60 }, { 42, 74, 50 } }
	function W.tree(x, z, kind, s)
		local y = W.groundY(x, z) - 0.6
		if kind == "pino" then
			local c = PINE[math.floor(W.rand() * #PINE) + 1]
			b:cylinder({ name = "Tronco", length = 16 * s, diameter = 1.3 * s, pos = { x, y + 8 * s, z }, color = { 86, 64, 48 }, mat = "Wood" })
			for i, t in ipairs({ { 10, 7 }, { 7.5, 11 }, { 4.6, 15 } }) do
				b:cylinder({ name = "Copa", length = 3.6 * s, diameter = t[1] * s, pos = { x, y + t[2] * s, z }, color = c, mat = "LeafyGrass", folder = "Decoracion" })
			end
		elseif kind == "muerto" then
			b:cylinder({ name = "Tronco", length = 12 * s, diameter = 1.2 * s, pos = { x, y + 6 * s, z }, color = { 104, 94, 84 }, mat = "Wood" })
			P.segment(b, { x, y + 8 * s, z }, { x + 3 * s, y + 12 * s, z + 1 * s }, 0.5 * s, { 104, 94, 84 }, "Wood", "Decoracion")
			P.segment(b, { x, y + 9 * s, z }, { x - 2.4 * s, y + 13 * s, z - 1.6 * s }, 0.45 * s, { 104, 94, 84 }, "Wood", "Decoracion")
		else
			local c = OAK[math.floor(W.rand() * #OAK) + 1]
			b:cylinder({ name = "Tronco", length = 10 * s, diameter = 1.7 * s, pos = { x, y + 5 * s, z }, color = { 90, 70, 52 }, mat = "Wood" })
			b:ball({ name = "Copa", diameter = 10 * s, pos = { x, y + 12 * s, z }, color = c, mat = "LeafyGrass", folder = "Decoracion" })
			b:ball({ name = "Copa", diameter = 7.5 * s, pos = { x + 3 * s, y + 10 * s, z + 1.2 * s }, color = P.lighter(c, 8), mat = "LeafyGrass", folder = "Decoracion" })
			b:ball({ name = "Copa", diameter = 7 * s, pos = { x - 2.6 * s, y + 10.6 * s, z - 1.6 * s }, color = P.darker(c, 8), mat = "LeafyGrass", folder = "Decoracion" })
		end
	end

	-- Densidad del bosque: hay zonas espesas y claros
	local function density(x, z)
		return 0.45 + 0.3 * math.sin(x / 310 + 1.3) * math.cos(z / 270 - 0.4) + 0.25 * math.sin((x + z) / 530)
	end

	function W.buildForest(target)
		local placed, tries = 0, 0
		while placed < target and tries < target * 8 do
			tries = tries + 1
			local x, z = W.range(-2000, 1560), W.range(-2000, 1500)
			local d = density(x, z)
			if W.rand() < d * d * 1.3 and W.isLand(x, z, 60) and not W.inZone(x, z, 14) and not W.nearRoad(x, z, 10) and not W.nearWater(x, z, 16) and W.groundY(x, z) < 70 then
				local r = W.rand()
				local kind = (r < 0.08) and "muerto" or ((z < -900 or r < 0.3) and "pino" or "roble")
				W.tree(x, z, kind, W.range(0.9, 1.5))
				placed = placed + 1
			end
		end
		-- Rocas sueltas
		for _ = 1, 160 do
			local x, z = W.range(-2000, 1500), W.range(-2000, 1450)
			if W.isLand(x, z, 40) and not W.inZone(x, z, 10) and not W.nearRoad(x, z, 6) and not W.nearWater(x, z, 10) then
				local s = W.range(2, 6)
				b:ball({ name = "Roca", diameter = s, pos = { x, W.groundY(x, z) + s * 0.2, z }, color = { 112, 110, 104 }, mat = "Slate" })
			end
		end
		return placed
	end

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
local FUENTES_ZONAS = {}
FUENTES_ZONAS["Antena"] = [=[
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
FUENTES_ZONAS["Cantera"] = [=[
-- Cantera: gran agujero de roca en terrazas (el terreno se excava en Mundo.luau) con charca en el fondo,
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
FUENTES_ZONAS["Ciudadela"] = [=[
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
	for k = 0, 3 do
		P.bench(b, { -170 + k * 9, 0, 1090 }, 0, { 120, 90, 60 })
	end
	W.spawn(-240, 920, 90)
	W.spawn(-100, 920, -90)
end
]=]
FUENTES_ZONAS["ColinaAlta"] = [=[
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
	MB.light(fire, "Point", { color = { 255, 140, 60 }, brightness = 1.5, range = 16 })
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
FUENTES_ZONAS["Comisaria"] = [=[
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
FUENTES_ZONAS["Condado"] = [=[
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
FUENTES_ZONAS["Estacion"] = [=[
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
FUENTES_ZONAS["Granjas"] = [=[
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
FUENTES_ZONAS["Ladera"] = [=[
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
FUENTES_ZONAS["LagoSereno"] = [=[
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
	W.spawn(cx + 10, cz - 20, 0)
end
]=]
FUENTES_ZONAS["Megatienda"] = [=[
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
FUENTES_ZONAS["Motel"] = [=[
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
FUENTES_ZONAS["Penal"] = [=[
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
FUENTES_ZONAS["Refugio"] = [=[
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
FUENTES_ZONAS["Villamuro"] = [=[
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
FUENTES_ZONAS["ZonaProhibida"] = [=[
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

local function modulo(nombre, fuente, padre)
	local m = Instance.new("ModuleScript")
	m.Name = nombre
	m.Source = fuente
	m.Parent = padre
	return m
end

-- MapBuilder (si ya existía, conserva sus mapas de duelo)
local mapBuilder = modulo("MapBuilder", FUENTE_MAPBUILDER)
modulo("Props", FUENTE_PROPS, mapBuilder)
local anterior = ServerStorage:FindFirstChild("MapBuilder")
if anterior then
	local mapas = anterior:FindFirstChild("Mapas")
	if mapas then mapas.Parent = mapBuilder end
	anterior:Destroy()
end
mapBuilder.Parent = ServerStorage

-- MundoAbierto con sus datos y una carpeta de zonas
local viejo = ServerStorage:FindFirstChild("MundoAbierto")
if viejo then viejo:Destroy() end
local mundo = modulo("MundoAbierto", FUENTE_MUNDO)
modulo("Mundo", FUENTE_DATOS, mundo)
local carpeta = Instance.new("Folder")
carpeta.Name = "Zonas"
carpeta.Parent = mundo
for nombre, fuente in pairs(FUENTES_ZONAS) do
	modulo(nombre, fuente, carpeta)
end
mundo.Parent = ServerStorage

local MapBuilder = require(mapBuilder)
pcall(function() game:GetService("Lighting").Technology = Enum.Technology.Future end)
-- Con un mapa tan grande, cada jugador carga solo lo que tiene cerca
pcall(function() workspace.StreamingEnabled = true end)
print("Construyendo el mundo abierto... puede tardar un minuto.")
local inicio = os.clock()
local modelo = MapBuilder.build("MundoAbierto", require(mundo))
MapBuilder.show(modelo, "MundoAbierto")
print(string.format("Mundo abierto listo en %.0f segundos. Guarda el lugar para conservarlo.", os.clock() - inicio))
