--castle://localhost:4000/dungeon_server.lua

local shash = require("lib/shash")
local cs = require("https://raw.githubusercontent.com/expo/share.lua/master/cs.lua")
local server = cs.server
local EntityType, EntityUtil, NetConstants, PlayerHistory = require("common")()

if USE_CASTLE_CONFIG then
    server.useCastleConfig()
else
    server.enabled = true
    server.start('22122') -- Port of server
end



local gameState = {}

local share = server.share
local homes = server.homes

local CLIENT_VISIBILITY = 5




function addEntity(entity)

  share.entities[entity.uuid] = entity;

  gameState.space:add(share.entities[entity.uuid], entity.x, entity.y, entity.w, entity.h);
  
end

function rehashEntity(entity)
  
  gameState.space:update(entity, entity.x, entity.y, entity.w, entity.h);

end

-- Initialize game map
function loadMap()
  
  share.entities = {};
  gameState.entities = share.entities;
  gameState.space = shash.new(1);
  gameState.timeTracker = 0;
  gameState.tick = 0;
  
  local space = gameState.space;
  
  -- Add some dummy entities
  for i = 1,10 do
        
    -- Add wall to spatial hash at pos = i,i and size = 1,1
    local wall = {
      type = EntityType.Wall,
      uuid = "w"..i,
      x = i,
      y = i,
      w = 1,
      h = 1
    }
    
    addEntity(wall)
  
  end
  
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
      --if (clientId ~= ent.uuid) then
        result[ent.uuid] = 1;
      --end
    end
    
    -- Use our spacial hash to call makeRelevant on nearby entities
    space:each(playerState.x - CLIENT_VISIBILITY, playerState.y - CLIENT_VISIBILITY,
               CLIENT_VISIBILITY * 2, CLIENT_VISIBILITY * 2, makeRelevant);

    return result;
  end)

end


function server.connect(id)

  addEntity({
    type = EntityType.Player,
    uuid = id,
    x = 0,
    y = 0,
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
      local foundUpdate = false;
    
      if (home.playerHistory) then
        
        --Client player State
        local clientState = PlayerHistory.getState(home.playerHistory, tick);
        
        if (clientState) then
          
          foundUpdate = true;
          
          local oldX, oldY = player.x, player.y;
          
          player.x, player.y = EntityUtil.applyVelocity(player, clientState);
          
          rehashEntity(player)
            
          -- If the player overlaps a wall, move it back
          local overlapsWall = false;
          
          space:each(player, function(entity) 
            overlapsWall = (entity.type == EntityType.Wall);
          end)
          
          if (overlapsWall) then
            player.x, player.y = oldX, oldY;
            rehashEntity(player);
          end
             
        end -- if client state             
      end -- if player history
      
      
      
      if (not foundUpdate) then
        
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
  end
  
  share.entities["cache"] = dt;

end