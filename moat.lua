local cs = require("cs")
local Shash = require("lib/shash")
local List = require("lib/list")

local PlayerHistory = {};
local Moat = {};

local Utils = {};
local Entity = {};
local Math2D = {};
local Math = {};

function Math.clamp(a, lo, hi) 
  
  if (a < lo) then return lo
  elseif (a > hi) then return hi 
  end
 
  return a;

end

function Math.sign(scalar)
  
  if (scalar < 0.0) then return -1 end;
  if (scalar > 0.0) then return 1 end;
  return 0.0;
  
end

function Utils.copyInto(toTable, fromTable)
  
  if (fromTable) then
    for k, v in pairs(fromTable) do
        if (type(v) == "table") then
          toTable[k] = Utils.copyInto({}, v);
        else
          toTable[k] = v;
        end
    end  
  end
  return toTable;
  
end

function Utils.lerp(a, b, t)
  return a * (1-t) + b * t;
end
Math.lerp = Utils.lerp;

-- Rotate over angle a in radians
function Math2D.rotate(x, y, a)
  local tx = x;
  local x = x * math.cos(a) - y * math.sin(a);
  local y = tx * math.sin(a) + y * math.cos(a);
  return x, y;
end

function Math2D.length(x, y)
  return math.sqrt(x * x + y * y);
end

function Utils.normalize(x, y)
  local mag = math.sqrt(x * x + y * y);
  if (mag > 0) then
    x = x / mag;
    y = y / mag;
  end
  return x, y;
end

--Shallow equality
function Utils.isEqualShallow(tableA, tableB, ignore) 
  
  for k,v in pairs(tableA) do
    if (k == ignore) then
    elseif (tableA[k] ~= tableB[k]) then
      return false
    end
  end
  
  for k,v in pairs(tableB) do
    if (k == ignore) then
    elseif (tableA[k] ~= tableB[k]) then
      return false
    end
  end
  
  return true
  
end

Math2D.normalize = Utils.normalize;

function Utils.distance(entityA, entityB)
  local dx, dy = entityA.x - entityB.x, entityA.y - entityB.y;
  return math.sqrt(dx * dx + dy * dy);
end
Entity.distance = Utils.distance;

function Math2D.dot(x1, y1, x2, y2)
  return x1 * x2 + y1 * y2;
end

--Signed angle between two normalized vectors
function Math2D.signedAngle(x1, y1, x2, y2)
  
  local dot = Math2D.dot(x1, y1, x2, y2);
  
  if (dot > 0.99) then  
    return 0.0;
  end
  
  local cross = y2 * x1 - x2 * y1;
  
  local angle = math.acos(dot);

  if (cross < 0.0) then
   angle = -1.0 * angle;
  end
  
  if (angle ~= angle) then
    print("Angle is nan", x1, y1, x2, y2, dot, cross);
  end
  
  return angle;

end

function Entity.getCenter(entity)
  return entity.x + entity.w * 0.5, entity.y + entity.h * 0.5;
end

function PlayerHistory.new(inputHistory)
  
  local ph =  {
    tick = 0,
    inputHistory = inputHistory,
    state = {
      x = 0,
      y = 0,
      w = 1,
      h = 1
    }
  }
 
  --ph.inputHistory.last = 0;
  List.pushright(ph.inputHistory, {changeMe = true, tick = -100000});
  
  return ph;
 
end


function PlayerHistory.getLastState(ph)
  return ph.state;
end

--[[
function PlayerHistory.getInput(ph, tick)
  return ph.inputHistory[tick];
end
]]

local doLog = 1000;
local alog = function(...)
  if (doLog > 0) then
  doLog = doLog - 1;
    print(...);
  end
end
  
function PlayerHistory.updateInput(ph, input, tick)

  if (input) then
  
      if (not Utils.isEqualShallow(ph.inputHistory[ph.inputHistory.last], input, "tick")) then
        List.pushright(ph.inputHistory, Utils.copyInto({tick = tick}, input));
      else
      end
  
    --[[
      while (List.length(ph.inputHistory) > 60) do
        List.popleft(ph.inputHistory);
      end
        ]]
        
    --ph.inputHistory[ph.tick] = ph.inputHistory[ph.tick] or {};
    --Moat.Utils.copyInto(ph.inputHistory[ph.tick], input);
  end
  
end

TICK_BUFFER = 2;
TICK_DEBUG = -1;

