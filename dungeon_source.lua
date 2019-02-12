--castle://localhost:4000/dungeon_source.lua

local Moat = require("moat");
local Sprite = require("lib/sprite");
local MazeGen = require("lib/maze_gen");

local GameEntities = {
  Player = 0,
  Enemy = 1,
  Wall = 2,
  Floor = 3,
  Orb = 4
}

local GameConstants = {
  RoomSize = 12,
  WorldSize = 200,
  ClientVisibility = 20,
  TickInterval = 1.0/60.0
}

local DGame = Moat:new(
  GameEntities,
  GameConstants
);

local showMenu = true;

function DGame:clientMousePressed(x, y)
  if (self:clientIsConnected() and showMenu) then
    
    self:clientSend({
      cmd = "request_spawn"
    });
    
    showMenu = false;
  end
end

function DGame:serverReceive(clientId, msg)
    
  if (msg.cmd == "request_spawn") then
    self:spawnPlayer(clientId);
  end
  
end

function DGame:playerUpdate(player, input)

  if (input) then 
    --Try mouse (mx, my) values
    local x, y = input.mx or 0, input.my or 0;
    
    --Move player based on keyboard input
    if (input.w) then y = -1 end
    if (input.a) then x = -1 end
    if (input.s) then y = 1 end
    if (input.d) then x = 1 end
    
    --Normalize movement vector
    local mag = math.sqrt(x * x + y * y);
    if (mag > 1.0) then
      x, y = x/mag, y/mag;
    end
    
    local speed = GameConstants.TickInterval * 6.0;
    
    local oldX, oldY = player.x, player.y;
    
    player.x = player.x + speed * x;
    player.y = player.y + speed * y;
    
    --dx is used to set the orientation of player sprite
    if (x > 0) then
      player.dx = -1.0
    elseif (x < 0) then
      player.dx = 1.0;
    end
    
    --Call rehash on any entity to update it for collision detection after moving
    DGame:rehashEntity(player);
    
    DGame:eachOverlapping(player, function(entity)
      if (entity.type == GameEntities.Wall) then
        player.x, player.y = oldX, oldY;
        DGame:rehashEntity(player);
      end
    end); 
    
  end -- if input
  
  local didRespawn = false;
  DGame:eachOverlapping(player, function(entity)
    --Avoid respawning twice if multiple hazards hit us
    if (didRespawn) then return end;

    if (entity.type == GameEntities.Orb) then
      --Higher fidelity hit detection
      if (DGame:getOverlapArea(player, entity) > 0.2) then
        DGame:respawnPlayer(player);
        didRespawn = true;
        return;
      end
    end
  end);

end

local input = {};
function DGame:clientUpdate()
  if (not self:clientIsSpawned()) then
    return
  end
  
  --Set inputs
  input.w = love.keyboard.isDown("w");
  input.a = love.keyboard.isDown("a");
  input.s = love.keyboard.isDown("s");
  input.d = love.keyboard.isDown("d");
  DGame:setPlayerInput(input);
end

function drawText(text)
    love.graphics.setColor(1,1,1,1);
    love.graphics.print(text, 10, 10, 0, 2, 2);
end

function drawEntities(type, ...)
  DGame:eachEntityOfType(type, Sprite.drawEntity, ...);
end

function DGame:clientDraw()
  if (not self:clientIsConnected()) then
    drawText("Connecting... signed in to castle?");
    return;
  end
  
  if (showMenu) then
    drawText("Click to spawn...")
    return;
  end

  if (not self:clientIsSpawned()) then
    drawText("Waiting for spawn...");
    return;
  end
  
  local player = self:getPlayerState();

  Sprite.cameraCenter.x = player.x + player.w * 0.5;
  Sprite.cameraCenter.y = player.y + player.h * 0.5;
  
  drawEntities(GameEntities.Floor, Sprite.images.dirt);
  drawEntities(GameEntities.Wall, Sprite.images.wall_front, 0.0, 1.0);
  drawEntities(GameEntities.Orb, Sprite.images.orb);
  drawEntities(GameEntities.Wall, Sprite.images.wall_top);
  drawEntities(GameEntities.Player, Sprite.images.wizard);
  Sprite.drawEntity(player, Sprite.images.wizard);

end


function addWall(x, y, w, h, isDoor)
    if (isDoor) then return end;
    
    DGame:spawn(GameEntities.Wall,
      x, y, w, h
    );
end

function addHazards(x, y, roomSize)
  
  local direction = (math.random() - 0.5) * 2.0;
  
  for i = 1, 5 do
  --Add an orb and set the circle center and radius properties
    DGame:spawn(GameEntities.Orb, x, y, 1.0, 1.0, {
      centerX = x - 1.0,
      centerY = y - 0.5,
      angle = (i / 5) * math.pi * 2.0,
      direction = direction,
      radius = roomSize * 0.3 
    });
  end
  
end

local createMaze = function(mazeWidth, mazeHeight)
  
  local roomSize = GameConstants.RoomSize;
  local mazeRooms = MazeGen(mazeWidth, mazeHeight);
    
  addWall(0, 0, mazeWidth * roomSize, 1);
  addWall(-1, 0, 1, mazeHeight * roomSize);

  for k, room in pairs(mazeRooms) do
    
    local x,y = (room.x-1) * roomSize, (room.y-1) * roomSize;
    
    DGame:spawn(GameEntities.Floor,
      x, y, roomSize, roomSize
    );
    
    addHazards(x + roomSize * 0.5, y + roomSize * 0.5, roomSize);
    
    local d = 3;
    local e = math.floor((roomSize - d) * 0.5);
    local r = roomSize - 1;
    local t = 1.0;
    local it = 1.0 - t;
    
    addWall(x + r+it,y, t, e);
    addWall(x + r+it,y + e + d, t, e+1);
    
    addWall(x, y + r+it, e, t);
    addWall(x + e + d, y + r+it, e, t);
    
    local doors = room.doors;
    
    addWall(x+r+it,y+e,t,d,doors[1]);
    addWall(x+e,y+r+it,d,t,doors[2]);
    
  end
  
end



function DGame:serverInitWorld()
  createMaze(7, 7);
end

function DGame:serverResetPlayer(player)
  player.x, player.y = 6,6;
end

function DGame:clientResize(x, y)
  Sprite.offsetPx.x = x * 0.5;
  Sprite.offsetPx.y = y * 0.5;
end

function DGame:worldUpdate(gameState)
  DGame:eachEntityOfType(GameEntities.Orb, function(orb)
    
    local t = (gameState.tick * GameConstants.TickInterval) * orb.direction;
    
    orb.x, orb.y = math.sin(t + orb.angle) * orb.radius + orb.centerX, math.cos(t + orb.angle) * orb.radius + orb.centerY;
    
    DGame:rehashEntity(orb);
  
  end);
end

function DGame:clientLoad()

  Sprite.loadImages({
    wall_top = "img/wall_top.png",
    wall_front = "img/wall_front.png",
    dirt = "img/dirt.png",
    wizard = "img/deep_elf_high_priest.png",
    orb = "img/conjure_ball_lightning.png"
  });

  local w, h = love.graphics.getDimensions();
  DGame:clientResize(w, h);
end

DGame:run();



