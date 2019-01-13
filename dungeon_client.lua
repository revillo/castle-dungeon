--castle://localhost:4000/dungeon_client.lua

-- Load Scripts
local cs = require("https://raw.githubusercontent.com/expo/share.lua/master/cs.lua")
local client = cs.client;
local shash = require("lib/shash")
local Class, GameController = require("lib/game_base")()
local List = require("lib/list")
local EntityType, EntityUtil, GameLogic, NetConstants, PlayerHistory = require("common")()

-- Globals

local State = {}
local gfx = {imgRes = 16}

gfx = {
  
  imgRes = 16,
  tileSize = 32.0,
  offsetX = 200.0,
  offsetY = 200.0,
  
  pxToUnits = function(x,y)
  
    local ts = gfx.tileSize;
    
    return (x - gfx.offsetX) / ts, (y - gfx.offsetY) / ts;
  
  end,
  
  floorQuad = love.graphics.newQuad(0,0, gfx.imgRes * NetConstants.RoomSize, gfx.imgRes * NetConstants.RoomSize, gfx.imgRes, gfx.imgRes),
  
  bricksQuad = love.graphics.newQuad(0,0, gfx.imgRes * NetConstants.RoomSize, gfx.imgRes, gfx.imgRes, gfx.imgRes),
  
  floorImg = (function() 
    local img = love.graphics.newImage("img/cobble.png")
    img:setWrap("repeat", "repeat");
    return img;
  end)(),
  
  bricksImg = (function() 
    local img = love.graphics.newImage("img/bricks.png")
    img:setWrap("repeat", "repeat");
    return img;
  end)(),
  
  unitsToPx = function(x, y)
    
    local ts = gfx.tileSize;
    
    return x * ts + gfx.offsetX, y * ts + gfx.offsetY;
  
  end,
  
  drawBorder = function()
    
    local edge = (NetConstants.ClientVisibility-1) * gfx.tileSize;
    
    love.graphics.setColor(1.0, 1.0, 1.0, 1.0);
    
    love.graphics.setLineWidth(gfx.tileSize* 0.1);
    
    love.graphics.rectangle("line", 
      gfx.offsetX - edge, 
      gfx.offsetY - edge,
      edge * 2.0,
      edge * 2.0
    );
  
  end,
  
  applyScissor = function()
      local edge = (NetConstants.ClientVisibility-1) * gfx.tileSize;

    love.graphics.setScissor(
      gfx.offsetX - edge, 
      gfx.offsetY - edge,
      edge * 2.0,
      edge * 2.0
    );
  end,
  
  clearScissor = function()
  
    love.graphics.setScissor();
  
  end,
  
  drawCursor = function(cursor)
    
    love.graphics.setColor(1.0, 1.0, 1.0, 0.5);
    
    love.graphics.setLineWidth(1.0);
    
    local x, y = gfx.unitsToPx(cursor.x + 0.5, cursor.y + 0.5);
    local w = 16.0;
    local h = 4.0;
    
    love.graphics.rectangle("fill",
      x-h*0.5, y-w*0.5, h, w 
    )
    
     love.graphics.rectangle("fill",
      x-w*0.5, y-h*0.5, w, h 
    )
    
  
  end,
  
  drawEntity = {
  
    [EntityType.Wall] = function(wall, center) 
      local ts = gfx.tileSize;
    
      love.graphics.setColor(0.8, 0.8, 0.8, 1.0);
      love.graphics.rectangle("fill", 
      (wall.x-center.x) * ts + gfx.offsetX, 
      (wall.y-center.y) * ts + gfx.offsetY, 
      ts * wall.w, ts * wall.h);
      
    end,
    
    [EntityType.Bullet] = function(bullet, center)
      
      local ts = gfx.tileSize;
      local x, y = gfx.unitsToPx(bullet.x - center.x, bullet.y - center.y);
      
      love.graphics.setColor(1.0, 0.5, 0.0, 1.0);
      love.graphics.circle("fill", x, y,
        ts * bullet.w);    
    
    end,
    
    [EntityType.Player] = function(player, center)
      local ts = gfx.tileSize;
    
      love.graphics.setColor(1.0, 1.0, 1.0, 1.0);
      love.graphics.rectangle("fill", 
        (player.x-center.x) * ts + gfx.offsetX, 
        (player.y-center.y) * ts + gfx.offsetY, 
        ts, ts);
      
    end,
    
    [EntityType.Floor] = function(flr, center)
    
      local ts = gfx.tileSize;
      local scale = gfx.tileSize / gfx.imgRes;
    
   
      love.graphics.setColor(1.0, 1.0, 1.0, 1.0);
      love.graphics.draw(gfx.floorImg, gfx.floorQuad,
        (flr.x-center.x) * ts + gfx.offsetX, 
        (flr.y-center.y) * ts + gfx.offsetY, 0,
        scale, scale);
        
    --[[
      love.graphics.draw(gfx.bricksImg, gfx.bricksQuad,
        (flr.x-center.x) * ts + gfx.offsetX, 
        (flr.y-center.y+1) * ts + gfx.offsetY, 0,
        scale, scale);
       ]]
        
        --[[
     love.graphics.setColor(0.3, 0.3, 0.3, 1.0);
      love.graphics.rectangle("fill", 
      (flr.x-center.x) * ts + gfx.offsetX, 
      (flr.y-center.y) * ts + gfx.offsetY, 
      ts * flr.w, ts * flr.h);
    ]]
    end
  
  }
}

