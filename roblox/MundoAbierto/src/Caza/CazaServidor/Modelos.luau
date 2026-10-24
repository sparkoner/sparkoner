--[[
	Modelos de la caza y la pesca (los construye el servidor):
	  · Animales a tamaño real (1 metro = 2,9 studs) hechos con formas orgánicas (elipsoides) y con
	    articulaciones (Motor6D) en caderas, rodillas, cuello y cola para que el cliente los anime al andar,
	    correr o pastar. Cada pieza lleva el atributo "Zona" (Cabeza, Cuello, Pecho, Cuerpo, Pata, Cola)
	    para el daño según dónde acierta el disparo.
	  · Armas y cañas de pescar como herramientas (Tool) con piezas detalladas.
	  · El corcho de la caña y las manchas del rastro de sangre.
	Los animales se construyen mirando hacia -Z con la raíz en el centro del cuerpo; "altura" es la
	distancia de la raíz al suelo.
]]
local Modelos = {}

local ZERO = CFrame.new()
local NEGRO = { 26, 24, 22 }

local function rgb(c)
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function giroDe(rot)
	if not rot then
		return ZERO
	end
	return CFrame.fromEulerAnglesYXZ(math.rad(rot[1] or 0), math.rad(rot[2] or 0), math.rad(rot[3] or 0))
end

local function mezclar(t, extra)
	if extra then
		for k, v in pairs(extra) do
			t[k] = v
		end
	end
	return t
end

-- =====================================================================
--  Piezas: E elipsoide, B bloque, W cuña, S bola, C cilindro (eje x/y/z), R cilindro entre dos puntos
-- =====================================================================
local function E(nombre, tam, pos, color, rot, x)
	return mezclar({ nombre = nombre, tam = tam, pos = pos, color = color, giro = giroDe(rot), elipse = true }, x)
end
local function B(nombre, tam, pos, color, rot, x)
	return mezclar({ nombre = nombre, tam = tam, pos = pos, color = color, giro = giroDe(rot) }, x)
end
local function W(nombre, tam, pos, color, rot, x)
	return mezclar({ nombre = nombre, tam = tam, pos = pos, color = color, giro = giroDe(rot), clase = "WedgePart" }, x)
end
local function S(nombre, d, pos, color, x)
	return mezclar({ nombre = nombre, tam = { d, d, d }, pos = pos, color = color, giro = ZERO, forma = "Ball" }, x)
end
local EJES = { x = ZERO, y = CFrame.Angles(0, 0, math.rad(90)), z = CFrame.Angles(0, math.rad(90), 0) }
local function C(nombre, d, largo, eje, pos, color, rot, x)
	return mezclar({ nombre = nombre, tam = { largo, d, d }, pos = pos, color = color, giro = giroDe(rot) * EJES[eje], forma = "Cylinder" }, x)
end
local function R(nombre, a, b, d, color, x)
	local va, vb = Vector3.new(a[1], a[2], a[3]), Vector3.new(b[1], b[2], b[3])
	local dir = vb - va
	local arriba = (math.abs(dir.Unit.Y) > 0.98) and Vector3.new(0, 0, -1) or Vector3.new(0, 1, 0)
	local m = (va + vb) / 2
	return mezclar({
		nombre = nombre, tam = { dir.Magnitude, d, d }, pos = { m.X, m.Y, m.Z }, color = color, forma = "Cylinder",
		giro = CFrame.lookAt(Vector3.new(0, 0, 0), dir, arriba) * CFrame.Angles(0, math.rad(90), 0),
	}, x)
end

-- Los dos lados (izquierda y derecha) de una pieza simétrica
local function par(lista, hacer)
	table.insert(lista, hacer(1))
	table.insert(lista, hacer(-1))
end

local function fabricar(sp, s)
	local part = Instance.new(sp.clase or "Part")
	part.Name = sp.nombre
	if sp.forma then
		part.Shape = Enum.PartType[sp.forma]
	end
	part.Size = Vector3.new(sp.tam[1] * s, sp.tam[2] * s, sp.tam[3] * s)
	part.CFrame = CFrame.new(sp.pos[1] * s, sp.pos[2] * s, sp.pos[3] * s) * sp.giro
	part.Color = rgb(sp.color)
	part.Material = Enum.Material[sp.mat or "SmoothPlastic"]
	if sp.trans then
		part.Transparency = sp.trans
	end
	if sp.refl then
		part.Reflectance = sp.refl
	end
	if sp.elipse then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanTouch = false
	part.Massless = true
	part.Anchored = false
	part.CastShadow = sp.sombra ~= false
	if sp.zona then
		part:SetAttribute("Zona", sp.zona)
	end
	return part
end

local function soldar(a, b)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

-- Articulación: el cliente gira Motor6D.Transform alrededor del punto "junta" (en studs, ejes del animal)
local function articular(nombre, padre, hijo, junta)
	local j = CFrame.new(junta)
	local m = Instance.new("Motor6D")
	m.Name = nombre
	m.Part0 = padre
	m.Part1 = hijo
	m.C0 = padre.CFrame:Inverse() * j
	m.C1 = hijo.CFrame:Inverse() * j
	m.Parent = hijo
	return m
end

-- =====================================================================
--  Animales (medidas en studs para el peso medio; se escalan según el peso de cada ejemplar)
--  patas: ancho (separación), delante/detras (z de las caderas), cadera (altura de la cadera respecto a
--  la raíz), largoMuslo, muslo/muslo2 (tamaño delante/detrás), grosorCana, pezuna (pie o pezuña)
-- =====================================================================
local ANIMALES = {}

