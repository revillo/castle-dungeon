--castle://localhost:4000/brick_source.lua

local Moat = require("moat");

local GameEntities = {
  Player = 0,
  Ball = 1,
  Brick = 2
}

local GameConstants = {
  ClientVisibility = 50,
  MaxClients = 2,
  BallSpeed = 15,
  PaddleHeight = 6,
  PaddleWidth = 1,
  GameWidth = 30,
  GameHeight = 30
}

local PlayerPosition = {
  Left = 1,
  Right = 2
}

local BrickGame = Moat:new(GameEntities, GameConstants);

local mouseDownEvent;
local unitSizePx = 10;
local offsetPx = {x = 0, y = 0};
local cameraCenter = {x = 15, y = 15};


function worldToPx(x, y)
  return (x - cameraCenter.x) * unitSizePx + offsetPx.x,
         (y - cameraCenter.y) * unitSizePx + offsetPx.y
end


local input = {};
function BrickGame:clientMouseMoved(x, y)
  input.my = cameraCenter.x + ((y - offsetPx.y) / unitSizePx);
end

function BrickGame:clientMousePressed(x, y)
  input.mouseDown = true;
end

function BrickGame:clientUpdate(dt)
  if (not BrickGame:clientIsSpawned()) then
    return
  end
  
  BrickGame:clientSetInput(input);
  input = {};
end

function drawRect(e)
  
  local x, y = worldToPx(e.x, e.y);

  love.graphics.rectangle("fill", 
    x, 
    y, 
    e.w * unitSizePx, 
    e.h * unitSizePx
  );

end

function drawPaddle(paddle)
  love.graphics.setColor(1,1,1,1);
  drawRect(paddle);
end

function drawBrick(brick)
  love.graphics.setColor(1,0,0,1);
  drawRect(brick);
end

function drawBall(ball)
  love.graphics.setColor(1,1,1,1);
  drawRect(ball);
end

function drawBorders()
  local x, y = worldToPx(1, -1);
  
  love.graphics.rectangle("fill",
    x, y,
    GameConstants.GameWidth * unitSizePx,
    1 * unitSizePx
  )
  
  x, y = worldToPx(1, GameConstants.GameHeight + 1);

  love.graphics.rectangle("fill",
    x, y,
    GameConstants.GameWidth * unitSizePx,
    1 * unitSizePx
  )
end

function BrickGame:clientDraw()
  local w, h = love.graphics.getDimensions()
  offsetPx.x, offsetPx.y = w * 0.5, h * 0.5;
  
  love.graphics.setBackgroundColor(1.0, 1.0, 1.0);
  drawBorders();
  
  BrickGame:eachEntityOfType(GameEntities.Player, drawPaddle);
  BrickGame:eachEntityOfType(GameEntities.Brick, drawBrick);
  BrickGame:eachEntityOfType(GameEntities.Ball, drawBall);
end

function BrickGame:clientLoad()
  local w, h = love.graphics.getDimensions()
  offsetPx.x, offsetPx.y = w * 0.5, h * 0.5;
end

function BrickGame:playerUpdate(player, input)
  local myBall = nil;
   
  if (player.hasBall) then
    myBall = BrickGame:getEntity(player.hasBall);
  end
   
  if (input) then
    --Center paddle to mouse
    if (input.my) then
      player.targetY = input.my - player.h * 0.5;  
    end
    
    --Fire if we own the ball
    if (input.mouseDown and myBall) then
      
      --Ball referenced by uuid
      myBall.dx = 1;
      
      -- Flip it for right side player
      if (player.position == PlayerPosition.Right) then
        myBall.dx = -1;
      end
      
      myBall.dy = 0;
      
      player.hasBall = false;
      myBall = nil;
    end
  end
  
      
  if (player.targetY) then
    player.y = Moat.Math.lerp(player.y, player.targetY, 0.1);
    
    if (myBall) then
      myBall.y = player.y + (player.h * 0.5) - (myBall.h * 0.5)
      myBall.x = player.x + 1.5;
      
       -- Flip it for right side player
      if (player.position == PlayerPosition.Right) then
        myBall.x = player.x - 1.5;
      end
      
      BrickGame:moveEntity(myBall);
    end
    
    BrickGame:moveEntity(player);
  end
  
end

function getEntityCenter(e)
  return e.x + e.w * 0.5, e.y + e.h * 0.5
end

function getMajorAxis(dx, dy)
  local nx, ny = 0, 0;
  
  if (math.abs(dx) > math.abs(dy)) then
    nx = Moat.Math.sign(dx);
  else
    ny = Moat.Math.sign(dy);
  end
  
  return nx, ny;
end

--Reflect ix, iy vector about nx, ny normal
function reflect(ix, iy, nx, ny)

  local dot = Moat.Math2D.dot(ix, iy, nx, ny);
  return ix - (nx * 2 * dot), iy - (ny * 2 * dot);
  
end

