USE_CASTLE_CONFIG = true

if CASTLE_PREFETCH then
    
    if (CASTLE_SERVER) then
      CASTLE_PREFETCH({
        'cs.lua',
        'state.lua',
        'lib/shash.lua',
        'lib/list.lua',
        'lib/sprite',
        'lib/maze_gen',
        'moat.lua',
      })
    else
      CASTLE_PREFETCH({
        'cs.lua',
        'state.lua',
        'lib/shash.lua',
        'lib/list.lua',
        'lib/sprite.lua',
        'lib/maze_gen.lua',
        'moat.lua',
        'img/wall_top.png',
        'img/wall_front.png',
        'img/wall_shadow.png',
        'img/dirt.png',
        'img/deep_elf_high_priest.png',
        'img/conjure_ball_lightning.png',
        'img/skeleton_bat.png',
        'img/ogre_mage.png',
        'img/shining_eye.png',
        'img/gold_pile_16.png',
        'img/chest_2_open.png',
        'img/hippogriff_old.png',
        'img/ozocubus_refrigeration.png'      
      })
    end
       
end

require('dungeon_source')