function PlayerHistory.rebuild(ph, state, serverTick, moat)


  moat:rehashEntity(state);
  
  -- Find the ideal tick offset between client and server, and decide whether or not to use it
  
  local idealTick = serverTick + math.ceil((moat:clientGetPing()*0.001) / moat.Constants.TickInterval) + TICK_BUFFER;
  
  TICK_DEBUG = idealTick - serverTick;
  
  local idealDiff = idealTick - ph.tick;
  
  if (idealDiff > -3 and idealDiff < 4) then
    idealTick = ph.tick;
  else
    --ph.input = {changeMe = 1};
    print("snap",idealDiff, serverTick, ph.tick);
  end
  

  
  local oldTick = ph.tick;
  
  --Rewind to the state at the old tick

  Utils.copyInto(ph.state, state);
  ph.tick = serverTick;
  
  --ph.inputHistory.last = serverTick;
  
  
  --local nextInput = ph.inputHistory[inputTick] or {tick = -10};
  
  local tdiff = idealTick - oldTick;
  for ii = ph.inputHistory.first, ph.inputHistory.last do
    ph.inputHistory[ii].tick = ph.inputHistory[ii].tick + tdiff;
  end
  
  local inputTick = ph.inputHistory.first;
  local currentInput, nextInput;
  currentInput = ph.inputHistory[inputTick];
  nextInput = ph.inputHistory[inputTick + 1];
      
  for t = serverTick, idealTick do
  
    while (nextInput and nextInput.tick <= t) do
      currentInput = nextInput;
      inputTick = inputTick + 1;
      nextInput = ph.inputHistory[inputTick + 1];
    end
       
    PlayerHistory.advance(ph, moat, currentInput);
  end  

end

function PlayerHistory.advance(ph, moat, input)
  
  moat.gameState.tick = ph.tick;

  moat:playerUpdate(ph.state, input, moat.Constants.TickInterval);
  moat:worldUpdate(moat.Constants.TickInterval);  
  moat:cacheTemporaries();

  ph.tick = ph.tick + 1;
    
  moat.gameState.tick = ph.tick;
  
end

