# Moat Multiplayer Framework for Castle
## Getting started

Moat is a multiplayer framework for Castle (Playcastle.io) with a focus on simplicity and ease of use.

Check out the medium posts for overview / tutorials:

[Part 1 - Introducing Moat / Make a simple multiplayer IO game](https://medium.com/@olivver/introducing-moat-a-multiplayer-framework-for-castle-32c92c8365ca)

[Part 2 - Making a Multiplayer Dungeon Crawler](https://medium.com/@olivver/moat-part-2-multiplayer-dungeon-crawler-cea6fe79801e)

Add moat to your project:
``` lua
-- game_source.lua
local Moat = require("https://raw.githubusercontent.com/revillo/castle-dungeon/master/moat.lua")
local MyGame = Moat:new()
-- Write Game Logic
```
Then make a second file:
``` lua
-- game_castle.lua
USE_CASTLE_CONFIG = true
require("game_source")
```
Now anyone with a castle account can run game_castle.lua in the castle app to play your multiplayer game in a production environment. Castle will set up a server automatically.

To create a local testing environment, make a test server:
``` lua
-- game_local_server.lua
CASTLE_SERVER_LOCAL = true
require("game_source")
```
Run game_local_server.lua in one castle app, and run game_source.lua in another, the source will default to a local client.

## Play the tutorial games

castle://raw.githubusercontent.com/revillo/castle-dungeon/master/munch.lua -  Eat other players to grow loarger (munch_source.lua)

castle://raw.githubusercontent.com/revillo/castle-dungeon/master/dungeon.lua - Dungeon crawler / roguelike topdown adventure (dungeon_source.lua)

castle://raw.githubusercontent.com/revillo/castle-dungeon/master/tails.lua - Multiplayer snake/slither (tails_source.lua)

castle://raw.githubusercontent.com/revillo/castle-dungeon/master/brick.lua - Multiplayer breakout/arkanoid (tails_source.lua)

## API Quick Reference (v1.1)
#### Common (shared between client and server)
 
##### Entity Built-In Properties
``` lua
x -- x position
y -- y position
w -- width in units
h -- height in units
uuid -- unique idenitifier
clientId -- For player entities, client's connection idenitifier
```
##### Hidden Entity Properties
``` lua
_spawnTick -- Spawn time for temporaries
_despawnTick -- Despawn time for locally despawned entities
```
##### GameConstants (Default Value)
``` lua
TickInterval -- Time between game ticks, (1/60 seconds)
ClientVisibility -- How far a player can see around their entity (20 units)
MaxClients -- Limit number of clients accepted by one server(64)
CellSize -- Size of cell in spatial hash acceleration structure (5 units)
MaxHistory -- How many ticks worth of input data to store. (120)
``` 
##### Callbacks
``` lua
function Moat:playerUpdate(player, input, dt) -- Defines how a player updates on each tick
function Moat:worldUpdate(dt) -- How npc entities update on each tick
```
##### Utilities
``` lua
function Moat:new(EntityTypes, GameConstants) --EntityTypes is enum of game types, Constants explained above
function Moat:run() -- Run the game
function Moat:getTick() -- Returns current tick of game state, like a timestamp
function Moat:getOverlapArea(entityA, entityB) -- Return the overlapping area of two entity hitboxes
function Moat:numEntitiesOfType(type)
function Moat:getEntity(uuid) 
function Moat:destroy(entity) -- Destroys an entity (Prefer using despawn instead)
function Moat:eachEntity(fn, [...]) -- Calls fn on each entity, extra arguments passed through
function Moat:eachEntityOfType(type, fn, [...])
function Moat:moveEntity(entity, [x], [y], [w], [h]) -- Update bounds for use with collision detection
function Moat:eachOverlapping(entity, fn) -- Calls fn on every entity that overlaps with current entity's bounds

function Moat:respawnPlayer(playerEntity, x, y, w, h, [data]) -- Respawn an existing player. Hides player locally and waits for server respawn
function Moat:playSound(source) -- Play a love audio source (no-op on server)
function Moat:spawn(type, x, y, w, h, [data]) -- Spawn a new entity (temporary on client)
function Moat:despawn(entity) -- Despawn an existing entity
```
##### Internal
``` lua
function Moat:update(dt)
function Moat:rehashEntity(entity) 
```
#### Client Functions

##### Callbacks (Overwrite these methods, they will be called by Moat)

```lua
function Moat:clientKeyPressed(key) 
function Moat:clientKeyReleased(key) 
function Moat:clientMousePressed(x, y)
function Moat:clientMouseMoved(x, y) 
function Moat:clientWheelMoved(dx, dy) 
function Moat:clientResize(w, h) 
function Moat:clientReceive(msg)
function Moat:clientDraw()
function Moat:clientOnConnected() 
function Moat:clientOnDisconnected() 
function Moat:clientLoad() 
function Moat:clientReceive(msg)
function Moat:clientUpdate(dt) 
```

#####  Utilities
``` lua
function Moat:clientGetPlayerState() -- Returns spawned player state
function Moat:clientGetPing() -- Returns client round trip time to server in ms
function Moat:clientSetInput(input) -- Set input used for updating player state. Shared with server
function Moat:clientIsSpawned() -- Returns true/false for whether client is spawned
function Moat:clientIsConnected() -- Returns true/false whether client is connected to server
function Moat:clientSend(msg) -- Send a direct message to server. msg is a serializable table. 
function self:clientSendUnreliable(msg) -- Message sent once, may never arrive
function Moat:clientGetId() -- return client id for this client

function Moat:clientGetShare() -- return server's 
share table that client can read. See https://github.com/castle-games/share.lua
function Moat:clientGetHome() -- return client's shared table. Client can write freely to this table and server can read.
"ih" (inputHistory) is reserved key.
```

#####  Internal operations 
``` lua
function Moat:clientSyncEntity(serverEntity)
function Moat:clientUnsyncEntityId(uuid)
function Moat:clientSyncEntities()
function Moat:advanceGameState()
function Moat:clientSyncPlayer(serverPlayer)
```
#### Server functions
##### Callbacks
``` lua
function Moat:serverInitWorld()
function Moat:serverReceive(clientId, msg) 
function Moat:serverOnClientConnected(clientId)
function Moat:serverOnClientDisconnected(clientId)

```
##### Utilities
``` lua
function Moat:serverSpawnPlayer(clientId, x, y, w, h, [data])
function Moat:serverUpdate(dt)
function Moat:serverSend(clientId, msg)
function Moat:serverSendUnreliable(clientId, msg) -- Message sent once, may never arrive
function Moat:serverGetEntityForClientId(clientId) -- Get player's game entity from their clientId
function Moat:serverGetShare() -- returns server's share table. Server can write to this table, all clients can read. "entities" and "tick" keys are used internally. See https://github.com/castle-games/share.lua 

function Moat:serverGetHome(clientId) -- return client's home table for client id
```
##### Internal
``` lua
function Moat:advanceGameState() 
function Moat.serverEntityRelevance(entities, clientId)
function Moat:serverUpdatePlayers()
```

## Release notes

#### Version 1.2

- Added Brick Example (brick_source.lua)

- Added MaxClients to GameConstants
  
- Added functions

``` lua
  Moat:serverGetEntityForClientId(clientId) -- returns player entity for client id
  
  Moat:serverGetShare() -- returns server's share table. See https://github.com/castle-games/share.lua

  Moat:serverGetHome(clientId) -- return client's home table for client id
  
  Moat:clientGetId() -- return client id for this client
  
  Moat:clientGetShare() -- return server's share table. See https://github.com/castle-games/share.lua
  
  Moat:clientGetHome() -- return client's shared table. See
  https://github.com/castle-games/share.lua
  
  Moat:clientSendUnreliable(msg) -- Uses ENet's unreliable channel to send a message that may never arrive.
  
  Moat:serverSendUnreliable(clientId, msg) -- Send unreliable message to client with clientId
  
```
  
#### Version 1.1

- Inputs are sent only when they change, as opposed to sent on every frame to cut down on bandwidth.

- Client implements Moat:spawn by spawning a temporary local entity.

- Moat:serverResetPlayer has been deprecated in favor of 

  Moat:serverSpawnPlayer(clientId, x, y, w, h, data) 
  and
  Moat:respawnPlayer(playerEntity, x, y, w, h, data)

  to be more consistent with the spawn function. (Respawn player on client just despawns local client and waits for server to spawn a new one.)
- Renamed the following functions  
```lua
  Moat:clientSetInput(input) -- was setPlayerInput
  Moat:clientGetPing() -- was getPing
```
- Added the following functions. (Can spawn player on connect now)
``` lua
  Moat:serverOnClientConnected(clientId)
  Moat:serverOnClientDisconnected(clientId)
  Moat:clientOnConnected()
  Moat:clientOnDisconnected()
  
  Moat:clientWheelMoved(dx, dy)
  
  Moat:eachEntity(fn) -- Calls fn on every entity in available state
  Moat:playSound(source) -- Plays a love audio source
```  
- Modified the update functions to take dt to be more consistent with love
```lua 
  Moat:clientUpdate(dt)
  Moat:serverUpdate(dt)
  Moat:worldUpdate(dt)
```


