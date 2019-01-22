local cs = require("cs")
local Shash = require("lib/shash")
local List = require("lib/list")

local PlayerHistory = {};
local Moat = {};

function PlayerHistory.new()
  
  local ph =  {
    tick = 0,
    tickStates = List.new()
  }
 
  List.pushright(ph.tickStates, {
    x = 0,
    y = 0,
    w = 1,
    h = 1
  })
  
  return ph;
 
end


function PlayerHistory.getLastState(ph)
  return ph.tickStates[ph.tick];
end

function PlayerHistory.getState(ph, tick)
  tick = tick or ph.tick;
  return ph.tickStates[tick];
end

function PlayerHistory.rebuild(ph, state, tick, moat)
  
  local ping = cs.client.getPing();
  
  local newTick = tick + math.ceil((ping/1000.0) / moat.Constants.TickInterval);
  
  local oldStates = ph.tickStates;
  local oldTick = ph.tick;
  
  ph.tickStates = List.new(tick);
  List.pushright(ph.tickStates, state);
  ph.tick = tick;
  
  for t = tick, newTick do
    
    PlayerHistory.advance(ph, moat);
    local oldState = oldStates[oldTick - (newTick - t)];
    if (oldState) then
      local newState = PlayerHistory.getLastState(ph);
      newState.input = oldState.input;
    end
    
  end
end

function PlayerHistory.advance(ph, moat)
  
  local tickStates = ph.tickStates;
  
  if (List.length(tickStates) >= moat.Constants.MaxHistory) then
    List.popleft(tickStates) 
  end
  
  List.pushright(tickStates, {});
  ph.tick = ph.tick + 1;
  
  local oldState = ph.tickStates[ph.tick-1];
  
  moat:advancePlayer(ph.tickStates[ph.tick], oldState);
  
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
  
  function self:spawnEntity()
    
    ---
  end
  
  function self:keypressed()
  
  end
  
  function self:getPlayerState()
  
    return PlayerHistory.getLastState(ph);
    
  end
  
  --Client Tick
  function self:advanceGameState()
    PlayerHistory.advance(ph, self); 
    
   
  end
  
  function self:setPlayerInput(input)
  
    local playerState = PlayerHistory.getLastState(ph);
    playerState.input = playerState.input or {};
    
    for k,v in pairs(input) do
      playerState.input[k] = v;
    end
  
  end
  
  local lastSyncPing = self.ping;
  
  function self:syncPlayer(player)
    local ping = cs.client.getPing();
  
    if (share.tick > gameState.tick or math.abs(ping - lastSyncPing) > 20) then
      print("rebuild", share.tick, gameState.tick);
      PlayerHistory.rebuild(ph, player, share.tick, self);
      gameState.tick = ph.tick;
      lastSyncPing = ping;
    else
      --print("no reb", ping, lastSyncPing);
    end
  end
  
  function self:syncEntity(entity)
    self:rehashEntity(entity);
    gameState.entitiesByType[entity.type][entity.uuid] = entity;
    gameState.entities[entity.uuid] = entity;
    
    if (entity.uuid == cs.client.id) then
        self:syncPlayer(entity);
    end
  end

  function self:unsyncEntityId(uuid) 
      local entity = gameState.entities[uuid];
      self:despawnEntity(entity);
  end
  
  function self:syncEntities(diff)
    local entities = cs.client.share.entities;
    local gameState = self.gameState;
    
    for uuid, e in pairs(entities) do
      self:syncEntity(e);
    end
    
    --Remove entity if no longer syncing
    for uuid, diff in pairs(diff.entities or {}) do 
      if (diff == cs.DIFF_NIL) then
        self:unsyncEntityId(uuid);
      end
    end
  end
    
  function self:draw()
  
  end
  
end


function Moat:initServer()
    print("init server");
    self.server = cs.server;
    self.share = cs.server.share;
    self.homes = cs.server.homes;
    self.uuidTracker = 0;
   
    local share = self.share;
    local gameState = self.gameState;
    local homes = self.homes;
    
    -- Initialize entities table on share so it's synced
    share.entities = {};
    gameState.entities = share.entities;
    
    function self:spawnEntity(type, x, y, w, h, data)
      
      local uuid;
      
      if (data and data.uuid) then
        uuid = data.uuid;
      else
        self.uuidTracker = self.uuidTracker + 1;
        uuid = self.uuidTracker;
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
      
      print("Adding", uuid);
      local entity = share.entities[uuid];

      gameState.space:add(entity, entity.x, entity.y, entity.w, entity.h);
      gameState.entitiesByType[entity.type][entity.uuid] = entity;
      
      return entity;
    end
    
    function self:setPlayerInput()
    
    end
    
    function self:updateAllPlayers()
      
      local tick = gameState.tick;
      local space = gameState.space;
      share.tick = tick;

      for id, home in pairs(homes) do
            --Server player state
          local player = share.entities[id];
          if (home.playerHistory) then
            local clientState = PlayerHistory.getState(home.playerHistory, tick);
            if (clientState) then
              clientState.x, clientState.y = player.x, player.y;
              clientState.w, clientState.h = player.w, player.h;
              --clientState.data = player.data;
              self:advancePlayer(player, clientState);
              self:rehashEntity(player);
              --print(player.y);
            end --if client state
          end -- if player history
      end -- each player
    end -- updateAllPlayers
    
    function self:advanceGameState() 
      self:updateAllPlayers();
    end
    
    function self:spawnNewPlayer(id)
      
      self:spawnEntity(self.EntityTypes.Player, 
        0, 0, 1, 1, {uuid = id}
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
    
  for name, value in pairs(self.EntityTypes) do
    gameState.entitiesByType[value] = {};
    print("ebt", name, value);
  end
 
  
  self.gameState = gameState;

end

function Moat:initCommon()
  
  local gameState = self.gameState;
  local space = gameState.space;
  
  
  function self:advancePlayer(newState, oldState)
    
    newState.x = oldState.x;
    newState.y = oldState.y;
    newState.w = oldState.w;
    newState.h = oldState.h;
    --newState.data = oldState.data;
    newState.input = nil;
    
    self:applyPlayerInput(newState, oldState, oldState.input);
    
  end
  
  function self:applyPlayerInput(newState, oldState, input)
    
  end
  
  function self:despawnEntity(entity)
      gameState.space:remove(entity);
      gameState.entitiesByType[entity.type][entity.uuid] = nil;
      gameState.entities[entity.uuid] = nil;
  end
  
  function self:eachEntityOfType(type, fn)
    for uuid, entity in pairs(gameState.entitiesByType[type]) do
      fn(entity);
    end
  end
  
  function self:rehashEntity(entity)
    space:update(entity, entity.x, entity.y, entity.w, entity.h);
  end
    
  function self:eachOverlapping(entity, fn)
    if (space:contains(entity)) then
      space:each(entity, fn);
    else
      space:each(entity.x, entity.y, entity.w, entity.h, fn);
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
        MaxHistory = 120
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
      self:spawnNewPlayer(id);
    end
    
    function server.disconnect(id)
    
    end
    
    function server.update(dt)
      self:update(dt);
    end
    
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

  function client.update(dt)
    self:update(dt);
  end

  function client.receive(msg)
    
  end
  
  self.keyboard = {};
  function client.keypressed(key)
    self.keyboard[key] = 1.0;
    self:keypressed(key);
  end
  
  function client.changed(diff)
    self:syncEntities(diff);
  end
  
  function client.draw()
    --print("Drawing");
    self:draw();
  end
  
  function client.load()
    --print("Loaded");
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
return Moat;