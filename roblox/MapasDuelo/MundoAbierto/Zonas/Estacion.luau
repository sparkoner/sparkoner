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
