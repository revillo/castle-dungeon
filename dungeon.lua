USE_CASTLE_CONFIG = true;

if CASTLE_SERVER then
  require('dungeon_server.lua')
else
  require('dungeon_client.lua')
end