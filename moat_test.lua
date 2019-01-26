--castle://localhost:4000/moat_test.lua

local Moat = require("moat");

local GameEntities = {
  --Must assign a player type
  Player = 0,
  Food = 1
}

local GameConstants = {
  PlayerSpeed = 0.1,
  WorldSize = 50
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

--Shared function for how a player updates, input may be nil
function MyGame:playerUpdate(player, input)
  
  if (input) then 
  
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
    
    player.x = player.x + GameConstants.PlayerSpeed * x;
    player.y = player.y + GameConstants.PlayerSpeed * y;
  
  end
  
  MyGame:eachOverlapping(player, function(entity)
    
    if (entity.type == GameEntities.Food) then
      MyGame:despawn(entity);
      player.w = player.w + 0.1;
      player.h = player.h + 0.1;
    end
  
  end);
  
  
  
end


local tileSize = 10.0;

function drawSquare(e)
  love.graphics.rectangle("fill", e.x * tileSize, e.y * tileSize, e.w * tileSize, e.h * tileSize);
end

function drawFood(food) 
  love.graphics.setColor(1.0, 0.0, 0.0, 1.0);
  drawSquare(food);
end

function drawPlayer(player)
  love.graphics.setColor(1.0, 1.0, 1.0, 1.0);
  drawSquare(player);
end

function MyGame:clientDraw() 
  local player = self:getPlayerState();
  drawPlayer(player);
  
  self:eachEntityOfType(GameEntities.Food, drawFood);
  self:eachEntityOfType(GameEntities.Player, drawPlayer);
end

function MyGame:serverInitWorld(gameState)
  for x = 1, 100 do
    local x = math.random() * (GameConstants.WorldSize - 0.3);
    local y = math.random() * (GameConstants.WorldSize - 0.3);
    local size = 0.3;
    
    self:spawn(self.EntityTypes.Food,
      x, y, size, size
    );
  end
end

function MyGame:spawnNewPlayer(id)

  local x,y = GameConstants.WorldSize * 0.5, GameConstants.WorldSize * 0.5;
  
  local width, height = 1, 1;
  
  self:spawn(self.EntityTypes.Player, 
    x, y, width, height, {uuid = id}
  );

end

MyGame:run();



