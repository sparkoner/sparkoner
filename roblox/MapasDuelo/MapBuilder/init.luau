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