function Moat:initClient()
  print("init client");
  self.client = cs.client;
  self.share = cs.client.share;
  self.home = cs.client.home;
  self.soundHistory = {};
  
  self.home.ih = List.new(0);
  local ph = PlayerHistory.new(self.home.ih);
  
  local isSpawned = false;
  
  local gameState = self.gameState;
  local space = gameState.space;
  local share = self.share;
  
  self.ping = 100;
  
  local tempUUID = 0;
  local tempCache = {};
  
  function self:playSound(source)
    local history = self.soundHistory[source];
    if (history) then
      local lastTime = history.lastTime;
      local now = love.timer.getTime();
      --Wait 0.1 seconds before replaying a sound
      if (now - lastTime > 0.1) then
        love.audio.play(source:clone());
        history.lastTime = now;
      end
    else
      self.soundHistory[source] = {
        lastTime = love.timer.getTime()
      }
      love.audio.play(source:clone());
    end
  end
  
  --Client spawns a temp
  function self:spawn(type, x, y, w, h, data)
    data = data or {};
    data.uuid = "temp"..tempUUID;
    tempUUID = tempUUID + 1;
    
    data._spawnTick = gameState.tick;
    
     local entity = {
        type = type,
        x = x,
        y = y,
        w = w,
        h = h,
      };     
      
      Utils.copyInto(entity, data);
      
      gameState.space:add(entity, entity.x, entity.y, entity.w, entity.h);
      gameState.entitiesByType[entity.type][entity.uuid] = entity;
      gameState.entityCounts[entity.type] = gameState.entityCounts[entity.type] + 1;
      gameState.entities[entity.uuid] = entity;
      
      tempCache[entity.uuid] = {};
      tempCache[entity.uuid][gameState.tick] = Utils.copyInto({}, entity);
      
      return entity;
  end
  
  function self:cacheTemporaries()
    for uuid, cacheEntity in pairs(tempCache) do
      local entity = gameState.entities[uuid];
      tempCache[uuid][gameState.tick] = Utils.copyInto({}, entity);
    end
  end
  
  function self:clientKeyPressed(key) end
  function self:clientKeyReleased(key) end
  function self:clientMousePressed() end  
  function self:clientMouseMoved() end
  function self:clientWheelMoved(dx, dy) end
  function self:clientResize() end

  function self:clientOnConnected() end
  function self:clientOnDisconnected() end
  function self:clientLoad() end
  
  function self:clientGetId() 
    return cs.client.id;
  end
  
  function self:clientGetHome()
    return self.home;
  end
  
  function self:clientGetShare()
    return self.share;
  end
  
  function self:clientGetPlayerState()
  
    return PlayerHistory.getLastState(ph);
    
  end
    
  function self:despawn(entity)
    entity._despawnTick = gameState.tick;
  end
  
  self.smoothedPing = -1;
  self.lastPing = -1;
  
  function self:smoothPing()
    if (self.smoothedPing < 0) then
      self.smoothedPing = cs.client.getPing();
    else
      self.lastPing = cs.client.getPing();
      self.smoothedPing = Utils.lerp(self.smoothedPing, self.lastPing, 0.2);
    end
  end
  
  function self:clientGetPing()
      return cs.client.getPing();
      --return self.smoothedPing;
  end
  
  function self:clientUpdate(dt)
  
  end
  
  --Client Tick
  function self:advanceGameState()
    
    self:clientSyncEntities();
    
    if (self.doRebuild) then  
      PlayerHistory.rebuild(ph, self.doRebuild.serverState, self.doRebuild.tick, self);
      self.doRebuild = nil;
    elseif (ph.state.clientId ~= nil) then
        PlayerHistory.advance(ph, self, ph.inputHistory[ph.inputHistory.last])
     end 
    --end
    
    --gameState.tick = ph.tick;
    --print("tick", ph.tick);

    
    self:clientUpdate(self.Constants.TickInterval);
  end

  function self:clientSetInput(input)    
    PlayerHistory.updateInput(ph, input, self.gameState.tick);
  end
  
  function self:clientSyncPlayer(serverPlayer)
      
      --if (serverPlayer.uuid ~= ph.state.uuid) then
        self.doRebuild = {
          serverState = serverPlayer,
          tick = share.tick
        };
     -- end
      
      self.gameState.entitiesByType[self.EntityTypes.Player][serverPlayer.uuid] = ph.state;
      self.gameState.entities[serverPlayer.uuid] = ph.state;
  end
    
  function self:clientIsSpawned()
    return isSpawned;
  end
  
  function self:clientSyncEntity(serverEntity)
    
    -- This is the server version of our player, so handle the special case
    if (serverEntity.clientId == cs.client.id and cs.client.id) then
        isSpawned = true;
        self:clientSyncPlayer(serverEntity);
    else
    --Sync any other game entity
      gameState.entities[serverEntity.uuid] = gameState.entities[serverEntity.uuid] or {};
      local localEntity = gameState.entities[serverEntity.uuid];
      Utils.copyInto(localEntity, serverEntity);
      self:rehashEntity(localEntity);
      gameState.entitiesByType[serverEntity.type][serverEntity.uuid] = localEntity;
      
      if (localEntity._despawnTick and (share.tick > localEntity._despawnTick + 20)) then
        localEntity._despawnTick = nil;
      end
    end
    
  end

  function self:clientUnsyncEntityId(uuid) 
      local entity = gameState.entities[uuid];
      if (entity) then
        self:destroy(entity);
      end
  end
  
  local lastSyncTick = -1;
  local share = cs.client.share;
  function self:clientSyncEntities()
    
    if (share.tick ~= lastSyncTick) then
      lastSyncTick = share.tick;
      local serverEntities = cs.client.share.entities;
      local gameState = self.gameState;
      isSpawned = false;

      for uuid, e in pairs(serverEntities or {}) do
        self:clientSyncEntity(e);
      end
      
      for uuid, e in pairs(gameState.entities) do
        --If entity is a temporary (has _spawnTick defined) then either rewind it to a cached state or delete it (It will be spawned again during rewind)
        if (e._spawnTick and e._spawnTick > share.tick and tempCache[uuid][share.tick]) then
          Utils.copyInto(gameState.entities[uuid], tempCache[uuid][share.tick]);
          self:moveEntity(gameState.entities[uuid]);
        elseif (not serverEntities[uuid]) then
          self:clientUnsyncEntityId(uuid);
          tempCache[uuid] = nil;
        end
        
      end
    end

  end
  
  function self:respawnPlayer(entity)
    if (entity.clientId ~= cs.client.id) then
      self:despawn(entity);
    end
  end
    
  function self:clientDraw()
  
  end
  
  function self:clientReceive(msg)
  
  end
  
  function self:clientSend(msg)
    cs.client.send(msg);
  end
  
  function self:clientSendUnreliable(msg)
    cs.client.sendUnreliable(msg);
  end
  
  function self:clientIsConnected()
    return cs.client.connected;
  end
  
