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
	return config
end

-- =====================================================================
--  Piezas reutilizables
-- =====================================================================
local Props = MapBuilder.Props

-- Caja de madera (pos = centro de la base)
function Props.crate(g, pos, size, rotY, color)
	local c = g:at(pos, rotY)
	local s = size or 5
	local wood = color or { 206, 160, 104 }
	c:box({ name = "Caja", size = { s, s, s }, pos = { 0, s / 2, 0 }, color = wood, mat = "WoodPlanks" })
	local dark = { wood[1] - 50, wood[2] - 45, wood[3] - 35 }
	c:box({ name = "Refuerzo", size = { s + 0.1, 0.5, s + 0.1 }, pos = { 0, 0.25, 0 }, color = dark, mat = "Wood" })
	c:box({ name = "Refuerzo", size = { s + 0.1, 0.5, s + 0.1 }, pos = { 0, s - 0.25, 0 }, color = dark, mat = "Wood" })
end

-- Árbol low-poly decorativo
function Props.tree(g, pos, scale, palette)
	local t = g:at(pos, 0)
	local s = scale or 1
	local leaves = palette or { { 196, 120, 58 }, { 168, 108, 50 }, { 134, 128, 62 } }
	t:cylinder({ name = "Tronco", length = 8 * s, diameter = 1.5 * s, pos = { 0, 4 * s, 0 }, color = { 98, 70, 50 }, mat = "Wood", folder = "Decoracion" })
	local blobs = {
		{ 0, 9 * s, 0, 9 * s, 1 },
		{ 2.6 * s, 7.6 * s, 1.2 * s, 6.5 * s, 2 },
		{ -2.4 * s, 8 * s, -1.4 * s, 7 * s, 3 },
		{ 0.8 * s, 11.6 * s, -0.8 * s, 6 * s, 2 },
		{ -1 * s, 7.4 * s, 2.4 * s, 5.5 * s, 1 },
	}
	for _, b in ipairs(blobs) do
		t:ball({ name = "Copa", diameter = b[4], pos = { b[1], b[2], b[3] }, color = leaves[b[5]], mat = "LeafyGrass", folder = "Decoracion" })
	end
end

-- Coche simple (frente hacia -Z local)
function Props.car(g, pos, rotY, color)
	local c = g:at(pos, rotY)
	local paint = color or { 190, 50, 50 }
	c:box({ name = "Carroceria", size = { 5.2, 2.4, 11 }, pos = { 0, 1.9, 0 }, color = paint, mat = "SmoothPlastic", reflectance = 0.05 })
	c:box({ name = "Cabina", size = { 4.6, 2, 5.6 }, pos = { 0, 4.1, 0.6 }, color = { 40, 46, 56 }, mat = "Glass", transparency = 0.15 })
	c:box({ name = "Techo", size = { 4.7, 0.3, 5 }, pos = { 0, 5.2, 0.6 }, color = paint })
	for _, w in ipairs({ { -2.5, -3.5 }, { 2.5, -3.5 }, { -2.5, 3.5 }, { 2.5, 3.5 } }) do
		c:cylinder({ name = "Rueda", axis = "x", length = 1, diameter = 2.6, pos = { w[1], 1.3, w[2] }, color = { 30, 30, 32 } })
	end
	c:box({ name = "Faro", size = { 4.2, 0.6, 0.2 }, pos = { 0, 2.3, -5.55 }, color = { 255, 240, 200 }, mat = "Neon", folder = "Decoracion" })
	c:box({ name = "Piloto", size = { 4.2, 0.5, 0.2 }, pos = { 0, 2.3, 5.55 }, color = { 200, 30, 30 }, mat = "Neon", folder = "Decoracion" })
end

-- Camión de reparto (frente hacia -Z local). Devuelve la caja para poner carteles
function Props.truck(g, pos, rotY, color)
	local t = g:at(pos, rotY)
	t:box({ name = "Chasis", size = { 7, 1.2, 22 }, pos = { 0, 1.6, 2 }, color = { 50, 50, 56 }, mat = "Metal" })
	local cargo = t:box({ name = "Caja", size = { 8, 8.5, 15 }, pos = { 0, 6.45, 5.5 }, color = color or { 236, 236, 232 } })
	t:box({ name = "Cabina", size = { 7.6, 6, 5.5 }, pos = { 0, 5.2, -5.3 }, color = { 200, 60, 50 } })
	t:box({ name = "Parabrisas", size = { 6.6, 2.4, 0.2 }, pos = { 0, 6.4, -8.1 }, color = { 40, 46, 56 }, mat = "Glass", transparency = 0.15, folder = "Decoracion" })
	for _, w in ipairs({ { -3.6, -5.5 }, { 3.6, -5.5 }, { -3.6, 4 }, { 3.6, 4 }, { -3.6, 9 }, { 3.6, 9 } }) do
		t:cylinder({ name = "Rueda", axis = "x", length = 1, diameter = 3, pos = { w[1], 1.5, w[2] }, color = { 30, 30, 32 } })
	end
	return cargo
end

-- Barrera de hormigón tipo New Jersey (a lo largo de X local)
function Props.barrier(g, pos, rotY)
	local b = g:at(pos, rotY)
	b:box({ name = "Barrera", size = { 8, 2, 2.4 }, pos = { 0, 1, 0 }, color = { 228, 226, 222 }, mat = "Concrete" })
	b:box({ name = "Barrera", size = { 8, 1.6, 1.2 }, pos = { 0, 2.8, 0 }, color = { 228, 226, 222 }, mat = "Concrete" })
	for _, x in ipairs({ -2.6, 2.6 }) do
		b:box({ name = "Franja", size = { 1.6, 1.2, 2.5 }, pos = { x, 1, 0 }, color = { 205, 45, 45 }, folder = "Decoracion" })
	end
end

-- Contenedor de 21 x 9 x 8.5 a lo largo de X local. open = túnel atravesable
function Props.container(g, pos, rotY, color, open)
	local c = g:at(pos, rotY)
	local L, H, W = 21, 9, 8.5
	local dark = { math.max(color[1] - 40, 0), math.max(color[2] - 40, 0), math.max(color[3] - 40, 0) }
	if open then
		c:box({ name = "Suelo", size = { L, 0.6, W }, pos = { 0, 0.3, 0 }, color = dark, mat = "DiamondPlate" })
		c:box({ name = "Techo", size = { L, 0.6, W }, pos = { 0, H - 0.3, 0 }, color = color, mat = "Metal" })
		c:box({ name = "Pared", size = { L, H, 0.6 }, pos = { 0, H / 2, -W / 2 + 0.3 }, color = color, mat = "Metal" })
		c:box({ name = "Pared", size = { L, H, 0.6 }, pos = { 0, H / 2, W / 2 - 0.3 }, color = color, mat = "Metal" })
	else
		c:box({ name = "Contenedor", size = { L, H, W }, pos = { 0, H / 2, 0 }, color = color, mat = "Metal" })
		-- Puertas en el extremo +X
		c:box({ name = "Puerta", size = { 0.3, H - 0.6, W / 2 - 0.3 }, pos = { L / 2 + 0.1, H / 2, -W / 4 }, color = dark, mat = "Metal", folder = "Decoracion" })
		c:box({ name = "Puerta", size = { 0.3, H - 0.6, W / 2 - 0.3 }, pos = { L / 2 + 0.1, H / 2, W / 4 }, color = dark, mat = "Metal", folder = "Decoracion" })
	end
	-- Nervios corrugados en los laterales
	for i = 0, 8 do
		local x = -L / 2 + 1.5 + i * 2.25
		for _, side in ipairs({ -1, 1 }) do
			c:box({ name = "Nervio", size = { 0.5, H - 0.8, 0.25 }, pos = { x, H / 2, side * (W / 2 + 0.1) }, color = dark, mat = "Metal", folder = "Decoracion" })
		end
	end