ANIMALES.Ciervo = function(op)
	local pelo = (op.variante == 1) and { 150, 108, 70 } or { 132, 98, 66 }
	local claro, oscuro, asta = { 226, 214, 196 }, { 92, 70, 52 }, { 206, 190, 158 }
	local cabeza = {
		E("Cuello", { 0.5, 1.85, 0.68 }, { 0, 1.0, -1.85 }, pelo, { -35, 0, 0 }, { zona = "Cuello" }),
		E("Garganta", { 0.36, 0.36, 0.3 }, { 0, 1.5, -2.2 }, claro, nil, { zona = "Cuello" }),
		E("Cabeza", { 0.52, 0.56, 1.0 }, { 0, 1.95, -2.38 }, pelo, { -15, 0, 0 }, { zona = "Cabeza" }),
		E("Hocico", { 0.34, 0.36, 0.55 }, { 0, 1.8, -2.82 }, oscuro, { -15, 0, 0 }, { zona = "Cabeza" }),
		S("Nariz", 0.17, { 0, 1.79, -3.07 }, NEGRO, { zona = "Cabeza" }),
	}
	par(cabeza, function(k)
		return S("Ojo", 0.11, { 0.25 * k, 2.03, -2.46 }, NEGRO, { zona = "Cabeza" })
	end)
	par(cabeza, function(k)
		return E("Oreja", { 0.1, 0.5, 0.3 }, { 0.36 * k, 2.3, -2.12 }, pelo, { 0, 0, -40 * k }, { zona = "Cabeza" })
	end)
	if op.macho then
		-- Cornamenta: rama principal curvada con tres puntas por lado
		for _, k in ipairs({ 1, -1 }) do
			local p0, p1, p2, p3 = { 0.2 * k, 2.25, -2.2 }, { 0.5 * k, 2.9, -2.0 }, { 0.72 * k, 3.45, -2.35 }, { 0.6 * k, 3.85, -2.85 }
			table.insert(cabeza, R("Cuerna", p0, p1, 0.15, asta, { zona = "Cabeza", mat = "Wood" }))
			table.insert(cabeza, R("Cuerna", p1, p2, 0.13, asta, { zona = "Cabeza", mat = "Wood" }))
			table.insert(cabeza, R("Cuerna", p2, p3, 0.11, asta, { zona = "Cabeza", mat = "Wood" }))
			table.insert(cabeza, R("Cuerna", p1, { 0.45 * k, 3.45, -1.75 }, 0.09, asta, { zona = "Cabeza", mat = "Wood" }))
			table.insert(cabeza, R("Cuerna", p2, { 0.85 * k, 4.0, -2.2 }, 0.09, asta, { zona = "Cabeza", mat = "Wood" }))
			table.insert(cabeza, R("Cuerna", { 0.28 * k, 2.45, -2.25 }, { 0.3 * k, 2.78, -2.62 }, 0.08, asta, { zona = "Cabeza", mat = "Wood" }))
		end
	end
	return {
		altura = 2.5, mat = "Fabric",
		cuerpo = {
			E("Cuerpo", { 1.35, 1.7, 2.7 }, { 0, 0, 0.7 }, pelo, nil, { zona = "Cuerpo" }),
			E("Pecho", { 1.4, 1.85, 2.2 }, { 0, 0.1, -0.85 }, pelo, nil, { zona = "Pecho" }),
			E("Vientre", { 1.0, 0.75, 2.8 }, { 0, -0.55, 0 }, claro, nil, { zona = "Cuerpo" }),
			E("Lomo", { 0.5, 0.26, 3.0 }, { 0, 0.73, -0.05 }, oscuro, nil, { zona = "Cuerpo" }),
			E("Grupa", { 0.8, 0.75, 0.28 }, { 0, 0.12, 1.98 }, claro, nil, { zona = "Cuerpo" }),
		},
		patas = { ancho = 0.42, delante = -1.2, detras = 1.3, cadera = -0.35, largoMuslo = 1.15, muslo = { 0.4, 1.15, 0.52 },
			muslo2 = { 0.5, 1.35, 0.78 }, grosorMuslo = 0.26, grosorCana = 0.18, colorMuslo = pelo, colorCana = pelo, pezuna = { 0.2, 0.16, 0.26 },
			colorPezuna = { 30, 26, 24 } },
		juntas = {
			{ nombre = "Cuello", junta = { 0, 0.45, -1.45 }, partes = cabeza },
			{ nombre = "Cola", junta = { 0, 0.75, 1.95 }, partes = {
				E("Cola", { 0.34, 0.6, 0.24 }, { 0, 0.5, 2.1 }, pelo, { 20, 0, 0 }, { zona = "Cola" }),
				E("Cola", { 0.26, 0.45, 0.12 }, { 0, 0.45, 2.2 }, claro, { 20, 0, 0 }, { zona = "Cola" }),
			} },
		},
	}
end

ANIMALES.Lobo = function(op)
	local pelo = (op.variante == 1) and { 128, 124, 116 } or { 104, 98, 90 }
	local claro, oscuro = { 206, 200, 188 }, { 62, 58, 54 }
	local cabeza = {
		E("Cuello", { 0.72, 1.15, 0.85 }, { 0, 0.62, -1.5 }, pelo, { -38, 0, 0 }, { zona = "Cuello" }),
		E("Cabeza", { 0.72, 0.68, 0.85 }, { 0, 1.05, -2.0 }, pelo, nil, { zona = "Cabeza" }),
		E("Mejilla", { 0.8, 0.5, 0.5 }, { 0, 0.92, -2.05 }, claro, nil, { zona = "Cabeza" }),
		E("Hocico", { 0.36, 0.36, 0.78 }, { 0, 0.9, -2.55 }, claro, { -6, 0, 0 }, { zona = "Cabeza" }),
		E("Hocico", { 0.3, 0.16, 0.6 }, { 0, 1.02, -2.6 }, pelo, { -6, 0, 0 }, { zona = "Cabeza" }),
		S("Nariz", 0.16, { 0, 0.98, -2.94 }, NEGRO, { zona = "Cabeza" }),
	}
	par(cabeza, function(k)
		return S("Ojo", 0.11, { 0.22 * k, 1.18, -2.32 }, { 196, 150, 50 }, { zona = "Cabeza" })
	end)
	par(cabeza, function(k)
		return W("Oreja", { 0.08, 0.42, 0.3 }, { 0.25 * k, 1.5, -1.92 }, pelo, { 0, 180, 12 * k }, { zona = "Cabeza" })
	end)
	return {
		altura = 2.0, mat = "Fabric",
		cuerpo = {
			E("Cuerpo", { 1.0, 1.2, 2.2 }, { 0, 0, 0.7 }, pelo, nil, { zona = "Cuerpo" }),
			E("Pecho", { 1.1, 1.45, 1.6 }, { 0, 0.05, -0.65 }, pelo, nil, { zona = "Pecho" }),
			E("Vientre", { 0.72, 0.5, 2.2 }, { 0, -0.42, 0.1 }, claro, nil, { zona = "Cuerpo" }),
			E("Lomo", { 0.6, 0.42, 2.8 }, { 0, 0.55, 0.1 }, oscuro, nil, { zona = "Cuerpo" }),
			E("Melena", { 1.2, 1.1, 0.9 }, { 0, 0.35, -1.15 }, pelo, nil, { zona = "Cuello" }),
		},
		patas = { ancho = 0.33, delante = -1.0, detras = 1.25, cadera = -0.2, largoMuslo = 0.85, muslo = { 0.34, 0.95, 0.44 },
			muslo2 = { 0.42, 1.05, 0.62 }, grosorMuslo = 0.22, grosorCana = 0.16, colorMuslo = pelo,
			colorCana = { pelo[1] + 26, pelo[2] + 26, pelo[3] + 26 }, pezuna = { 0.24, 0.14, 0.34 }, colorPezuna = oscuro, dedos = -0.06, pieRedondo = true },
		juntas = {
			{ nombre = "Cuello", junta = { 0, 0.35, -1.2 }, partes = cabeza },
			{ nombre = "Cola", junta = { 0, 0.45, 1.75 }, partes = {
				E("Cola", { 0.42, 0.42, 1.55 }, { 0, 0.02, 2.4 }, pelo, { 38, 0, 0 }, { zona = "Cola" }),
				E("Cola", { 0.3, 0.3, 0.5 }, { 0, -0.38, 2.95 }, oscuro, { 38, 0, 0 }, { zona = "Cola" }),
			} },
		},
	}
end

ANIMALES.Oso = function(op)
	local pelo = (op.variante == 1) and { 96, 66, 44 } or { 78, 56, 40 }
	local claro, oscuro = { 128, 96, 68 }, { 56, 40, 30 }
	local cabeza = {
		E("Cuello", { 1.5, 1.5, 1.3 }, { 0, 0.55, -2.3 }, pelo, nil, { zona = "Cuello" }),
		E("Cabeza", { 1.45, 1.35, 1.35 }, { 0, 0.88, -2.95 }, pelo, nil, { zona = "Cabeza" }),
		E("Hocico", { 0.78, 0.68, 0.9 }, { 0, 0.62, -3.58 }, claro, nil, { zona = "Cabeza" }),
		E("Nariz", { 0.42, 0.3, 0.25 }, { 0, 0.8, -3.98 }, NEGRO, nil, { zona = "Cabeza" }),
	}
	par(cabeza, function(k)
		return S("Ojo", 0.14, { 0.36 * k, 1.15, -3.45 }, NEGRO, { zona = "Cabeza" })
	end)
	par(cabeza, function(k)
		return S("Oreja", 0.46, { 0.56 * k, 1.55, -2.82 }, pelo, { zona = "Cabeza" })
	end)
	return {
		altura = 2.3, mat = "Fabric",
		cuerpo = {
			E("Cuerpo", { 2.4, 2.6, 3.3 }, { 0, 0.1, 0.9 }, pelo, nil, { zona = "Cuerpo" }),
			E("Pecho", { 2.5, 2.8, 2.6 }, { 0, 0.25, -0.9 }, pelo, nil, { zona = "Pecho" }),
			E("Joroba", { 1.8, 1.0, 1.8 }, { 0, 1.2, -0.9 }, pelo, nil, { zona = "Pecho" }),
			E("Vientre", { 1.8, 1.0, 3.6 }, { 0, -0.8, 0 }, oscuro, nil, { zona = "Cuerpo" }),
			S("Cola", 0.45, { 0, 0.6, 2.5 }, pelo, { zona = "Cola" }),
		},
		patas = { ancho = 0.85, delante = -1.6, detras = 1.7, cadera = -0.4, largoMuslo = 1.1, muslo = { 0.72, 1.4, 1.0 },
			muslo2 = { 0.8, 1.5, 1.25 }, grosorMuslo = 0.85, grosorCana = 0.74, colorMuslo = pelo, colorCana = pelo, pezuna = { 0.92, 0.44, 1.15 },
			colorPezuna = oscuro, dedos = -0.12, pieRedondo = true },
		juntas = {
			{ nombre = "Cuello", junta = { 0, 0.6, -2.0 }, partes = cabeza },
		},
	}