end


function Moat:initServer()
    print("init server");
    self.server = cs.server;
    self.share = cs.server.share;
    self.homes = cs.server.homes;
    self.uuidTracker = 0;
    self.entityForClient = {};
   
    local share = self.share;
    local gameState = self.gameState;
    local homes = self.homes;
    local constants = self.Constants;
    
    -- Initialize entities table on share so it's synced
    share.entities = {};
    
    function self.serverEntityRelevance(ents, clientId)
      result = {};

      local playerState = self.entityForClient[clientId];
      
      if (not playerState) then
        return result;
      end
          
      function makeRelevant(ent)
        result[ent.uuid] = 1;
      end
      
      -- Use our spatial hash to call makeRelevant on visible entities
      local viz = constants.ClientVisibility;
      
      gameState.space:each(playerState.x - viz, playerState.y - viz,
                 viz * 2, viz * 2, makeRelevant);

      return result;
      
    end
    
    
    gameState.entities = share.entities;
    
    local lastUuid = -1;
    
    function self:serverGetLastUuid()
      return lastUuid;
    end
    
    function self:playSound()
    
    end
    
    function self:serverGetShare()
      return self.share;
    end
    
    function self:serverGetHome(clientId)
      return self.homes[clientId];
    end
    
    function self:spawn(type, x, y, w, h, data)
      
      local uuid;
     
      if (data and data.uuid) then
        uuid = data.uuid;
      else
        self.uuidTracker = self.uuidTracker + 1;
        uuid = self.uuidTracker;
      end
      
      lastUuid = uuid;
      
      share.entities[uuid] = {
        type = type,
        x = x,
        y = y,
        w = w,
        h = h,
        --data = data,
        uuid = uuid
      };
      
      local entity = share.entities[uuid];

      
      Utils.copyInto(entity, data);
      
      gameState.space:add(entity, entity.x, entity.y, entity.w, entity.h);
      gameState.entitiesByType[entity.type][entity.uuid] = entity;
      gameState.entityCounts[entity.type] = gameState.entityCounts[entity.type] + 1;
      
      if (type == self.EntityTypes.Player and data and data.clientId) then
        self.entityForClient[data.clientId] = entity;
      end
      
      return entity;
    end
    
    function self:serverSpawnPlayer(clientId, x, y, w, h, data)
      
      if (self.entityForClient[clientId]) then
        self:despawn(self.entityForClient[clientId]);
      end
      
      local player = {
        x = x or 0,
        y = y or 0,
        w = w or 1,
        h = h or 1
      }
      
      local data = data or {};
      --self:serverResetPlayer(player);
      
      data.clientId = clientId;
      
      self:spawn(self.EntityTypes.Player, 
        player.x, player.y, player.w, player.h, data
      );
    
    end
    
    function self:despawn(entity)
      if not entity then return end;
      
      if (entity.type == self.EntityTypes.Player) then
        self.entityForClient[entity.clientId] = nil;
      end
      
      self:destroy(entity);
    end

    function self:respawnPlayer(player, x, y, w, h, data)
      self:serverSpawnPlayer(player.clientId, x, y, w, h, data);
    end
    
    function self:serverInitWorld()
      
    end
    
    function self:serverUpdatePlayers()
      
      local tick = gameState.tick;
      local space = gameState.space;
      share.tick = tick;

      for id, home in pairs(homes) do
            --Server player state
          local player = self.entityForClient[id];
          
          if (player and home.ih) then
          
            local inputHistory = home.ih;
            local clientInput = nil; --PlayerHistory.getInput(home.playerHistory, tick-1);
            
            --Todo improve
            for i = inputHistory.first, inputHistory.last do
              if (inputHistory[i] and inputHistory[i].tick < tick) then
                --print("Found", i, inputHistory[i].tick, tick, inputHistory.first, inputHistory.last);
                clientInput = inputHistory[i];
              end
            end
            
            if (not clientInput) then
              
              self.server.send(id, {
                debug_msg = "NIL_INPUT",
                tick = tick;
              });
              
            end
            
            self:playerUpdate(player, clientInput, self.Constants.TickInterval);
            
          end -- if player history
      end -- each player
    end -- updateAllPlayers
    
    function self:serverUpdate(dt)
      
    end
    
    function self:advanceGameState() 
      self:serverUpdatePlayers();
      self:worldUpdate(self.Constants.TickInterval);
      self:serverUpdate(self.Constants.TickInterval);
    end
    
    function self:serverSend(clientId, msg)
      cs.server.send(clientId, msg);
    end
    
    function self:serverSendUnreliable(clientId, msg)
      cs.server.sendUnreliable(clientId, msg);
    end
    
    function self:serverReceive(clientId, msg) 
    
    end
       
    function self:serverOnClientConnected(clientId)
    
    end
    
    function self:serverOnClientDisconnected(clientId)
    
    end
    
    function self:serverGetEntityForClientId(clientId)
      return self.entityForClient[clientId];
    end
    
