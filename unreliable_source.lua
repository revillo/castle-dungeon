--castle://localhost:4000/unreliable_source.lua

local Moat = require("moat");

local GameEntities = {
  Player = 0
}


local GameConstants = {
  PlayerSpeed = 0.1,
  WorldSize = 30
}

local UGame = Moat:new(
  GameEntities,
  GameConstants
);

local showMenu = true;
local tileSizePx = 30.0;
local cameraCenter = {x = 0, y = 0};
local offsetPx = {x = 0, y = 0};
local mousePos = {x = 0, y = 0};

function UGame:clientMousePressed(x, y)
  if (self:clientIsConnected() and showMenu) then
    -- Initial handshake to connect
    self:clientSend({
      cmd = "request_spawn"
    });
    showMenu = false;
  else
    --mouseEvent = {x = x, y = y};
  end  
end

function UGame:serverReceive(clientId, msg)
  if (msg.cmd == "request_spawn") then
    self:spawnPlayer(clientId);
    print("spawn", clientId);
  end
end


local input = {};
function UGame:clientUpdate()
  if (not UGame:clientIsSpawned()) then
    return
  end
  
  --Set inputs
  input.w = love.keyboard.isDown("w");
  input.a = love.keyboard.isDown("a");
  input.s = love.keyboard.isDown("s");
  input.d = love.keyboard.isDown("d");
  
  --Handle mouse click direction
  if (mouseEvent) then
    input.mx, input.my = Sprite.pxToUnits(mouseEvent.x, mouseEvent.y);
    
    --Player center is at 0.5, 0.5
    input.mx = input.mx + 0.5;
    input.my = input.my + 0.5;
    mouseEvent = nil;
  else
    input.mx = nil;
    input.my = nil;
  end
    
  UGame:setPlayerInput(input);
end

function handlePlayerInput(player, input)
    local x, y = 0, 0;
    
    --Move player based on keyboard input
    if (input.w) then y = -1 end
    if (input.a) then x = -1 end
    if (input.s) then y = 1 end
    if (input.d) then x = 1 end
    
    --Normalize movement vector
    x, y = UGame.Utils.normalize(x, y);

    UGame:moveEntity(player, player.x + GameConstants.PlayerSpeed * x, player.y + GameConstants.PlayerSpeed * y);
end

function UGame:playerUpdate(player, input)

  if (input) then 
    handlePlayerInput(player, input);
  end
  
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

function drawText(text)
    love.graphics.setColor(1,1,1,1);
    love.graphics.print(text, 10, 10, 0, 2, 2);
end


function UGame:clientDraw() 

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
  --self:eachEntityOfType(GameEntities.Food, drawFood);
  self:eachEntityOfType(GameEntities.Player, drawPlayer);
end

function UGame:clientResize(x, y)
  offsetPx.x = x * 0.5;
  offsetPx.y = y * 0.5;
end

--Calls when a player spawns 
function UGame:serverResetPlayer(player)
  player.x , player.y = math.random(GameConstants.WorldSize), math.random(GameConstants.WorldSize) 
  player.w , player.h = 1, 1;
end

function UGame:clientLoad()
  local w, h = love.graphics.getDimensions();
  self:clientResize(w, h);
end

UGame:run();