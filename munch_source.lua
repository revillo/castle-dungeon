--castle://localhost:4000/munch_source.lua

local Moat = require("moat");

local GameEntities = {
  --Must assign a player type
  Player = 0,
  Food = 1
}

local GameConstants = {
  WorldSize = 100,
  MaxFood = 100,
  ClientVisibility = 40,
  FoodGain = 0.02,
  SizeLoss = 0.0001
}

local MyGame = Moat:new(
  GameEntities,
  GameConstants
);

local Sounds = {};

local showMenu = true;
local tileSizePx = 30.0;
local cameraCenter = {x = 0, y = 0};
local offsetPx = {x = 0, y = 0};
local mousePos = {x = 0, y = 0};


function MyGame:clientMouseMoved(x, y)
  mousePos.x = x;
  mousePos.y = y;
end

--These quick and dirty functions just allow a player to click before spawning into the world when "showMenu" is true
function MyGame:clientMousePressed(x, y)
  if (MyGame:clientIsConnected() and showMenu) then
    
    -- Send any table as a message to server using clientSend
    MyGame:clientSend({
      cmd = "request_spawn"
    });
    
    showMenu = false;
  end
end

function spawnNewPlayer(clientId)
  local x, y = math.random(GameConstants.WorldSize), math.random(GameConstants.WorldSize) 
  local w, h = 1, 1;    
  MyGame:serverSpawnPlayer(clientId, x, y, w, h);
end

-- Server receives a send command
function MyGame:serverReceive(clientId, msg)
  if (msg.cmd == "request_spawn") then
    spawnNewPlayer(clientId);
  end
end

-- We can also have a player spawn immediately.
-- Uncomment the following function to have player spawn on connect
function MyGame:serverOnClientConnected(clientId)
  spawnNewPlayer(clientId);
end

--Update client for every game tick. 
local input = {};
function MyGame:clientUpdate(dt)
  if (not MyGame:clientIsSpawned()) then
    return
  end
  
  showMenu = false;
  
  --Set inputs
  input.w = love.keyboard.isDown("w");
  input.a = love.keyboard.isDown("a");
  input.s = love.keyboard.isDown("s");
  input.d = love.keyboard.isDown("d");
  
  --Scale the to-mouse vector a few tiles worth so we can modify speed based on distance
  local mouseScale = tileSizePx * 5.0;
  
  --offsetPx is the center point
  input.mx = ((mousePos.x - offsetPx.x) / mouseScale);
  input.my = ((mousePos.y - offsetPx.y) / mouseScale);
  
  -- Input to be shared with server to determine player motion. 
  -- Menu clicks and other UI/UX inputs need not be sent to the server and can be handled separately.
  MyGame:clientSetInput(input);
  
end

function getSpeedForSize(player) 
  return 0.3 / player.w;
end

-- Helper function to set the width and height values simultaneously
function resizePlayer(player, newSize)
  local diff = newSize - player.w;
  player.w = newSize;
  player.h = newSize;
  player.x = player.x - diff * 0.5;
  player.y = player.y - diff * 0.5;
end

--Shared function for how a player updates, input may be nil
function MyGame:playerUpdate(player, input)
  
  if (input) then 
    
    --Try mouse (mx, my) values
    local x, y = input.mx or 0, input.my or 0;
    
    --Move player based on keyboard input
    if (input.w) then y = -1 end
    if (input.a) then x = -1 end
    if (input.s) then y = 1 end
    if (input.d) then x = 1 end
    
    --Normalize movement vector but preserve lengths < 1
    local mag = math.sqrt(x * x + y * y);
    if (mag > 1.0) then
      x, y = x/mag, y/mag;
    end
    
    local speed = getSpeedForSize(player);
    player.x = player.x + speed * x;
    player.y = player.y + speed * y;
  end

  
  --Each player loses a small amount of size over time
  local sizeLoss = GameConstants.SizeLoss;
  resizePlayer(player, math.max(1.0, player.w - sizeLoss))
  
  
   --Clamp player to game boundaries
  if (player.x < 0) then player.x = 0 end
  if (player.y < 0) then player.y = 0 end
  if (player.x + player.w > GameConstants.WorldSize) then player.x = GameConstants.WorldSize - player.w end
  if (player.y + player.h > GameConstants.WorldSize) then player.y = GameConstants.WorldSize - player.h end
  
  
  --Handle interactions with other entities, (players and food)
  MyGame:eachOverlapping(player, function(entity)
    
    --Interact with food
    if (entity.type == GameEntities.Food) then
      MyGame:despawn(entity);
      resizePlayer(player, player.w + GameConstants.FoodGain);
      MyGame:playSound(Sounds.pop);
    end
    
    --Interact with another player
    if (entity.type == GameEntities.Player) then
      if (player.w > entity.w) then
          --I get bigger
          resizePlayer(player, player.w + entity.w / 5.0);
          MyGame:playSound(Sounds.pop);
          --Other player respawns
          local x, y = math.random(GameConstants.WorldSize), math.random(GameConstants.WorldSize) 
          local w, h = 1, 1;    
          
          self:respawnPlayer(entity, x, y, w, h);
      end
    end
  end);
  
  MyGame:moveEntity(player);
  
