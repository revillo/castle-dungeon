--castle://localhost:4000/moat_test.lua

local Moat = require("moat");

local GameEntities = {
  --Must assign a player type
  Player = 0,
  Food = 1
}

local GameConstants = {
  PlayerSpeed = 0.1,
  WorldSize = 100
}

local MyGame = Moat:new(
  GameEntities,
  GameConstants
);

local input = {};
--Update client for every game tick
function MyGame:clientUpdate(gameState)

  --Set inputs
  input.w = love.keyboard.isDown("w");
  input.a = love.keyboard.isDown("a");
  input.s = love.keyboard.isDown("s");
  input.d = love.keyboard.isDown("d");
  MyGame:setPlayerInput(input);
  
end

function getSpeedForSize(player) 
  return 0.3 / player.w;
end

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
    
    --Move player based on keyboard input
    local x, y = 0, 0;
    
    if (input.w) then y = -1 end
    if (input.a) then x = -1 end
    if (input.s) then y = 1 end
    if (input.d) then x = 1 end
    
    --Normalize movement vector
    local mag = math.sqrt(x * x + y * y);
    if (mag > 0.0) then
      x, y = x/mag, y/mag;
    end
    
    local speed = getSpeedForSize(player);
    player.x = player.x + speed * x;
    player.y = player.y + speed * y;
  end

  
  --Each player loses a small amount of size over time
  local sizeLoss = 0.0001;
  resizePlayer(player, math.max(1.0, player.w - sizeLoss))
  
  
   --Clamp player to game boundaries
  if (player.x < 0) then player.x = 0 end
  if (player.y < 0) then player.y = 0 end
  if (player.x + player.w > GameConstants.WorldSize) then player.x = GameConstants.WorldSize - player.w end
  if (player.y + player.h > GameConstants.WorldSize) then player.y = GameConstants.WorldSize - player.h end
  
  
  --Handle interactions with other entities, (players and food)
  MyGame:eachOverlapping(player, function(entity)
    
    if (entity.type == GameEntities.Food) then
      MyGame:despawn(entity);
      resizePlayer(player, player.w + 0.02);
    end
    
    if (entity.type == GameEntities.Player) then
      if (entity.w > player.w) then
        -- Other user handles this case
      elseif (entity.w < player.w) then
        resizePlayer(player, player.w + entity.w / 5.0);
        
          MyGame:despawn(entity);

          if MyGame.isServer then -- Can call spawn on client but it does nothing, spawning should happen on server
            MyGame:spawnPlayer(entity.clientId);
          end
      end
    end
  end);
  
end


local tileSizePx = 30.0;
local cameraCenter = {x = 0, y = 0};
local offsetPx = {x = 0, y = 0};

function drawRect(e)
  
  if (e.despawned) then
    love.graphics.setColor(0.2, 0.2, 0.2, 1.0);
  end
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

function drawPlayer(player)
  love.graphics.setColor(1.0, 1.0, 1.0, 1.0);
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

function MyGame:clientDraw() 
  local player = self:getPlayerState();
  cameraCenter.x = player.x + player.w * 0.5;
  cameraCenter.y = player.y + player.h * 0.5;
  tileSizePx = tileSizePx * 0.95 + (30.0 / player.w) * 0.05;
  
  drawGrid();
  self:eachEntityOfType(GameEntities.Food, drawFood);
  self:eachEntityOfType(GameEntities.Player, drawPlayer);
  drawPlayer(player);
end


function spawnFood()
    local x = math.random() * (GameConstants.WorldSize - 0.3);
    local y = math.random() * (GameConstants.WorldSize - 0.3);
    local size = 0.3;
    
    MyGame:spawn(GameEntities.Food,
      x, y, size, size
    );
end

function MyGame:serverInitWorld()
  for x = 1, 100 do
     spawnFood();
  end
end

function MyGame:serverUpdate()
  
  if (self:numEntitiesOfType(GameEntities.Food) < 100) then
    if (math.random() < 0.1) then
      spawnFood()
    end
  end

end

function MyGame:clientResize(x, y)
  offsetPx.x = x * 0.5;
  offsetPx.y = y * 0.5;
end

--Calls when a player spawns 
function MyGame:resetPlayer(player)
  player.x , player.y = math.random(GameConstants.WorldSize), math.random(GameConstants.WorldSize) 
  player.w , player.h = 1, 1;
end

function MyGame:clientLoad()
  local w, h = love.graphics.getDimensions();
  self:clientResize(w, h);
end

MyGame:run();



