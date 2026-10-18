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

function Builder:folder(name)
	local folder = self.folders[name]
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = self.model
		self.folders[name] = folder
	end
	return folder
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

-- Devuelve { A = { CFrame, ... }, B = { CFrame, ... } }
function MapBuilder.getSpawns(map)
	local spawns = { A = {}, B = {} }
	local folder = map:FindFirstChild("Spawns")
	if folder then
		for _, part in ipairs(folder:GetChildren()) do
			local team = part:GetAttribute("Team")
			if spawns[team] then
				table.insert(spawns[team], part.CFrame + Vector3.new(0, 3, 0))
			end
		end
	end
	return spawns
end

-- Pone un mapa en Workspace (quitando el anterior) y aplica su iluminación
function MapBuilder.load(name, position)
	local folder = game:GetService("ServerStorage"):FindFirstChild(CONTAINER_NAME)
	local template = folder and folder:FindFirstChild(name)
	assert(template, "No existe el mapa " .. tostring(name) .. ". Ejecuta MapBuilder.buildAll() primero.")
	local current = workspace:FindFirstChild("MapaActual")
	if current then
		current:Destroy()
	end
	local map = template:Clone()
	map.Name = "MapaActual"
	map:SetAttribute("Mapa", name)
	if position then
		map:PivotTo(CFrame.new(position))
	end
	map.Parent = workspace
	MapBuilder.applyLighting(map)
	return map, MapBuilder.getSpawns(map)
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
	function P.car(g, pos, rotY, color)
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
			c:box({ name = "Faro", size = { 1.2, 0.5, 0.15 }, pos = { x, 2.2, -5.62 }, color = { 255, 244, 214 }, mat = "Neon", folder = "Decoracion" })
			c:box({ name = "Piloto", size = { 1.2, 0.5, 0.15 }, pos = { x, 2.2, 5.62 }, color = { 210, 30, 30 }, mat = "Neon", folder = "Decoracion" })
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
