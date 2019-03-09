--castle://localhost:4000/tails_source.lua

local Moat = require("moat");
local List = require("lib/list");

local GameEntities = {
  --Must assign a player type
  Player = 0,
  Food = 1,
  Tail = 2
}

local TimeStep = 1.0 / 60.0;
local GameConstants = {
  WorldSize = 100,
  TickInterval = TimeStep,
  PlayerSpeed = TimeStep * 10.0,
  MaxFood = 50,
  ClientVisibility = 40,
  TailMaxAngle = 0.8, -- radians
  TurningMaxAngle = 0.1
}

local MyGame = Moat:new(
  GameEntities,
  GameConstants
);

local showMenu = true;
local tileSizePx = 30.0;
local cameraCenter = {x = 0, y = 0};
local offsetPx = {x = 0, y = 0};
local mousePos = {x = 0, y = 0};


function getNewPlayerState()
  local player = {};
  player.x , player.y = math.random(GameConstants.WorldSize), math.random(GameConstants.WorldSize) 
  player.w , player.h = 1, 1;
  
  player.dirX = 0.0;
  player.dirY = -1.0;
  player.tail = List.new(1); -- Create an empty tails array that is 1 indexed
  return player;
end


function MyGame:clientMouseMoved(x, y)
  mousePos.x = x;
  mousePos.y = y;
end

function MyGame:clientMousePressed(x, y)
  if (self:clientIsConnected() and showMenu) then
    
    self:clientSend({
      cmd = "request_spawn"
    });
    
    showMenu = false;
  end
end

function MyGame:serverReceive(clientId, msg)
  if (msg.cmd == "request_spawn") then
    local playerData = getNewPlayerState();
    self:serverSpawnPlayer(clientId, 
    playerData.x, playerData.y, 
    playerData.w, playerData.h, 
    playerData);
  end
  
end

--Update client for every game tick
local input = {};
function MyGame:clientUpdate(dt)
  if (not MyGame:clientIsSpawned()) then
    return
  end
  
  --Scale the to-mouse vector a few tiles worth so we can modify speed based on distance
  local mouseScale = tileSizePx * 5.0;
  
  input.mx = ((mousePos.x - offsetPx.x) / mouseScale);
  input.my = ((mousePos.y - offsetPx.y) / mouseScale);
  
  MyGame:clientSetInput(input);
  
end

local normalize = Moat.Math2D.normalize;

function followLeader(follower, leader)

  --Get center points
  local fx, fy = MyGame.Entity.getCenter(follower);
  local lx, ly = MyGame.Entity.getCenter(leader);
  local halfSize = 0.5;
    
  --Direction to leader
  local dx, dy = normalize(lx - fx, ly - fy);

  local leaderAngle = math.atan2(leader.dirY, leader.dirX);
  
  --Compute and clamp the offset angle
  local angle = Moat.Math2D.signedAngle(leader.dirX, leader.dirY, dx, dy);    
  angle = Moat.Math.clamp(angle, -GameConstants.TailMaxAngle, GameConstants.TailMaxAngle);
  
  --Create a new difference vector
  local ndx, ndy = math.cos(leaderAngle + angle), math.sin(leaderAngle + angle);

  --Set position and direction values
  local tx, ty = lx - ndx, ly - ndy;
  follower.dirX, follower.dirY = ndx, ndy;
  MyGame:moveEntity(follower, tx - halfSize, ty - halfSize);

end

