
local All = {}

function All:__index(v)
  return function(allSelf, ...)
    -- print("Calling on each object", v)
    for _, obj in ipairs(self.contents) do
      obj[v](obj, ...) -- throw away output
    end
    return allSelf
  end
end

function All.new(t)
  local self = {
    contents = t
  }

  setmetatable(self, All)

  return self
end


function A(t)
  return All.new(t)
end

return A;

