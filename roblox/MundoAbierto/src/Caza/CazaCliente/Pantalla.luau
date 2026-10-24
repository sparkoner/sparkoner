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
