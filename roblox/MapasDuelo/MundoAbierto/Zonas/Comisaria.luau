-- Comisaría junto a la carretera: edificio en el que se puede entrar, coches patrulla y barricadas.
return function(b, MB, W)
	local P = MB.Props
	-- La carretera pasa por x ≈ -1395: la comisaría queda al oeste mirando a la carretera
	P.openHouse(b, { -1440, 0, -70 }, -90, { w = 40, d = 24, color = { 120, 130, 150 }, trim = { 230, 230, 226 }, roofColor = { 60, 64, 72 }, floor = { 140, 140, 136 }, sofa = { 60, 70, 90 }, ruined = true })
	P.poster(b, { -1427.3, 15.6, -70 }, -90, { 18, 2.6 }, { 30, 50, 100 }, "COMISARÍA", { 240, 240, 240 }, "GothamBlack")
	P.house(b, { -1460, 0, -132 }, 0, { w = 30, h = 10, d = 20, color = { 110, 118, 130 }, trim = { 220, 220, 216 }, floors = 1, ruined = true })
	W.parking(-1380, -1306, -140, -10)
	W.policeCar(-1360, 0.2, -110, 90)
	W.policeCar(-1340, 0.2, -60, 75)
	W.policeCar(-1325, 0.2, -30, 100)
	P.car(b, { -1350, 0.2, -130 }, 90, { 90, 96, 100 }, true)
	for _, z in ipairs({ -150, 10 }) do
		P.barrier(b, { -1395, 0.2, z }, 0)
		P.sandbags(b, { -1420, 0, z }, 90, 8, 3)
	end
	P.debris(b, { -1415, 0, -96 }, 1)
	P.dumpster(b, { -1462, 0, -108 }, 90, { 50, 80, 70 })
	W.spawn(-1370, -80, 90)
end
