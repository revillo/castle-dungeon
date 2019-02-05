local cs = require("cs")
local Shash = require("lib/shash")
local List = require("lib/list")

local PlayerHistory = {};
local Moat = {};

local Utils = {};

function Utils.copyInto(toTable, fromTable)
  
  if (fromTable) then
    for k, v in pairs(fromTable) do
        toTable[k] = v;
    end  
  end
  return toTable;
  
end

function Utils.distance(entityA, entityB)
  local dx, dy = entityA.x - entityB.x, entityA.y - entityB.y;
  return math.sqrt(dx * dx + dy * dy);
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
 
  List.pushright(ph.inputHistory, nil);
  
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

function PlayerHistory.rebuild(ph, state, tick, moat)
  local idealTick = tick + math.ceil((moat:getPing()*0.001) / moat.Constants.TickInterval) + 2;
  
  local idealDiff = idealTick - ph.tick;
  
  if (idealDiff > -2 and idealDiff < 4) then
    idealTick = ph.tick;
  else
    print("snap");
  end
  
  local oldTick = ph.tick;
  
  Utils.copyInto(ph.state, state);
  ph.tick = tick;
  
  
  for pt = ph.inputHistory.last, tick do
    if (not ph.inputHistory[pt]) then
      ph.inputHistory[pt] = {};
      Utils.copyInto(ph.inputHistory[pt], ph.inputHistory[pt-1]);
    end
  end
  ph.inputHistory.last = tick;

  for t = tick, idealTick do
      PlayerHistory.advance(ph, moat, ph.inputHistory);
  end

end

function PlayerHistory.advance(ph, moat, inputHistory)
  
  moat:playerUpdate(ph.state, inputHistory[ph.tick]);
  moat:rehashEntity(ph.state);
  
  --List.pushright(inputHistory, nil);
  ph.tick = ph.tick + 1;
  inputHistory.last = ph.tick;
  inputHistory[ph.tick] = inputHistory[ph.tick] or {};
  --Utils.copyInto(inputHistory[ph.tick], inputHistory[ph.tick-1]);
  
  if (List.length(inputHistory) >= moat.Constants.MaxHistory) then
    List.popleft(inputHistory) 
  end
  
end

function Moat:initClient()
  print("init client");
  self.client = cs.client;
  self.share = cs.client.share;
  self.home = cs.client.home;
  self.home.playerHistory = PlayerHistory:new();
  local ph = self.home.playerHistory;
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
    entity.despawned = share.tick;
  end
  
  function self:getPing()
    return cs.client.getPing();
  end
  
  --Client Tick
  function self:advanceGameState()
    
    if (self.doRebuild) then
      PlayerHistory.rebuild(ph, self.doRebuild.serverState, self.doRebuild.tick, self);
      self.doRebuild = nil;
    else
      if (ph.state.clientId == nil) then return end
      PlayerHistory.advance(ph, self, ph.inputHistory); 
    end
    gameState.tick = ph.tick;

    self:clientUpdate(self.gameState);
  end
  
  function self:setPlayerInput(input)    
    PlayerHistory.updateInput(ph, input);
  end
  
  function self:syncPlayer(serverPlayer)
      self.doRebuild = {
        serverState = serverPlayer,
        tick = share.tick
      };
  end
  
  local cntr = 10;
  
  function self:syncEntity(serverEntity)
    
    
    if (serverEntity.clientId == cs.client.id and cs.client.id) then
             
        self:syncPlayer(serverEntity);       
        self.gameState.entitiesByType[self.EntityTypes.Player][serverEntity.uuid] = nil;
        self.gameState.entities[serverEntity.uuid] = nil;
      
    else
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

  function self:unsyncEntityId(uuid) 
      local entity = gameState.entities[uuid];
      if (entity) then
        self:destroy(entity);
      end
  end
  
  function self:syncEntities(diff)
    local serverEntities = cs.client.share.entities;
    local gameState = self.gameState;
    
    for uuid, e in pairs(serverEntities) do
      self:syncEntity(e);
    end
    
    --Remove entity if no longer syncing
    --[[
    for uuid, diff in pairs(diff.entities or {}) do 
      if (diff == cs.DIFF_NIL) then
        self:unsyncEntityId(uuid);
      end
    end
    ]]
    
    for uuid, e in pairs(gameState.entities) do
      if (not serverEntities[uuid]) then
        self:unsyncEntityId(uuid);
      end
    end
    
  end
    
  function self:clientDraw()
  
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
    
    -- Initialize entities table on share so it's synced
    share.entities = {};
    gameState.entities = share.entities;
    
    function self:spawn(type, x, y, w, h, data)
      
      local uuid;
     
      
      if (data and data.uuid) then
        uuid = data.uuid;
      else
        self.uuidTracker = self.uuidTracker + 1;
        uuid = "e"..self.uuidTracker;
      end
      
      
      
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
        print("spawn", entity.clientId, entity.uuid);
      end
      
      return entity;
    end
    
    function self:despawn(entity)
      self:destroy(entity);
    end

    function self:setPlayerInput()
    
    end
    
    function self:serverInitWorld()
      
    end
    
    function self:updateAllPlayers()
      
      local tick = gameState.tick;
      local space = gameState.space;
      share.tick = tick;

      for id, home in pairs(homes) do
            --Server player state
          local player = self.entityForClient[id];
          if (home.playerHistory) then
          
            local clientInput = PlayerHistory.getInput(home.playerHistory, tick-1);
            
            self:playerUpdate(player, clientInput);
            self:rehashEntity(player);

            
          end -- if player history
      end -- each player
    end -- updateAllPlayers
    
    function self:advanceGameState() 
      self:updateAllPlayers();
      self:serverUpdate(self.gameState);
    end
    
       
    function self:spawnPlayer(id)
      
      local x,y = 0,0;
      local width, height = 1, 1;
      local player = {
        x = x,
        y = y,
        w = width,
        h = height
      }
      
      self:resetPlayer(player);
      
      player.clientId = id;
      
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

