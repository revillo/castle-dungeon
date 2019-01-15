local Class = {}

function Class:new(o)
    o = o or {};
    
    setmetatable(o, self);
    self.__index = self;
    
    if (o.init) then
        o:init();
    end
    
    return o;
end

local GameController = Class:new();

function GameController:keypressed(k) end
function GameController:keyreleased(k) end
function GameController:update(dt) end
function GameController:mousemoved(x,y) end
function GameController:mousepressed(x,y) end
function GameController:receive(msg) end
function GameController:changed(diff) end

local State = {  
  controller = GameController:new(),

}

local Game = {

   keyboard = {
    w = 0,
    a = 0,
    s = 0,
    d = 0
  }
  
}

function Game.setController(gameController)

  State.controller = gameController;
  
end

function Game.run(client)
    
  function client.changed(diff)

    State.controller:changed(diff);

  end

  function client.load()
    
  end

  function client.receive(msg)
    
    State.controller:receive(msg);

  end

  function client.keyreleased(k)
    
    Game.keyboard[k] = 0;
    
  end

  function client.mousemoved(x, y)

    State.controller:mousemoved(x,y);

  end

  function client.mousepressed(x,y)

    State.controller:mousepressed(x,y);
   
  end

  function client.keypressed(k)
    
    Game.keyboard[k] = 1;
    State.controller:keypressed(k);

  end

  function client.draw()

    State.controller:draw()

  end

  function client.resize(w, h)
    
    State.controller:resize(w, h);

  end

  function client.update(dt)
   
     State.controller:update(dt);
    
  end
  

end




return function() return Class, GameController, Game end