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

function Utils.overwrite(toTable, fromTable)
  
  for k,v in pairs(toTable) do
    toTable[k] = nil;
  end
  
  Utils.copyInto(toTable, fromTable);
  return toTable;
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
Math2D.lerp = Utils.lerp;

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

Math2D.normalize = Utils.normalize;

function Utils.distance(entityA, entityB)
  local dx, dy = entityA.x - entityB.x, entityA.y - entityB.y;
  return math.sqrt(dx * dx + dy * dy);
end
Entity.distance = Utils.distance;

--Signed angle between two normalized vectors
function Math2D.signedAngle(x1, y1, x2, y2)
  
  local dot = x1 * x2 + y1 * y2;
  
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

function PlayerHistory.new()
  
  local ph =  {
    tick = 0,
    inputHistory = List.new(),
    state = {
      x = 0,
      y = 0,
      w = 1,
      h = 1
    }
  }
 
  ph.inputHistory.last = 0;
  --List.pushright(ph.inputHistory, nil);
  
  return ph;
 
end


function PlayerHistory.getLastState(ph)
  return ph.state;
end

function PlayerHistory.getInput(ph, tick)
  return ph.inputHistory[tick];
end

local doLog = 1000;
local alog = function(...)
  if (doLog > 0) then
  doLog = doLog - 1;
    print(...);
  end
end
  
function PlayerHistory.updateInput(ph, input)

  if (input) then
    ph.inputHistory[ph.tick] = ph.inputHistory[ph.tick] or {};
    Moat.Utils.copyInto(ph.inputHistory[ph.tick], input);
  end
  
end



TICK_BUFFER = 4;
TICK_DEBUG = -1;

function PlayerHistory.rebuild(ph, state, serverTick, moat)


  moat:rehashEntity(state);
  
  -- Find the ideal tick offset between client and server, and decide whether or not to use it
  
  local idealTick = serverTick + math.ceil((moat:getPing()*0.001) / moat.Constants.TickInterval) + TICK_BUFFER;
  
  TICK_DEBUG = idealTick - serverTick;
  
  local idealDiff = idealTick - ph.tick;
  local didSnap = false;
  
  if (idealDiff > -10 and idealDiff < 4) then
    idealTick = ph.tick;
  else
    didSnap = true;
   print("snap", ph.tick, idealTick, serverTick, idealDiff);
    idealTick = idealTick;
  end
  
  --print("Time:", love.timer.getTime());
  
  local oldTick = ph.tick;
  
  --Rewind to the state at the old tick
  Utils.copyInto(ph.state, state);
  ph.tick = serverTick;
  
  --[[
  for pt = ph.inputHistory.last, serverTick, -1 do
    if (not ph.inputHistory[pt]) then
      ph.inputHistory[pt] = {};
      Utils.copyInto(ph.inputHistory[pt], ph.inputHistory[pt-1]);
    end
  end
  ]]
  
  ph.inputHistory.last = serverTick;

  for t = serverTick, idealTick do
      PlayerHistory.advance(ph, moat, ph.inputHistory);
  end

  if (didSnap) then
    --print("Snapped to", ph.tick);
  end
end

function PlayerHistory.advance(ph, moat, inputHistory)
  
  moat.gameState.tick = ph.tick;

  moat:playerUpdate(ph.state, inputHistory[ph.tick]);
  --moat:worldUpdate(ph.tick);

  ph.tick = ph.tick + 1;
  inputHistory.last = ph.tick;
  inputHistory[ph.tick] = inputHistory[ph.tick] or {};
  
  while (List.length(inputHistory) > moat.Constants.MaxHistory) do
    List.popleft(inputHistory) 
  end
    
  moat.gameState.tick = ph.tick;
  
end

Moat.Commands = {
  
  CLIENT_SEND_VOLATILE = 0,
  CLIENT_RECEIVE_VOLATILE = 1

}