end

function drawRect(e)
  love.graphics.rectangle("fill", 
    (e.x - cameraCenter.x) * tileSizePx + offsetPx.x, 
    (e.y - cameraCenter.y) * tileSizePx + offsetPx.y, 
    e.w * tileSizePx, 
    e.h * tileSizePx
  );
  
end

function drawFood(food) 
  love.graphics.setColor(1.0, 0.0, 0.0, 1.0);
  drawRect(food);
end

function randomizeColor(seed)
  local r = math.sin(seed * 123.456 + 789) * 0.2 + 0.8;
  local g = math.cos(seed * 123.456 + 789) * 0.2 + 0.8;
  local b = math.sin(seed * 987.654 + 321) * 0.2 + 0.8;
  love.graphics.setColor(r, g, b, 1.0);
end

function drawPlayer(player)
  randomizeColor(player.uuid);
  drawRect(player);
end

local gridBar = {};
function drawGrid()
  local size = GameConstants.WorldSize;
  
  love.graphics.setColor(0.2, 0.2, 0.2, 1.0);
  
  for i = 0,size,10 do
    gridBar.x, gridBar.y = 0, i;
    gridBar.w, gridBar.h = GameConstants.WorldSize, 0.1;
    drawRect(gridBar);
    gridBar.x, gridBar.y = i, 0;
    gridBar.w, gridBar.h = 0.1, GameConstants.WorldSize;
    drawRect(gridBar);
  end
end

function drawText(text)
    love.graphics.setColor(1,1,1,1);
    love.graphics.print(text, 10, 10, 0, 2, 2);
end

function MyGame:clientDraw() 

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
  cameraCenter.x = player.x + player.w * 0.5;
  cameraCenter.y = player.y + player.h * 0.5;
  tileSizePx = tileSizePx * 0.95 + (30.0 / player.w) * 0.05;
  
  drawGrid();
  self:eachEntityOfType(GameEntities.Food, drawFood);
  self:eachEntityOfType(GameEntities.Player, drawPlayer);
end

--Spawns a food entity at a random location
function spawnFood()
    local x = math.random() * (GameConstants.WorldSize - 0.3);
    local y = math.random() * (GameConstants.WorldSize - 0.3);
    local size = 0.3;
    
    MyGame:spawn(GameEntities.Food,
      x, y, size, size
    );
end

-- Called when the server is started
function MyGame:serverInitWorld()
  for x = 1, GameConstants.MaxFood do
     spawnFood();
  end
end


--Since food is spawned randomly, client can't predict spawn locations. So do it in serverUpdate rather than worldUpdate
function MyGame:serverUpdate(dt)
  
  if (self:numEntitiesOfType(GameEntities.Food) < GameConstants.MaxFood) then
    if (math.random() < 0.1) then
      spawnFood()
    end
  end

end

-- Callback for when player's window is resized.
function MyGame:clientResize(x, y)
  offsetPx.x = x * 0.5;
  offsetPx.y = y * 0.5;
end

function MyGame:clientLoad()

  --Can call resize handler manually just to set the window data
  local w, h = love.graphics.getDimensions();
  self:clientResize(w, h);
  
  --Load any images, sounds, shaders etc..
  Sounds.pop = love.audio.newSource("audio/pop.ogg", "static");
  
end

MyGame:run();