function resetBall(ball)

  local existingPlayer = nil;
      
  BrickGame:eachEntityOfType(GameEntities.Player, function(player)
    existingPlayer = player;
  end);
  
  if (existingPlayer) then
    existingPlayer.hasBall = ball.uuid;
    ball.dx = 0;
    ball.dy = 0;
  end
  
  --Just move the ball away from the map, next time a player updates it will be in the right place
  ball.x = -100;
  ball.y = -100;

end

function updateBall(ball, dt)

    local vx, vy = ball.dx * dt * GameConstants.BallSpeed, ball.dy * dt * GameConstants.BallSpeed;
    
    BrickGame:moveEntity(ball, ball.x + vx, ball.y + vy);
    
    --Bounce ball off top and bottom
    if (ball.y < 0 or ball.y > GameConstants.GameHeight) then
      ball.dy = -ball.dy;
      ball.y = Moat.Math.clamp(ball.y, 0, GameConstants.GameHeight);
    end
    
    --Handle out of bounds on server only just to make sure ball is reset properly
    if (BrickGame.isServer and ball.x < -2 or ball.x > GameConstants.GameWidth + 2) then
      resetBall(ball);
      return;
    end
    
    local mx, my = getEntityCenter(ball);
    local didBounce = false;
    
    BrickGame:moveEntity(ball);

    BrickGame:eachOverlapping(ball, function(entity)
        if(didBounce) then return end;
    
        local ex, ey = getEntityCenter(entity);
          
        if (entity.type == GameEntities.Brick) then
          BrickGame:despawn(entity);
          
          --Get delta between ball and block;
          local dx, dy = mx - ex, my - ey;
          --Get normal direction of block
          local nx, ny = getMajorAxis(dx, dy);
          --Reflect ball velocity about normal
          ball.dx, ball.dy = reflect(ball.dx, ball.dy, nx, ny);
          
          didBounce = true;
          
        end
        
        if (entity.type == GameEntities.Player) then
          local dx, dy = mx - ex, my - ey;
          local push;
          if (entity.position == PlayerPosition.Left) then
            push = 1.0;
          else
            push = -1.0;
          end
          
          ball.dx, ball.dy = Moat.Math2D.normalize(dx + push, dy);
          ball.x = entity.x + push;
   
          BrickGame:moveEntity(ball);
          didBounce = true;
        end
    end);
    
end

function BrickGame:worldUpdate(dt)
  BrickGame:eachEntityOfType(GameEntities.Ball, updateBall, dt)
end

function BrickGame:serverOnClientDisconnected(clientId)
  
  local dcPlayer = BrickGame:serverGetEntityForClientId(clientId);
  local numPlayers = BrickGame:numEntitiesOfType(GameEntities.Player);
  
  if (dcPlayer.hasBall) then  
    if (numPlayers == 0) then
      BrickGame:despawn(BrickGame:getEntity(dcPlayer.hasBall.uuid));
    else      
      BrickGame:eachEntityOfType(GameEntities.Player, function(player)
        if (not player.hasBall) then
          player.hasBall = dcPlayer.hasBall
        end
      end);
    end
  end
  
end

function BrickGame:serverOnClientConnected(clientId)  

  local playerPosition = PlayerPosition.Left;
  local playerX = 1;
  
  local numPlayers = BrickGame:numEntitiesOfType(GameEntities.Player);
  local hasBall = false;
  
  if (numPlayers > 2) then
    -- Todo handle more than 2 players
    return 
  elseif (numPlayers == 1) then
  
    local existingPlayer;
    
    BrickGame:eachEntityOfType(GameEntities.Player, function(player)
      existingPlayer = player;
    end);
    
    --Place second player opposite first player
    if (existingPlayer.position == PlayerPosition.Left) then
      playerPosition = PlayerPosition.Right;
      playerX = GameConstants.GameWidth;
    end
  
  else
  
    --First Player gets the ball
    local ball = BrickGame:spawn(GameEntities.Ball, -100, -100, 1, 1, {
      dx = 0,
      dy = 0
    });
    
    hasBall = ball.uuid;
  end
 
  BrickGame:serverSpawnPlayer(clientId, playerX, 15, GameConstants.PaddleWidth, GameConstants.PaddleHeight, {
    hasBall = hasBall,
    position = playerPosition
  });
  
end

function serverSpawnBricks()
  local brickSize = 1.5;
  local brickMargin = brickSize + 0.3;
  
  for x = 0, 4 do for y = 0, 4 do
    local spawn = BrickGame:spawn(GameEntities.Brick, (x-2) * brickMargin + (GameConstants.GameWidth * 0.5), (y-2.5) * brickMargin + (GameConstants.GameHeight * 0.5), brickSize, brickSize);
  end end
  
end

function BrickGame:serverUpdate(dt)
  --Respawn bricks when cleared
  if (BrickGame:numEntitiesOfType(GameEntities.Brick) == 0) then
    
    serverSpawnBricks();
    self:eachEntityOfType(GameEntities.Ball, function(ball)
      resetBall(ball);
    end);
    
  end
end

function BrickGame:serverInitWorld()
  serverSpawnBricks();
end

BrickGame:run();