end

ANIMALES.Jabali = function(op)
	local pelo = (op.variante == 1) and { 72, 60, 52 } or { 88, 72, 58 }
	local oscuro, hocico, colmillo = { 44, 38, 34 }, { 112, 92, 86 }, { 236, 228, 210 }
	local cabeza = {
		E("Cuello", { 0.95, 1.05, 0.75 }, { 0, 0.25, -1.55 }, pelo, nil, { zona = "Cuello" }),
		E("Cabeza", { 0.58, 0.72, 1.75 }, { 0, -0.06, -2.25 }, pelo, { 22, 0, 0 }, { zona = "Cabeza" }),
		E("Frente", { 0.5, 0.5, 0.9 }, { 0, 0.2, -1.95 }, oscuro, { 22, 0, 0 }, { zona = "Cabeza" }),
		C("Hocico", 0.32, 0.12, "z", { 0, -0.4, -3.02 }, hocico, { 22, 0, 0 }, { zona = "Cabeza" }),
	}
	par(cabeza, function(k)
		return W("Colmillo", { 0.07, 0.28, 0.11 }, { 0.17 * k, -0.3, -2.74 }, colmillo, { -30, 0, 14 * k }, { zona = "Cabeza" })
	end)
	par(cabeza, function(k)
		return S("Ojo", 0.1, { 0.3 * k, 0.25, -2.25 }, NEGRO, { zona = "Cabeza" })
	end)
	par(cabeza, function(k)
		return W("Oreja", { 0.1, 0.36, 0.26 }, { 0.3 * k, 0.55, -1.85 }, oscuro, { 0, 180, 18 * k }, { zona = "Cabeza" })
	end)
	return {
		altura = 1.7, mat = "Fabric",
		cuerpo = {
			E("Cuerpo", { 1.25, 1.5, 2.1 }, { 0, 0, 0.6 }, pelo, nil, { zona = "Cuerpo" }),
			E("Pecho", { 1.35, 1.75, 1.75 }, { 0, 0.12, -0.75 }, pelo, nil, { zona = "Pecho" }),
			E("Crin", { 0.26, 0.36, 2.4 }, { 0, 0.84, -0.3 }, oscuro, nil, { zona = "Cuerpo" }),
			E("Vientre", { 0.95, 0.6, 2.4 }, { 0, -0.5, 0 }, oscuro, nil, { zona = "Cuerpo" }),
		},
		patas = { ancho = 0.38, delante = -1.05, detras = 1.15, cadera = -0.35, largoMuslo = 0.65, muslo = { 0.4, 0.8, 0.5 },
			muslo2 = { 0.46, 0.85, 0.64 }, grosorMuslo = 0.24, grosorCana = 0.16, colorMuslo = pelo, colorCana = oscuro, pezuna = { 0.22, 0.15, 0.26 },
			colorPezuna = NEGRO },
		juntas = {
			{ nombre = "Cuello", junta = { 0, 0.25, -1.35 }, partes = cabeza },
			{ nombre = "Cola", junta = { 0, 0.3, 1.62 }, partes = {
				R("Cola", { 0, 0.3, 1.62 }, { 0, -0.35, 1.82 }, 0.08, oscuro, { zona = "Cola" }),
				E("Cola", { 0.14, 0.26, 0.14 }, { 0, -0.42, 1.84 }, oscuro, nil, { zona = "Cola" }),
			} },
		},
	}
end

ANIMALES.Conejo = function(op)
	local pelo = (op.variante == 1) and { 132, 114, 92 } or { 112, 98, 82 }
	local claro = { 228, 222, 210 }
	local cabeza = {
		E("Cabeza", { 0.38, 0.36, 0.46 }, { 0, 0.32, -0.5 }, pelo, nil, { zona = "Cabeza" }),
		E("Hocico", { 0.2, 0.18, 0.16 }, { 0, 0.26, -0.72 }, claro, nil, { zona = "Cabeza" }),
		S("Nariz", 0.06, { 0, 0.3, -0.79 }, { 170, 120, 120 }, { zona = "Cabeza" }),
	}
	par(cabeza, function(k)
		return S("Ojo", 0.08, { 0.17 * k, 0.39, -0.55 }, NEGRO, { zona = "Cabeza" })
	end)
	par(cabeza, function(k)
		return E("Oreja", { 0.07, 0.5, 0.16 }, { 0.08 * k, 0.72, -0.38 }, pelo, { 18, 0, -10 * k }, { zona = "Cabeza" })
	end)
	return {
		altura = 0.42, mat = "Fabric", salta = true,
		cuerpo = {
			E("Cuerpo", { 0.62, 0.68, 0.85 }, { 0, 0, 0.12 }, pelo, nil, { zona = "Cuerpo" }),
			E("Pecho", { 0.55, 0.6, 0.5 }, { 0, 0.04, -0.24 }, pelo, nil, { zona = "Pecho" }),
			E("Vientre", { 0.42, 0.3, 0.7 }, { 0, -0.2, 0 }, claro, nil, { zona = "Cuerpo" }),
			S("Cola", 0.22, { 0, 0.16, 0.54 }, claro, { zona = "Cola" }),
		},
		patas = { ancho = 0.17, ancho2 = 0.22, delante = -0.26, detras = 0.22, cadera = -0.08, largoMuslo = 0.22, muslo = { 0.12, 0.28, 0.14 },
			muslo2 = { 0.2, 0.42, 0.5 }, grosorCana = 0.07, colorMuslo = pelo, colorCana = pelo, pezuna = { 0.1, 0.07, 0.3 },
			colorPezuna = pelo, dedos = -0.08, pieRedondo = true },
		juntas = {
			{ nombre = "Cuello", junta = { 0, 0.15, -0.32 }, partes = cabeza },
		},
	}
end

