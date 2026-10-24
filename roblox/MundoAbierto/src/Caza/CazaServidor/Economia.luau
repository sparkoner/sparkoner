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
