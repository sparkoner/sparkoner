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
