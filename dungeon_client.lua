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
local gfx = {}

QuadCache = {};

TileGfx = {

  imgRes = 32,
  
  loadImg = function(path)
    
    local img = love.graphics.newImage(path);
    img:setWrap("repeat", "repeat");
    img:setFilter("nearest", "nearest");
    return img;
  
  end,
  
  getQuad = function(width, height)
    
    local key = width.."+"..height;
    
    if (not QuadCache[key]) then
      QuadCache[key] = love.graphics.newQuad(
        0,0, TileGfx.imgRes * width, TileGfx.imgRes * height, TileGfx.imgRes, TileGfx.imgRes
      );
    end
    
    return QuadCache[key];
  
  end,
  
  drawTiles = function(img, x, y, w, h, scale, flipx)
    
    love.graphics.setColor(1.0, 1.0, 1.0, 1.0);

    love.graphics.draw(img, TileGfx.getQuad(w, h),
        x, y, 0.0, scale * (flipx or 1.0), scale, 16, 16);
  
  end

}

gfx = {
  
  tileSize = 32.0,
  offsetX = 200.0,
  offsetY = 200.0,
  
  pxToUnits = function(x,y)
  
    local ts = gfx.tileSize;
    
    return (x - gfx.offsetX) / ts, (y - gfx.offsetY) / ts;
  
  end,
  
  img = {
    fire = TileGfx.loadImg("img/orb_of_destruction.png"),
    grass = TileGfx.loadImg("img/grass.png"),
    wizard = TileGfx.loadImg("img/deep_elf_high_priest.png"),
    brickdark = TileGfx.loadImg("img/brickdark.png"),
    brick = TileGfx.loadImg("img/bricks.png"),
    wallshadow = TileGfx.loadImg("img/wallshadow.png"),
    cobble = TileGfx.loadImg("img/cobble.png"),
    bat = TileGfx.loadImg("img/skeleton_bat.png")
  },
  
  unitsToPx = function(x, y)
    
    local ts = gfx.tileSize;
    
    return x * ts + gfx.offsetX, y * ts + gfx.offsetY;
  
  end,
  
  drawBasic = function(img, entity, center)
  
    local scale = gfx.tileSize/TileGfx.imgRes;
    local x, y = gfx.unitsToPx(entity.x - center.x, entity.y - center.y);   
    
    if (entity.vx and entity.vx > 0) then
      TileGfx.drawTiles(img, x, y, entity.w, entity.h, scale, -1.0);
    else
      TileGfx.drawTiles(img, x, y, entity.w, entity.h, scale);
    end
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
  
  drawWallBricks = function(wall, center)
      
      local scale = gfx.tileSize/TileGfx.imgRes;
      local x, y = gfx.unitsToPx(wall.x - center.x, wall.y - center.y + wall.h);      
      TileGfx.drawTiles(gfx.img.brick, x, y, wall.w, 1, scale);
      
      x,y = gfx.unitsToPx(wall.x - center.x, wall.y - center.y + wall.h + 0.95);
      TileGfx.drawTiles(gfx.img.wallshadow, x, y, wall.w, 1, scale);

  end,
  
  drawEntity = {
  
    [EntityType.Wall] = function(wall, center) 

      gfx.drawBasic(gfx.img.brickdark, wall, center);

    end,
    
    [EntityType.Bullet] = function(bullet, center)
      
      local ts = gfx.tileSize;
      local x, y = gfx.unitsToPx(bullet.x - center.x, bullet.y - center.y);
      love.graphics.setColor(1.0, 1.0, 1.0, 1.0);
            
      love.graphics.draw(gfx.img.fire, x, y, math.atan2(bullet.vy, bullet.vx) + math.pi * 1.5, ts * bullet.w / TileGfx.imgRes, ts * bullet.w / TileGfx.imgRes, TileGfx.imgRes/2, TileGfx.imgRes/2);
      
    end,
    
    [EntityType.Player] = function(player, center)

      gfx.drawBasic(gfx.img.wizard, player, center);
      
    end,
    
    [EntityType.Floor] = function(flr, center)
    
      gfx.drawBasic(gfx.img.cobble, flr, center);
   
    end,
    
    [EntityType.Enemy] = function(flr, center)
    
      gfx.drawBasic(gfx.img.bat, flr, center);
   
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
    
end

function PlayController:keypressed(k)
  
  

end

function PlayController:syncHistory(msg)
  
  print("Force Sync");
  
  PlayerHistory.rebuild(self.playerHistory, msg);
  
end

function PlayController:drawEntitiesOfType(type)
  local playerState = PlayerHistory.getLastState(self.playerHistory);

  for id, e in pairs(self.entitiesByType[type]) do
    gfx.drawEntity[type](e, playerState);
  end

end

local grassEntity = {x = -100, y = -100, w = 1000, h = 1000} 

function PlayController:draw()
  
  gfx.applyScissor();
  local playerState = PlayerHistory.getLastState(self.playerHistory);

  gfx.drawBasic(gfx.img.grass,  grassEntity, playerState);

  self:drawEntitiesOfType(EntityType.Floor);
  
  -- Front Facing Wall Effects
  for id, e in pairs(self.entitiesByType[EntityType.Wall]) do
    gfx.drawWallBricks(e, playerState);
  end
  
  self:drawEntitiesOfType(EntityType.Enemy);
  self:drawEntitiesOfType(EntityType.Player);
  
  -- Draw Local player
  gfx.drawEntity[EntityType.Player](playerState, playerState);

  self:drawEntitiesOfType(EntityType.Bullet);
  self:drawEntitiesOfType(EntityType.Wall);
  self:drawEntitiesOfType(EntityType.Door);
  
  --gfx.drawCursor(self.cursor);
  
  gfx.clearScissor();

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

    local ph = self.playerHistory;
    PlayerHistory.advance(ph, self.space);

    -- Set player movement request
    local velX = (State.keyboard.d - State.keyboard.a);
    local velY = (State.keyboard.s - State.keyboard.w);
    PlayerHistory.setVelocity(ph, velX, velY);
    
    -- Set player fire request
    local didFire = self.fireFlag;
    self.fireFlag = false;
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
      --GameLogic.updateBullets(self);
    
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