--castle://localhost:4000/dungeon_client.lua

-- Load Scripts
local cs = require("https://raw.githubusercontent.com/expo/share.lua/master/cs.lua")
local client = cs.client;
local Class, GameController = require("lib/game_base")()
local List = require("lib/list")
local EntityType, EntityUtil, NetConstants, PlayerHistory = require("common")()

-- Globals

local State = {}
local gfx = {}

gfx = {
  
  tileSize = 20.0,
  offsetX = 200.0,
  offsetY = 200.0,
  
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
  
  drawEntity = {
  
    [EntityType.Wall] = function(wall, center) 
      local ts = gfx.tileSize;
    
      love.graphics.setColor(1.0, 0.0, 0.0, 1.0);
      love.graphics.rectangle("fill", 
      (wall.x-center.x) * ts + gfx.offsetX, 
      (wall.y-center.y) * ts + gfx.offsetY, 
      ts * wall.w, ts * wall.h);
      
    end,
    
    [EntityType.Player] = function(player, center)
      local ts = gfx.tileSize;
    
      love.graphics.setColor(1.0, 1.0, 1.0, 1.0);
      love.graphics.rectangle("fill", 
        (player.x-center.x) * ts + gfx.offsetX, 
        (player.y-center.y) * ts + gfx.offsetY, 
        ts, ts);
      
    end
  
  }
}

-- Game state controllers

local PlayController = GameController:new();
local MenuController = GameController:new();

function PlayController:init()

  self.timeTracker = 0;    
  client.home.playerHistory = PlayerHistory.new();
  self.playerHistory = client.home.playerHistory;
  
end

function PlayController:keypressed(k)
  
  

end

function PlayController:syncHistory()
  
  
end

function PlayController:draw()
  
  local playerState = PlayerHistory.getLastState(self.playerHistory);
    
  for k,v in pairs(client.share.entities or {}) do
    
    gfx.drawEntity[v.type](v, playerState);
  
  end
  
  gfx.drawEntity[EntityType.Player](playerState, playerState);

  gfx.drawBorder();

end

function PlayController:receive(msg)
  
  print("received");
  
  PlayerHistory.rebuild(self.playerHistory, msg.tick, {
    
    x = msg.x,
    y = msg.y,
    vx = 0,
    vy = 0,
    health = 1,
    damage = 0
    
  });

end

function PlayController:update(dt)
  --client.home.playerHistory = self.playerHistory;

    self.timeTracker = self.timeTracker + dt;
    local velX = (State.keyboard.d - State.keyboard.a)
    local velY = (State.keyboard.s - State.keyboard.w)
    local ph = self.playerHistory;
    
    -- Apply updates at a fixed interval
    
    while (self.timeTracker > NetConstants.TickInterval) do
      self.timeTracker = self.timeTracker - NetConstants.TickInterval;
      
      PlayerHistory.advance(ph);
      PlayerHistory.setVelocity(ph, velX, velY);
      
    end 
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
  
  --[[
  
  for k,v in pairs(client.share.entities or {}) do
    
    print(k);
  
  end
  -]]

   State.controller:update(dt);
  
end