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