end

function Moat:initGameState()
  local gameState = {};
  
  gameState.entities = {};
  gameState.space = Shash.new(self.Constants.CellSize);
  gameState.timeTracker = 0;
  gameState.tick = 0;
  gameState.entitiesByType = {};
  gameState.entityCounts = {};
    
  for name, value in pairs(self.EntityTypes) do
    gameState.entitiesByType[value] = {};
    gameState.entityCounts[value] = 0;
  end
 
  
  self.gameState = gameState;

end

function Moat:initCommon()
  
  local gameState = self.gameState;
  local space = gameState.space;
  
  function self:getTick()
    return gameState.tick;
  end
  
  function self:playerUpdate(player, input, dt)
    
  end
  
  function self:worldUpdate(dt)
  
  end
  
  --Return the overlapping area of two entity hitboxes
  function self:getOverlapArea(entityA, entityB) 
    local ax = (math.max(entityA.x, entityB.x) - math.min(entityA.x + entityA.w, entityB.x + entityB.w));
    
    local ay = (math.max(entityA.y, entityB.y) - math.min(entityA.y + entityA.h, entityB.y + entityB.h));
    
    return ax * ay;
  end
  
  function self:numEntitiesOfType(type)
    return gameState.entityCounts[type];
  end
  
  function self:getEntity(uuid)
    return gameState.entities[uuid];
  end
  
  function self:destroy(entity)   
      gameState.space:remove(entity);
      gameState.entitiesByType[entity.type][entity.uuid] = nil;
      gameState.entities[entity.uuid] = nil;
      gameState.entityCounts[entity.type] = gameState.entityCounts[entity.type] - 1;
  end
  
  function self:eachEntity(fn, ...)
    for uuid, entity in pairs(gameState.entities) do
      fn(entity, ...)
    end
  end
  
  function self:eachEntityOfType(type, fn, ...)
    if (not gameState.entitiesByType[type]) then
      print("Bad Type", type);
    end
  
    for uuid, entity in pairs(gameState.entitiesByType[type]) do
      if (not entity._despawnTick or gameState.tick <= entity._despawnTick) then
        fn(entity, ...);
      end
    end
  end
  
  --Debug version w/o despawning
  function self:eachEntityOfType2(type, fn)
    if (not gameState.entitiesByType[type]) then
      print("Bad Type", type);
    end
  
    for uuid, entity in pairs(gameState.entitiesByType[type]) do
        fn(entity);
    end
  end
  
  function self:moveEntity(entity, x, y, w, h)
    entity.x = x or entity.x;
    entity.y = y or entity.y;
    entity.w = w or entity.w;
    entity.h = h or entity.h;
    self:rehashEntity(entity);
  end
  
  function self:rehashEntity(entity)
    space:update(entity, entity.x, entity.y, entity.w, entity.h);
  end
  
  function self:eachOverlapping(entity, fn)
    
    local ifActive = function(entity)
      if (not entity._despawnTick or gameState.tick <= entity._despawnTick) then
        fn(entity);
      end
    end
  
    if (entity.uuid and space:contains(entity)) then
      space:each(entity, ifActive);
    else
      space:each(entity.x, entity.y, entity.w, entity.h, ifActive);
    end
  end
  

  local TickInterval = self.Constants.TickInterval;
  
  function self:update(dt)
    gameState.timeTracker = gameState.timeTracker + dt;
    while (gameState.timeTracker > TickInterval) do
      gameState.timeTracker = gameState.timeTracker - TickInterval;
      gameState.tick = gameState.tick + 1;
      
      self:advanceGameState(gameState);
    end
  
  end