ANIMALES.Pavo = function(op)
	local plumas = { 62, 48, 38 }
	local bronce, cabezaC, rojo, pata = { 92, 70, 48 }, { 150, 172, 196 }, { 176, 52, 46 }, { 170, 132, 120 }
	local cuello = {
		E("Cuello", { 0.22, 0.85, 0.26 }, { 0, 0.85, -0.75 }, { 120, 92, 88 }, { -12, 0, 0 }, { zona = "Cuello" }),
		E("Cabeza", { 0.26, 0.28, 0.32 }, { 0, 1.3, -0.86 }, cabezaC, nil, { zona = "Cabeza" }),
		E("Moco", { 0.07, 0.24, 0.07 }, { 0, 1.24, -1.04 }, rojo, nil, { zona = "Cabeza" }),
		E("Barba", { 0.13, 0.32, 0.13 }, { 0, 1.06, -0.93 }, rojo, nil, { zona = "Cabeza" }),
		W("Pico", { 0.09, 0.09, 0.2 }, { 0, 1.27, -1.06 }, { 200, 180, 150 }, { 0, 0, 0 }, { zona = "Cabeza" }),
	}
	par(cuello, function(k)
		return S("Ojo", 0.06, { 0.11 * k, 1.36, -0.92 }, NEGRO, { zona = "Cabeza" })
	end)
	local cuerpo = {
		E("Cuerpo", { 1.25, 1.2, 1.5 }, { 0, 0, 0.1 }, plumas, nil, { zona = "Cuerpo" }),
		E("Pecho", { 1.0, 1.1, 0.85 }, { 0, 0.12, -0.55 }, bronce, nil, { zona = "Pecho" }),
		E("Cola", { 0.95, 0.3, 1.15 }, { 0, -0.02, 0.95 }, plumas, { 25, 0, 0 }, { zona = "Cola" }),
		E("Cola", { 0.86, 0.1, 0.32 }, { 0, -0.22, 1.42 }, { 196, 176, 140 }, { 25, 0, 0 }, { zona = "Cola" }),
	}
	par(cuerpo, function(k)
		return E("Ala", { 0.24, 0.78, 1.25 }, { 0.6 * k, 0.04, 0.12 }, { 76, 62, 48 }, { 0, 0, 6 * k }, { zona = "Cuerpo" })
	end)
	return {
		altura = 1.4, mat = "Fabric", cuerpo = cuerpo,
		piernas = { ancho = 0.25, cadera = -0.35, z = 0.05, grosor = 0.12, color = pata },
		juntas = { { nombre = "Cuello", junta = { 0, 0.45, -0.6 }, partes = cuello } },
	}
end

ANIMALES.Pato = function(op)
	local macho = op.macho
	local cuerpoC = macho and { 150, 146, 140 } or { 140, 112, 82 }
	local cabezaC = macho and { 34, 92, 52 } or { 120, 94, 66 }
	local pechoC = macho and { 104, 66, 48 } or { 132, 104, 76 }
	local cuello = {
		E("Cuello", { 0.28, 0.45, 0.3 }, { 0, 0.55, -0.66 }, cabezaC, nil, { zona = "Cuello" }),
		E("Cabeza", { 0.36, 0.38, 0.5 }, { 0, 0.85, -0.76 }, cabezaC, nil, { zona = "Cabeza" }),
		E("Pico", { 0.18, 0.08, 0.38 }, { 0, 0.78, -1.1 }, { 214, 176, 60 }, nil, { zona = "Cabeza" }),
	}
	if macho then
		table.insert(cuello, E("Collar", { 0.31, 0.07, 0.33 }, { 0, 0.4, -0.64 }, { 236, 236, 232 }, nil, { zona = "Cuello" }))
	end
	par(cuello, function(k)
		return S("Ojo", 0.06, { 0.15 * k, 0.9, -0.88 }, NEGRO, { zona = "Cabeza" })
	end)
	local cuerpo = {
		E("Cuerpo", { 0.75, 0.6, 1.4 }, { 0, 0, 0.05 }, cuerpoC, nil, { zona = "Cuerpo" }),
		E("Pecho", { 0.66, 0.55, 0.52 }, { 0, 0.12, -0.5 }, pechoC, nil, { zona = "Pecho" }),
		E("Lomo", { 0.7, 0.28, 1.1 }, { 0, 0.24, 0.12 }, macho and { 110, 100, 90 } or { 112, 88, 64 }, nil, { zona = "Cuerpo" }),
		W("Cola", { 0.3, 0.16, 0.35 }, { 0, 0.18, 0.8 }, macho and { 30, 30, 30 } or { 112, 88, 64 }, { 0, 180, 0 }, { zona = "Cola" }),
	}
	par(cuerpo, function(k)
		return E("Ala", { 0.08, 0.14, 0.32 }, { 0.36 * k, 0.16, 0.2 }, { 60, 70, 150 }, nil, { zona = "Cuerpo" })
	end)
	return { altura = 0.22, mat = "Fabric", nada = true, cuerpo = cuerpo,
		juntas = { { nombre = "Cuello", junta = { 0, 0.3, -0.55 }, partes = cuello } } }
end

ANIMALES.Cangrejo = function(op)
	local cap, oscuro = { 186, 84, 48 }, { 140, 60, 36 }
	local cuerpo = {
		E("Cuerpo", { 0.78, 0.3, 0.58 }, { 0, 0, 0 }, cap, nil, { zona = "Cuerpo" }),
		E("Pecho", { 0.5, 0.16, 0.35 }, { 0, 0.12, -0.05 }, oscuro, nil, { zona = "Pecho" }),
	}
	par(cuerpo, function(k)
		return R("Ojo", { 0.1 * k, 0.1, -0.24 }, { 0.12 * k, 0.24, -0.28 }, 0.03, oscuro, { zona = "Cabeza" })
	end)
	par(cuerpo, function(k)
		return S("Ojo", 0.06, { 0.12 * k, 0.26, -0.28 }, NEGRO, { zona = "Cabeza" })
	end)
	par(cuerpo, function(k)
		return R("Brazo", { 0.3 * k, 0, -0.2 }, { 0.42 * k, 0.02, -0.42 }, 0.07, cap, { zona = "Pata" })
	end)
	par(cuerpo, function(k)
		return E("Pinza", { 0.2, 0.15, 0.3 }, { 0.4 * k, 0.04, -0.56 }, cap, { 0, -20 * k, 0 }, { zona = "Pata" })
	end)
	return { altura = 0.2, mat = "SmoothPlastic", cuerpo = cuerpo, patasCangrejo = { color = oscuro } }
end

-- Patas de cuadrúpedo: cadera y rodilla articuladas, caña y pezuña
local function patas(def, s, modelo, raiz)
	local P = def.patas
	for _, lado in ipairs({ { "DI", -1, P.delante, P.muslo, P.ancho }, { "DD", 1, P.delante, P.muslo, P.ancho },
		{ "TI", -1, P.detras, P.muslo2, P.ancho2 or P.ancho }, { "TD", 1, P.detras, P.muslo2, P.ancho2 or P.ancho } }) do
		local nombre, k, z, tm, ancho = lado[1], lado[2], lado[3], lado[4], lado[5]
		local x = k * ancho
		local yRodilla = P.cadera - P.largoMuslo
		local largoCana = def.altura + yRodilla - P.pezuna[2]
		-- Pierna (hueso de la cadera) + anca musculosa que se funde con el cuerpo, caña fina y pezuña o pie
		local grosor = P.grosorMuslo or P.grosorCana * 1.5
		local pierna = fabricar(C("Pata", grosor, P.largoMuslo + 0.1, "y", { x, P.cadera - P.largoMuslo / 2, z }, P.colorMuslo, nil, { zona = "Pata" }), s)
		local anca = fabricar(E("Pata", tm, { x * 0.85, P.cadera - tm[2] * 0.08, z }, P.colorMuslo, nil, { zona = "Pata" }), s)
		local cana = fabricar(C("Pata", P.grosorCana, largoCana + 0.1, "y", { x, yRodilla - largoCana / 2, z }, P.colorCana, nil, { zona = "Pata" }), s)
		local forma = P.pieRedondo and E or B
		local pie = fabricar(forma("Pata", P.pezuna, { x, -def.altura + P.pezuna[2] / 2, z + (P.dedos or 0) }, P.colorPezuna, nil, { zona = "Pata" }), s)
		for _, p in ipairs({ pierna, anca, cana, pie }) do
			p.Material = Enum.Material[def.mat]
			p.Parent = modelo
		end
		if not P.pieRedondo then
			pie.Material = Enum.Material.SmoothPlastic
		end
		articular("Cadera" .. nombre, raiz, pierna, Vector3.new(x, P.cadera, z) * s)
		soldar(pierna, anca)
		articular("Rodilla" .. nombre, pierna, cana, Vector3.new(x, yRodilla, z) * s)
		soldar(cana, pie)
	end
