
local QuadCache = {};
local TileGfx = {};

TileGfx = {

  imgRes = 32,
  
  loadImg = function(path)
    
    local img = love.graphics.newImage(path);
    img:setWrap("repeat", "repeat");
    img:setFilter("nearest", "nearest");
    return img;
  
  end,
  
  getQuad = function(width, height)
    
    local key = width.."+"..height;
    
    if (not QuadCache[key]) then
      QuadCache[key] = love.graphics.newQuad(
        0,0, TileGfx.imgRes * width, TileGfx.imgRes * height, TileGfx.imgRes, TileGfx.imgRes
      );
    end
    
    return QuadCache[key];
  
  end,
  
  drawTiles = function(img, x, y, w, h, scale, flipx)
    
    love.graphics.setColor(1.0, 1.0, 1.0, 1.0);

    love.graphics.draw(img, TileGfx.getQuad(w, h),
        x, y, 0.0, scale * (flipx or 1.0), scale, 16, 16);
  
  end
}

return TileGfx