function Moat:initClient()
  print("init client");
  self.client = cs.client;
  self.share = cs.client.share;
  self.home = cs.client.home;
  --self.home.playerHistory = PlayerHistory:new();
  
  local isSpawned = false;
  
  --local ph = self.home.playerHistory;
  local ph = PlayerHistory:new();
  local gameState = self.gameState;
  local space = gameState.space;
  local share = self.share;
  
  self.ping = 100;
  
  function self:spawn()
  end
  
  function self:spawnPlayer()
  end
  
  function self:clientKeyPressed(key) end
  
  function self:clientKeyReleased(key) end
  
  function self:clientMousePressed() end
  
  function self:clientMouseMoved() end
  
  function self:clientLoad() end
  function self:clientResize() end
  
  function self:getPlayerState()
  
    return PlayerHistory.getLastState(ph);
    
  end
  
  function self:clientTick(gameState)
    
  end
    
  function self:despawn(entity)
    entity.despawned = gameState.tick;
  end
  
  self.smoothedPing = -1;
  self.lastPing = -1;
  
  function self:smoothPing()
    if (self.smoothedPing < 0) then
      self.smoothedPing = cs.client.getPing();
    else
      self.lastPing = cs.client.getPing();
      self.smoothedPing = self.lastPing;
      --self.smoothedPing = Utils.lerp(self.smoothedPing, self.lastPing, 0.2);
    end
  end
  
  function self:getPing()
      return self.smoothedPing;
  end
  
  function self:clientUpdate()
  
  end
  
  --Client Tick
  function self:advanceGameState()
    
    --self:clientSyncEntities();
    
    if (self.doRebuild) then 
      
      local backup = Utils.copyInto({}, ph.state);
      
      local serverState = self.doRebuild.serverState;
      
      PlayerHistory.rebuild(ph, self.doRebuild.serverState, self.doRebuild.tick, self);
      self.doRebuild = nil;
      --print("doin rebuild", serverState.x, serverState.y);
      
      if (not backup.uuid or backup.uuid ~= serverState.uuid or Entity.distance(backup, serverState) > 3) then
        --print("Used rebuild");
      else
       -- print("overwrote");
       Utils.copyInto(ph.state, backup);
      end
    
     --end
     
    else
     if (ph.state.clientId == nil) then return end
     PlayerHistory.advance(ph, self, ph.inputHistory)
    end
   
     if (ph.state.clientId == nil) then return end

     
    self.client.sendUnreliable({
      cmd = Moat.Commands.CLIENT_SEND_VOLATILE,
      state = ph.state,
      tick = ph.tick
    });
    
    gameState.tick = ph.tick;
    --print("tick", ph.tick);

    
    self:clientUpdate(self.gameState);
  end
  
  function self:setPlayerInput(input)    
    PlayerHistory.updateInput(ph, input);    
  end
  
  local lastRebuildTick = -1;
  function self:clientSyncPlayer(serverPlayer)
    
       --print("CSP", serverPlayer.x, serverPlayer.y);
      if (share.tick > lastRebuildTick) then
        self.doRebuild = {
          serverState = serverPlayer,
          tick = share.tick
        };
        lastRebuildTick = share.tick;
      end
      
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
    
      local volatileMap = self.volatileState[serverEntity.uuid] or {lastTick = -100};
      if (volatileMap.lastTick > share.tick) then
        return;
      end
      
      if (not gameState.entitiesByType[serverEntity.type]) then
        return;
      end
    
      gameState.entities[serverEntity.uuid] = gameState.entities[serverEntity.uuid] or {};
      local localEntity = gameState.entities[serverEntity.uuid];
      Utils.copyInto(localEntity, serverEntity);
      self:rehashEntity(localEntity);
      gameState.entitiesByType[serverEntity.type][serverEntity.uuid] = localEntity;
      
      if (localEntity.despawned and (share.tick > localEntity.despawned + 20)) then
        localEntity.despawned = nil;
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
  
    --if (share.tick ~= lastSyncTick) then
      lastSyncTick = share.tick;
      --print("cse", share.tick);

      local serverEntities = cs.client.share.entities;
      local gameState = self.gameState;
      isSpawned = false;

      for uuid, e in pairs(serverEntities or {}) do
        self:clientSyncEntity(e);
      end
       
      for uuid, e in pairs(gameState.entities) do
        if (not serverEntities[uuid]) then
          self:clientUnsyncEntityId(uuid);
        end
      end
    --end

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
    
    self.relevanceMap = {};
 
    local share = self.share;
    local gameState = self.gameState;
    local homes = self.homes;
    local Constants = self.Constants;
    local EntityTypes = self.EntityTypes;
    
    -- Shared entity map
    share.entities = {};
    
    --gameState.entities = share.entities;

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
      local viz = Constants.ClientVisibility;
      
      gameState.space:each(playerState.x - viz, playerState.y - viz,
                 viz * 2, viz * 2, makeRelevant);

      return result;
      
    end
    
    
    
    local lastUuid = -1;
    
    function self:serverGetLastUuid()
      return lastUuid;
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
      print("spawn", uuid, type, x, y);
      
      local entity = {
        type = type,
        x = x,
        y = y,
        w = w,
        h = h,
        --data = data,
        uuid = uuid
      };
      
    -- local entity = share.entities[uuid];      
      Utils.copyInto(entity, data);
      
      
      gameState.entities[entity.uuid] = Utils.copyInto({}, entity);
      local gsEntity = gameState.entities[uuid];
      
      gameState.space:add(gsEntity, gsEntity.x, gsEntity.y, gsEntity.w, gsEntity.h);
      gameState.entitiesByType[gsEntity.type][uuid] = gsEntity;
      gameState.entityCounts[gsEntity.type] = gameState.entityCounts[gsEntity.type] + 1;
      
      if (type == self.EntityTypes.Player and data and data.clientId) then
        self.entityForClient[data.clientId] = gsEntity;
        self.volatileState[uuid] = {};
        --print("spawn", entity.clientId, entity.uuid);
      end
      
      --share.tick = self:getTick();
      share.entities[uuid] = Utils.copyInto({}, entity);
      return gsEntity;
    end
    
    function self:despawn(entity)
      if not entity then return end;
      
      print("despawn", entity.uuid);
      
      if (entity.type == self.EntityTypes.Player) then
        self.entityForClient[entity.clientId] = nil;
      end
      
      self:destroy(entity);
      share.entities[entity.uuid] = nil;
      --share.tick = self:getTick();
    end

    function self:respawnPlayer(player)
      self:despawn(player);
      self:spawnPlayer(player.clientId);
    end
    
    function self:setPlayerInput()
    
    end
    
    function self:serverInitWorld()
      
    end
    
    function self:serverUpdatePlayers()
      local tick = gameState.tick;
      local space = gameState.space;

      for id, home in pairs(homes) do
            --Server player state
        local player = self.entityForClient[id];
        
        if (player) then
          self:playerUpdate(player, nil);
        end
      end
    end
    
    --[[
    function self:serverUpdatePlayers()
      
      local tick = gameState.tick;
      local space = gameState.space;
      share.tick = tick;

      for id, home in pairs(homes) do
            --Server player state
          local player = self.entityForClient[id];
          
          if (player and home.playerHistory) then
          
            local clientInput = PlayerHistory.getInput(home.playerHistory, tick-1);
            
            if (not clientInput) then
              self.server.send(id, {
                debug_msg = "NIL_INPUT",
                tick = tick
              });
            end
            
            self:playerUpdate(player, clientInput);
            
          end -- if player history
      end -- each player
    end -- updateAllPlayers
    ]]
    
    function self:serverUpdate()
      
    end
    
    local lastCheckpoint = -1;
    
    -- Periodically transfer gameState entities over to share and broadcast checkpoint
    function self:serverMakeCheckpoint()
      lastCheckpoint = gameState.tick;
      share.tick = gameState.tick;
      
      --[[
      for id, home in pairs(homes) do
        --Server player state
        local player = self.entityForClient[id];
      
        if player then
          local vs = self.volatileState[player.uuid];
          
          if vs then
            Utils.copyInto(player, vs.state);
            self.volatileState[player.uuid] = nil;
          end
        end
      end
      ]]
      
      for uuid, gsEntity in pairs(self.changedSinceCheckpoint) do
        local sharedEntity = share.entities[uuid];
        if (sharedEntity) then
          Utils.overwrite(sharedEntity, gsEntity);
         end
      end
      
      self.changedSinceCheckpoint = {};
    end
    
    -- Load volatile player states into gameState
    function self:serverLoadVolatiles()
    
       local tick = gameState.tick;
       local volatileState = self.volatileState;
       
       for id, home in pairs(homes) do
          --Server player state
          local player = self.entityForClient[id];
        
          if player then
            local vs = volatileState[player.uuid][tick];
            
            if vs then
              Utils.copyInto(player, vs);
              volatileState[player.uuid][tick] = nil;
              self.changedSinceCheckpoint[player.uuid] = player;
              self:moveEntity(player);
            end
          end
        end
    end
    
    function self:serverSyncClients()    
    
      for id, home in pairs(homes) do
      --Todo use relevance instead
        for uuid, entity in pairs(self.changedSinceCheckpoint) do
        
          if (entity.clientId and entity.clientId == id) then
            --Don't relevant self?
          else
          
            local sendTick = gameState.tick;
            
            if (entity.type == EntityTypes.Player) then
              local volatileMap = self.volatileState[entity.uuid];
              if (volatileMap.lastTick and volatileMap.lastTick > gameState.tick) then
                entity = volatileMap[volatileMap.lastTick];
                sendTick = volatileMap.lastTick;
              end
            end
            
            self.server.sendUnreliable(id, {
              cmd = Moat.Commands.CLIENT_RECEIVE_VOLATILE,
              uuid = uuid,
              tick = sendTick,
              state = entity
            });
          end
        end
      end
    end
    
    function self:advanceGameState() 
      --self:serverUpdatePlayers();
      local tick = gameState.tick;
   
      
      self:serverLoadVolatiles();     
      self:serverUpdatePlayers();
      self:worldUpdate(self.gameState.tick);
      self:serverUpdate(self.gameState.tick);
         
      if (lastCheckpoint < 0 or tick % 60 == 0) then
          self:serverMakeCheckpoint();
      end
      
      self:serverSyncClients();
    end
    
    function self:serverSend(clientId, msg)
      cs.server.send(clientId, msg);
    end
    
    function self:serverReceive(clientId, msg) 
      
    end
    
    function self:serverResetPlayer(player)

    end
       
    function self:spawnPlayer(clientId)
      
      local x,y = 0,0;
      local width, height = 1, 1;
      local player = {
        x = x,
        y = y,
        w = width,
        h = height
      }
      
      self:serverResetPlayer(player);
      
      player.clientId = clientId;
      
      self:spawn(self.EntityTypes.Player, 
        player.x, player.y, player.w, player.h, player
      );
    
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
  self.volatileState = {};
  self.changedSinceCheckpoint = {};
   