end

function Moat:initCommon()
  
  local gameState = self.gameState;
  local space = gameState.space;
  
  function self:playerUpdate(player, input)
    
  end
  
  function self:numEntitiesOfType(type)
    return gameState.entityCounts[type];
  end
  
  function self:destroy(entity)
      gameState.space:remove(entity);
      gameState.entitiesByType[entity.type][entity.uuid] = nil;
      gameState.entities[entity.uuid] = nil;
      gameState.entityCounts[entity.type] = gameState.entityCounts[entity.type] - 1;
  end
  
  function self:eachEntityOfType(type, fn)
    if (not gameState.entitiesByType[type]) then
      print("Bad Type", type);
    end
  
    for uuid, entity in pairs(gameState.entitiesByType[type]) do
      if (not entity.despawned) then
        fn(entity);
      end
    end
  end
  
  function self:eachEntityOfType2(type, fn)
    if (not gameState.entitiesByType[type]) then
      print("Bad Type", type);
    end
  
    for uuid, entity in pairs(gameState.entitiesByType[type]) do
      --if (not entity.despawned) then
        fn(entity);
      --end
    end
  end
  
  function self:rehashEntity(entity)
    space:update(entity, entity.x, entity.y, entity.w, entity.h);
  end
    
  function self:eachOverlapping(entity, fn)
    
    local ifActive = function(entity)
      if (not entity.despawned) then
        fn(entity);
      end
    end
  
    if (space:contains(entity)) then
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
        DriftLimit = 4
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
      self:spawnPlayer(id);
    end
    
    function server.disconnect(id)
      self:despawn(self.entityForClient[id]);
    end
    
    function server.update(dt)
      self:update(dt);
    end
    
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
    if (client.id) then
      
      if (not hasConnected) then
        hasConnected = true;
        self:syncEntities({});
      end
    
      self:update(dt);
    end
  end

  function client.load()
    self:clientLoad();
  end
  
  function client.receive(msg)
    
  end
  
  function client.resize(x, y)
    self:clientResize(x, y);
  end
  
  function client.keypressed(key)
    self:clientKeyPressed(key);
  end
  
  function client.keyreleased(key)
    self:clientKeyReleased(key);
  end
  
  function client.mousepressed()
    self:clientMousePressed();
  end
  
  function client.mousemoved(x, y)
    self:clientMouseMoved(x, y);
  end
  
  function client.changed(diff)
    self:syncEntities(diff);
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

return Moat;