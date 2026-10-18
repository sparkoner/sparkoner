# Mapas de duelo para Roblox

4 mapas para duelos de tiros, en el estilo low-poly de colores suaves de tus capturas. Todos son **simétricos**: el equipo A aparece en un lado y el B en el otro, con el mismo terreno y la misma cobertura.

| Mapa | Ambiente | Lo que tiene |
|---|---|---|
| **Skatepark SK8 OR DIE** | Nave cubierta, tarde | Bloque central "SK8 OR DIE" con plataforma alta, half-pipe con escaleras, funbox, cajas, ledges con borde amarillo, ventanales con árboles fuera. |
| **Gasolinera** | Atardecer rojizo | Tienda "Mini Market 24H" con 3 puertas y estanterías dentro, marquesina con surtidores, coches, barreras, postes eléctricos, colinas y árboles de otoño. |
| **Azotea Neón** | Noche | Valla luminosa "NEO CITY" sobre una pasarela (se sube con escaleras de mano), casetas como sala de spawn, aires acondicionados, depósito de agua y rascacielos alrededor. |
| **Puerto de Contenedores** | Mediodía nublado | Contenedores de colores, uno abierto como túnel, uno con rampa para ganar altura, grúa pórtico y muelle rodeado de mar. |

Vista general y vista desde el spawn de cada mapa:

![Skatepark](previews/Skatepark.jpg)
![Gasolinera](previews/Gasolinera.jpg)
![Azotea](previews/Azotea.jpg)
![Puerto](previews/Puerto.jpg)

Estas imágenes son una aproximación hecha fuera de Roblox. En Studio, la luz, los materiales y las fuentes se ven mejor.

## Instalación

### Opción A: barra de comandos (la más fácil)

1. Abre tu juego en Roblox Studio.
2. Abre `ConstruirMapas.luau`, selecciona todo y cópialo.
3. En Studio, ve a **Ver → Barra de comandos**, pega el texto y pulsa **Enter**.
4. Se crean tres cosas:
   - `ServerStorage.MapBuilder`, el módulo para cargar mapas.
   - `ServerStorage.MapasDuelo`, con los 4 mapas.
   - `Workspace.MapaActual`, con la Gasolinera colocada para que la veas.
5. Guarda el juego.

Para ver otro mapa, escribe esto en la barra de comandos:
```lua
require(game.ServerStorage.MapBuilder).load("Skatepark")
```

### Opción B: Rojo

Añade el módulo a tu `default.project.json`, dentro de `ServerStorage`:
```json
"ServerStorage": {
  "$className": "ServerStorage",
  "MapBuilder": { "$path": "MapasDuelo/MapBuilder" }
}
```
Con Rojo los mapas no se guardan en el juego: se construyen al arrancar el servidor (`DueloMapas.luau` ya lo hace).

## Usarlos en tu juego

```lua
local MapBuilder = require(game.ServerStorage.MapBuilder)
local mapa, spawns = MapBuilder.load("Gasolinera")
-- spawns.A y spawns.B son listas de CFrames: personaje:PivotTo(spawns.A[1])
```

`load` hace tres cosas: quita el mapa anterior de Workspace, coloca el nuevo y aplica su iluminación (hora del día, atmósfera, nubes y color).

`DueloMapas.luau` es un ejemplo listo para tu sistema de rondas: elige un mapa al azar y coloca a cada equipo en sus spawns.
```lua
local startDuel = require(game.ServerScriptService.DueloMapas)
startDuel({ jugador1 }, { jugador2 })
```

Cada mapa tiene estas carpetas:
- **Mapa:** suelo, paredes y cobertura.
- **Decoracion:** detalles sin colisión.
- **Spawns:** piezas invisibles con el atributo `Team` = `A` o `B`, tres por equipo.
- **Limites:** paredes invisibles para que nadie se salga del mapa.

## Editar los mapas

- **Retocar a mano:** después de construirlos son piezas normales, así que puedes moverlos, pintarlos o añadir cosas en Studio. Ojo: si vuelves a ejecutar `ConstruirMapas.luau`, se sobrescribe `ServerStorage.MapasDuelo`, así que guarda tus cambios con otro nombre.
- **Cambiar el código:** los mapas están en `MapBuilder/Mapas/*.luau`. Cada pieza es una línea, por ejemplo:
  ```lua
  b:box({ name = "Caja", size = { 5, 5, 5 }, pos = { -30, 2.5, -10 }, color = { 206, 160, 104 }, mat = "WoodPlanks" })
  ```
  Todo lo que va dentro de `b:symmetric(function(b) ... end)` se crea dos veces, una por cada lado. Así el mapa sigue siendo justo para los dos equipos.
- **Regenerar el script:** después de cambiar código, ejecuta `python3 build_bundle.py` para volver a crear `ConstruirMapas.luau`.

## Comprobaciones hechas

- El código se ejecutó con una simulación de la API de Roblox. Los 4 mapas se construyen sin errores, y al cambiar de mapa se limpia el anterior y su iluminación.
- Ningún spawn queda dentro de un objeto.
- Ningún spawn tiene visión directa de los spawns rivales, para evitar que se mate a nadie nada más aparecer.
- Cada mapa usa entre 250 y 520 piezas, ligero para cualquier dispositivo.