end

-- Poste eléctrico de ladrillo con travesaño
function Props.pole(g, pos, height)
	local p = g:at(pos, 0)
	p:box({ name = "Poste", size = { 1.8, height, 1.8 }, pos = { 0, height / 2, 0 }, color = { 150, 82, 66 }, mat = "Brick" })
	p:box({ name = "Travesano", size = { 9, 0.6, 0.6 }, pos = { 0, height - 1.5, 0 }, color = { 90, 70, 55 }, mat = "Wood", folder = "Decoracion" })
	for _, x in ipairs({ -3.5, 0, 3.5 }) do
		p:cylinder({ name = "Aislante", length = 0.8, diameter = 0.4, pos = { x, height - 0.8, 0 }, color = { 200, 200, 190 }, folder = "Decoracion" })
	end
end

-- Lámpara de techo con panel de neón y luz hacia abajo
function Props.ceilingLight(g, pos, withLight, color)
	local l = g:at(pos, 0)
	l:box({ name = "Carcasa", size = { 10, 0.6, 3 }, pos = { 0, 0, 0 }, color = { 50, 48, 60 }, folder = "Decoracion" })
	local panel = l:box({ name = "Panel", size = { 9, 0.2, 2.4 }, pos = { 0, -0.4, 0 }, color = color or { 255, 238, 214 }, mat = "Neon", folder = "Decoracion" })
	if withLight then
		MapBuilder.light(panel, "Surface", { face = "Bottom", brightness = 1.4, range = 38, angle = 120, color = color or { 255, 236, 210 } })
	end
end

-- Barandilla entre dos puntos a la misma altura
function Props.railing(g, from, to, height, color)
	local dx, dz = to[1] - from[1], to[3] - from[3]
	local length = math.sqrt(dx * dx + dz * dz)
	local yaw = math.deg(math.atan2(-dz, dx))
	local mid = { (from[1] + to[1]) / 2, from[2], (from[3] + to[3]) / 2 }
	local r = g:at(mid, yaw)
	local metal = color or { 186, 188, 196 }
	local posts = math.max(2, math.floor(length / 4) + 1)
	for i = 0, posts - 1 do
		local x = -length / 2 + i * length / (posts - 1)
		r:box({ name = "Poste", size = { 0.3, height, 0.3 }, pos = { x, height / 2, 0 }, color = metal, mat = "Metal" })
	end
	r:box({ name = "Pasamanos", size = { length, 0.3, 0.3 }, pos = { 0, height, 0 }, color = metal, mat = "Metal" })
	r:box({ name = "Barra", size = { length, 0.2, 0.2 }, pos = { 0, height / 2, 0 }, color = metal, mat = "Metal", folder = "Decoracion" })
end

-- Escalera: sube hacia +Z local
function Props.stairs(g, pos, rotY, steps, stepHeight, stepDepth, width, color)
	local s = g:at(pos, rotY)
	for i = 1, steps do
		local h = i * stepHeight
		s:box({ name = "Escalon", size = { width, h, stepDepth }, pos = { 0, h / 2, (i - 0.5) * stepDepth }, color = color })
	end
end

-- Cuarto de tubo (quarter pipe): curva que sube hacia +Z local
function Props.quarterPipe(g, pos, rotY, width, radius, surface, side)
	local q = g:at(pos, rotY)
	local segments = 8
	local prevZ, prevY = 0, 0
	for i = 1, segments do
		local phi = math.rad(90 * i / segments)
		local z, y = radius * math.sin(phi), radius - radius * math.cos(phi)
		local dz, dy = z - prevZ, y - prevY
		local len = math.sqrt(dz * dz + dy * dy)
		local angle = math.deg(math.atan2(dy, dz))
		q:box({ name = "Curva", size = { width, 0.6, len + 0.15 }, pos = { 0, (y + prevY) / 2, (z + prevZ) / 2 }, rot = { -angle, 0, 0 }, color = surface, mat = "WoodPlanks" })
		-- Relleno bajo la curva para que no haya huecos
		local fill = math.min(y, prevY) - 0.3
		if fill > 0.2 then
			q:box({ name = "Relleno", size = { width - 0.2, fill, dz }, pos = { 0, fill / 2, (z + prevZ) / 2 }, color = side })
		end
		prevZ, prevY = z, y
	end
	q:cylinder({ name = "Coping", axis = "x", length = width, diameter = 0.7, pos = { 0, radius, radius }, color = { 190, 192, 200 }, mat = "Metal" })
end

-- Aire acondicionado industrial
function Props.acUnit(g, pos, rotY)
	local a = g:at(pos, rotY)
	a:box({ name = "AireAcondicionado", size = { 7, 4.5, 5 }, pos = { 0, 2.25, 0 }, color = { 182, 186, 192 }, mat = "Metal" })
	a:box({ name = "Rejilla", size = { 6, 3, 0.2 }, pos = { 0, 2.4, -2.55 }, color = { 110, 114, 122 }, mat = "DiamondPlate", folder = "Decoracion" })
	a:cylinder({ name = "Ventilador", length = 0.4, diameter = 3.6, pos = { 0, 4.6, 0.5 }, color = { 60, 62, 70 }, folder = "Decoracion" })
end

-- Surtidor de gasolina
function Props.pump(g, pos, rotY)
	local p = g:at(pos, rotY)
	p:box({ name = "Surtidor", size = { 2.4, 5, 1.6 }, pos = { 0, 2.5, 0 }, color = { 236, 232, 228 } })
	p:box({ name = "FranjaRoja", size = { 2.5, 1, 1.7 }, pos = { 0, 4.6, 0 }, color = { 205, 45, 45 }, folder = "Decoracion" })
	p:box({ name = "Pantalla", size = { 1.6, 0.8, 0.1 }, pos = { 0, 3.4, -0.85 }, color = { 120, 230, 140 }, mat = "Neon", folder = "Decoracion" })
	p:box({ name = "Pantalla", size = { 1.6, 0.8, 0.1 }, pos = { 0, 3.4, 0.85 }, color = { 120, 230, 140 }, mat = "Neon", folder = "Decoracion" })
	p:box({ name = "Manguera", size = { 0.25, 2.6, 0.25 }, pos = { 1.35, 2.2, 0 }, color = { 30, 30, 30 }, folder = "Decoracion" })
end

-- Bidón metálico
function Props.drum(g, pos, color)
	g:cylinder({ name = "Bidon", length = 3.4, diameter = 2.4, pos = { pos[1], pos[2] + 1.7, pos[3] }, color = color or { 48, 92, 150 }, mat = "Metal" })
