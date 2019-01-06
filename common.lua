local List = require("lib/list")

local NetConstants = {
  TickInterval = 1.0 / 60.0,
  PlayerSpeed = 0.1,
  ClientVisibility = 10,
  MaxHistory = 20,
  StrayDistance = 0.2 -- Max units a player can stray from server before resync
}

local EntityType = {
  Player = 1,
  Wall = 2,
  Enemy = 3
}

local EntityUtil = {
  
  applyVelocity = function(pos, vel)
    
    local mag = vel.vx * vel.vx + vel.vy * vel.vy;
    
    if (mag > 0.0) then
      
      mag = math.sqrt(mag);
      local x = pos.x + vel.vx * NetConstants.PlayerSpeed / mag;
      local y = pos.y + vel.vy * NetConstants.PlayerSpeed / mag;
      
      return x, y;
    
    end
  
    return pos.x, pos.y;
  end,
  
  
  distanceSquared = function(pos1, pos2) 
    
    local dx = pos2.x - pos1.x
    local dy = pos2.y - pos1.y;

    return dx * dx + dy * dy;
     
  end
}

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

function PlayerHistory.rebuild(ph, tick, state)
  
  ph.tick = tick;
  ph.tickStates = List.new(tick);
  List.pushright(ph.tickStates, state);

end

function PlayerHistory.advance(ph)
  
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
  
  newState.health = oldState.health - oldState.damage;
  newState.damage = 0;
  
end

return function() return EntityType, EntityUtil, NetConstants, PlayerHistory end