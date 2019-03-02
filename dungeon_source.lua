--castle://localhost:4000/dungeon_source.lua

local Moat = require("moat");
local Sprite = require("lib/sprite");
local MazeGen = require("lib/maze_gen");

local GameEntities = {
  Player = 0,
  Monster = 1,
  Wall = 2,
  Floor = 3,
  Spinner = 4,
  Eye = 5,
  EyeBullet = 6,
  Gold = 7,
  Chest = 8,
  NPC = 9,
  IceBullet = 10
}

local TimeStep = 1.0 / 60.0;

local GameConstants = {
  -- Configures view distance
  ClientVisibility = 22,
  -- Configures time step
  TickInterval = TimeStep,
  
  -- Any custom constants
  RoomSize = 12,
  WorldSize = 200,
  MonsterSpeed = TimeStep * 3.0,
  PlayerSpeed = TimeStep * 6.0,
  IceBulletSpeed = TimeStep * 20.0,
  EyeBulletSpeed = TimeStep * 4.0,
  PlayerStartX = 6,
  PlayerStartY = 6
}

local DGame = Moat:new(
  GameEntities,
  GameConstants
);

local NPCText = nil;
local NPCTextID = nil;
local showMenu = true;
local mouseEvent = nil;

function DGame:clientMousePressed(x, y)
  if (DGame:clientIsConnected() and showMenu) then
    
    -- Initial handshake to connect
    DGame:clientSend({
      cmd = "request_spawn"
    });
    
    showMenu = false;
  else
    
    mouseEvent = {x = x, y = y};
  
  end  
end

function DGame:serverReceive(clientId, msg)
    
  if (msg.cmd == "request_spawn") then
    DGame:serverSpawnPlayer(clientId, GameConstants.PlayerStartX, GameConstants.PlayerStartY);
  end
  
end

function handlePlayerInput(player, input)
    local x, y = 0, 0;
    
    --Move player based on keyboard input
    if (input.w) then y = -1 end
    if (input.a) then x = -1 end
    if (input.s) then y = 1 end
    if (input.d) then x = 1 end
    
    --Normalize movement vector
    x, y = DGame.Utils.normalize(x, y);
        
    local oldX, oldY = player.x, player.y;
    
    player.x = player.x + GameConstants.PlayerSpeed * x;
    player.y = player.y + GameConstants.PlayerSpeed * y;
    
    --xflip is used by sprite.lua set the orientation of player sprite
    if (x > 0) then
      player.xflip = -1.0
    elseif (x < 0) then
      player.xflip = 1.0;
    end
    
    --Call move on any entity to update it for collision detection after changing x, y, w, h
    DGame:moveEntity(player);
    
    --Reset player if movement would intersect a wall
    DGame:eachOverlapping(player, function(entity)
      if (entity.type == GameEntities.Wall) then
        DGame:moveEntity(player, oldX, oldY);
      end
    end); 
    
    --Handle shooting ice
    if (input.mx) then
      local dx, dy = DGame.Utils.normalize(input.mx, input.my);

      DGame:spawn(GameEntities.IceBullet, player.x, player.y, 1, 1, {
        dx = dx,
        dy = dy
      });
    end
end

function DGame:playerUpdate(player, input)

  if (input) then 
    handlePlayerInput(player, input);
  end
  
  local didRespawn = false;
  NPCText = nil;
  NPCTextID = nil;
  
  DGame:eachOverlapping(player, function(entity)
    --Avoid respawning twice if multiple hazards hit us
    if (didRespawn) then return end;

    local type = entity.type;
    
    if (type == GameEntities.Spinner or type == GameEntities.Monster or type == GameEntities.EyeBullet) then
      --Higher fidelity hit detection
      if (DGame:getOverlapArea(player, entity) > 0.2) then
        DGame:respawnPlayer(player, GameConstants.PlayerStartX, GameConstants.PlayerStartY);
        print("respawn");
        didRespawn = true;
        return;
      end
    end
    
    if (entity.type == GameEntities.Gold) then
      DGame:despawn(entity);
    end
    
    if (entity.type == GameEntities.NPC and DGame.isClient) then
      NPCText = entity.dialogue;
      NPCTextID = entity.uuid;
    end
    
  end);

end

local input = {};
function DGame:clientUpdate(dt)
  if (not DGame:clientIsSpawned()) then
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
    
  DGame:clientSetInput(input);
end

-- Drawing/Rendering functions

