
local QuadCache = {};
local Sprite = {};

Sprite = {

  imgRes = 32,
  tileSizePx = 32,
  
  offsetPx = {x = 0, y = 0},
  cameraCenter = {x = 0, y = 0},
  
  images = {},
  
  loadImages = function(images)
    for k, v in pairs(images) do
      Sprite.images[k] = Sprite.loadImage(v)
    end
  end,
  
  loadImage = function(path, clampEdges)
    
    local img = love.graphics.newImage(path);
    
    if (not clampEdges) then
      img:setWrap("repeat", "repeat");
      img:setFilter("nearest", "nearest");
    end
    
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
  
  drawTiles = function(img, x, y, w, h, scaleX, scaleY)
    love.graphics.setColor(1.0, 1.0, 1.0, 1.0);

    love.graphics.draw(img, Sprite.getQuad(w, h),
        x, y, 0.0, scaleX, scaleY, Sprite.imgRes/2, Sprite.imgRes/2);
  end,
  
  pxToUnits = function(x,y)
    local ts = Sprite.tileSizePx;
    return (x - Sprite.offsetPx.x) / ts, (y - Sprite.offsetPx.y) / ts;
  end,
  
  
  scissorBounds = function(visibility)
    local x, y = Sprite.unitsToPx(-visibility, -visibility);
    local x2, y2 = Sprite.unitsToPx(visibility, visibility);
    love.graphics.setScissor(x, y, x2-x, y2-y);
  end,

  clearScissor = function()
    love.graphics.setScissor();
  end,
  
  unitsToPx = function(x, y)
    local ts = Sprite.tileSizePx;
    return x * ts + Sprite.offsetPx.x, y * ts + Sprite.offsetPx.y;
  end,
  
  drawEntity = function(entity, img, ox, oy)
    local scale = Sprite.tileSizePx / Sprite.imgRes;
    
    ox = ox or 0;
    oy = oy or 0;
    
    local x, y = Sprite.unitsToPx(ox + entity.x - Sprite.cameraCenter.x, oy + entity.y - Sprite.cameraCenter.y);   
    Sprite.drawTiles(img, x, y, entity.w, entity.h, scale * (entity.xflip or 1.0), scale);
  end
}

return Sprite