end

-- Patas de ave (pavo): dos patas finas con tres dedos
local function piernas(def, s, modelo, raiz)
	local P = def.piernas
	for _, lado in ipairs({ { "I", -1 }, { "D", 1 } }) do
		local x = lado[2] * P.ancho
		local largo = def.altura + P.cadera
		local pierna = fabricar(C("Pata", P.grosor, largo, "y", { x, P.cadera - largo / 2, P.z }, P.color, nil, { zona = "Pata" }), s)
		pierna.Parent = modelo
		articular("Pierna" .. lado[1], raiz, pierna, Vector3.new(x, P.cadera, P.z) * s)
		for _, a in ipairs({ -30, 0, 30 }) do
			local dedo = fabricar(B("Pata", { 0.06, 0.05, 0.36 }, { x + math.sin(math.rad(a)) * -0.15, -def.altura + 0.03, P.z - math.cos(math.rad(a)) * 0.15 }, P.color, { 0, a, 0 }, { zona = "Pata" }), s)
			dedo.Parent = modelo
			soldar(pierna, dedo)
		end
	end
end

-- Patas de cangrejo: cuatro por lado, cada una articulada
local function patasCangrejo(def, s, modelo, raiz)
	local n = 0
	for _, k in ipairs({ 1, -1 }) do
		for i, z in ipairs({ -0.1, 0.04, 0.18, 0.3 }) do
			n = n + 1
			local a, c = { 0.32 * k, 0, z }, { 0.62 * k, -def.altura + 0.03, z + 0.04 * (i - 2) }
			local pata = fabricar(R("Pata", a, c, 0.05, def.patasCangrejo.color, { zona = "Pata" }), s)
			pata.Parent = modelo
			articular("Pata" .. n, raiz, pata, Vector3.new(a[1], a[2], a[3]) * s)
		end
	end
end

--[[
	Construye un animal. op: { escala, macho, variante }. Devuelve el Model (Raiz anclada en el origen,
	las demás piezas unidas a ella) y la altura de la raíz sobre el suelo en studs.
]]
function Modelos.animal(especie, op)
	op = op or {}
	local s = op.escala or 1
	local def = ANIMALES[especie](op)
	local modelo = Instance.new("Model")
	modelo.Name = especie
	local raiz = Instance.new("Part")
	raiz.Name = "Raiz"
	raiz.Size = Vector3.new(0.4, 0.4, 0.4) * s
	raiz.Transparency = 1
	raiz.Anchored = true
	raiz.CanCollide = false
	raiz.CanQuery = false
	raiz.CanTouch = false
	raiz.CFrame = ZERO
	raiz.Parent = modelo
	modelo.PrimaryPart = raiz
	for _, sp in ipairs(def.cuerpo) do
		local p = fabricar(sp, s)
		if sp.forma ~= "Ball" or sp.nombre == "Cola" then
			p.Material = Enum.Material[def.mat]
		end
		p.Parent = modelo
		soldar(raiz, p)
	end
	for _, j in ipairs(def.juntas or {}) do
		local hueso
		for i, sp in ipairs(j.partes) do
			local p = fabricar(sp, s)
			if sp.forma ~= "Ball" and not sp.mat and sp.nombre ~= "Pico" and sp.nombre ~= "Nariz" then
				p.Material = Enum.Material[def.mat]
			end
			p.Parent = modelo
			if i == 1 then
				hueso = p
				articular(j.nombre, raiz, p, Vector3.new(j.junta[1], j.junta[2], j.junta[3]) * s)
			else
				soldar(hueso, p)
			end
		end
	end
	if def.patas then
		patas(def, s, modelo, raiz)
	elseif def.piernas then
		piernas(def, s, modelo, raiz)
	elseif def.patasCangrejo then
		patasCangrejo(def, s, modelo, raiz)
	end
	modelo:SetAttribute("Especie", especie)
	modelo:SetAttribute("Escala", s)
	if def.salta then
		modelo:SetAttribute("Salta", true)
	end
	if def.nada then
		modelo:SetAttribute("Nada", true)
	end
	pcall(function()
		modelo.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end)
	return modelo, def.altura * s
end

-- =====================================================================
--  Armas y cañas (en el espacio del mango: -Z hacia delante, +Y hacia arriba, origen en la mano)
-- =====================================================================
local ACERO, PAVONADO, POLIMERO, NOGAL, MADERA = { 176, 178, 184 }, { 44, 46, 50 }, { 34, 34, 36 }, { 104, 66, 40 }, { 150, 108, 66 }
local VERDE_OLIVA = { 76, 80, 62 }

local HERRAMIENTAS = {}

HERRAMIENTAS.Cuchillo = function()
	return { partes = {
		B("Mango", { 0.17, 0.24, 0.52 }, { 0, 0, 0.02 }, POLIMERO, nil, { mat = "Fabric" }),
		B("Guarda", { 0.3, 0.06, 0.06 }, { 0, 0, -0.27 }, PAVONADO, nil, { mat = "Metal" }),
		B("Hoja", { 0.04, 0.2, 0.52 }, { 0, 0.02, -0.56 }, ACERO, nil, { mat = "Metal", refl = 0.15 }),
		W("Hoja", { 0.04, 0.2, 0.22 }, { 0, 0.02, -0.93 }, ACERO, { 0, 0, 180 }, { mat = "Metal", refl = 0.15 }),
	} }
end
HERRAMIENTAS.Bate = function()
	return { partes = {
		C("Mango", 0.17, 0.6, "z", { 0, 0, 0 }, MADERA, nil, { mat = "Wood" }),
		C("Pomo", 0.24, 0.08, "z", { 0, 0, 0.32 }, MADERA, nil, { mat = "Wood" }),
		C("Bate", 0.22, 0.8, "z", { 0, 0, -0.68 }, MADERA, nil, { mat = "Wood" }),
		C("Bate", 0.29, 0.8, "z", { 0, 0, -1.45 }, MADERA, nil, { mat = "Wood" }),
		C("Bate", 0.35, 0.95, "z", { 0, 0, -2.3 }, MADERA, nil, { mat = "Wood" }),
		S("Bate", 0.35, { 0, 0, -2.78 }, MADERA, { mat = "Wood" }),
		C("Cinta", 0.18, 0.45, "z", { 0, 0, -0.05 }, { 30, 30, 30 }, nil, { mat = "Fabric" }),
	} }
end
HERRAMIENTAS.Machete = function()
	return { partes = {
		B("Mango", { 0.18, 0.26, 0.58 }, { 0, 0, 0.04 }, { 40, 40, 40 }, nil, { mat = "Fabric" }),
		B("Hoja", { 0.04, 0.3, 1.4 }, { 0, 0.03, -0.98 }, { 120, 122, 126 }, nil, { mat = "Metal", refl = 0.1 }),
		B("Hoja", { 0.04, 0.12, 0.5 }, { 0, -0.12, -1.45 }, { 120, 122, 126 }, nil, { mat = "Metal", refl = 0.1 }),
		W("Punta", { 0.04, 0.42, 0.32 }, { 0, -0.03, -1.83 }, { 120, 122, 126 }, { 0, 0, 180 }, { mat = "Metal", refl = 0.1 }),
	} }
