--castle://localhost:4000/moat_test.lua

local Moat = require("moat");

local GameEntities = {
  Food = 1
}

local GameConstants = {
  PlayerSpeed = 1
}

local MyGame = Moat:new(
  GameEntities,
  GameConstants
);

function MyGame:applyPlayerInput(state, input)
  
  if (input == nil) then return end;
  
  if (input.w) then
    state.y = state.y + GameConstants.PlayerSpeed
    print("apply y up");
  end
  
end


function MyGame:clientKeyPressed(key)
    print("press", key);
   self:setPlayerInput({
     [key] = true
   });
end

function MyGame:clientKeyReleased(key)
   self:setPlayerInput({
     [key] = false
   });
end


local tileSize = 10.0;

function drawSquare(e)
  love.graphics.rectangle("fill", e.x * tileSize, e.y * tileSize, e.w * tileSize, e.h * tileSize);
end

function drawFood(food) 
  love.graphics.setColor(1.0, 0.0, 0.0, 1.0);
  drawSquare(food);
end

function MyGame:clientDraw() 
  local player = self:getPlayerState();
  love.graphics.setColor(1.0, 1.0, 1.0, 1.0);
  drawSquare(player);
  
  self:eachEntityOfType(GameEntities.Food, drawFood);
end

function MyGame:serverInitWorld(gameState)

  for x = 1, 100 do
    
    local x = math.random() * 100.0;
    local y = math.random() * 100.0;
    local size = 0.3;
    
    self:spawnEntity(self.EntityTypes.Food,
      x, y, size, size
    );
    
  end

end

MyGame:run();



