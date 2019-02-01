
local QuadCache = {};
local Sprite = {};

Sprite = {

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
        0,0, Sprite.imgRes * width, Sprite.imgRes * height, Sprite.imgRes, Sprite.imgRes
      );
    end
    
    return QuadCache[key];
  
  end,
  
  drawTiles = function(img, x, y, w, h, scale, flipx)
    
    love.graphics.setColor(1.0, 1.0, 1.0, 1.0);

    love.graphics.draw(img, Sprite.getQuad(w, h),
        x, y, 0.0, scale * (flipx or 1.0), scale, 16, 16);
  
  end
}

return Sprite