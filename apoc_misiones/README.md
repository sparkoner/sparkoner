# apoc_misiones

15 misiones apocalípticas para servidores **QBCore**. Se pueden hacer **en solitario o en grupo** (hasta 4 jugadores), y la dificultad y la recompensa se ajustan al tamaño del grupo.

## Misiones

Ordenadas por la reputación que piden, de más fácil a más difícil:

| Misión | Qué hay que hacer | Reputación necesaria |
|--------|-------------------|----------------------|
| **Suministros Médicos** | Ir a un hospital infestado, registrar cajas de suministros mientras atacan los infectados y volver al refugio. | 0 |
| **Combustible para el Generador** | Recuperar un camión en una gasolinera vigilada por infectados y llevarlo al refugio. A mitad de camino, los saqueadores os tienden una emboscada en coche. Si destruyen el camión, la misión falla. | 0 |
| **Purgar el Nido** | Eliminar una horda de infectados que va apareciendo por tandas y quemar el nido al final. | 0 |
| **Despensa Vacía** | Saquear comida en una tienda 24/7 infestada y volver al refugio. | 0 |
| **Agua Potable** | Reparar una bomba de agua en un muelle, llenar bidones y llevarlos al refugio. | 0 |
| **Chatarrería** | Rebuscar materiales (chatarra, acero, cobre...) en un desguace. Útil en servidores con crafteo. | 0 |
| **Rescate de Supervivientes** | Encontrar a un grupo de civiles rodeados de infectados, hacer que te sigan (`E`) y escoltarlos al refugio. Cada superviviente que muere reduce la recompensa, y si muere más de la mitad, la misión falla. | 10 |
| **Ambulancia de Campaña** | Recuperar una ambulancia abandonada en la carretera y llevarla al refugio. Por el camino, emboscada de saqueadores. | 10 |
| **Saqueo de la Armería** | Saquear cajas de munición en una Ammu-Nation mientras una banda de saqueadores armados la defiende. | 15 |
| **Campamento de Saqueadores** | Asaltar un campamento de saqueadores armados, recuperar el botín y volver. | 20 |
| **Señal de Socorro** | Reparar el generador de una antena de radio y resistir oleadas durante 3 minutos sin abandonar la zona. | 25 |
| **Helicóptero Derribado** | Eliminar a los saqueadores del lugar del accidente, recuperar la caja negra y volver al refugio. | 25 |
| **Asedio al Refugio** | La horda ataca el propio refugio. Hay 30 segundos para prepararse y luego 4 minutos de oleadas. | 30 |
| **El Doctor** | Escoltar a una doctora hasta el refugio. Si muere, la misión falla. | 35 |
| **El Coloso** | Abrirse paso entre una horda y derribar a un infectado gigante con 3000 de vida al que no se mata de un tiro en la cabeza. | 50 |

Durante el **Asedio al Refugio** los infectados aparecen alrededor del refugio, así que también pueden atacar a otros jugadores que estén por allí.

Cada misión elige al azar una de sus ubicaciones libres, así que dos grupos nunca comparten la misma zona a la vez.

## Requisitos

- `qb-core` (con `progressbar`, que ya viene con QBCore)
- `qb-menu`
- **OneSync activado** (el servidor lee la posición de los jugadores y de las entidades)
- Opcional: `qb-vehiclekeys` para las llaves del camión y cualquier sistema de combustible (LegacyFuel, cdn-fuel, ps-fuel u ox_fuel se detectan solos)

## Instalación

1. Copia la carpeta `apoc_misiones` en `resources/` (por ejemplo en `resources/[apocalipsis]/`).
2. En `server.cfg`, añade después de `qb-core` y `qb-menu`:
   ```
   ensure apoc_misiones
   ```
3. Revisa `config.lua`, sobre todo las **coordenadas** (ver más abajo).

## Cómo se juega

- En el mapa aparece el **Refugio - Misiones** (por defecto en Sandy Shores). Acércate al coordinador y pulsa `E` para abrir el menú.
- **En solitario:** eliges la misión y empiezas.
- **En grupo:** el líder crea el grupo e invita a los demás. Los miembros que estén a menos de 30 m del líder cuando acepte la misión entran con él.
- El objetivo actual, el progreso y el tiempo restante se muestran a la derecha de la pantalla.
- Para cobrar hay que **haber ido a la zona de la misión** y estar cerca del punto final cuando se complete (250 m por defecto). Quien se queda AFK en el refugio no cobra (`Config.Group.RequireVisit`).

### Comandos