--For debug / top left corner text
function drawText(text)
    love.graphics.setColor(1,1,1,1);
    love.graphics.print(text, 10, 10, 0, 2, 2);
end

local dialogueId;
local dialogueCursor = 1;

--Draws the scrolling text prompts when talking to npcs
function drawDialogue(text, id)
  if (text) then
    local displayText;
    
    if (dialogueId == id) then
      dialogueCursor = dialogueCursor + 0.3;
      displayText = string.sub(text, 1, math.floor(dialogueCursor));
    else
      dialogueId = id;
      dialogueCursor = 1;
      displayText = ""
    end
    
    local screenWidth, screenHeight = love.graphics.getDimensions();
    local halfWidth = screenWidth * 0.5;
    
    love.graphics.setColor(0,0,0,0.8);
    love.graphics.rectangle("fill", halfWidth-250, screenHeight-100, 500, 100);
    love.graphics.setColor(1,1,1,1);
    love.graphics.rectangle("line", halfWidth-250, screenHeight-100, 500, 100);
    love.graphics.print(displayText, halfWidth-240, screenHeight-90, 0, 1, 1);
  else
    dialogueId = nil;
    dialogueCursor = nil;
  end
end

-- This intermediate function can draw any additional effects
function drawWithEffects(entity, ...)

  Sprite.drawEntity(entity, ...);
  
  -- Draw ice over frozen enemies
  if (entity.freezeCounter and entity.freezeCounter > 0) then
    Sprite.drawEntity(entity, Sprite.images.ice);
  end
end
 
-- Basic pass through function that calls drawWithEffects on all entity of type
function drawEntities(type, ...)
  DGame:eachEntityOfType(type, drawWithEffects, ...);
end

function DGame:clientDraw()
  if (not DGame:clientIsConnected()) then
    drawText("Connecting... signed in to castle?");
    return;
  end
  
  if (showMenu) then
    drawText("Click to spawn...")
    return;
  end

  if (not DGame:clientIsSpawned()) then
    drawText("Waiting for spawn...");
    return;
  end
    
  local player = DGame:getPlayerState();

  Sprite.cameraCenter.x = player.x + player.w * 0.5;
  Sprite.cameraCenter.y = player.y + player.h * 0.5;
  
  --Crop the viewing area to the client visibility
  Sprite.scissorBounds( GameConstants.ClientVisibility - 2);
  
  drawEntities(GameEntities.Floor, Sprite.images.dirt);
  
  -- Front facing wall effects
  drawEntities(GameEntities.Wall, Sprite.images.wall_front, 0.0, 1.0);
  drawEntities(GameEntities.Wall, Sprite.images.wall_shadow, 0.0, 1.9);
  
  drawEntities(GameEntities.Spinner, Sprite.images.skeleton_bat);
  drawEntities(GameEntities.Monster, Sprite.images.ogre);
  drawEntities(GameEntities.NPC, Sprite.images.npc);
  drawEntities(GameEntities.Chest, Sprite.images.chest);
  drawEntities(GameEntities.Gold, Sprite.images.gold);

  drawEntities(GameEntities.Eye, Sprite.images.shining_eye);
  drawEntities(GameEntities.EyeBullet, Sprite.images.orb);
  drawEntities(GameEntities.Player, Sprite.images.wizard);
  drawEntities(GameEntities.IceBullet, Sprite.images.ice);
  drawEntities(GameEntities.Wall, Sprite.images.wall_top);

  drawDialogue(NPCText, NPCTextID);
  
  Sprite.clearScissor();
end


function addWall(x, y, w, h, isDoor)
    if (isDoor) then return end;
    
    DGame:spawn(GameEntities.Wall,
      x, y, w, h
    );
end

local NPCDialogues = {
  "Good luck adventurer!",
  "May ye enjoy this tasty loot.",
  "There is no shame in partaking of treasure.",
  "Gnosh on some dosh wizard.",
  "I'm actually a vegan.",
  "Come back any time.",
  "Call me?",
  "I have more money than sense.",
  "Coins. Have them.",
  "There is meaning in your quest. Probably.",
  "What has six faces but cannot see?",
  "What has many keys but opens no doors?",
  "What do leave behind for every one you take?",
  "You're gonna pay me back right?"
}

