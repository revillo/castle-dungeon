local List = require("lib/list")
math.randomseed(os.time());

function FYShuffle( tInput )
  
    local tReturn = {}
    for i = #tInput, 1, -1 do
        local j = math.random(i)
        tInput[i], tInput[j] = tInput[j], tInput[i]
        table.insert(tReturn, tInput[i])
    end
    
    return tReturn
end

local mazegen = function(width, height)
  
  local rooms = {};
  
  local roomIdx = function(x, y)
    return y * 1e7 + x;
  end

  for rx = 1, width do
  for ry = 1, height do
    rooms[roomIdx(rx,ry)] = {x = rx, y = ry, doors = {}};
  end
  end
  
  local search = List.new();
  local seen = {};
  local doors = List.new();
  
  List.pushright(search, {1,1,nil,nil});

  while(List.length(search) > 0) do
    
    local room = List.popright(search);
    local x,y = room[1], room[2];
    local idx = roomIdx(x,y);
    
    if (not seen[idx]) then
    
      seen[idx] = 1;
      
      local prevIdx = room[4];
      if (prevIdx and rooms[prevIdx]) then
        rooms[prevIdx].doors[room[3]] = 1;
        rooms[idx].doors[(room[3] + 1) % 4 + 1] = 1;        
      end
      
      nrs = FYShuffle({{x+1, y, 1}, {x, y+1, 2}, {x-1, y, 3}, {x, y - 1, 4}});
    
      for i = 1, 4 do
        
        local nx, ny = nrs[i][1], nrs[i][2];
        
        nrs[i][4] = idx;
        
        if (nx < 1 or ny < 1 or nx > width or ny > height or seen[roomIdx(nx,ny)]) then
        
          --continue
          
        else
      
          List.pushright(search, nrs[i]);
          
        end
        
      end -- each neighbor
    end -- not seen already
  end -- while searching
     
  return rooms;
end



return mazegen;