end

-- Palé de madera
function Props.pallet(g, pos, rotY)
	local p = g:at(pos, rotY)
	for _, z in ipairs({ -1.6, 0, 1.6 }) do
		p:box({ name = "Taco", size = { 4.4, 0.5, 0.6 }, pos = { 0, 0.25, z }, color = { 150, 110, 70 }, mat = "Wood" })
	end
	p:box({ name = "Tablas", size = { 4.4, 0.3, 4 }, pos = { 0, 0.65, 0 }, color = { 176, 132, 86 }, mat = "WoodPlanks" })
end

-- Banco
function Props.bench(g, pos, rotY)
	local b = g:at(pos, rotY)
	b:box({ name = "Asiento", size = { 6, 0.5, 1.6 }, pos = { 0, 1.6, 0 }, color = { 150, 100, 60 }, mat = "WoodPlanks" })
	b:box({ name = "Respaldo", size = { 6, 1.4, 0.3 }, pos = { 0, 2.6, 0.7 }, color = { 150, 100, 60 }, mat = "WoodPlanks" })
	for _, x in ipairs({ -2.5, 2.5 }) do
		b:box({ name = "Pata", size = { 0.4, 1.4, 1.4 }, pos = { x, 0.7, 0 }, color = { 50, 50, 56 }, mat = "Metal" })
	end