-- Game state controllers

local PlayController = GameController:new();
local MenuController = GameController:new();

function PlayController:init()

  self.timeTracker = 0;    
  self.cursor = {x = 0, y = 0}
  client.home.playerHistory = PlayerHistory.new();
  self.playerHistory = client.home.playerHistory;
  self.space = shash.new(NetConstants.CellSize);
  self.entitiesByType = {};
  self.entities = {};
  
  for k, type in pairs(EntityType) do
    self.entitiesByType[type] = {};
  end
  
  self.bullets = self.entitiesByType[EntityType.Bullet];
  
end

function PlayController:keypressed(k)
  
  

end

function PlayController:syncHistory(msg)
  
  print("Force Sync");
  
  PlayerHistory.rebuild(self.playerHistory, msg.tick, {
    
    x = msg.x,
    y = msg.y,
    vx = 0,
    vy = 0,
    health = 1,
    damage = 0,
    w = 1,
    h = 1
    
  });
  
end

function PlayController:drawEntitiesOfType(type)
  local playerState = PlayerHistory.getLastState(self.playerHistory);

  for id, e in pairs(self.entitiesByType[type]) do
    gfx.drawEntity[type](e, playerState);
  end

end

function PlayController:draw()
  
  gfx.applyScissor();
  
  local playerState = PlayerHistory.getLastState(self.playerHistory);
  

     --[[
  for k,v in pairs(client.share.entities or {}) do
    
    gfx.drawEntity[v.type](v, playerState);
  
  end]]
  
  self:drawEntitiesOfType(EntityType.Floor);
  self:drawEntitiesOfType(EntityType.Enemy);
  self:drawEntitiesOfType(EntityType.Player);
  self:drawEntitiesOfType(EntityType.Bullet);
  self:drawEntitiesOfType(EntityType.Wall);
  self:drawEntitiesOfType(EntityType.Door);
  
  gfx.drawEntity[EntityType.Player](playerState, playerState);
  
  --gfx.drawCursor(self.cursor);
  
  gfx.clearScissor();

  gfx.drawBorder();

end

function PlayController:receive(msg)
  
  self:syncHistory(msg);

end

function PlayController:mousepressed(x, y)
  
  self.fireFlag = true;
  
end

function PlayController:mousemoved(x, y)
  
  local offset = gfx.tileSize * NetConstants.PlayerSize * 0.5;
  
  self.cursor.x, self.cursor.y = gfx.pxToUnits(x - offset, y - offset);

  
end

function PlayController:updatePlayer()
    local velX = (State.keyboard.d - State.keyboard.a);
    local velY = (State.keyboard.s - State.keyboard.w);
    local ph = self.playerHistory;

    local didFire = self.fireFlag;
    self.fireFlag = false;
  
    PlayerHistory.advance(ph, self.space);
    PlayerHistory.setVelocity(ph, velX, velY);
    
    if (didFire) then
      PlayerHistory.setFire(ph, self.cursor.x, self.cursor.y);
    end
end

function PlayController:update(dt)

    self.timeTracker = self.timeTracker + dt;
   
    -- Apply updates at a fixed interval
    while (self.timeTracker > NetConstants.TickInterval) do
      self.timeTracker = self.timeTracker - NetConstants.TickInterval;
       
      self:updatePlayer();
      
      GameLogic.updateBullets(self);
      
      
    end 
end

-- When a synced entity changes, update in spatial hash
function PlayController:changed(diff)
    local entities = client.share.entities;
    local space = self.space;
  
  for uuid, e in pairs(entities) do
    EntityUtil.rehash(e, space);
    self.entitiesByType[e.type][e.uuid] = e;
  end
  
  --Remove entity if no longer syncing
  for uuid, diff in pairs(diff.entities) do 
    if (diff == cs.DIFF_NIL) then
      space:removeByUUID(uuid);
      for k, ents in pairs(self.entitiesByType) do
        ents[uuid] = nil;
      end
    end
  end

end

function client.changed(diff)

  --local space = State.playController;

  State.controller:changed(diff);

end


if USE_CASTLE_CONFIG then
    client.useCastleConfig()
else
    client.enabled = true
    client.start("localhost:22122")
end

function client.load()
  local w, h = love.graphics.getDimensions();
  gfx.offsetX = w / 2.0;
  gfx.offsetY = h / 2.0;
  
  love.mouse.setCursor(love.mouse.getSystemCursor("crosshair"));
    
  State = {
    controller = PlayController:new(),
    keyboard = {
      w = 0,
      a = 0,
      s = 0,
      d = 0
    };
  }
  
end

function client.receive(msg)
  
  State.controller:receive(msg);

end

function client.keyreleased(k)
  
  State.keyboard[k] = 0;
  
end

function client.mousemoved(x, y)

  State.controller:mousemoved(x,y);

end

function client.mousepressed(x,y)

  State.controller:mousepressed(x,y);
 

end

function client.keypressed(k)
  
  State.keyboard[k] = 1;
  State.controller:keypressed(k);

end

function client.draw()

  State.controller:draw()

end

function client.resize()
  
    local w, h = love.graphics.getDimensions();
    gfx.offsetX = w / 2.0;
    gfx.offsetY = h / 2.0;

end

function client.update(dt)
 
   State.controller:update(dt);
  
end