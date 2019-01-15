--castle://localhost:4000/dungeon.lua

USE_CASTLE_CONFIG = true;
local foo = require

if CASTLE_SERVER then
  foo('dungeon_server.lua')
else
  foo('dungeon_client.lua')
end	