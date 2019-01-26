local cs = require("cs")
local Shash = require("lib/shash")
local List = require("lib/list")

local PlayerHistory = {};
local Moat = {};

local Utils = {};

function Utils.copyInto(toTable, fromTable)
  
  for k, v in pairs(fromTable) do
      toTable[k] = v;
  end  
  
  return toTable;
  
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

function PlayerHistory.updateInput(ph, input)

  if (input) then
    ph.inputHistory[ph.tick] = ph.inputHistory[ph.tick] or {};
    Moat.Utils.copyInto(ph.inputHistory[ph.tick], input);
  end
  
end

function PlayerHistory.rebuild(ph, state, tick, moat)
  local ping = cs.client.getPing();
  
  local newTick = tick + math.ceil((ping/1000.0) / moat.Constants.TickInterval);
 
  local oldTick = ph.tick;
  ph.tick = tick;
  local oldHistory = ph.inputHistory;
  ph.inputHistory = List.new(tick);
  List.pushright(ph.inputHistory, nil);

  
  ph.state = {};
  Utils.copyInto(ph.state, state);
  
  
   for t = tick, newTick do
    
    local oldInput = oldHistory[oldTick - (newTick - t)];
    
    if (oldInput) then
      ph.inputHistory[ph.tick] = Utils.copyInto({}, oldInput);
    end
    
    PlayerHistory.advance(ph, moat);
    
  end
  
end

function PlayerHistory.advance(ph, moat)
  
  local inputHistory = ph.inputHistory;  

  moat:playerUpdate(ph.state, inputHistory[ph.tick]);
  moat:rehashEntity(ph.state);
  
  List.pushright(inputHistory, nil);
  ph.tick = ph.tick + 1;
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
    
    ---
  end
  
  function self:clientKeyPressed(key) end
  
  function self:clientKeyReleased(key) end
  
  function self:clientMousePressed() end
  
  function self:clientMouseMoved() end
  
  function self:getPlayerState()
  
    return PlayerHistory.getLastState(ph);
    
  end
  
  function self:clientTick(gameState)
    
  end
  
  function self:despawn(entity)
    entity.despawned = true;
  end
  
  --Client Tick
  function self:advanceGameState()
    PlayerHistory.advance(ph, self); 
    self:clientUpdate(self.gameState);
  end
  
  function self:setPlayerInput(input)  
    PlayerHistory.updateInput(ph, input);
  end
  
  local lastSyncPing = self.ping;
  
  function self:syncPlayer(player)
    local ping = cs.client.getPing();
  
    if (share.tick > gameState.tick or 
      math.abs(ping - lastSyncPing) > 20
    ) then
      print("rebuild", share.tick, gameState.tick);
      PlayerHistory.rebuild(ph, player, share.tick, self);
      gameState.tick = ph.tick;
      lastSyncPing = ping;
    else
      --print("no reb", ping, lastSyncPing);
    end
  end
  
  function self:syncEntity(entity)
    
    
    if (entity.uuid == cs.client.id and cs.client.id) then
        
        self:syncPlayer(entity);       
        self.gameState.entitiesByType[self.EntityTypes.Player][entity.uuid] = nil;
        self.gameState.entities[entity.uuid] = nil;
      
    else
      gameState.entities[entity.uuid] = gameState.entities[entity.uuid] or {};
      local localEntity = gameState.entities[entity.uuid];
      Utils.copyInto(localEntity, entity);
      self:rehashEntity(localEntity);
      gameState.entitiesByType[entity.type][entity.uuid] = localEntity;
      
    end
    
  end

  function self:unsyncEntityId(uuid) 
      local entity = gameState.entities[uuid];
      if (entity) then
        self:despawn(entity);
      end
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
    
  function self:clientDraw()
  
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

      gameState.space:add(entity, entity.x, entity.y, entity.w, entity.h);
      gameState.entitiesByType[entity.type][entity.uuid] = entity;
      
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
          local player = share.entities[id];
          if (home.playerHistory) then
          
            local clientInput = PlayerHistory.getInput(home.playerHistory, tick);
            self:playerUpdate(player, clientInput);
            self:rehashEntity(player);

            
          end -- if player history
      end -- each player
    end -- updateAllPlayers
    
    function self:advanceGameState() 
      self:updateAllPlayers();
      self:serverTick(self.gameState);
    end
    
    function self:serverTick()
      
    end
       
    function self:spawnNewPlayer(id)
      
      local x,y = self:newPlayerPosition();
      local width, height = 1, 1;
      
      self:spawn(self.EntityTypes.Player, 
        x, y, width, height, {uuid = id}
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
    print("ebt", value);
  end
 
  
  self.gameState = gameState;

end

function Moat:initCommon()
  
  local gameState = self.gameState;
  local space = gameState.space;
  
  function self:playerUpdate(player, input)
    
  end
  
  function self:destroy(entity)
      gameState.space:remove(entity);
      gameState.entitiesByType[entity.type][entity.uuid] = nil;
      gameState.entities[entity.uuid] = nil;
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
      self:despawn(self.gameState.entities[id]);
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

  function client.update(dt)
    self:update(dt);
  end

  function client.receive(msg)
    
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
    --print("Drawing");
    self:clientDraw();
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

Moat.Utils = Utils;

return Moat;