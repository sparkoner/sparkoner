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
