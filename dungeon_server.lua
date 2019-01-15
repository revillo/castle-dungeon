--castle://localhost:4000/dungeon_server.lua

local cs = require("https://raw.githubusercontent.com/expo/share.lua/master/cs.lua")
local server = cs.server
local mazegen = require("lib/maze_gen")
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
  
    gameState.entitiesByType[entity.type][entity.uuid] = share.entities[entity.uuid];
  
end

createMaze = function(mazeWidth, mazeHeight)
  
  local roomSize = NetConstants.RoomSize;
  local mazeRooms = mazegen(mazeWidth, mazeHeight);

  local wallId = 0;
  local addWall = function(x,y,w,h, isDoor)
    if (isDoor) then 
      
      wallId = wallId + 1;
   
      addEntity({
        type = EntityType.Enemy,
        uuid = "e"..wallId,
        x = x + w * 0.5 - 0.5,
        y = y + h * 0.5,
        w = 1,
        h = 1
      });
      return;

    end

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
    
  addWall(0, 0, mazeWidth * roomSize, 1);
  addWall(-1, 0, 1, mazeHeight * roomSize);

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
    
    local d = 3;
    local e = math.floor((roomSize - d) * 0.5);
    local r = roomSize - 1;
    local t = 1.0;
    local it = 1.0 - t;
    
    --[[
    addWall(x,y, t, e);
    addWall(x,y + e + d, t, e);
    
    addWall(x, y, e, t);
    addWall(x + e + d, y, e, t);
    ]]
    
    addWall(x + r+it,y, t, e);
    addWall(x + r+it,y + e + d, t, e+1);
    
    addWall(x, y + r+it, e, t);
    addWall(x + e + d, y + r+it, e, t);
    
    local doors = room.doors;
    
    addWall(x+r+it,y+e,t,d,doors[1]);
    addWall(x+e,y+r+it,d,t,doors[2]);
    
    --[[
    addWall(x,y+e,t,d,doors[3]);
    addWall(x+e,y,d,t,doors[4]);
    ]]
    
  end
  

end


-- Initialize game map
function loadMap()
  
  share.entities = {};
  gameState = GameLogic.newState();
  gameState.entities = share.entities;

  
  local space = gameState.space;
  
  createMaze(7, 7);
  
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
    x = NetConstants.RoomSize * 0.5,
    y = NetConstants.RoomSize * 0.5,
    vx = 0,
    vy = 0,
    w = NetConstants.PlayerSize,
    h = NetConstants.PlayerSize
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
      local hadHistory = false;
      local hadState = false;
      local wasFar = false;
      local myTick = tick;
      local clientTick = 0;
    
      if (home.playerHistory) then
        clientTick = home.playerHistory.tick
        
        hadHistory = true;
        
        --Client player State
        local clientState = PlayerHistory.getState(home.playerHistory, tick);
        
        if (clientState) then
          
          hadState = true;
          
          --Most likely don't need to sync, unless client is too far from server state
          
          shouldSyncClient = EntityUtil.distanceSquared(player, clientState) > NetConstants.StrayDistance;
          
          wasFar = shouldSyncClient;
          
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
            gameState.bulletId = gameState.bulletId + 1;

            addEntity({
            
              type = EntityType.Bullet,
              uuid = uuid,
              x = oldX,
              y = oldY,
              vx = clientState.fx,
              vy = clientState.fy,
              w = NetConstants.BulletSize,
              h = NetConstants.BulletSize
              
            });
            
          end
             
        end -- if client state             
      end -- if player history
      
      
      
      if (shouldSyncClient) then
        
        server.send(id, {
          
          tick = tick,
          x = player.x,
          y = player.y,
          hadHistory = hadHistory,
          hadState = hadState,
          wasFar = wasFar,
          servertick = myTick,
          clienttick = clientTick
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