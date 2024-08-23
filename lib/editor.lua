local Editor = {}
Editor.__index = Editor

function Editor.new(options)
  local options = options or {}
  local self = {
    content = "",
    cursor = 1,
    x_offset = options.x_offset or 0,
    y_offset = options.y_offset or 0,
    line_y_adjustment = options.line_y_adjustment or 0,
    max_x = options.max_x or 127,
    max_y = options.max_y or 62
  }
  setmetatable(self, Editor)
  return self
end

function Editor:redraw()
  -- This allows us to have a bottom-aligned editor
  local height = self:draw_wrapped_content(
    self.x_offset,
    self.y_offset,
    false)
  self:draw_wrapped_content(
    self.x_offset,
    self.max_y - self.line_y_adjustment - height,
    true)
  return height
end

local _cached_text_width = {}
function Editor:text_width(text)
  if seamstress then
    if _cached_text_width[text] then
      return _cached_text_width[text]
    end
    local width, height = screen.get_text_size(text)
    _cached_text_width[text] = width
    return width
  else
    return screen.text_extents(text)
  end
end

function Editor:draw_wrapped_content(start_x, start_y, do_draw)
  -- Draw characters one at a time based on width
  -- And then reverse the currect character if it is where the cursor is
  -- screen.text draws from the lower-left corner for some weird reason, that's
  -- weird. I guess we'll call this method twice, first to get the height and the second to draw the content
  local content = self.content .. " " -- Add a space so we can see the cursor
  local x = start_x
  local y = start_y
  for i = 1, #content do
    local char = content:sub(i, i)
    local char_width = self:text_width(char)
    if char_width == 0 then
      char_width = 4 -- When in doubt
    end
    if x + char_width > self.max_x  or char == "\n" then
      x = self.x_offset
      y = y + 8
    end
    if do_draw and char ~= "\n" then
      screen.move(x, y)
      if i == self.cursor then
        -- screen.level(15)
        -- screen.text(char)
        -- self:invert_rect(x, y, char_width, 9)
        screen.level(15)
        self:invert_rect(x, y, char_width, 9)
        screen.level(0)
        screen.text(char)
      else
        screen.level(15)
        screen.text(char)
      end
    end
    if char ~= "\n" then
      x = x + char_width + 1
    end
  end
  return y
end

function Editor:invert_rect(x, y, width, height)
  -- screen.move(x, y)
  -- screen.rect_fill(width, height)
  local rect = screen.peek(x, y, width, height)
  local out = {}
  for i = 1, #rect do
    out[i] = string.char(15 - string.byte(rect, i))
  end
  screen.poke(x, y, width, height, table.concat(out))
end


function Editor:insert(char)
  self.content = self.content:sub(1, self.cursor - 1) .. char .. self.content:sub(self.cursor)
  -- self.content = self.content .. char
  self.cursor = self.cursor + 1
end

function Editor:backspace()
  if self.cursor > 1 then
    self.content = self.content:sub(1, self.cursor - 2) .. self.content:sub(self.cursor)
    self.cursor = self.cursor - 1
  end
end

function Editor:delete()
  if self.cursor <= #self.content then
    self.content = self.content:sub(1, self.cursor - 1) .. self.content:sub(self.cursor + 1)
  end
end

function Editor:move_cursor_left()
  self.cursor = math.max(1, self.cursor - 1)
end

function Editor:move_cursor_right()
  self.cursor = math.min(#self.content + 1, self.cursor + 1)
end

function Editor:move_cursor_to_start()
  self.cursor = 1
end

function Editor:move_cursor_to_end()
  self.cursor = #self.content + 1
end

function Editor:clear()
  self.content = ""
  self.cursor = 1
end

function Editor:set_content(new_content)
  self.content = new_content
  self.cursor = #new_content + 1
end

return Editor

