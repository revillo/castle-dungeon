--castle://localhost:4000/moat_test.lua

local Moat = require("moat");

local GameEntities = {
  Food = 1
}

local GameConstants = {
  PlayerSpeed = 10
}

local MyGame = Moat:new(
  GameEntities,
  GameConstants
);

function MyGame:applyPlayerInput(newState, oldState, input)
  
  if (input == nil) then return end;
  
  if (input.w) then
    newState.y = oldState.y + GameConstants.PlayerSpeed
    print("moved y up");
  end
  
end

function MyGame:keypressed(key)
   self:setPlayerInput({
     [key] = 1.0
   });
end

function MyGame:draw() 
  
  local player = self:getPlayerState();

  love.graphics.rectangle("fill", player.x, player.y, 100, 100);
end



MyGame:run();