function serverAddHazards(room, x, y, roomSize)

  if (room.x == 1 and room.y == 1) then
    return;
  end
  
  local centerX = x + roomSize * 0.5 - 1.0;
  local centerY = y + roomSize * 0.5 - 0.5;
  
  local roomArea = {
    x = x + 1.0,
    y = y + 1.0,
    w = roomSize - 2.0,
    h = roomSize - 2.0
  }
  
  -- Make a treasure room?
  if (room.x > 2 and room.y > 2 and math.random() < 0.15) then
    DGame:spawn(GameEntities.Chest, centerX-0.5, centerY, 1.0, 1.0, {
        searchArea = roomArea
    });
    
    DGame:spawn(GameEntities.NPC, centerX+0.5, centerY, 1.0, 1.0, {
        dialogue = NPCDialogues[math.random(#NPCDialogues)];
    });
    
    return;
  end
  
  
  local whichHazard = math.random(3);
  
  if (whichHazard == 1) then
    -- Add Orb Wheel
    local spinDir = (math.random() - 0.5) * 2.0;
    
    for i = 1, 5 do
      --Spawn a spinner type enemy and set custom circle center and radius properties
      DGame:spawn(GameEntities.Spinner, centerX, centerY, 1.0, 1.0, {
        centerX = centerX,
        centerY = centerY,
        angle = (i / 5) * math.pi * 2.0,
        spinDir = spinDir,
        radius = roomSize * 0.3 
      });
    end
  elseif (whichHazard == 2) then
  
    -- Spawn a monster enemy and provide room area info    
      DGame:spawn(GameEntities.Monster, centerX, centerY, 1.0, 1.0, {
        health = 5,
        searchArea = roomArea
      });
  
  elseif (whichHazard == 3) then
    -- Spawn an Eye enemy    
      DGame:spawn(GameEntities.Eye, centerX, centerY, 1.0, 1.0, {
        health = 5,
        searchArea = roomArea
      });
  else
    
  end
end

function serverCreateMaze(mazeWidth, mazeHeight)
  
  local roomSize = GameConstants.RoomSize;
  local mazeRooms = MazeGen(mazeWidth, mazeHeight);
    
  addWall(0, 0, mazeWidth * roomSize, 1);
  addWall(-1, 0, 1, mazeHeight * roomSize);

  for k, room in pairs(mazeRooms) do
    
    local x,y = (room.x-1) * roomSize, (room.y-1) * roomSize;
    
    DGame:spawn(GameEntities.Floor,
      x, y, roomSize, roomSize
    );
    
    serverAddHazards(room, x, y, roomSize);
    
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
  serverCreateMaze(10, 10);
end

function DGame:clientResize(x, y)
  Sprite.offsetPx.x = x * 0.5;
  Sprite.offsetPx.y = y * 0.5;
end

function findNearestPlayer(entity, searchArea)
    local closestPlayer = nil;
    local closestPlayerDistance = 100;
    
    DGame:eachOverlapping(searchArea, function(foundEntity)
      
      if (foundEntity.type == GameEntities.Player) then
        local distance = DGame.Utils.distance(entity, foundEntity);
        if (distance < closestPlayerDistance) then
          closestPlayer = foundEntity;
          closestPlayerDistance = distance;
        end
      end
      
    end);
    
    return closestPlayer;
end


function updateMonster(monster, tick)
    
    if (monster.freezeCounter and monster.freezeCounter > 0) then
      monster.freezeCounter = monster.freezeCounter - 1;
      return;
    end
    
    local closestPlayer = findNearestPlayer(monster, monster.searchArea);
    
    local oldX, oldY = monster.x, monster.y;
    
    if (closestPlayer) then
        local dx = closestPlayer.x - monster.x;
        local dy = closestPlayer.y - monster.y;
        dx, dy = DGame.Utils.normalize(dx, dy);        
        local x = monster.x + dx * GameConstants.MonsterSpeed;
        local y = monster.y + dy * GameConstants.MonsterSpeed;
        DGame:moveEntity(monster, x, y);
    end
    
    DGame:eachOverlapping(monster, function(entity) 
      
     if (entity.type == GameEntities.Wall) then
        monster.x, monster.y = oldX, oldY;
        DGame:moveEntity(monter);
      end
    
    end);
    
end

function updateSpinner(spinner, tick)
    
    local t = (tick * GameConstants.TickInterval) * spinner.spinDir;
    
    local x, y = math.sin(t + spinner.angle) * spinner.radius + spinner.centerX, math.cos(t + spinner.angle) * spinner.radius + spinner.centerY;
    
    DGame:moveEntity(spinner, x, y);
  
end

function updateEye(eye, tick)

  if (eye.freezeCounter and eye.freezeCounter > 0) then
    eye.freezeCounter = eye.freezeCounter - 1;
    return;
  end
    
  --Fire every second
  if (tick % 40 == 0) then
  
    local closestPlayer = findNearestPlayer(eye, eye.searchArea);
    
    if (closestPlayer) then
        local dx = closestPlayer.x - eye.x;
        local dy = closestPlayer.y - eye.y;
        dx, dy = DGame.Utils.normalize(dx, dy);   
        
        DGame:spawn(GameEntities.EyeBullet, eye.x, eye.y, 1, 1, {
           dx = dx,
           dy = dy,
        });
    end
    
  end
  
end

function updateEyeBullet(eyeBullet)

  eyeBullet.x = eyeBullet.x + eyeBullet.dx * GameConstants.EyeBulletSpeed;
  eyeBullet.y = eyeBullet.y + eyeBullet.dy * GameConstants.EyeBulletSpeed
  
  DGame:moveEntity(eyeBullet);
  
  local hitOnce = false;
  
  DGame:eachOverlapping(eyeBullet, function(entity) 
    if (hitOnce) then return end;
    
    if (entity.type == GameEntities.Wall) then
      hitOnce = true;
      DGame:despawn(eyeBullet);
    end
  
  end);
  
end

function updateChest(chest, tick)
  
  if (DGame.isClient) then  
    return
  end
  
  if (tick % 1000 == 0) then
    
    local goldCount = 0;
    DGame:eachOverlapping(chest.searchArea, function (entity)
      if (entity.type == GameEntities.Gold) then
        goldCount = goldCount + 1;
      end
    end);
    
    if (goldCount < 4) then
      
      local x = chest.searchArea.x + (chest.searchArea.w-1) * math.random();
      local y = chest.searchArea.y + (chest.searchArea.h-1) * math.random();
      
      DGame:spawn(GameEntities.Gold, x,  y, 1, 1);
    end
    
  end

end

function updateIceBullet(bullet, tick)
  
  local dx = bullet.dx * GameConstants.IceBulletSpeed;
  local dy = bullet.dy * GameConstants.IceBulletSpeed;
  DGame:moveEntity(bullet, bullet.x + dx, bullet.y + dy);

  local hitOnce = false;
  DGame:eachOverlapping(bullet, function(entity) 
    if (hitOnce) then return end;
    
    --Check if enough area is overlapping to count
    if (DGame:getOverlapArea(bullet, entity) < 0.4) then
      return;
    end
    
    if (entity.type == GameEntities.Wall) then
      hitOnce = true;
      DGame:despawn(bullet);
    end
    
    if (entity.type == GameEntities.Monster or entity.type == GameEntities.Eye) then
      entity.freezeCounter = 120; -- Put a freeze countdown on enemey entity 
      hitOnce = true;
      DGame:despawn(bullet);
    end
  
  end);
  
end

--Update non-player entitiess
function DGame:worldUpdate(dt)

  -- Get the tick (time index) for the current frame
  local tick = DGame:getTick();
  DGame:eachEntityOfType(GameEntities.Spinner, updateSpinner, tick);
  DGame:eachEntityOfType(GameEntities.Monster, updateMonster, tick);
  DGame:eachEntityOfType(GameEntities.Eye, updateEye, tick);
  DGame:eachEntityOfType(GameEntities.EyeBullet, updateEyeBullet);
  DGame:eachEntityOfType(GameEntities.Chest, updateChest, tick);
  DGame:eachEntityOfType(GameEntities.IceBullet, updateIceBullet, tick);
  
end

function DGame:clientLoad()
  love.mouse.setCursor(love.mouse.getSystemCursor("crosshair"));

  Sprite.loadImages({
    wall_top = "img/wall_top.png",
    wall_front = "img/wall_front.png",
    wall_shadow = "img/wall_shadow.png",
    dirt = "img/dirt.png",
    wizard = "img/deep_elf_high_priest.png",
    orb = "img/conjure_ball_lightning.png",
    skeleton_bat = "img/skeleton_bat.png",
    ogre = "img/ogre_mage.png",
    shining_eye = "img/shining_eye.png",
    gold = "img/gold_pile_16.png",
    chest = "img/chest_2_open.png",
    npc = "img/hippogriff_old.png",
    ice = "img/ozocubus_refrigeration.png"
  });

  -- Fixes subtle texture glitch on the wall shadow
  Sprite.images.wall_shadow:setWrap("repeat", "clampzero");
  
  local w, h = love.graphics.getDimensions();
  DGame:clientResize(w, h);
end

DGame:run();