| Comando | Descripción |
|---------|-------------|
| `/grupo crear` | Crea un grupo (también se crea solo al invitar). |
| `/grupo invitar [id]` | Invita a un jugador (solo el líder). |
| `/grupo aceptar` / `/grupo rechazar` | Responde a una invitación (caduca a los 60 s). |
| `/grupo salir` | Sale del grupo. Si sale el líder, el liderazgo pasa al siguiente miembro. |
| `/grupo expulsar [id]` | Expulsa a un miembro (solo el líder). |
| `/grupo info` | Muestra los miembros del grupo. |
| `/abandonarmision` | Sale de la misión actual sin recompensa. |
| `/apocreset [id]` | (admin) Reinicia los tiempos de espera de un jugador. |

## Escalado en grupo

Los valores escritos como `{ base = X, perMember = Y }` en `config.lua` crecen con cada miembro extra: `X + Y × (miembros − 1)`. Esto afecta a:

- el número de enemigos y de cajas;
- el número de supervivientes que hay que rescatar;
- el tamaño de las oleadas y de la emboscada.

Además, cada participante cobra un **+10% de dinero por cada miembro extra** (`Config.Group.BonusPerMember`).

## Reputación

Cada misión completada suma reputación, que se guarda en los metadatos del personaje (`apoc_reputacion`) y por tanto persiste entre reinicios. Las misiones más difíciles piden reputación para desbloquearse (ver la tabla de arriba). Si quieres que estén todas disponibles desde el principio, pon `minReputation = 0`. Para desactivar el sistema entero, usa `Config.Reputation.enabled = false`.

## Configuración

- **Coordenadas:** las del refugio y las de las misiones son **de ejemplo**. El script ajusta solo enemigos, cajas y supervivientes al suelo más cercano, pero conviene comprobar cada zona en tu mapa, sobre todo si usas un mapa personalizado.
- **Recompensas:** en `rewards` de cada misión. Si un objeto no existe en `qb-core/shared/items.lua`, se omite y la consola muestra un aviso. Por ejemplo, `jerry_can` depende de tu versión de QBCore.
- **Enemigos:** los modelos, la vida, las armas y los vehículos de infectados y saqueadores están en `Config.Enemies`.
- **Llaves y combustible:** en `Config.GiveKeys` y `Config.SetFuel`. Adáptalos si usas otro script.
- **Tiempos de espera:** se guardan en memoria, así que se reinician al reiniciar el servidor. Van por personaje (citizenid), por lo que reconectar no los salta.

### Crear misiones nuevas

Cada misión es una lista de etapas, y puedes combinarlas como quieras:

| Tipo | Qué hace |
|------|----------|
| `search` | Registrar N cajas en la zona. |
| `return` | Volver al refugio. |
| `vehicle` | Recoger un vehículo en la zona (`model`). |
| `deliver` | Llevar ese vehículo al refugio. |
| `kill` | Eliminar N enemigos. |
| `interact` | Acción con barra de progreso en un punto (reparar, quemar...). Puede pedir un objeto con `requiredItem`. |
| `escort` | Rescatar supervivientes y llevarlos al refugio. |
| `defend` | Resistir en la zona durante `duration` segundos. |

Cualquier etapa puede llevar `enemies` con uno de estos modos:

- `guards`: vigilan la zona.
- `objective`: hay que matarlos.
- `waves`: oleadas durante `defend`.
- `ambush`: emboscada durante `deliver`.

Copia una misión de `config.lua`, cámbiale el `id` y ajusta las etapas.

**Opciones extra por tipo de etapa:**

- `interact`
  - `interactDistance`: distancia para interactuar con objetos grandes, como el helicóptero.
  - `requiredItem` y `consumeItem`: exigir un objeto y, si quieres, gastarlo.
- `escort`
  - `models`: modelos propios para los supervivientes (por ejemplo, la doctora).
  - `interactLabel`: texto de la interacción.
  - `minRescuedRatio`: proporción mínima que hay que salvar.
  - `failMessage`: mensaje si la misión falla.
- `defend`
  - `prepTime`: segundos de preparación antes de la primera oleada.
  - `timerLabel`: texto del contador.
  - `progressText`, `startMessage` y `failMessage`: mensajes de la etapa.

**Tipos de enemigos** (`Config.Enemies`):

- `infected`: infectados.
- `raiders`: saqueadores armados.
- `mutant`: el jefe. Admite `criticalHits = false` (no muere de un disparo en la cabeza) y `fallbackModels`.

## Exports (servidor)

```lua
exports['apoc_misiones']:IsInMission(source)     -- true/false
exports['apoc_misiones']:GetGroupMembers(source) -- { src, ... }
```