end
HERRAMIENTAS.Hacha = function()
	return { partes = {
		C("Mango", 0.2, 2.5, "z", { 0, 0, -0.9 }, MADERA, nil, { mat = "Wood" }),
		B("Cabeza", { 0.22, 0.5, 0.34 }, { 0, 0.12, -2.05 }, PAVONADO, nil, { mat = "Metal" }),
		E("Hoja", { 0.07, 0.78, 0.64 }, { 0, 0.6, -2.05 }, ACERO, nil, { mat = "Metal", refl = 0.15 }),
	} }
end
HERRAMIENTAS.Lanza = function()
	return { partes = {
		C("Asta", 0.14, 5.8, "z", { 0, 0, -1.2 }, { 120, 92, 62 }, nil, { mat = "Wood" }),
		C("Atadura", 0.18, 0.35, "z", { 0, 0, -4.05 }, { 70, 56, 40 }, nil, { mat = "Fabric" }),
		E("Punta", { 0.05, 0.3, 0.85 }, { 0, 0, -4.55 }, ACERO, nil, { mat = "Metal", refl = 0.15 }),
		C("Cinta", 0.17, 0.5, "z", { 0, 0, 0 }, { 40, 34, 30 }, nil, { mat = "Fabric" }),
	} }
end
HERRAMIENTAS.Arco = function()
	local partes = {
		B("Empunadura", { 0.18, 0.62, 0.3 }, { 0, 0, 0 }, { 82, 54, 36 }, nil, { mat = "Wood" }),
		C("Cuerda", 0.025, 4.4, "y", { 0, 0, 0.43 }, { 230, 226, 214 }, nil, { mat = "Fabric", sombra = false }),
	}
	for _, k in ipairs({ 1, -1 }) do
		table.insert(partes, B("Cuerpo", { 0.15, 0.62, 0.22 }, { 0, 0.6 * k, -0.04 }, { 82, 54, 36 }, nil, { mat = "Wood" }))
		local p = { { 0, 0.9 * k, -0.02 }, { 0, 1.55 * k, 0.28 }, { 0, 2.05 * k, 0.5 }, { 0, 2.2 * k, 0.42 } }
		for i = 1, 3 do
			table.insert(partes, R("Pala", p[i], p[i + 1], 0.09 - i * 0.015, { 60, 44, 34 }, { mat = "Wood" }))
		end
	end
	return { partes = partes, boca = { 0, 0.15, -0.3 } }
end
HERRAMIENTAS.Ballesta = function()
	local partes = {
		B("Culata", { 0.24, 0.36, 1.5 }, { 0, 0.08, 0.35 }, { 50, 50, 46 }, nil, { mat = "SmoothPlastic" }),
		B("Empunadura", { 0.2, 0.48, 0.3 }, { 0, -0.12, 0 }, { 40, 40, 38 }, { -15, 0, 0 }),
		B("Riel", { 0.16, 0.12, 1.5 }, { 0, 0.3, -0.65 }, PAVONADO, nil, { mat = "Metal" }),
		B("Estribo", { 0.42, 0.06, 0.06 }, { 0, 0.18, -1.48 }, PAVONADO, nil, { mat = "Metal" }),
		C("Mira", 0.14, 0.7, "z", { 0, 0.55, -0.2 }, PAVONADO, nil, { mat = "Metal" }),
		R("Cuerda", { 0.95, 0.33, -1.15 }, { 0, 0.33, -0.55 }, 0.025, { 220, 216, 200 }, { mat = "Fabric", sombra = false }),
		R("Cuerda", { -0.95, 0.33, -1.15 }, { 0, 0.33, -0.55 }, 0.025, { 220, 216, 200 }, { mat = "Fabric", sombra = false }),
		C("Virote", 0.05, 1.0, "z", { 0, 0.38, -0.95 }, { 40, 40, 40 }),
	}
	par(partes, function(k)
		return R("Pala", { 0.05 * k, 0.33, -1.38 }, { 1.0 * k, 0.33, -1.18 }, 0.1, { 60, 60, 56 }, { mat = "SmoothPlastic" })
	end)
	return { partes = partes, boca = { 0, 0.38, -1.5 } }
end
HERRAMIENTAS.Pistola = function()
	return { partes = {
		B("Empunadura", { 0.22, 0.55, 0.32 }, { 0, -0.06, 0.02 }, POLIMERO, { -14, 0, 0 }),
		B("Armazon", { 0.2, 0.14, 0.8 }, { 0, 0.25, -0.22 }, POLIMERO),
		B("Corredera", { 0.22, 0.2, 0.92 }, { 0, 0.41, -0.24 }, { 56, 56, 60 }, nil, { mat = "Metal" }),
		C("Canon", 0.1, 0.06, "z", { 0, 0.42, -0.72 }, { 14, 14, 14 }),
		B("Guardamonte", { 0.05, 0.05, 0.32 }, { 0, 0.07, -0.32 }, POLIMERO),
		B("Guardamonte", { 0.05, 0.16, 0.05 }, { 0, 0.13, -0.47 }, POLIMERO),
		B("Gatillo", { 0.04, 0.12, 0.04 }, { 0, 0.13, -0.26 }, { 56, 56, 60 }, nil, { mat = "Metal" }),
		B("Mira", { 0.06, 0.05, 0.05 }, { 0, 0.53, -0.66 }, POLIMERO),
		B("Mira", { 0.14, 0.05, 0.06 }, { 0, 0.53, 0.17 }, POLIMERO),
		B("Cargador", { 0.16, 0.08, 0.22 }, { 0, -0.36, 0.06 }, POLIMERO, { -14, 0, 0 }),
	}, boca = { 0, 0.42, -0.76 } }
end
HERRAMIENTAS.Revolver = function()
	return { partes = {
		B("Empunadura", { 0.22, 0.55, 0.3 }, { 0, -0.08, 0.06 }, NOGAL, { -20, 0, 0 }, { mat = "Wood" }),
		B("Armazon", { 0.2, 0.32, 0.55 }, { 0, 0.3, -0.2 }, ACERO, nil, { mat = "Metal", refl = 0.1 }),
		C("Tambor", 0.4, 0.34, "z", { 0, 0.34, -0.24 }, ACERO, nil, { mat = "Metal", refl = 0.1 }),
		C("Canon", 0.14, 0.8, "z", { 0, 0.42, -0.85 }, ACERO, nil, { mat = "Metal", refl = 0.1 }),
		B("Guia", { 0.12, 0.1, 0.76 }, { 0, 0.32, -0.86 }, ACERO, nil, { mat = "Metal" }),
		B("Martillo", { 0.06, 0.14, 0.1 }, { 0, 0.5, 0.06 }, PAVONADO, { 20, 0, 0 }),
		B("Guardamonte", { 0.05, 0.05, 0.28 }, { 0, 0.1, -0.24 }, ACERO, nil, { mat = "Metal" }),
		B("Mira", { 0.04, 0.07, 0.08 }, { 0, 0.52, -1.2 }, ACERO, nil, { mat = "Metal" }),
	}, boca = { 0, 0.42, -1.27 } }