end

function Moat:initCommon()
  
  local gameState = self.gameState;
  local space = gameState.space;
  
  function self:getTick()
    return gameState.tick;
  end
  
  function self:playerUpdate(player, input)
    
  end
  
  function self:worldUpdate(gameState)
  
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
      --print("destroy", entity.uuid);
      gameState.space:remove(entity);
      gameState.entitiesByType[entity.type][entity.uuid] = nil;
      gameState.entities[entity.uuid] = nil;
      gameState.entityCounts[entity.type] = gameState.entityCounts[entity.type] - 1;
      self.volatileState[entity.uuid] = nil;
      self.changedSinceCheckpoint[entity.uuid] = nil;
  end
  
  function self:eachEntityOfType(type, fn, ...)
    if (not gameState.entitiesByType[type]) then
      print("Bad Type", type);
    end
  
    for uuid, entity in pairs(gameState.entitiesByType[type]) do
      if (not entity.despawned or gameState.tick <= entity.despawned) then
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
    self.changedSinceCheckpoint[entity.uuid] = entity;
    space:update(entity, entity.x, entity.y, entity.w, entity.h);
  end
  
  function self:eachOverlapping(entity, fn)
    
    local ifActive = function(entity)
      if (not entity.despawned or gameState.tick <= entity.despawned) then
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
  
  function self:receiveVolatile(msg)
    local entity = gameState.entities[msg.state.uuid];
      if (entity) then
        local volatileMap = self.volatileState[entity.uuid] or {};
        volatileMap[msg.tick] = msg.state;
        volatileMap.lastTick = math.max(volatileMap.lastTick or -1, msg.tick);
        self.volatileState[entity.uuid] = volatileMap;
      end
    end    
