--castle://localhost:4000/dungeon_server.lua

local shash = require("lib/shash")
local cs = require("https://raw.githubusercontent.com/expo/share.lua/master/cs.lua")
local server = cs.server
local mazegen = require("maze_gen")
local EntityType, EntityUtil, GameLogic, NetConstants, PlayerHistory = require("common")()

if USE_CASTLE_CONFIG then
    server.useCastleConfig()
else
    server.enabled = true
    server.start('22122') -- Port of server
end

local gameState = {};

local share = server.share;
local homes = server.homes;

function addEntity(entity)

  share.entities[entity.uuid] = entity;

  gameState.space:add(share.entities[entity.uuid], entity.x, entity.y, entity.w, entity.h);
  
end

addMazeWalls = function()
  
  local roomSize = NetConstants.RoomSize;
  local mazeRooms = mazegen(2, 2);

  
  local wallId = 0;
  local addWall = function(x,y,w,h, isDoor)
    if (isDoor) then return end;
    
    wallId = wallId + 1;
    
    addEntity({
      type = EntityType.Wall,
      uuid = "w"..wallId,
      x = x,
      y = y,
      w = w,
      h = h 
    });
  end
  
  for k, room in pairs(mazeRooms) do
    
    local x,y = (room.x-1) * roomSize, (room.y-1) * roomSize;

    
    addEntity({
        type = EntityType.Floor,
        uuid = "f"..k,
        x = x,
        y = y,
        w = roomSize,
        h = roomSize
    });
    
    local d = 4;
    local e = (roomSize - d) * 0.5;
    local r = roomSize - 1;
    
    addWall(x,y, 1, e);
    addWall(x,y + e + d, 1, e);
    
    addWall(x, y, e, 1);
    addWall(x + e + d, y, e, 1);
    
    addWall(x + r,y, 1, e);
    addWall(x + r,y + e + d, 1, e);
    
    addWall(x, y + r, e, 1);
    addWall(x + e + d, y + r, e, 1);
    
    local doors = room.doors;
    
    addWall(x+r,y+e,1,d,doors[1]);
    addWall(x+e,y+r,d,1,doors[2]);
    addWall(x,y+e,1,d,doors[3]);
    addWall(x+e,y,d,1,doors[4]);
    
  end
  

end


-- Initialize game map
function loadMap()
  
  share.entities = {};
  gameState.entities = share.entities;
  gameState.space = shash.new(NetConstants.CellSize);
  gameState.timeTracker = 0;
  gameState.tick = 0;
  gameState.bulletId = 0;
  gameState.bullets = {};
  
  local space = gameState.space;
  
  --[[
  for i = 0,24 do
        
    addEntity({
      type = EntityType.Wall,
      uuid = "w"..i,
      x = (math.floor(i / 5)-2) * 5 + 2,
      y = ((i % 5)-2) * 5 + 2,
      w = 2,
      h = 2
    })
  
  end]]
  
  addMazeWalls();
  
  --[[
  addEntity({
      type = EntityType.Wall,
      uuid = "wdfsfd",
      x = 1,
      y = 1,
      w = 10,
      h = 1
    })
  ]]
  
  --[[
  
  for i = 1, 10 do
    
    local enemy = {
      type = EntityType.Enemy,
      uuid = 100 + id
    }
    
    space:add(enemy, 2, i, 1, 1);
    entities[enemy.uuid] = enemy;
  
  end
  
  ]]
  
  -- A client only gets updates for nearby entities
  share.entities:__relevance(function(ents, clientId)
    
    local playerState = share.entities[clientId];
    result = {};
        
    function makeRelevant(ent)
      if (clientId ~= ent.uuid) then
        result[ent.uuid] = 1;
      end
    end
    
    -- Use our spatial hash to call makeRelevant on visible entities
    
    local viz = NetConstants.ClientVisibility;
    
    space:each(playerState.x - viz, playerState.y - viz,
               viz * 2, viz * 2, makeRelevant);

    return result;
  end)

end


function server.connect(id)

  addEntity({
    type = EntityType.Player,
    uuid = id,
    x = 10,
    y = 10,
    vx = 0,
    vy = 0,
    w = 1,
    h = 1
  });
  
end


function server.disconnect(id)
  
  share.entities[id] = nil;

end

function server.load()
  
  loadMap()

end


function updatePlayers()
    local tick = gameState.tick;
    local space = gameState.space;

    for id, home in pairs(homes) do
          
      --Server player state
      local player = share.entities[id];
      local shouldSyncClient = true;
    
      if (home.playerHistory) then
        
        --Client player State
        local clientState = PlayerHistory.getState(home.playerHistory, tick);
        
        if (clientState) then
          
          --Most likely don't need to sync, unless client is too far from server state
          
          shouldSyncClient = EntityUtil.distanceSquared(player, clientState) > NetConstants.StrayDistance;
          
          local oldX, oldY = player.x, player.y;
          
          -- Move player
          player.x, player.y = EntityUtil.applyVelocity(player, clientState);
          
          -- Update shash
          EntityUtil.rehash(player, gameState.space);            
          
          -- If the player overlaps a wall, move it back
          if (EntityUtil.overlapsType(player, space, EntityType.Wall)) then
            player.x, player.y = oldX, oldY;
            EntityUtil.rehash(player, gameState.space);
          end
         
          if (clientState.fx) then
          
            local uuid = "b"..gameState.bulletId;
            addEntity({
            
              type = EntityType.Bullet,
              uuid = uuid,
              x = oldX + NetConstants.PlayerSize * 0.5,
              y = oldY + NetConstants.PlayerSize * 0.5,
              vx = clientState.fx,
              vy = clientState.fy,
              w = NetConstants.BulletSize,
              h = NetConstants.BulletSize
              
            });
            
            gameState.bullets[uuid] = share.entities[uuid];
            gameState.bulletId = gameState.bulletId + 1;
          end
             
        end -- if client state             
      end -- if player history
      
      
      
      if (shouldSyncClient) then
        
        server.send(id, {
          
          tick = tick,
          x = player.x,
          y = player.y
        
        });
      
      end
      
    end -- home loop
end

function server.update(dt)

  gameState.timeTracker = gameState.timeTracker + dt;

  while (gameState.timeTracker > NetConstants.TickInterval) do
    
    gameState.timeTracker = gameState.timeTracker - NetConstants.TickInterval;
    
    gameState.tick = gameState.tick + 1;
    
    updatePlayers();
    
    GameLogic.updateBullets(gameState);
    
  end
  
  share.entities["cache"] = dt;

end