--Shared function for how a player updates, input may be nil
function MyGame:playerUpdate(player, input)
  
  if (input) then 
    
    --Try mouse (mx, my) values
    local x, y = input.mx or 0, input.my or 0;
    
    --Set maximum length of movement vector to 1
    local mag = Moat.Math2D.length(x, y);
    
    if (mag > 0.0) then
      local nmx, nmy = MyGame.Math2D.normalize(x, y)
      local angle = MyGame.Math2D.signedAngle(player.dirX, player.dirY, nmx, nmy);
      angle = Moat.Math.clamp(angle, -GameConstants.TurningMaxAngle, GameConstants.TurningMaxAngle);
      local ogAngle = math.atan2(player.dirY, player.dirX);
      player.dirX, player.dirY = math.cos(ogAngle + angle), math.sin(ogAngle + angle);       
      local speed = GameConstants.PlayerSpeed * math.min(1.0, mag);
      player.x = player.x + speed * player.dirX;
      player.y = player.y + speed * player.dirY;  
     end
    
    if (x ~= 0 and y ~= 0) then
      --player.dirX, player.dirY = MyGame.Math2D.normalize(x, y);
    end
    
  end -- End input handling

  
   --Clamp player to game boundaries
  if (player.x < 0) then player.x = 0 end
  if (player.y < 0) then player.y = 0 end
  if (player.x + player.w > GameConstants.WorldSize) then player.x = GameConstants.WorldSize - player.w end
  if (player.y + player.h > GameConstants.WorldSize) then player.y = GameConstants.WorldSize - player.h end
  
  MyGame:moveEntity(player);
  
  for i = player.tail.first, player.tail.last do
  
    local uuid = player.tail[i];
    local tail = MyGame:getEntity(uuid);
    
    if (not tail) then return end;
    
    if (i == player.tail.first) then
      followLeader(tail, player)
    else
      local prevUuid = player.tail[i-1];
      local prevTail = MyGame:getEntity(prevUuid);
      if (not prevTail) then return end;
      followLeader(tail, prevTail);
    end
    
  end
  
  local didRespawn = false;
  --Handle interactions with other entities, (players and food)
  MyGame:eachOverlapping(player, function(entity)
    
    --Don't do any more work if respawn event has fired already
    if (didRespawn) then return end;
    
    --Eat food and spawn a new tail segment
    if (entity.type == GameEntities.Food) then
      --Remove the food
      MyGame:despawn(entity);
     
        local tx, ty = player.x - player.dirX, player.y - player.dirY;
        local dirX, dirY = player.dirX, player.dirY;
        
        --Find position at end of tail
        if (List.length(player.tail) > 0) then
          local lastTailUuid = player.tail[player.tail.last];
          local tailEntity = MyGame:getEntity(lastTailUuid);
          if (not tailEntity) then return end;
          tx, ty = tailEntity.x - tailEntity.dirX, tailEntity.y - tailEntity.dirY;
          dirX, dirY = tailEntity.dirX, tailEntity.dirY;
        end
      
        local entity = MyGame:spawn(GameEntities.Tail, tx, ty, 1.0, 1.0, {
          dirX = dirX,
          dirY = dirY
        });
        
        --Push UUID of this spawn to tail list
        List.pushright(player.tail, entity.uuid);      
    end
    
    
    --Player hit a tail
    if (entity.type == GameEntities.Player or entity.type == GameEntities.Tail) then
        
        if (player.tail[1] ~= entity.uuid) then
            
            didRespawn = true;
        
           --Despawn the tail segments
           List.each(player.tail, function(tailId)
             MyGame:despawn(MyGame:getEntity(tailId));
           end);
        
           local playerData = getNewPlayerState();
           MyGame:respawnPlayer(player, 
            playerData.x, playerData.y, 
            playerData.w, playerData.h, playerData);   
        end
        
    end
  end);
  
  
end


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


function drawCircle(e, radiusScale)
  
  radiusScale = radiusScale or 1;
  
  love.graphics.circle("fill", 
    (e.x + e.w * 0.5 - cameraCenter.x) * tileSizePx + offsetPx.x, 
    (e.y + e.h * 0.5 - cameraCenter.y) * tileSizePx + offsetPx.y, 
    e.w * tileSizePx * 0.5 * radiusScale
  );
  
end

function drawFood(food) 
  love.graphics.setColor(1.0, 0.0, 0.0, 1.0);
  drawRect(food);
end

function drawPlayer(player)
  love.graphics.setColor(1.0, 1.0, 1.0, 1.0);
  drawCircle(player);
  love.graphics.setColor(0,0,0,1);
  drawCircle(player, 0.6);
  love.graphics.setColor(1.0, 1.0, 1.0, 1.0);
  drawCircle(player, 0.25);
end

function drawTail(player)
  love.graphics.setColor(1.0, 1.0, 1.0, 1.0);
  drawCircle(player);
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
  
  local player = self:clientGetPlayerState();
  cameraCenter.x = player.x + player.w * 0.5;
  cameraCenter.y = player.y + player.h * 0.5;
  tileSizePx = 20.0;
  
  drawGrid();
  self:eachEntityOfType(GameEntities.Food, drawFood);
  self:eachEntityOfType(GameEntities.Player, drawPlayer);
  self:eachEntityOfType(GameEntities.Tail, drawTail);
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
  for x = 1, GameConstants.MaxFood do
     spawnFood();
  end
end

function MyGame:serverUpdate()
  
  if (self:numEntitiesOfType(GameEntities.Food) < GameConstants.MaxFood) then
    if (math.random() < 0.1) then
      spawnFood()
    end
  end

end

function MyGame:clientResize(x, y)
  offsetPx.x = x * 0.5;
  offsetPx.y = y * 0.5;
end


function MyGame:clientLoad()
  local w, h = love.graphics.getDimensions();
  self:clientResize(w, h);
end

MyGame:run();