end

function Moat:new(entityTypes, constants) 
  local m = {
    Constants = {
        CellSize = 5,
        TickInterval = 1.0 / 60.0,
        MaxHistory = 120,
        ClientVisibility = 20,
        MaxClients = 64
    },
    EntityTypes = {
      Player = 0
    }
  };
   
  for k,v in pairs(constants or {}) do
    m.Constants[k] = v;
  end
  
  for k,v in pairs(entityTypes or {}) do
    m.EntityTypes[k] = v;
  end
  
  self.__index = self;
  setmetatable(m, self);
  m:initGameState();
  
  m.isServer = CASTLE_SERVER or CASTLE_SERVER_LOCAL;
  m.isClient = not m.isServer;
  
  if (m.isServer) then
    m:initServer();
  else
    m:initClient();
  end
  
  m:initCommon();
  
  return m;
    
end


function Moat:runServer()

  print("run server");
  
    local server = cs.server;
    
    server.maxClients = self.Constants.MaxClients;
    
    --(type, x, y, w, h, data)
    function server.connect(id)
      --self:spawnPlayer(id);
      self:serverOnClientConnected(id);
    end
    
    function server.disconnect(id)
      
      self:serverOnClientDisconnected(id);
      
      self:despawn(self.entityForClient[id]);
    end
    
    function server.update(dt)
      self:update(dt);
    end
    
    function server.backgroundupdate(dt)
      self:update(dt)
    end
    
    function server.receive(clientId, msg)
      self:serverReceive(clientId, msg);
    end
    
    self.share.entities:__relevance(self.serverEntityRelevance);
    
    self:serverInitWorld(self.gameState);
    
    if USE_CASTLE_CONFIG then
      server.useCastleConfig()
    else
      print("Start local server");
      server.enabled = true
      server.start('22122') -- Port of server
    end

end


function Moat:runClient()

  local client = self.client;

  local hasConnected = false;
  
  function client.update(dt)
    --print("dt", dt);
    if (client.connected and client.id) then
      
      self:smoothPing();
      
      if (not hasConnected) then
        hasConnected = true;
        self:clientSyncEntities();
      end
    
      self:update(dt);
    end
  end

  function client.connect()
    self:clientOnConnected();
  end
  
  function client.disconnect()
    self:clientOnDisconnected();
  end
  
  function client.load()
    self:clientLoad();
  end
  
  function client.receive(msg)
    
    if (msg.debug_msg) then
      print(msg.debug_msg, msg.tick);
    end
    self:clientReceive(msg);
  end
  
  function client.resize(x, y)
    self:clientResize(x, y);
  end
  
  function client.keypressed(key)
    self:clientKeyPressed(key);
    
    if (key == "`") then
      print(self.smoothedPing, self.lastPing, TICK_DEBUG);
    end
    
    if (key == "{") then
      TICK_BUFFER = TICK_BUFFER + 1;
      print("tb", TICK_BUFFER, TICK_DEBUG);
   end
    
    if (key == "}") then
      TICK_BUFFER = TICK_BUFFER - 1;
      print("tb", TICK_BUFFER, TICK_DEBUG);
    end
    
    
  end
  
  function client.backgroundupdate(dt)
    self:update(dt)
  end
  
  function client.keyreleased(key)
    self:clientKeyReleased(key);
  end
  
  function client.mousepressed(x, y)
    self:clientMousePressed(x, y);
  end
  
  function client.mousemoved(x, y)
    self:clientMouseMoved(x, y);
  end
  
  function client.wheelmoved(dx, dy)
    self:clientWheelMoved(dx, dy);
  end
  
  --[[
  function client.changed(diff)
    --self:clientSyncEntities(diff);
  end
  ]]
  
  function client.draw()
    self:clientDraw();
  end
 

  if USE_CASTLE_CONFIG then
      print("Use castle config");
      client.useCastleConfig()
  else
      print("Connect to local host");
      client.enabled = true
      client.start("localhost:22122")
  end
end

function Moat:run()
  
  if (self.isServer) then
    self:runServer()
   else
    self:runClient()
   end

end

Moat.Utils = Utils;
Moat.PlayerHistory = PlayerHistory;
Moat.Math2D = Math2D;
Moat.Entity = Entity;
Moat.Math = Math;

return Moat;