end

function Moat:new(entityTypes, constants) 
  local m = {
    Constants = {
        CellSize = 5,
        TickInterval = 1.0 / 60.0,
        MaxHistory = 120,
        ClientVisibility = 20 
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
    --(type, x, y, w, h, data)
    function server.connect(id)
      --self:spawnPlayer(id);
    end
    
    function server.disconnect(id)
      self:despawn(self.entityForClient[id]);
    end
    
    function server.update(dt)
      self:update(dt);
    end
    
    function server.backgroundupdate(dt)
      self:update(dt)
    end
    
    function server.receive(clientId, msg)
      
      if (msg.cmd == Moat.Commands.CLIENT_SEND_VOLATILE) then
        --TODO VALIDATE
        self:receiveVolatile(msg);
        return;
      end
      
      self:serverReceive(clientId, msg);
    end
    
    --self.share.entities:__relevance(self.serverEntityRelevance);
    
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

  function client.load()
    self:clientLoad();
  end
  
  function client.receive(msg)
    
    if (msg.cmd == Moat.Commands.CLIENT_RECEIVE_VOLATILE) then
       
      self:receiveVolatile(msg);
    
      local entity = self.gameState.entities[msg.uuid];

      
      if (entity) then
        
        local tick = msg.tick;
        
        Utils.copyInto(entity, msg.state);
        self:moveEntity(entity);
        
      end
    end
    
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
  
  
  function client.changed(diff)
    self:clientSyncEntities();
    
    --[[
    if (diff and diff.entities) then
      for uuid, entity in pairs(diff.entities) do
        
        if (entity == cs.DIFF_NIL) then
          self:clientUnsyncEntityId(uuid);
        elseif (uuid ~= self:getPlayerState().uuid) then
          
          local ent2 = entity; 
          if (self.share.entities[uuid]) then
            ent2 = self.share.entities[uuid];
          end
          
          if (ent2 and ent2.clientId == client.id) then
            
          end
        end
        
      end
    end]]
    
  end
  
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