local Grid = {}
Grid.__index = Grid

function Grid.new(key_handler)
  local self = {
    device = grid.connect(),
    data = {}
  }

  self.device.key = key_handler

  -- Initialize data based on grid cols/rows
  for x = 1, 16 do
    self.data[x] = {}
    for y = 1, 8 do
      self.data[x][y] = 0
    end
  end

  setmetatable(self, Grid)
  return self
end

function Grid:refresh()
  self.device:refresh()
end

function Grid:led(x, y, brightness)
  self.device:led(x, y, brightness)
  self.data[x] = self.data[x] or {}
  self.data[x][y] = brightness
end

function Grid:all(brightness)
  self.device:all(brightness)
  self.data = {}
  for x = 1, 16 do
    self.data[x] = {}
    for y = 1, 8 do
      self.data[x][y] = 0
    end
  end
end

return Grid
