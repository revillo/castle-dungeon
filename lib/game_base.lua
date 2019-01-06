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


return function() return Class, GameController end