end

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
		Lighting[name] = value
	end
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:GetAttribute("DeMapa") or (child:IsA("Atmosphere") and config:FindFirstChildOfClass("Atmosphere")) then
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
local FUENTES_MAPAS = {}
FUENTES_MAPAS["Azotea"] = [=[
-- Azotea Neón: tejado de noche con un gran cartel luminoso. Equipo A en -X, B en +X.
return function(b, MB)
	local P = MB.Props
	local ROOF = { 84, 82, 94 }
	local PARAPET = { 106, 104, 118 }
	local HUT = { 92, 88, 104 }
	local PINK = { 255, 60, 180 }
	local CYAN = { 40, 230, 255 }
	local DARK = { 34, 33, 44 }
	local METAL = { 150, 156, 166 }
	local WINDOW = { 255, 204, 130 }

	b.model:SetAttribute("Nombre", "Azotea Neón")

	-- Edificio y ciudad de fondo
	b:box({ name = "Calle", size = { 800, 1, 800 }, pos = { 0, -80.5, 0 }, color = { 28, 28, 34 }, mat = "Asphalt", folder = "Decoracion" })
	b:box({ name = "Edificio", size = { 124, 80, 84 }, pos = { 0, -40.5, 0 }, color = { 50, 48, 62 }, mat = "Concrete" })
	local city = {
		{ -120, -90, 40, 40, 150 }, { -60, -125, 50, 30, 120 }, { 10, -132, 40, 40, 170 }, { 80, -112, 40, 40, 130 },
		{ 132, -40, 40, 50, 160 }, { 136, 50, 40, 40, 110 }, { 72, 120, 50, 40, 140 }, { -10, 132, 40, 40, 125 },
		{ -82, 116, 40, 40, 160 }, { -136, 30, 40, 50, 130 }, { -142, -32, 30, 30, 100 },
	}
	for _, c in ipairs(city) do
		local x, z, w, d, h = c[1], c[2], c[3], c[4], c[5]
		b:box({ name = "Rascacielos", size = { w, h, d }, pos = { x, -80 + h / 2, z }, color = { 44, 42, 56 }, mat = "Concrete", folder = "Decoracion" })
		-- Filas de ventanas encendidas en la cara que mira al tejado
		for y = -72, -80 + h - 6, 7 do
			if math.abs(x) > math.abs(z) then
				local sx = x - (x > 0 and 1 or -1) * (w / 2 + 0.1)
				b:box({ name = "Ventanas", size = { 0.2, 1.4, d - 4 }, pos = { sx, y, z }, color = WINDOW, mat = "Neon", transparency = 0.35, folder = "Decoracion", shadow = false })
			else
				local sz = z - (z > 0 and 1 or -1) * (d / 2 + 0.1)
				b:box({ name = "Ventanas", size = { w - 4, 1.4, 0.2 }, pos = { x, y, sz }, color = WINDOW, mat = "Neon", transparency = 0.35, folder = "Decoracion", shadow = false })
			end
		end
	end

	-- Tejado y pretil con neón
	b:box({ name = "Tejado", size = { 124, 1, 84 }, pos = { 0, -0.5, 0 }, color = ROOF, mat = "Concrete" })
	for _, z in ipairs({ -41.25, 41.25 }) do
		b:box({ name = "Pretil", size = { 124, 3.5, 1.5 }, pos = { 0, 1.75, z }, color = PARAPET, mat = "Concrete" })
		b:box({ name = "Neon", size = { 124, 0.3, 0.4 }, pos = { 0, 3.65, z }, color = PINK, mat = "Neon", folder = "Decoracion" })
	end

	-- Centro: valla publicitaria sobre una pasarela (se sube por las escaleras de mano)
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
	MB.light(glowFront, "Point", { color = PINK, brightness = 2, range = 26 })
	local glowBack = b:box({ name = "Foco", size = { 2, 0.4, 0.6 }, pos = { 0, 8.5, 1.5 }, color = CYAN, mat = "Neon", folder = "Decoracion" })
	MB.light(glowBack, "Point", { color = CYAN, brightness = 2, range = 26 })

	b:symmetric(function(b)
		b:box({ name = "Pretil", size = { 1.5, 3.5, 81 }, pos = { -61.25, 1.75, 0 }, color = PARAPET, mat = "Concrete" })
		b:box({ name = "Neon", size = { 0.4, 0.3, 81 }, pos = { -61.25, 3.65, 0 }, color = CYAN, mat = "Neon", folder = "Decoracion" })

		-- Caseta de acceso (sala de spawn con puerta hacia el centro)
		b:box({ name = "Caseta", size = { 1, 10, 14 }, pos = { -57.5, 5, 0 }, color = HUT, mat = "Brick" })
		for _, z in ipairs({ -6.5, 6.5 }) do
			b:box({ name = "Caseta", size = { 11, 10, 1 }, pos = { -52.5, 5, z }, color = HUT, mat = "Brick" })
		end
		for _, z in ipairs({ -4.75, 4.75 }) do
			b:box({ name = "Caseta", size = { 1, 10, 4.5 }, pos = { -47.5, 5, z }, color = HUT, mat = "Brick" })
		end
		b:box({ name = "Dintel", size = { 1, 2.5, 5 }, pos = { -47.5, 8.75, 0 }, color = HUT, mat = "Brick" })
		b:box({ name = "TechoCaseta", size = { 12, 1, 15 }, pos = { -52.5, 10.5, 0 }, color = DARK })
		local hutLight = b:box({ name = "Lampara", size = { 2, 0.3, 2 }, pos = { -52.5, 9.8, 0 }, color = b.mirrored and PINK or CYAN, mat = "Neon", folder = "Decoracion" })
		MB.light(hutLight, "Point", { color = b.mirrored and PINK or CYAN, brightness = 1.5, range = 14 })

		-- Soportes de la valla y escaleras de mano
		b:box({ name = "Poste", size = { 1, 22, 1 }, pos = { -12, 11, 0 }, color = METAL, mat = "Metal" })
		for _, z in ipairs({ -1.6, 1.6 }) do
			b:box({ name = "Pata", size = { 0.8, 8, 0.8 }, pos = { -8, 4, z }, color = METAL, mat = "Metal" })
		end
		b:truss({ name = "Escalera", size = { 2, 8, 2 }, pos = { -15, 4, 0 }, color = METAL })
		b:box({ name = "Neon", size = { 0.3, 11, 1.2 }, pos = { -15.15, 16.5, 0 }, color = PINK, mat = "Neon", folder = "Decoracion" })

		-- Cobertura: aires acondicionados, depósito de agua, tragaluz, jardinera
		P.acUnit(b, { -24, 0, -22 }, 0)
		P.acUnit(b, { -40, 0, -26 }, 90)
		P.acUnit(b, { -22, 0, 14 }, 0)
		for _, o in ipairs({ { -3.2, -3.2 }, { 3.2, -3.2 }, { -3.2, 3.2 }, { 3.2, 3.2 } }) do
			b:box({ name = "Pata", size = { 0.8, 6.5, 0.8 }, pos = { -36 + o[1], 3.25, 26 + o[2] }, color = METAL, mat = "Metal" })
		end
		b:box({ name = "Base", size = { 8, 0.5, 8 }, pos = { -36, 6.75, 26 }, color = METAL, mat = "DiamondPlate" })
		b:cylinder({ name = "Deposito", length = 8, diameter = 8.5, pos = { -36, 11, 26 }, color = { 122, 96, 76 }, mat = "WoodPlanks" })
		for _, y in ipairs({ 8.5, 13.5 }) do
			b:cylinder({ name = "Aro", length = 0.3, diameter = 8.7, pos = { -36, y, 26 }, color = { 60, 60, 66 }, mat = "Metal", folder = "Decoracion" })
		end
		b:box({ name = "Tragaluz", size = { 8.6, 1, 8.6 }, pos = { -12, 0.5, -26 }, color = DARK })
		b:box({ name = "Cristal", size = { 8, 0.6, 8 }, pos = { -12, 1.3, -26 }, color = { 150, 180, 230 }, mat = "Glass", transparency = 0.3 })
		b:box({ name = "Jardinera", size = { 10, 3, 3 }, pos = { -28, 1.5, -4 }, color = PARAPET, mat = "Concrete" })
		b:box({ name = "Plantas", size = { 9.4, 0.5, 2.4 }, pos = { -28, 3.2, -4 }, color = { 70, 110, 70 }, mat = "LeafyGrass" })
		P.crate(b, { -8, 0, 22 }, 4.5)
		P.crate(b, { -8, 0, 27 }, 4.5, 12)
		P.crate(b, { -8, 4.5, 24.5 }, 4)

		-- Tubería en el suelo y antena parabólica
		b:cylinder({ name = "Tuberia", axis = "z", length = 60, diameter = 1.4, pos = { -44, 0.9, 6 }, color = { 120, 124, 132 }, mat = "Metal" })
		b:cylinder({ name = "Antena", length = 3, diameter = 0.6, pos = { -55, 1.5, 33 }, color = METAL, folder = "Decoracion" })
		b:cylinder({ name = "Plato", axis = "x", length = 0.5, diameter = 5, pos = { -55, 3.6, 33 }, rot = { 0, 0, 35 }, color = { 210, 212, 218 }, folder = "Decoracion" })

		for _, z in ipairs({ -3, 0, 3 }) do
			b:spawn("A", { -54, 0.5, z }, -90)
		end
	end)

	b:bounds(-60, 60, -40, 40, 30)

	b:lighting({
		lighting = {
			ClockTime = 0.2,
			Brightness = 1.2,
			Ambient = { 72, 62, 104 },
			OutdoorAmbient = { 82, 72, 124 },
			ExposureCompensation = 0.35,
			EnvironmentDiffuseScale = 0.4,
		},
		atmosphere = { density = 0.3, color = { 112, 82, 162 }, decay = { 62, 42, 112 }, haze = 1.5, glare = 0 },
		colorCorrection = { contrast = 0.1, saturation = 0.2, tint = { 236, 226, 255 } },
	})
end
]=]
FUENTES_MAPAS["Gasolinera"] = [=[
-- Gasolinera al atardecer. Equipo A en -X, equipo B en +X.
return function(b, MB)
	local P = MB.Props
	local ASPHALT = { 96, 84, 86 }
	local ROAD = { 72, 64, 68 }
	local LINE = { 236, 230, 220 }
	local STORE = { 62, 92, 74 }
	local TRIM = { 40, 44, 48 }
	local WHITE = { 238, 236, 232 }
	local RED = { 205, 45, 45 }
	local BRICK = { 150, 82, 68 }
	local YELLOW = { 245, 200, 40 }
	local AUTUMN = {
		{ { 198, 122, 60 }, { 170, 108, 52 }, { 136, 128, 62 } },
		{ { 176, 132, 58 }, { 204, 150, 72 }, { 122, 120, 58 } },
		{ { 150, 104, 50 }, { 188, 112, 56 }, { 146, 138, 70 } },
	}

	b.model:SetAttribute("Nombre", "Gasolinera")

	-- Terreno de alrededor: césped, colinas y árboles de otoño
	b:box({ name = "Cesped", size = { 700, 1, 700 }, pos = { 0, -1.2, 0 }, color = { 110, 146, 72 }, mat = "Grass", folder = "Decoracion" })
	local hills = { { 0, -40, 140, 150 }, { -115, -32, 100, 120 }, { 115, -32, 100, 120 }, { -160, -42, 0, 140 }, { 160, -42, 0, 140 }, { -70, -48, -125, 130 }, { 70, -48, -125, 130 } }
	for _, h in ipairs(hills) do
		b:ball({ name = "Colina", diameter = h[4], pos = { h[1], h[2], h[3] }, color = { 112, 150, 74 }, mat = "Grass", folder = "Decoracion" })
	end
	local trees = {
		{ -70, 72, 1.5 }, { -40, 80, 1.7 }, { -12, 74, 1.4 }, { 18, 82, 1.8 }, { 46, 72, 1.5 }, { 74, 80, 1.6 },
		{ -100, 40, 1.6 }, { -104, 0, 1.8 }, { -98, -36, 1.5 }, { 100, 36, 1.7 }, { 104, -4, 1.5 }, { 98, -40, 1.8 },
		{ -60, -78, 1.6 }, { -20, -82, 1.4 }, { 24, -80, 1.7 }, { 62, -76, 1.5 },
	}
	for i, t in ipairs(trees) do
		P.tree(b, { t[1], -0.7, t[2] }, t[3], AUTUMN[(i % 3) + 1])
	end

	-- Aparcamiento y carretera
	b:box({ name = "Asfalto", size = { 164, 1, 116 }, pos = { 0, -0.5, 0 }, color = ASPHALT, mat = "Asphalt" })
	b:box({ name = "Carretera", size = { 164, 0.1, 22 }, pos = { 0, 0.05, -44 }, color = ROAD, mat = "Asphalt", folder = "Decoracion" })
	for x = -78, 78, 12 do
		b:box({ name = "Linea", size = { 6, 0.12, 0.6 }, pos = { x, 0.07, -44 }, color = LINE, folder = "Decoracion" })
	end
	b:box({ name = "Linea", size = { 164, 0.12, 0.5 }, pos = { 0, 0.07, -32.8 }, color = LINE, folder = "Decoracion" })

	-- Tienda (centro, con puerta delantera y dos laterales)
	b:box({ name = "ParedTrasera", size = { 36, 14, 1.5 }, pos = { 0, 7, 39.25 }, color = STORE, mat = "Slate" })
	b:box({ name = "Zocalo", size = { 36, 2, 1.2 }, pos = { 0, 1, 20.6 }, color = TRIM })
	b:box({ name = "Fachada", size = { 36, 4, 1.5 }, pos = { 0, 12, 20.75 }, color = STORE, mat = "Slate" })
	local header = b:box({ name = "Rotulo", size = { 22, 2.6, 0.3 }, pos = { 0, 12, 19.85 }, color = { 30, 34, 38 } })
	MB.sign(header, "MINI MARKET 24H", { font = "GothamBlack", color = { 255, 214, 90 }, glow = true })
	b:box({ name = "Tejado", size = { 38, 1, 22 }, pos = { 0, 14.5, 30 }, color = TRIM })
	b:box({ name = "SueloTienda", size = { 34, 0.1, 18 }, pos = { 0, 0.06, 30 }, color = { 222, 220, 214 }, folder = "Decoracion" })
	b:box({ name = "Mostrador", size = { 8, 3.5, 2.4 }, pos = { 0, 1.75, 35 }, color = { 120, 80, 56 }, mat = "WoodPlanks" })
	local lamp = b:box({ name = "LuzTienda", size = { 10, 0.2, 2 }, pos = { 0, 13.9, 30 }, color = { 255, 244, 220 }, mat = "Neon", folder = "Decoracion" })
	MB.light(lamp, "Surface", { face = "Bottom", brightness = 1.2, range = 20, angle = 120 })

	-- Carteles de los escaparates
	local cafe = b:box({ name = "Cartel", size = { 5, 2.2, 0.1 }, pos = { -11, 8, 19.9 }, color = { 214, 120, 40 } })
	MB.sign(cafe, "CAFÉ", { bg = { 214, 120, 40 }, color = { 255, 255, 255 } })
	local ice = b:box({ name = "Cartel", size = { 5, 2.2, 0.1 }, pos = { -5.5, 6, 19.9 }, color = { 245, 245, 245 } })
	MB.sign(ice, "HELADO", { bg = { 245, 245, 245 }, color = { 40, 110, 200 } })
	local offer = b:box({ name = "Cartel", size = { 5, 3, 0.1 }, pos = { 9, 7, 19.9 }, color = YELLOW })
	MB.sign(offer, "OFERTA 2x1", { bg = YELLOW, color = { 200, 30, 30 } })

	-- Marquesina con surtidores
	b:box({ name = "Marquesina", size = { 44, 1.6, 18 }, pos = { 0, 16.8, -7 }, color = WHITE })
	b:box({ name = "FranjaRoja", size = { 44.6, 0.8, 18.6 }, pos = { 0, 15.8, -7 }, color = RED, folder = "Decoracion" })
	local canopySign = b:box({ name = "Rotulo", size = { 20, 1.6, 0.2 }, pos = { 0, 16.8, -16.15 }, color = WHITE })
	MB.sign(canopySign, "GASOLINA 24H", { font = "GothamBlack", color = RED })

	-- Cables entre postes
	b:box({ name = "Cable", size = { 132, 0.15, 0.15 }, pos = { 0, 27.2, -30.6 }, color = { 30, 30, 30 }, folder = "Decoracion", shadow = false })
	b:box({ name = "Cable", size = { 132, 0.15, 0.15 }, pos = { 0, 27.2, -29.4 }, color = { 30, 30, 30 }, folder = "Decoracion", shadow = false })

	b:symmetric(function(b)
		-- Pared lateral de la tienda con puerta
		b:box({ name = "Pared", size = { 1.5, 14, 6 }, pos = { -17.25, 7, 23 }, color = STORE, mat = "Slate" })
		b:box({ name = "Pared", size = { 1.5, 14, 8 }, pos = { -17.25, 7, 36 }, color = STORE, mat = "Slate" })
		b:box({ name = "Dintel", size = { 1.5, 5, 6 }, pos = { -17.25, 11.5, 29 }, color = STORE, mat = "Slate" })
		-- Escaparate y puerta central
		b:box({ name = "Escaparate", size = { 13.4, 8, 0.4 }, pos = { -10.2, 6, 20.4 }, color = { 170, 200, 210 }, mat = "Glass", transparency = 0.45 })
		b:box({ name = "Marco", size = { 1.2, 10, 1.2 }, pos = { -3.6, 5, 20.6 }, color = TRIM })
		-- Interior: estantería y neveras
		b:box({ name = "Estanteria", size = { 1.6, 5, 9 }, pos = { -9, 2.5, 30 }, color = { 210, 210, 214 }, mat = "Metal" })
		for i = 0, 3 do
			local colors = { { 220, 60, 60 }, { 60, 140, 220 }, { 250, 200, 60 }, { 90, 190, 110 } }
			b:box({ name = "Productos", size = { 1.9, 0.8, 8 }, pos = { -9, 0.9 + i * 1.2, 30 }, color = colors[i + 1], folder = "Decoracion" })
		end
		local fridge = b:box({ name = "Nevera", size = { 7, 8, 1.6 }, pos = { -11, 4, 37.6 }, color = { 205, 225, 238 } })
		MB.light(fridge, "Surface", { face = "Front", brightness = 0.6, range = 8, color = { 200, 230, 255 } })
		P.acUnit(b, { -9, 15, 33 }, 0)

		-- Arcón de hielo y banco en la entrada
		local iceBox = b:box({ name = "Hielo", size = { 4.4, 3.6, 2.4 }, pos = { -21.5, 1.8, 18 }, color = { 240, 244, 248 } })
		MB.sign(iceBox, "HIELO", { color = { 40, 110, 200 }, font = "GothamBlack" })
		P.bench(b, { -9, 0, 16.5 }, 0)

		-- Pilares de la marquesina, isla y surtidores
		for _, z in ipairs({ -14, 0 }) do
			b:box({ name = "Pilar", size = { 2, 15, 2 }, pos = { -18, 7.5, z }, color = BRICK, mat = "Brick" })
		end
		local light = b:box({ name = "LuzMarquesina", size = { 8, 0.2, 3 }, pos = { -9, 15.9, -7 }, color = { 255, 246, 226 }, mat = "Neon", folder = "Decoracion" })
		MB.light(light, "Surface", { face = "Bottom", brightness = 1.3, range = 24, angle = 120 })
		b:box({ name = "Isla", size = { 3, 0.6, 13 }, pos = { -8, 0.3, -7 }, color = YELLOW, mat = "Concrete" })
		P.pump(b, { -8, 0.6, -10.5 }, 0)
		P.pump(b, { -8, 0.6, -3.5 }, 0)
		for _, z in ipairs({ -14.2, 0.2 }) do
			b:cylinder({ name = "Bolardo", length = 3, diameter = 1, pos = { -8, 1.5, z }, color = YELLOW })
		end

		-- Coches
		P.car(b, { -40, 0, 30 }, 0, b.mirrored and { 50, 100, 190 } or { 190, 50, 50 })
		P.car(b, { -29, 0, -44 }, 70, b.mirrored and { 220, 220, 220 } or { 90, 90, 96 })

		-- Barreras, setos y contenedor de basura
		P.barrier(b, { -50, 0, -22 }, 0)
		P.barrier(b, { -30, 0, -18 }, 20)
		P.barrier(b, { -62, 0, 12 }, 90)
		P.barrier(b, { -38, 0, 6 }, 90)
		b:box({ name = "Seto", size = { 22, 3, 3 }, pos = { -52, 1.5, 44 }, color = { 92, 124, 62 }, mat = "LeafyGrass" })
		b:box({ name = "Contenedor", size = { 6, 4.5, 3.5 }, pos = { -26, 2.25, 42 }, color = { 60, 110, 70 }, mat = "Metal" })
		P.crate(b, { -52, 0, 26 }, 4)
		P.crate(b, { -60, 0, -38 }, 4.5, 25)

		-- Plazas de aparcamiento
		for _, x in ipairs({ -46, -40, -34 }) do
			b:box({ name = "Plaza", size = { 0.4, 0.12, 10 }, pos = { x - 3, 0.07, 30 }, color = LINE, folder = "Decoracion" })
		end

		-- Postes eléctricos
		P.pole(b, { -66, 0, -30 }, 28)
		P.pole(b, { -66, 0, 48 }, 28)
		b:box({ name = "Cable", size = { 0.15, 0.15, 78 }, pos = { -66.6, 27.2, 9 }, color = { 30, 30, 30 }, folder = "Decoracion", shadow = false })

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
		lighting = {
			ClockTime = 17.7,
			Brightness = 2.6,
			Ambient = { 112, 82, 82 },
			OutdoorAmbient = { 152, 106, 102 },
			ExposureCompensation = 0.1,
			ShadowSoftness = 0.3,
		},
		atmosphere = { density = 0.32, offset = 0.1, color = { 255, 162, 142 }, decay = { 152, 82, 92 }, glare = 1.2, haze = 2.2 },
		colorCorrection = { contrast = 0.05, saturation = 0.15, tint = { 255, 236, 228 } },
		clouds = { cover = 0.72, density = 0.6, color = { 255, 132, 122 } },
	})
end
]=]
FUENTES_MAPAS["Puerto"] = [=[
-- Puerto de contenedores a mediodía. Equipo A en -X, equipo B en +X.
return function(b, MB)
	local P = MB.Props
	local CONCRETE = { 162, 160, 154 }
	local LANE = { 236, 196, 40 }
	local RED = { 176, 58, 46 }
	local BLUE = { 48, 92, 150 }
	local GREEN = { 60, 120, 80 }
	local ORANGE = { 214, 120, 40 }
	local GREY = { 130, 134, 140 }
	local CRANE = { 236, 186, 36 }

	b.model:SetAttribute("Nombre", "Puerto de Contenedores")

	-- Mar y muelle
	b:box({ name = "Mar", size = { 800, 1, 800 }, pos = { 0, -8, 0 }, color = { 54, 98, 124 }, reflectance = 0.2, folder = "Decoracion" })
	b:box({ name = "Muelle", size = { 156, 1, 108 }, pos = { 0, -0.5, 0 }, color = CONCRETE, mat = "Concrete" })
	for _, z in ipairs({ -54.5, 54.5 }) do
		b:box({ name = "Borde", size = { 158, 8, 1 }, pos = { 0, -4, z }, color = { 118, 116, 112 }, mat = "Concrete", folder = "Decoracion" })
	end
	for _, z in ipairs({ -14, 14 }) do
		b:box({ name = "Linea", size = { 150, 0.12, 0.6 }, pos = { 0, 0.06, z }, color = LANE, folder = "Decoracion" })
	end

	-- Centro: dos contenedores y una pila de cajas en medio
	P.container(b, { 0, 0, 34 }, 0, GREY)
	P.container(b, { 0, 0, -34 }, 0, ORANGE)

	-- Grúa pórtico con un contenedor colgando (decoración)
	for _, x in ipairs({ -11, 11 }) do
		b:box({ name = "Viga", size = { 2.5, 3, 94.5 }, pos = { x, 35.5, 0 }, color = CRANE, mat = "Metal" })
	end
	for _, z in ipairs({ -46, 46 }) do
		b:box({ name = "Viga", size = { 24.5, 3, 2.5 }, pos = { 0, 35.5, z }, color = CRANE, mat = "Metal" })
	end
	b:box({ name = "Carro", size = { 24, 3, 6 }, pos = { 0, 32.5, -4 }, color = CRANE, mat = "Metal" })
	b:box({ name = "Cabina", size = { 5, 4, 5 }, pos = { 6, 29, -4 }, color = { 200, 205, 210 }, mat = "Metal" })
	for _, x in ipairs({ -3, 3 }) do
		b:cylinder({ name = "Cable", length = 7, diameter = 0.3, pos = { x, 27.5, -4 }, color = { 30, 30, 30 }, folder = "Decoracion", shadow = false })
	end
	P.container(b, { 0, 15, -4 }, 0, BLUE)

	b:symmetric(function(b)
		-- Patas de la grúa
		for _, z in ipairs({ -46, 46 }) do
			b:box({ name = "Pata", size = { 2.5, 34, 2.5 }, pos = { -11, 17, z }, color = CRANE, mat = "Metal" })
		end
		b:box({ name = "Borde", size = { 1, 8, 108 }, pos = { -78.5, -4, 0 }, color = { 118, 116, 112 }, mat = "Concrete", folder = "Decoracion" })
		b:box({ name = "Linea", size = { 0.6, 0.12, 100 }, pos = { -40, 0.06, 0 }, color = LANE, folder = "Decoracion" })

		-- Pila de cajas en el centro
		P.crate(b, { -3, 0, 1 }, 5)
		P.crate(b, { -3, 5, 1 }, 5, 10)

		-- Muro de contenedores que protege el spawn (se sale por los huecos)
		P.container(b, { -58, 0, -26 }, 90, BLUE)
		P.container(b, { -58, 0, 26 }, 90, RED)
		P.container(b, { -46, 0, 0 }, 90, b.mirrored and GREEN or ORANGE)

		-- Contenedor abierto (túnel) y pila de dos
		P.container(b, { -28, 0, 0 }, 0, GREEN, true)
		P.container(b, { -34, 0, -30 }, 0, RED)
		P.container(b, { -34, 9, -30 }, 0, b.mirrored and ORANGE or BLUE)

		-- Contenedor con rampa para ganar altura
		P.container(b, { -34, 0, 30 }, 0, GREEN)
		b:wedge({ name = "Rampa", size = { 8.5, 9, 12 }, pos = { -17.5, 4.5, 30 }, rot = { 0, -90, 0 }, color = { 120, 116, 110 }, mat = "DiamondPlate" })

		-- Contenedor a media distancia
		P.container(b, { -12, 0, -16 }, 90, GREY)

		-- Bidones, palés y carretilla elevadora
		P.drum(b, { -24, 0, 12 }, BLUE)
		P.drum(b, { -21.4, 0, 12.6 }, RED)
		P.drum(b, { -23, 0, 14.9 }, BLUE)
		P.pallet(b, { -48, 0, 40 }, 0)
		P.crate(b, { -48, 0.8, 40 }, 3.5)
		P.pallet(b, { -42, 0, 42 }, 30)

		local f = b:at({ -50, 0, -42 }, 0)
		f:box({ name = "Carretilla", size = { 4.5, 3.5, 6 }, pos = { 0, 2.2, 0 }, color = ORANGE })
		f:box({ name = "Mastil", size = { 3.4, 9, 0.6 }, pos = { 0, 4.8, -3.4 }, color = { 60, 60, 66 }, mat = "Metal" })
		f:box({ name = "Horquilla", size = { 0.5, 0.3, 4 }, pos = { -1, 0.4, -5.6 }, color = { 60, 60, 66 }, mat = "Metal" })
		f:box({ name = "Horquilla", size = { 0.5, 0.3, 4 }, pos = { 1, 0.4, -5.6 }, color = { 60, 60, 66 }, mat = "Metal" })
		f:box({ name = "Techo", size = { 4.2, 0.3, 3.6 }, pos = { 0, 7, 0.8 }, color = { 60, 60, 66 }, mat = "Metal" })
		for _, w in ipairs({ { -2.3, -2 }, { 2.3, -2 }, { -2.3, 2 }, { 2.3, 2 } }) do
			f:cylinder({ name = "Rueda", axis = "x", length = 0.8, diameter = 1.8, pos = { w[1], 0.9, w[2] }, color = { 30, 30, 32 } })
		end

		-- Farolas y bolardos del borde del muelle
		for _, z in ipairs({ -46, 46 }) do
			b:cylinder({ name = "Farola", length = 24, diameter = 1, pos = { -70, 12, z }, color = { 90, 94, 100 }, mat = "Metal" })
			b:box({ name = "Lampara", size = { 3, 0.6, 1.5 }, pos = { -69, 24, z }, color = { 255, 244, 214 }, mat = "Neon", folder = "Decoracion" })
		end
		for x = -66, -6, 12 do
			b:cylinder({ name = "Bolardo", length = 1.6, diameter = 1.2, pos = { x, 0.8, -52.5 }, color = { 40, 40, 46 }, mat = "Metal" })
		end

		for _, z in ipairs({ -8, 0, 8 }) do
			b:spawn("A", { -68, 0.5, z }, -90)
		end
	end)

	b:bounds(-76, 76, -52, 52, 40)

	b:lighting({
		lighting = {
			ClockTime = 13.2,
			Brightness = 2.2,
			Ambient = { 120, 125, 130 },
			OutdoorAmbient = { 140, 145, 150 },
			ShadowSoftness = 0.25,
		},
		atmosphere = { density = 0.3, color = { 200, 212, 222 }, decay = { 122, 132, 152 }, haze = 1.2, glare = 0.2 },
		colorCorrection = { contrast = 0.05, saturation = -0.05, tint = { 246, 248, 255 } },
		clouds = { cover = 0.78, density = 0.5, color = { 226, 230, 236 } },
	})
end
]=]
FUENTES_MAPAS["Skatepark"] = [=[
-- SK8 OR DIE: skatepark cubierto. Equipo A en -X, equipo B en +X.
return function(b, MB)
	local P = MB.Props
	local FLOOR = { 200, 166, 196 }
	local FLOOR_DARK = { 184, 146, 182 }
	local PATH = { 236, 222, 220 }
	local YELLOW = { 242, 202, 66 }
	local WALL = { 236, 228, 226 }
	local SKIRT = { 232, 200, 206 }
	local PILLAR = { 64, 62, 76 }
	local BEAM = { 58, 56, 70 }
	local TEAL = { 112, 206, 186 }
	local WOOD = { 228, 194, 142 }
	local DARK = { 40, 38, 50 }
	local PINK = { 245, 122, 192 }
	local CEILING = { 178, 152, 174 }
	local LEDGE = { 242, 218, 200 }

	b.model:SetAttribute("Nombre", "Skatepark SK8 OR DIE")

	-- Exterior (se ve por los ventanales)
	b:box({ name = "Cesped", size = { 700, 1, 700 }, pos = { 0, -1.2, 0 }, color = { 108, 142, 76 }, mat = "Grass", folder = "Decoracion" })
	local trees = { { -50, 64 }, { -18, 72 }, { 16, 66 }, { 48, 74 }, { -42, -68 }, { 6, -76 }, { 40, -66 }, { -96, 20 }, { 96, -18 } }
	for _, t in ipairs(trees) do
		P.tree(b, { t[1], -0.7, t[2] }, 1.3)
	end

	-- Nave
	b:box({ name = "Suelo", size = { 140, 1, 80 }, pos = { 0, -0.5, 0 }, color = FLOOR })
	b:box({ name = "Techo", size = { 144, 1, 84 }, pos = { 0, 26.5, 0 }, color = CEILING })
	for _, z in ipairs({ -41, 41 }) do
		b:box({ name = "Zocalo", size = { 144, 4, 2 }, pos = { 0, 2, z }, color = SKIRT })
		b:box({ name = "Ventanal", size = { 144, 17, 1 }, pos = { 0, 12.5, z }, color = { 210, 226, 236 }, mat = "Glass", transparency = 0.45 })
		b:box({ name = "Muro", size = { 144, 5, 2 }, pos = { 0, 23.5, z }, color = WALL })
	end

	-- Suelo: pasillos claros y líneas amarillas
	for _, z in ipairs({ -34.5, 34.5 }) do
		b:box({ name = "Pasillo", size = { 140, 0.1, 9 }, pos = { 0, 0.05, z }, color = PATH, folder = "Decoracion" })
		b:box({ name = "Linea", size = { 140, 0.12, 0.5 }, pos = { 0, 0.06, z > 0 and 29.8 or -29.8 }, color = YELLOW, folder = "Decoracion" })
	end
	b:box({ name = "Zona", size = { 60, 0.1, 34 }, pos = { 0, 0.05, 0 }, color = FLOOR_DARK, folder = "Decoracion" })

	-- Estructura del techo: vigas oscuras y tubos turquesa
	for _, z in ipairs({ -32, -16, 0, 16, 32 }) do
		b:box({ name = "Viga", size = { 140, 1.4, 1.4 }, pos = { 0, 24.6, z }, color = BEAM, folder = "Decoracion" })
	end
	for _, x in ipairs({ -60, -40, -20, 0, 20, 40, 60 }) do
		b:box({ name = "Viga", size = { 1.4, 1.4, 80 }, pos = { x, 23.6, 0 }, color = BEAM, folder = "Decoracion" })
	end
	for _, z in ipairs({ -24, -8, 8, 24 }) do
		b:box({ name = "Tubo", size = { 140, 0.7, 0.7 }, pos = { 0, 22.6, z }, color = TEAL, folder = "Decoracion" })
	end
	for _, x in ipairs({ -50, -30, -10, 10, 30, 50 }) do
		b:box({ name = "Tubo", size = { 0.7, 0.7, 80 }, pos = { x, 22, 0 }, color = TEAL, folder = "Decoracion" })
	end
	for _, x in ipairs({ -45, -15, 15, 45 }) do
		for _, z in ipairs({ -16, 16 }) do
			P.ceilingLight(b, { x, 23.4, z }, true)
		end
	end

	-- Centro: bloque SK8 OR DIE con plataforma alta y rampas a los lados
	local block = b:box({ name = "Sk8OrDie", size = { 34, 8, 10 }, pos = { 0, 4, 0 }, color = DARK })
	local dots = {
		{ 0.08, 0.3, 0.55, PINK }, { 0.2, 0.8, 0.4, PINK }, { 0.36, 0.2, 0.3, PINK }, { 0.52, 0.85, 0.5, PINK },
		{ 0.66, 0.25, 0.45, PINK }, { 0.82, 0.7, 0.6, PINK }, { 0.94, 0.2, 0.35, PINK },
	}
	for _, face in ipairs({ "Front", "Back" }) do
		MB.sign(block, "SK8 OR DIE", { face = face, font = "LuckiestGuy", color = { 226, 244, 248 }, stroke = { 24, 40, 60 }, dots = dots, width = 0.9, height = 0.78 })
	end
	b:box({ name = "Cubierta", size = { 34, 0.3, 10 }, pos = { 0, 8.15, 0 }, color = { 88, 86, 100 } })
	P.railing(b, { -16.5, 8.3, -4.8 }, { 16.5, 8.3, -4.8 }, 3)
	P.railing(b, { -16.5, 8.3, 4.8 }, { 16.5, 8.3, 4.8 }, 3)

	-- Fondo: gran cuarto de tubo con plataforma
	P.quarterPipe(b, { 0, 0, 24 }, 0, 44, 10, WOOD, DARK)
	b:box({ name = "Plataforma", size = { 44, 10, 6 }, pos = { 0, 5, 37 }, color = DARK })
	b:box({ name = "Plataforma", size = { 44, 0.4, 6 }, pos = { 0, 10.2, 37 }, color = WOOD, mat = "WoodPlanks" })

	-- Frente: funbox central
	b:box({ name = "Funbox", size = { 14, 3, 8 }, pos = { 0, 1.5, -27 }, color = LEDGE })
	b:box({ name = "Borde", size = { 14, 0.2, 8 }, pos = { 0, 3.1, -27 }, color = YELLOW, folder = "Decoracion" })

	b:symmetric(function(b)
		-- Muro lateral (detrás de los spawns) y pilares de los ventanales
		b:box({ name = "Muro", size = { 2, 26, 84 }, pos = { -71, 13, 0 }, color = WALL })
		for x = -63, -7, 14 do
			for _, z in ipairs({ -40.2, 40.2 }) do
				b:box({ name = "Pilar", size = { 2.4, 26, 2.4 }, pos = { x, 13, z }, color = PILLAR })
			end
		end

		-- Rampa de subida a la plataforma central
		b:wedge({ name = "Rampa", size = { 10, 8, 10 }, pos = { -22, 4, 0 }, rot = { 0, 90, 0 }, color = WOOD })

		-- Escaleras a la plataforma del fondo y lateral del tubo
		P.stairs(b, { -24.5, 0, 24 }, 0, 8, 1.25, 1.25, 5, LEDGE)
		b:box({ name = "Lateral", size = { 0.4, 10, 10 }, pos = { -22.2, 5, 29 }, color = DARK })

		-- Rampas del funbox
		b:wedge({ name = "Rampa", size = { 8, 3, 6 }, pos = { -10, 1.5, -27 }, rot = { 0, 90, 0 }, color = WOOD })

		-- Cajas de madera (cobertura)
		P.crate(b, { -30, 0, -10 }, 5)
		P.crate(b, { -30, 0, -5 }, 5)
		P.crate(b, { -30, 5, -7.5 }, 5, 15)
		P.crate(b, { -42, 0, 14 }, 5, 10)
		P.crate(b, { -42, 0, 19.5 }, 4)

		-- Ledge con borde amarillo
		b:box({ name = "Ledge", size = { 14, 2, 4 }, pos = { -44, 1, -22 }, color = LEDGE })
		b:box({ name = "Borde", size = { 14, 0.2, 4 }, pos = { -44, 2.1, -22 }, color = YELLOW, folder = "Decoracion" })

		-- Pirámide de escalones
		b:box({ name = "Escalon", size = { 12, 1.5, 10 }, pos = { -52, 0.75, 22 }, color = LEDGE })
		b:box({ name = "Escalon", size = { 8, 3, 10 }, pos = { -52, 1.5, 22 }, color = LEDGE })
		b:box({ name = "Escalon", size = { 4, 4.5, 10 }, pos = { -52, 2.25, 22 }, color = LEDGE })
		b:box({ name = "Borde", size = { 4, 0.2, 10 }, pos = { -52, 4.6, 22 }, color = YELLOW, folder = "Decoracion" })

		-- Muro de protección del spawn y bancos
		b:box({ name = "MuroSpawn", size = { 2, 7, 26 }, pos = { -58, 3.5, 0 }, color = DARK })
		b:box({ name = "Bloque", size = { 2, 3, 10 }, pos = { -55, 1.5, -20 }, color = LEDGE })
		b:box({ name = "Bloque", size = { 2, 3, 10 }, pos = { -55, 1.5, 20 }, color = LEDGE })

		-- Detalles: papelera y fuente de agua
		b:cylinder({ name = "Papelera", length = 3, diameter = 2.2, pos = { -66, 1.5, 34 }, color = { 50, 50, 58 } })
		b:box({ name = "Fuente", size = { 2.4, 3.6, 3 }, pos = { -68.6, 1.8, -26 }, color = { 80, 150, 210 } })

		-- Spawns del equipo A (el reflejo crea los del B)
		for _, z in ipairs({ -10, 0, 10 }) do
			b:spawn("A", { -65, 0.5, z }, -90)
		end
	end)

	b:lighting({
		lighting = {
			ClockTime = 14.5,
			Brightness = 2,
			Ambient = { 124, 108, 128 },
			OutdoorAmbient = { 150, 140, 160 },
			ExposureCompensation = 0.15,
			EnvironmentDiffuseScale = 0.5,
			EnvironmentSpecularScale = 0.3,
		},
		atmosphere = { density = 0.25, color = { 232, 204, 222 }, decay = { 150, 120, 150 }, haze = 0.6, glare = 0 },
		colorCorrection = { brightness = 0.02, contrast = 0.06, saturation = 0.12, tint = { 255, 242, 250 } },
		clouds = { cover = 0.5, density = 0.4, color = { 255, 236, 245 } },
	})
end
]=]

local anterior = ServerStorage:FindFirstChild("MapBuilder")
if anterior then anterior:Destroy() end
local modulo = Instance.new("ModuleScript")
modulo.Name = "MapBuilder"
modulo.Source = FUENTE_MAPBUILDER
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
MapBuilder.buildAll()
if VER_MAPA then
	MapBuilder.load(VER_MAPA)
end
print("Mapas de duelo creados en ServerStorage.MapasDuelo. Mapa en Workspace: " .. tostring(VER_MAPA))
