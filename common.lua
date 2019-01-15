local List = require("lib/list")

local NetConstants = {
  TickInterval = 1.0 / 60.0,
  PlayerSpeed = 0.1,
  PlayerSize = 1.0,
  ClientVisibility = 15,
  CellSize = 1,
  RoomSize = 12.0,
  MaxHistory = 60,
  BulletSize = 0.5,
  BulletSpeed = 0.5,
  StrayDistance = 0.2 -- Max units a player can stray from server before resync
}

local EntityType = {
  Player = 1,
  Wall = 2,
  Enemy = 3,
  Bullet = 4,
  Door = 5,
  Floor = 6
}

local EntityUtil = {
  
  applyVelocity = function(pos, vel, speed)
    
    speed = speed or NetConstants.PlayerSpeed;
    
    local mag = vel.vx * vel.vx + vel.vy * vel.vy;
    
    if (mag > 0.0) then
      
      mag = math.sqrt(mag);
      local x = pos.x + vel.vx * speed / mag;
      local y = pos.y + vel.vy * speed / mag;
      
      return x, y;
    
    end
  
    return pos.x, pos.y;
  end,
  
  
  distanceSquared = function(pos1, pos2) 
    
    local dx = pos2.x - pos1.x
    local dy = pos2.y - pos1.y;

    return dx * dx + dy * dy;
     
  end,
  
  overlapsType = function(entity, space, type, fn)
    
    local doesOverlap = false;
    
    local typeTest = function(ent) 
      if (ent.type == type) then
        doesOverlap = true;
              
        if (fn) then
          fn(ent);
        end
      end

    end
    
    if (space:contains(entity)) then
      space:each(entity, typeTest);
    else
      space:each(entity.x, entity.y, entity.w, entity.h, typeTest);
    end
    
    return doesOverlap;
            
  end,
  
  
  rehash = function(entity, space)
  
    space:update(entity, entity.x, entity.y, entity.w, entity.h);
  
  end,
  
  
  removeEntity = function(entity, gameState)
  
    gameState.space:remove(entity);
    gameState.entitiesByType[entity.type][entity.uuid] = nil;
    gameState.entities[entity.uuid] = nil;
  
  end
  
}

local GameLogic = {};

function GameLogic.updateBullets(gameState)
  
    local bullets = gameState.entitiesByType[EntityType.Bullet];
    local space = gameState.space;
    
    for uuid, bullet in pairs(bullets) do
     
     if (bullet) then
      bullet.x, bullet.y = EntityUtil.applyVelocity(bullet, bullet, NetConstants.BulletSpeed);
      EntityUtil.rehash(bullet, space);
      
     
      local hitOnce = false;
      
       EntityUtil.overlapsType(bullet, space, EntityType.Wall, function()          
          hitOnce = true;
       end);
       
       
       EntityUtil.overlapsType(bullet, space, EntityType.Enemy, function(enemy)
          hitOnce = true;
          EntityUtil.removeEntity(enemy, gameState);
       end);
       
       
       if (hitOnce) then
        EntityUtil.removeEntity(bullet, gameState);
       end
    
       
      end
    end
end

local PlayerHistory = {};

function PlayerHistory.new()
  
  local ph =  {
    tick = 0,
    tickStates = List.new()
  }
 
  List.pushright(ph.tickStates, {
    x = 0,
    y = 0,
    vx = 0,
    vy = 0,
    w = NetConstants.PlayerSize,
    h = NetConstants.PlayerSize,
    health = 0,
    damage = 0
  })
  
  return ph;
 
end

function PlayerHistory.setPosition(ph, x, y)
  local state = ph.tickStates[ph.tick];
  state.x = x;
  state.y = y;
end

function PlayerHistory.getPosition(ph, tick)
  
  tick = tick or ph.tick;

  local state = ph.tickStates[tick];
  
  if (not state) then
    return nil, nil;
  else
    return state.x, state.y;
  end
  
end

function PlayerHistory.setHealth(ph, health)
  local state = ph.tickStates[ph.tick];
  state.health = health;
end

function PlayerHistory.setDamage(ph, damage)
  
  local state = ph.tickStates[ph.tick];
  state.damage = damage;
  
end

function PlayerHistory.setFire(ph, dx, dy)

  local mag = dx * dx + dy * dy;

  if (mag > 0.3) then
  
    local state = ph.tickStates[ph.tick];
    state.fx = dx / mag;
    state.fy = dy / mag;

  end
    
end

function PlayerHistory.getLastState(ph)
  
  return ph.tickStates[ph.tick];

end

function PlayerHistory.getState(ph, tick)
  
  tick = tick or ph.tick;
  
  return ph.tickStates[tick];

end

function PlayerHistory.setVelocity(ph, vx, vy)
  local state = ph.tickStates[ph.tick];
  state.vx = vx;
  state.vy = vy;
end

function PlayerHistory.rebuild(ph, msg)
  
  local state = {
    
    x = msg.x,
    y = msg.y,
    vx = 0,
    vy = 0,
    health = 1,
    damage = 0,
    w = NetConstants.PlayerSize,
    h = NetConstants.PlayerSize
    
  }
  
  ph.tick = msg.tick;
  ph.tickStates = List.new(msg.tick);
  List.pushright(ph.tickStates, state);

end

function PlayerHistory.advance(ph, space)
  
  local tickStates = ph.tickStates;
  
  if (List.length(tickStates) >= NetConstants.MaxHistory) then
    List.pushright(tickStates, List.popleft(tickStates)) 
  else
    List.pushright(tickStates, {});
  end
  
  ph.tick = ph.tick + 1;
  
  local newState = ph.tickStates[ph.tick];
  local oldState = ph.tickStates[ph.tick-1];
  
  for k,v in pairs(oldState) do
    newState[k] = v;
  end
  
  newState.x, newState.y = EntityUtil.applyVelocity(oldState, oldState); 

  if (EntityUtil.overlapsType(newState, space, EntityType.Wall)) then
    newState.x, newState.y = oldState.x, oldState.y;
  end

  newState.fx, newState.fy = nil, nil;
  newState.health = oldState.health - oldState.damage;
  newState.damage = 0;
  
end

return function() return EntityType, EntityUtil, GameLogic, NetConstants, PlayerHistory end