end
HERRAMIENTAS.Escopeta = function()
	return { partes = {
		B("Empunadura", { 0.21, 0.34, 0.6 }, { 0, 0.12, 0.18 }, NOGAL, { -14, 0, 0 }, { mat = "Wood" }),
		B("Culata", { 0.23, 0.44, 1.25 }, { 0, 0.1, 1.02 }, NOGAL, nil, { mat = "Wood" }),
		B("Cantonera", { 0.25, 0.5, 0.08 }, { 0, 0.1, 1.67 }, { 30, 30, 30 }),
		B("Cajon", { 0.26, 0.4, 1.0 }, { 0, 0.28, -0.4 }, PAVONADO, nil, { mat = "Metal" }),
		C("Canon", 0.15, 2.3, "z", { 0, 0.4, -2.05 }, PAVONADO, nil, { mat = "Metal" }),
		C("Deposito", 0.13, 1.7, "z", { 0, 0.24, -1.75 }, PAVONADO, nil, { mat = "Metal" }),
		C("Corredera", 0.24, 0.62, "z", { 0, 0.24, -1.45 }, NOGAL, nil, { mat = "Wood" }),
		B("Guardamonte", { 0.06, 0.05, 0.36 }, { 0, 0.05, -0.18 }, PAVONADO),
		S("Mira", 0.06, { 0, 0.5, -3.15 }, { 230, 210, 160 }),
	}, boca = { 0, 0.4, -3.22 } }
end
HERRAMIENTAS.Subfusil = function()
	return { partes = {
		B("Empunadura", { 0.2, 0.48, 0.28 }, { 0, -0.04, 0.04 }, POLIMERO, { -16, 0, 0 }),
		B("Cajon", { 0.24, 0.38, 1.0 }, { 0, 0.3, -0.28 }, POLIMERO),
		C("Funda", 0.2, 0.42, "z", { 0, 0.34, -0.98 }, PAVONADO, nil, { mat = "Metal" }),
		B("Cargador", { 0.15, 0.72, 0.25 }, { 0, -0.1, -0.5 }, PAVONADO, { 6, 0, 0 }),
		R("Culata", { 0.08, 0.36, 0.2 }, { 0.08, 0.3, 1.0 }, 0.05, PAVONADO),
		R("Culata", { -0.08, 0.36, 0.2 }, { -0.08, 0.3, 1.0 }, 0.05, PAVONADO),
		B("Cantonera", { 0.24, 0.42, 0.06 }, { 0, 0.22, 1.02 }, POLIMERO),
		B("Mira", { 0.06, 0.1, 0.12 }, { 0, 0.54, 0.1 }, POLIMERO),
		B("Mira", { 0.06, 0.1, 0.06 }, { 0, 0.54, -0.72 }, POLIMERO),
	}, boca = { 0, 0.34, -1.22 } }
end
HERRAMIENTAS.Fusil = function()
	return { partes = {
		B("Empunadura", { 0.2, 0.48, 0.28 }, { 0, -0.04, 0.05 }, POLIMERO, { -18, 0, 0 }),
		B("Cajon", { 0.24, 0.42, 1.15 }, { 0, 0.32, -0.32 }, POLIMERO),
		B("Cargador", { 0.17, 0.78, 0.34 }, { 0, -0.12, -0.5 }, POLIMERO, { -14, 0, 0 }),
		B("Culata", { 0.22, 0.45, 0.95 }, { 0, 0.26, 0.78 }, POLIMERO),
		B("Cantonera", { 0.24, 0.55, 0.08 }, { 0, 0.22, 1.28 }, { 20, 20, 20 }),
		B("Guardamanos", { 0.26, 0.3, 1.0 }, { 0, 0.35, -1.38 }, POLIMERO),
		C("Canon", 0.09, 0.66, "z", { 0, 0.37, -2.2 }, PAVONADO, nil, { mat = "Metal" }),
		C("Bocacha", 0.13, 0.16, "z", { 0, 0.37, -2.6 }, PAVONADO, nil, { mat = "Metal" }),
		B("Riel", { 0.12, 0.06, 1.0 }, { 0, 0.56, -0.4 }, POLIMERO),
		C("Visor", 0.18, 0.38, "z", { 0, 0.7, -0.35 }, POLIMERO),
		C("Lente", 0.15, 0.02, "z", { 0, 0.7, -0.55 }, { 120, 40, 40 }, nil, { mat = "Glass", trans = 0.2 }),
	}, boca = { 0, 0.37, -2.7 } }
end

local function rifleCerrojo(op)
	local partes = {
		B("Empunadura", { 0.21, 0.34, 0.6 }, { 0, 0.12, 0.18 }, op.madera, { -14, 0, 0 }, { mat = op.mat }),
		B("Culata", { 0.23, 0.44, 1.2 }, { 0, 0.1, 1.0 }, op.madera, nil, { mat = op.mat }),
		B("Cantonera", { 0.25, 0.5, 0.08 }, { 0, 0.1, 1.62 }, { 30, 30, 30 }),
		B("Fuste", { 0.24, 0.24, 1.5 }, { 0, 0.22, -1.0 }, op.madera, nil, { mat = op.mat }),
		B("Cajon", { 0.22, 0.24, 0.85 }, { 0, 0.36, -0.28 }, PAVONADO, nil, { mat = "Metal" }),
		R("Cerrojo", { 0.08, 0.38, 0.05 }, { 0.3, 0.3, 0.12 }, 0.06, PAVONADO, { mat = "Metal" }),
		S("Cerrojo", 0.12, { 0.32, 0.29, 0.13 }, PAVONADO, { mat = "Metal" }),
		C("Canon", 0.12, op.canon, "z", { 0, 0.38, -0.7 - op.canon / 2 }, PAVONADO, nil, { mat = "Metal" }),
		B("Guardamonte", { 0.06, 0.05, 0.36 }, { 0, 0.1, -0.18 }, PAVONADO),
		C("Mira", op.mira, 1.15, "z", { 0, 0.72, -0.38 }, PAVONADO, nil, { mat = "Metal" }),
		C("Objetivo", op.mira * 1.6, 0.34, "z", { 0, 0.72, -1.05 }, PAVONADO, nil, { mat = "Metal" }),
		C("Ocular", op.mira * 1.35, 0.24, "z", { 0, 0.72, 0.28 }, PAVONADO, nil, { mat = "Metal" }),
		C("Lente", op.mira * 1.45, 0.02, "z", { 0, 0.72, -1.23 }, { 70, 120, 150 }, nil, { mat = "Glass", trans = 0.15, refl = 0.3 }),
		C("Torreta", 0.12, 0.14, "y", { 0, 0.86, -0.38 }, PAVONADO, nil, { mat = "Metal" }),
		B("Anilla", { 0.08, 0.24, 0.1 }, { 0, 0.55, -0.7 }, PAVONADO),
		B("Anilla", { 0.08, 0.24, 0.1 }, { 0, 0.55, -0.05 }, PAVONADO),
	}
	if op.bipode then
		for _, k in ipairs({ 1, -1 }) do
			table.insert(partes, R("Bipode", { 0.05 * k, 0.15, -1.6 }, { 0.35 * k, -0.85, -1.85 }, 0.05, PAVONADO, { mat = "Metal" }))
		end
		table.insert(partes, B("Freno", { 0.2, 0.2, 0.3 }, { 0, 0.38, -0.85 - op.canon }, PAVONADO, nil, { mat = "Metal" }))
	end
	return { partes = partes, boca = { 0, 0.38, -0.75 - op.canon - (op.bipode and 0.2 or 0) } }
end
HERRAMIENTAS.RifleCaza = function()
	return rifleCerrojo({ madera = NOGAL, mat = "Wood", canon = 1.9, mira = 0.17 })
end
HERRAMIENTAS.Francotirador = function()
	return rifleCerrojo({ madera = VERDE_OLIVA, mat = "SmoothPlastic", canon = 2.5, mira = 0.2, bipode = true })
