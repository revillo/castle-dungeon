--castle://localhost:4000/brick_source.lua

local Moat = require("moat");

local GameEntities = {
  Player = 0,
  Ball = 1,
  Brick = 2
}

local GameConstants = {
  ClientVisibility = 200,
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
  
  x, y = worldToPx(1, GameConstants.GameHeight);

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

  if (input) then
  
     local myBall = nil;
     
     if (player.hasBall) then
      myBall = BrickGame:getEntity(player.hasBall);
     end
  
    --Center paddle to mouse
    if (input.my) then
      player.y = input.my - player.h * 0.5;
      BrickGame:moveEntity(player);
      
      --Move ball too if owner
      if (myBall) then
        myBall.y = input.my - myBall.h;
        myBall.x = player.x + 1.5;
      end
      
    end
    
    --Fire if we own the ball
    if (input.mouseDown and myBall) then
      
      --Ball referenced by uuid
      myBall.dx = 1;
      myBall.dy = 0;
      
      player.hasBall = nil;
      
    end
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

function updateBall(ball, dt)

    local vx, vy = ball.dx * dt * GameConstants.BallSpeed, ball.dy * dt * GameConstants.BallSpeed;
    
    BrickGame:moveEntity(ball, ball.x + vx, ball.y + vy);
    
    --Bounce ball off top and bottom
    if (ball.y < 0 or ball.y > GameConstants.GameHeight) then
      ball.dy = -ball.dy;
      ball.y = Moat.Math.clamp(ball.y, 0, GameConstants.GameHeight);
    end
    
    if (ball.x > GameConstants.GameWidth) then
      ball.x = GameConstants.GameWidth;
      ball.dx = -math.abs(ball.dx);
    end
    
    if (ball.x < 0) then
      ball.x = 0;
      ball.dx = math.abs(ball.dx);
    end
    
    local mx, my = getEntityCenter(ball);
    local didBounce = false;

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
          
          if (entity.position == PlayerPosition.Left) then
            dx = dx + 1.0;
          else
            dx = dx - 1.0;
          end
          
          ball.dx, ball.dy = Moat.Math2D.normalize(dx, dy);
          didBounce = true;
        end
    end);
    
end

function BrickGame:worldUpdate(dt)
  BrickGame:eachEntityOfType(GameEntities.Ball, updateBall, dt)
end

function BrickGame:serverOnClientConnected(clientId)  

  local playerPosition = PlayerPosition.Left;
  local playerX = 1;
  
  local numPlayers = BrickGame:numEntitiesOfType(GameEntities.Player);
  local hasBall = nil;
  
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
      playerX = 30;
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

function BrickGame:serverInitWorld()
  serverSpawnBricks();
end

BrickGame:run();