end
HERRAMIENTAS.Molotov = function()
	return { partes = {
		C("Botella", 0.34, 0.62, "y", { 0, 0.05, 0 }, { 70, 100, 56 }, nil, { mat = "Glass", trans = 0.25 }),
		C("Liquido", 0.3, 0.42, "y", { 0, -0.04, 0 }, { 196, 140, 60 }, nil, { trans = 0.3 }),
		C("Gollete", 0.14, 0.3, "y", { 0, 0.5, 0 }, { 70, 100, 56 }, nil, { mat = "Glass", trans = 0.25 }),
		E("Trapo", { 0.16, 0.38, 0.16 }, { 0, 0.74, 0 }, { 196, 186, 166 }, { 0, 0, 12 }, { mat = "Fabric" }),
	}, mecha = { 0, 0.88, 0 } }
end
HERRAMIENTAS.Granada = function()
	return { partes = {
		E("Cuerpo", { 0.32, 0.44, 0.32 }, { 0, 0.04, 0 }, VERDE_OLIVA, nil, { mat = "Metal" }),
		C("Espoleta", 0.14, 0.14, "y", { 0, 0.32, 0 }, { 120, 120, 110 }, nil, { mat = "Metal" }),
		B("Cuchara", { 0.05, 0.36, 0.08 }, { 0.16, 0.16, 0 }, { 120, 120, 110 }, { 0, 0, -8 }, { mat = "Metal" }),
		C("Anilla", 0.16, 0.03, "x", { -0.1, 0.38, 0 }, { 150, 150, 140 }, nil, { mat = "Metal" }),
	} }
end

-- Caña: mango de corcho, carrete debajo, tramos cada vez más finos y anillas; "Punta" al final
local function cana(cfg, op)
	local color = cfg.color
	local metal = op.dorado and { 200, 160, 70 } or { 150, 150, 156 }
	local partes = {
		C("Mango", 0.2, 0.95, "z", { 0, 0, 0.1 }, { 176, 140, 100 }, nil, { mat = "Sand" }),
		C("Portacarrete", 0.16, 0.35, "z", { 0, 0, -0.5 }, metal, nil, { mat = "Metal" }),
		B("Pie", { 0.06, 0.28, 0.1 }, { 0, -0.18, -0.5 }, metal, nil, { mat = "Metal" }),
		C("Carrete", op.carrete, 0.26, "z", { 0, -0.32 - op.carrete / 2, -0.5 }, metal, nil, { mat = "Metal" }),
		C("Bobina", op.carrete * 0.75, 0.2, "z", { 0, -0.32 - op.carrete / 2, -0.66 }, { 220, 220, 210 }),
		R("Manivela", { 0.15, -0.32 - op.carrete / 2, -0.5 }, { 0.32, -0.42 - op.carrete / 2, -0.5 }, 0.04, metal, { mat = "Metal" }),
	}
	-- La caña sale hacia delante y arriba
	local dir = Vector3.new(0, math.sin(math.rad(op.angulo)), -math.cos(math.rad(op.angulo)))
	local base = Vector3.new(0, 0, -0.65)
	local tramos = { { 0, 0.34, 0.13 }, { 0.34, 0.68, 0.09 }, { 0.68, 1, 0.055 } }
	for _, t in ipairs(tramos) do
		local a, b = base + dir * (op.largo * t[1]), base + dir * (op.largo * t[2])
		table.insert(partes, R("Tramo", { a.X, a.Y, a.Z }, { b.X, b.Y, b.Z }, t[3], color, { mat = op.mat or "SmoothPlastic" }))
	end
	for i = 1, 4 do
		local p = base + dir * (op.largo * (0.22 + i * 0.18))
		table.insert(partes, C("Anilla", 0.12 - i * 0.015, 0.02, "z", { p.X, p.Y - 0.08, p.Z }, metal, { op.angulo, 0, 0 }, { mat = "Metal" }))
	end
	local punta = base + dir * op.largo
	return { partes = partes, punta = { punta.X, punta.Y, punta.Z } }
end
local CANAS = {
	CanaBambu = { largo = 7.5, angulo = 26, carrete = 0, mat = "Wood" },
	CanaMadera = { largo = 6.5, angulo = 26, carrete = 0.32, mat = "Wood" },
	CanaFibra = { largo = 6.8, angulo = 26, carrete = 0.36 },
	CanaCarbono = { largo = 7, angulo = 26, carrete = 0.38 },
	CanaMar = { largo = 11, angulo = 30, carrete = 0.5 },
	CanaCurrican = { largo = 5.6, angulo = 24, carrete = 0.62, dorado = true },
}

-- Construye la herramienta (Tool) de un arma o una caña con sus datos de CazaConfig
function Modelos.herramienta(id, cfg, esCana)
	local def
	if esCana then
		local op = CANAS[id]
		def = cana(cfg, op)
		if op.carrete == 0 then
			-- La de bambú no lleva carrete: el sedal va atado a la punta
			for i = #def.partes, 1, -1 do
				local n = def.partes[i].nombre
				if n == "Carrete" or n == "Bobina" or n == "Manivela" or n == "Portacarrete" or n == "Pie" then
					table.remove(def.partes, i)
				end
			end
		end
	else
		def = HERRAMIENTAS[id]()
	end
	local tool = Instance.new("Tool")
	tool.Name = cfg.nombre
	tool.ToolTip = cfg.desc or ""
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute(esCana and "Cana" or "Arma", id)
	tool:SetAttribute("CazaPesca", true)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.2, 0.2, 0.2)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.CanQuery = false
	handle.CanTouch = false
	handle.Massless = true
	handle.CFrame = ZERO
	handle.Parent = tool
	for _, sp in ipairs(def.partes) do
		local p = fabricar(sp, 1)
		p.CanQuery = false
		p.Parent = tool
		soldar(handle, p)
	end
	for nombre, pos in pairs({ Boca = def.boca, Punta = def.punta, Mecha = def.mecha }) do
		local a = Instance.new("Attachment")
		a.Name = nombre
		a.Position = Vector3.new(pos[1], pos[2], pos[3])
		a.Parent = handle
	end
	if def.mecha then
		local fuego = Instance.new("Fire")
		fuego.Size = 1.2
		fuego.Heat = 4
		fuego.Parent = handle.Mecha
	end
	return tool
end

-- =====================================================================
--  Corcho de pesca y rastro de sangre
-- =====================================================================
function Modelos.corcho()
	local m = Instance.new("Model")
	m.Name = "Corcho"
	local raiz = Instance.new("Part")
	raiz.Name = "Raiz"
	raiz.Shape = Enum.PartType.Ball
	raiz.Size = Vector3.new(0.36, 0.36, 0.36)
	raiz.Color = Color3.fromRGB(214, 40, 34)
	raiz.Material = Enum.Material.SmoothPlastic
	raiz.Anchored = true
	raiz.CanCollide = false
	raiz.CanQuery = false
	raiz.CanTouch = false
	raiz.Parent = m
	m.PrimaryPart = raiz
	local franja = fabricar(C("Franja", 0.37, 0.12, "y", { 0, -0.08, 0 }, { 240, 240, 236 }), 1)
	franja.CanQuery = false
	franja.Parent = m
	soldar(raiz, franja)
	local antena = fabricar(C("Antena", 0.05, 0.36, "y", { 0, 0.32, 0 }, { 250, 210, 60 }), 1)
	antena.CanQuery = false
	antena.Parent = m
	soldar(raiz, antena)
	local a = Instance.new("Attachment")
	a.Name = "Linea"
	a.Position = Vector3.new(0, 0.5, 0)
	a.Parent = raiz
	return m
end

function Modelos.manchaSangre(cf, tam)
	local p = Instance.new("Part")
	p.Name = "RastroSangre"
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(0.05, tam, tam * (0.6 + math.random() * 0.5))
	p.CFrame = cf * CFrame.Angles(0, 0, math.rad(90))
	p.Color = Color3.fromRGB(92 + math.random(0, 20), 14, 12)
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

Modelos.especies = ANIMALES
return Modelos
