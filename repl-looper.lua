-- repl-looper v0.5.1
-- Record/play code loops!
--
-- llllllll.co/t/repl-looper
--
-- Use with keyboard+grid
--
--     ███████████
--     █         █
--    ███   █
--     █     █   █
--          █   ███
--     █         █
--     ███████████
--

-- Add repl-looper lib dir in to load .so files like cjson.so
if not string.find(package.cpath, "/home/we/dust/code/repl-looper/lib/", 1, true) then
  package.cpath = package.cpath .. ";/home/we/dust/code/repl-looper/lib/?.so"
  package.path = package.path .. ";/home/we/dust/code/repl-looper/lib/?.lua"
end

JSON = require("cjson")
Deque = require("container.deque")
UI = require("ui")
comp = require("completion")

-- Locally augmented libraries
Lattice = require("repl-looper/lib/lattice") -- system one is broken
musicutil = include("repl-looper/lib/musicutil_extended")
sequins = include("repl-looper/lib/sequins_extended")

-- Local helpers
local helper = include("repl-looper/lib/helper")
ls = helper.ls
eval = helper.eval
keys = helper.tabkeys

-- ALL helper
-- Use like all{a,b,c}:stop()
-- Which is equivalent to a:stop();b:stop();c:stop()
all = include("repl-looper/lib/all")

-- Enable/Disable global debugging
function bug(...)
  if true then
    print(...)
  end
end

---------------------------------------------------------------------
-- Grid Wrapper -----------------------------------------------------
---------------------------------------------------------------------

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
  redraw()
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

---------------------------------------------------------------------
-- Editor -----------------------------------------------------------
---------------------------------------------------------------------

local Editor = {}
Editor.__index = Editor

function Editor.new()
  local self = {
    content = "",
    draw_at_x = 0,
    draw_at_y = 62,
    cursor = 1
  }
  setmetatable(self, Editor)
  return self
end

function Editor:redraw()
  -- This allows us to have a bottom-aligned editor
  local height = self:draw_wrapped_content(0, 0, false)
  self:draw_wrapped_content(0, self.draw_at_y - height, true)
  return height
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
    local char_width = screen.text_extents(char)
    if char_width == 0 then
      char_width = 4
    end
    if x + char_width > 127 then
      x = 0
      y = y + 8
    end
    if do_draw then
      screen.move(x, y)
      if i == self.cursor then
        screen.level(15)
        screen.text(char)
        self:invert_rect(x, y-7, char_width, 9)
      else
        screen.level(15)
        screen.text(char)
      end
    end
    x = x + char_width + 1
  end
  return y
end

function Editor:invert_rect(x, y, width, height)
  local rect = screen.peek(x, y, width, height)
  local out = {}
  for i = 1, #rect do
    out[i] = string.char(15 - string.byte(rect, i))
  end
  screen.poke(x, y, width, height, table.concat(out))
end

function Editor:wrap_text(text, max_len)
  local lines = {}
  local remaining_text = text
  local current_line = ""
  local character_number = 1
  while #remaining_text > 0 do
    local next_character = remaining_text:sub(1, 1)
    local current_line_size = screen.text_extents(current_line .. next_character)
    if current_line_size > max_len then
      table.insert(lines, current_line)
      current_line = ""
    end
    current_line = current_line .. next_character
    remaining_text = remaining_text:sub(2)
    character_number = character_number + 1
  end
  table.insert(lines, current_line)
  return lines
end

function Editor:insert(char)
  self.content = self.content:sub(1, self.cursor - 1) .. char .. self.content:sub(self.cursor)
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

-- Single global editor for all to use
editor = Editor.new()

---------------------------------------------------------------------
-- Loop-related objects ---------------------------------------------
---------------------------------------------------------------------

local Event = {}
Event.__index = Event
Event.last_id = 0

function Event.new(init)
  local self = init or {
    command = "",
    relative_time = 0,
    pulse_offset = 0,
    step = 0
  }
  setmetatable(self, Event)

  Event.last_id = Event.last_id + 1
  self.id = Event.last_id

  return self
end

function Event:lua()
  return {
    -- pulse = self.pulse, -- The absolute time
    -- pulse_offset = self.pulse_offset, -- loop relative time
    -- phase = self.sprocket and self.sprocket.phase, -- current countdown in pulses
    step = self.step,
    command = self.command
  }
end

current_context_loop_id = 0
loop = nil -- shortcut for "current eval loop"
function Event:eval(context_loop_id, from_playing_loop)
  current_context_loop_id = context_loop_id
  loop = loops[context_loop_id]
  -- print("Set context loop id to", current_context_loop_id)
  local result = live_event(self.command, from_playing_loop)
  -- print("Reset context loop id to 0")
  current_context_loop_id = 0
  return result
end

function Event:destroy()
  self.sprocket:destroy()
end

function Event:clone()
  return Event.new({
    pulse = self.pulse,
    command = self.command
  })
end

---------------------------------------

Loop = {}
Loop.__index = Loop
Loop.last_id = 0

function Loop.new(init)
  local self = init or {
    events = {},
    off_events = {},
    loop_length_qn = 16,
    step = 1,
    current_substep = 1.0,
    duration = 10212,
    lattice = Lattice:new{},
    record_feedback = false,
    auto_quantize = false,
    send_feedback = false,
    stop_next = false,
    mods = {
      amp = 1,
      ampLag = 0,
      pan = 0
    },
    selected = false,
    mode = "stop"
  }

  setmetatable(self, Loop)

  Loop.last_id = Loop.last_id + 1
  self.id = Loop.last_id

  -- Register with global list of loops
  loops[self.id] = self

  -- Kinda evil shortcut!
  -- for loops 1..8 make global var 'a' .. 'h'
  if self.id < 9 then
    self.loop_letter = string.char(string.byte("a") + self.id - 1)
    _G[self.loop_letter] = self
  end

  -- Basically a quarter-note metronome
  -- This is used to update the grid and client
  self.status_sprocket = self.status_sprocket or self.lattice:new_sprocket {
    action = function(t)
      self:send_status(t)
    end,
    division = 1/4
  }

  return self
end

function Loop:get_current_step(t)
  t = t or self.lattice.transport
  return (math.floor(t / self.lattice.ppqn) % self.loop_length_qn) + 1
end

function Loop:get_current_substep(t)
  t = t or self.lattice.transport
  return ((t / self.lattice.ppqn) % self.loop_length_qn) + 1
end

function Loop:select()
  self.selected = true
  self:draw_grid_row()
end

function Loop:deselect()
  self.selected = false
  self:draw_grid_row()
end

function Loop:send_status(t)
  t = t or 0

  clock.sleep(0.001) -- Allow other things to run

  self.step = self:get_current_step(t)
  self:draw_grid_row()

  messageFromServer {
    action = "playback_step",
    step = self.current_step,
    stepCount = self.loop_length_qn,
    loop_id = self.id,
    command = self.recent_command,
    mode = self.mode,
    loop_letter = self.loop_letter
  }
end

function Loop:qn_per_ms()
  return clock.get_tempo() / 60 / 1000
end

function Loop:pulse_per_ms()
  return self:qn_per_ms() * self.lattice.ppqn
end

function Loop:pulse_per_measure()
  return self.lattice.ppqn * 4
end

function Loop:loop_length_measure()
  return self.loop_length_qn / 4
end

function Loop:loop_length_pulse()
  return self.loop_length_qn * self.lattice.ppqn
end

function Loop:setLength(qn)
  self.loop_length_qn = qn
  self:update_lattice()
end

function Loop:update_event(event, off_event)
  event.pulse_offset = event.pulse % self:loop_length_pulse()
  event.step = event.pulse_offset / self.lattice.ppqn + 1

  if off_event then
    -- Don't actually schedule grid-key-off events
    return
  end

  if self.auto_quantize then
    event.step = math.floor(event.step + 0.5) -- nearest whole step
    event.pulse_offset = (event.step - 1) * self.lattice.ppqn
  end

  local action = function(t)
    self.recent_command = event.command

    -- Update current step (fractional) and see if we should stop
    local substep = self:get_current_substep(t)
    if self.stop_next and self.current_substep > substep then
      self:stop()
      self:setStep(1) -- Reset back to the top of the loop (we might already be there a little)
    else
      -- We don't need to stop, so go ahead and execute the command!
      event:eval(self.id, not self.send_feedback) -- `true` to indicate we are a playback event
    end

    self.current_substep = substep
  end

  event.sprocket = event.sprocket or self.lattice:new_sprocket{}

  event.sprocket:set_action(action)
  event.sprocket:set_division(self:loop_length_measure()) -- division is in measures

  -- Forcing the phase is what sets the actual offset for this sprocket based on
  -- the current transport (play position). The phase is a count-down until the
  -- event is fired
  local loop_phase = self.lattice.transport % self:loop_length_pulse()
  local phase_distance = (event.pulse_offset - loop_phase) % self:loop_length_pulse()
  event.sprocket.phase = self:loop_length_pulse() - phase_distance
end

-- Update all events; this is handy for re-working the loop length
function Loop:update_lattice()
  for _, event in ipairs(self.events) do
    self:update_event(event)
  end
end

function Loop:setStep(step)
  step = step or 1
  step = step - 1
  step = step % self.loop_length_qn
  self.lattice.transport = step * self.lattice.ppqn
  self.step = self:get_current_step()
  self:update_lattice()
  self:draw_grid_row()
end

function Loop:remove_event(event_to_remove)
  -- Go backwards so that when we remove nothing weird happens
  for i = #self.events, 1, -1 do
    local event = self.events[i]
    if event == event_to_remove then
      event.sprocket:destroy()
      event.sprocket = nil
      table.remove(self.events, i)
    end
  end
end

function Loop:add_event(event)
  self:update_event(event)
  table.insert(self.events, event)
  return event
end

-- Let's get some GRID!!
function Loop:draw_grid_row()
  clear_grid_row(self.id)

  local row = self:to_grid_row()
  for n = 1, 16 do

    -- Highlight currently selected row
    local val = row[n] or 0
    if self.selected then
      val = util.clamp(val + 2, 0, 15)
    end

    -- Mod-16 so we can show long sequences overlaid; maybe confusing
    grid_device:led((((n-1) % 16)+1), self.id, val)
  end

  grid_device:refresh()
end

function Loop:lua()
  local output = {}
  output.step = self.step
  output.loop_length_qn = self.loop_length_qn
  output.transport = self.lattice.transport
  output.stop_next = self.stop_next
  output.mods = self.mods
  output.events = {}
  for _, event in ipairs(self.events) do
    table.insert(output.events, event:lua())
  end
  output.off_events = {}
  for _, event in ipairs(self.off_events) do
    table.insert(output.off_events, event:lua())
  end
  return output
end

function Loop:show()
  return self:lua()
end

function Loop:to_grid_row()
  local row = {}
  -- Basically zoom-out for longer loops, but still in increments of 16
  -- This is might be weird for non-powers-of-2
  local div = math.floor((self.loop_length_qn - 1) / 16) + 1

  -- Highlight the current step even if we're not
  -- on an event; all the rest are dark by default
  for n = 1, self.loop_length_qn do
    if math.ceil(n/div) == math.ceil(self.step/div) then
      row[math.ceil(n/div)] = 10
    else
      row[math.ceil(n/div)] = 0
    end
  end

  -- Entries with events glow. Event+current glow a lot
  for _, event in ipairs(self.events) do
    local visual_step = math.ceil(math.floor(event.step)/div)
    if visual_step == math.ceil(self.step/div) then
      row[visual_step] = 15
    else
      row[visual_step] = 5
    end
  end

  return row
end

s = nil

function Loop:play_events_at_step(step)
  for _, event in ipairs(self.events) do
    local event_step = math.floor(event.step)
    if event_step == step then
      s = event_step
      event:eval(self.id)
    end
  end
end

function Loop:play_off_events_at_step(step)
  for _, event in ipairs(self.off_events) do
    local event_step = math.floor(event.step)
    if event_step == step then
      s = event_step
      event:eval(self.id)
    end
  end
end

function Loop:commands_at_step(step)
  local commands = {}
  for _, event in ipairs(self.events) do
    local event_step = math.floor(event.step)
    if event_step == step then
      table.insert(commands, event.command)
    end
  end
  return commands
end

function Loop:toggle_commands_at_step(step, commands)
  print("toggle_commands_at_step: ", step)
  local found_commands = false
  for i = #self.events, 1, -1 do
    local event = self.events[i]
    local event_step = math.floor(event.step)
    if event_step == step then
      if self.events[i].sprocket then
        self.events[i].sprocket:destroy()
      end
      table.remove(self.events, i)
      found_commands = true
    end
  end

  if not found_commands then
    for _, command in ipairs(commands) do
      local new_event = Event.new({
        command = command,
        pulse = step * self.lattice.ppqn
      })

      table.insert(self.events, new_event)

      self:update_event(new_event)
    end
  end
end

function Loop:play(startStep)
  self:yesLoop()
  if startStep then
    self:setStep(startStep)
  end
  self.mode = "play"
  self.lattice:start()
end

function Loop:stop()
  if self.mode == "recording" then
    self.mode = "stop_recording"
    self:draw_grid_row()
  elseif self.mode == "sample_recording" then
    self.mode = "stop_recording"
    stop_record_sample()
    self:draw_grid_row()
  else
    self.mode = "stop"
    self.lattice:stop()
  end
end

function Loop:noLoop()
  self.stop_next = true
end

function Loop:once()
  self:noLoop()
  self:play(1)
end

function Loop:yesLoop()
  self.stop_next = false
end

function Loop:rec()
  self.mode = "start_recording"
  self.lattice:start()
end

-- Record to one step and then go to the next
-- This is good for thoughtful recording and macro recording
function Loop:stepRec()
  self.mode = "start_recording_step"
end

function Loop:nextStep()
  self:setStep(self:get_current_step() + 1)
end

function Loop:prevStep()
  self:setStep(self:get_current_step() - 1)
end

function Loop:sampleRec()
  self.mode = "sample_recording"
  select_nth_loop(self.id)
  start_record_sample()
end

function Loop:add_event_command(cmd)
  local event = Event.new({
    pulse = self.lattice.transport,
    command = cmd
  })
  self:update_event(event)
  table.insert(self.events, event)
  return event
end

-- Loop Manipulation
--------------------

-- Do a one-time permanent quantize
function Loop:quantize()
  for _, event in ipairs(self.events) do
    event.step = math.floor(event.step + 0.5) -- nearest whole step

    -- Update the absolute-time pulse
    event.pulse = (event.step - 1) * self.lattice.ppqn
  end

  self:update_lattice()
end

function Loop:align(other_loop)
  local substep_diff = self:get_current_substep() - other_loop:get_current_substep()
  local transport_diff = substep_diff * self.lattice.ppqn
  self:shift(-1 * transport_diff)
end

function Loop:shift(transport_diff)
  self.lattice.transport = self.lattice.transport + transport_diff

  for _, event in ipairs(self.events) do
    event.pulse = event.pulse - transport_diff
  end

  self.step = self:get_current_step()
  self:update_lattice()
  self:draw_grid_row()
end

-- Copy all of the events to another loop
function Loop:clone(other_loop)
  other_loop:clear()
  for _, event in ipairs(self.events) do
    other_loop:add_event(event:clone())
  end
  self:draw_grid_row()
end

-- a:gen("CH") puts the "CH" function on every step
-- a:gen("CH", 1/2) puts the "CH" on every half step
-- a:gen("CH", 2, 2) puts the "CH" on every other step starting with step 2
-- a:gen("CH", { 1, 3, 4.5 }) puts the "CH" on the given steps (even fractional)
-- a:gen({"BD","SD","CP"}) puts each one on each step
-- a:gen("molly:note(`50+m`)", "molly:offNote(`50+m`)") off notes during grid-play
function Loop:gen(code_string, modification, offset)
  if type(code_string) == "table" then
    for n, cmd in ipairs(code_string) do
      local event = Event.new({
        pulse = (n - 1) * self.lattice.ppqn,
        command = cmd
      })
      self:update_event(event)
      table.insert(self.events, event)
    end
  elseif type(modification) == "table" then
    for _, n in ipairs(modification) do
      local expanded_code_string =
        string.gsub(
          code_string,
          "`([^`]+)`",
          function (snippet)
            local injected_snippet = "local n = dynamic('n'); local m = n - 1; return " .. snippet
            return eval(injected_snippet)
          end
        )
      local event = Event.new({
        pulse = (n - 1) * self.lattice.ppqn,
        command = expanded_code_string
      })
      self:update_event(event)
      table.insert(self.events, event)
    end
  elseif type(modification) == "number" then
    offset = offset or 1
    for step = 1, (self.loop_length_qn / modification) do
      local n = (step - 1) * modification + offset
      local expanded_code_string =
        string.gsub(
          code_string,
          "`([^`]+)`",
          function (snippet)
            local injected_snippet = "local step = dynamic('step'); local n = dynamic('n'); local m = n - 1; return " .. snippet
            return eval(injected_snippet)
          end
        )
      local event = Event.new({
        pulse = (n - 1) * self.lattice.ppqn,
        command = expanded_code_string
      })
      self:update_event(event)
      table.insert(self.events, event)
    end
  else
    for n = 1, self.loop_length_qn do
      local expanded_code_string =
        string.gsub(
          code_string,
          "`([^`]+)`",
          function (snippet)
            local injected_snippet = "local n = dynamic('n'); local m = n - 1; return " .. snippet
            return eval(injected_snippet)
          end
        )
      local event = Event.new({
        pulse = (n - 1) * self.lattice.ppqn,
        command = expanded_code_string
      })
      self:update_event(event)
      table.insert(self.events, event)

      -- Look for key-off modification
      if modification then
        local expanded_code_string =
          string.gsub(
            modification,
            "`([^`]+)`",
            function (snippet)
              local injected_snippet = "local n = dynamic('n'); local m = n - 1; return " .. snippet
              return eval(injected_snippet)
            end
          )
        local event = Event.new({
          pulse = (n - 1) * self.lattice.ppqn,
          command = expanded_code_string
        })
        self:update_event(event, true)
        table.insert(self.off_events, event)
      end

    end
  end
  self:draw_grid_row()
end

-- Shorthand to put some code at a specific step
function Loop:put(step, code_string)
  self:gen(code_string, { step })
end

function Loop:slice(sample, step_offset, step_count, reverse)
  step_offset = step_offset or 1
  bug("Current tempo", clock.get_tempo())
  bug("Current qn_per_ms", self:qn_per_ms())
  width = math.ceil(48000 / (self:qn_per_ms() * 1000)) -- 29090
  bug("Slice width", width)

  -- We'll name this like ls1 ls2 ls3 etc
  -- like "loop_sample_1"
  -- Then we can still use it by-name
  local sample_name = "ls" .. self.id
  _G[sample_name] = sample

  local frame_offset = (step_offset - 1) * width
  local slice_start = width .. "* m + " .. frame_offset
  -- local slice_end = width .. "* n + " .. (frame_offset + 10)
  local slice_end = width .. "* n + " .. (frame_offset + 1000)

  if reverse then
    local num_frames = sample:info().num_frames
    slice_start = num_frames .. " - (" .. slice_start .. ")"
    slice_end = num_frames .. " - (" .. slice_end .. ")"
  end

  -- If this is less than a whole loop, cut the loop length
  step_count = step_count or math.ceil((sample:info().num_frames - frame_offset) / width)
  self:setLength(step_count)
  bug("slice step_count", step_count)

  self:gen(sample_name .. ":play(`" .. slice_start .. "`, `" .. slice_end .. "`)")
  bug("slice gen", sample_name .. ":play(`" .. slice_start .. "`, `" .. slice_end .. "`)")

  -- self:gen(
  --      sample_name .. ":startFrame(`" .. slice_start .. "`);"
  --   .. sample_name .. ":loopStartFrame(`" .. slice_start .. "`);"
  --   .. sample_name .. ":loopEndFrame(`" .. slice_end .. "`);"
  --   .. sample_name .. ":endFrame(`" .. slice_end .. "`);"
  --   .. sample_name .. ":play()"
  -- )
end

function Loop:fill(sample, step_count)
  local step_count = step_count or 16 -- quarter notes
  local frame_count = sample:info().num_frames
  bug("Fill frame_count", frame_count)
  local length_seconds = frame_count / 48000 -- 48k sample rate
  local bpm = step_count / length_seconds * 60

  bug("Fill set BPM", bpm)
  params:set("clock_tempo", bpm)

  -- Run other callbacks
  clock.sleep(0.1)

  self:slice(sample)
end

function Loop:clear()
  for _, event in ipairs(self.events) do
    event:destroy()
  end
  self.events = {}
  self.off_events = {}
  self:draw_grid_row()
end

function Loop:merge(other_loop)

  print "Aligning loops"
  other_loop:align(self)
  -- clock.sleep(0.001)

  for _, event in ipairs(other_loop.events) do
    self:add_event(event:clone())
  end
  other_loop:clear()
  other_loop:stop()
  self:draw_grid_row()
end

function Loop:split(other_loop, base_command)
  if #self.events < 2 then
    return
  end

  clock.run(function()

  print "Gathering all events"
  local events = {}
  for _, event in ipairs(self.events) do
    table.insert(events, event:clone())
    clock.sleep(0.001)
  end

  -- Do we need to stop? Eh
  -- print "Stopping both loops"
  -- self:stop()
  -- other_loop:stop()

  print "Clearing both loops"
  self:clear()
  other_loop:clear()

  print "Copying settings"
  other_loop.loop_length_qn = self.loop_length_qn
  other_loop.lattice.transport = self.lattice.transport
  other_loop.step = self.step

  print "Calculating event distances"
  base_command = base_command or events[1].command
  local distances = {}
  local total_dist = 0
  for _, event in ipairs(events) do
    local dist = helper.leven(base_command, event.command)
    total_dist = total_dist + dist

    -- for debugging and to minimize sort calcs
    distances[event.command] = dist
  end

  print "Sorting by distance"
  table.sort(events, function(a, b)
    local a_dist = distances[a.command]
    local b_dist = distances[b.command]
    return a_dist < b_dist
  end)

  local mean_dist = total_dist / #events

  print "Adding events back"
  for _, event in ipairs(events) do
    local event_dist = distances[event.command]
    if event_dist <= mean_dist then
      self:add_event(event)
    else
      other_loop:add_event(event)
    end
    clock.sleep(0.001)
  end

  print "Redrawing grid"
  self:draw_grid_row()
  other_loop:draw_grid_row()

  if self.mode == "play" then
    print "We are playing so split should play too"
    other_loop:play()
  end

  print "DONE!"
  -- return {
  --   mean_dist = mean_dist,
  --   distances = distances
  -- }
  end)
end

-- Loops as tracks

function Loop:updateTrack()
  engine.trackMod(
    self.id,
    self.mods.amp,
    self.mods.ampLag,
    self.mods.pan
  )
end

function Loop:amp(amp, ampLag)
  self.mods.ampLag = ampLag or 0
  self.mods.amp = amp
  self:updateTrack()
end

function Loop:pan(pan)
  self.mods.pan = pan
  self:updateTrack()
end

---------------------------------------
-- General controls across all loops --
---------------------------------------

loops = {}
samples = {}

function clear_grid_row(row)
  for n = 1, 16 do
    grid_device:led(n, row, 0)
  end
end

grid_mode = "one-shot"
local grid_data = {}

function handle_grid_key(col, row, state)
  local loop_id = row
  local step = col
  local loop = loops[loop_id]

  if state == 0 then
    loop:play_off_events_at_step(col)
  else
    if grid_mode == "one-shot" then
      loop:play_events_at_step(col)
    elseif grid_mode == "sequence" then
      if not grid_data.commands then
        grid_data.commands = loop:commands_at_step(step)
        loop:draw_grid_row()
      else
        loop:toggle_commands_at_step(step, grid_data.commands)
        loop:draw_grid_row()
      end
    end
  end
end

local recent_command = ""
local history_select = nil

-- Modified redraw ScrollingList
-- This version doesn't show blanks at the top/bottom
function UI.ScrollingList:redraw()
  local num_entries = #self.entries
  -- Changed to `num_entries - 4` so we get the whole view
  local scroll_offset = self.index - 1 - math.max(self.index - (num_entries - 4), 0)
  scroll_offset = scroll_offset - util.linlin(num_entries - self.num_above_selected, num_entries, self.num_above_selected, 0, self.index - 1) -- For end of list

  for i = 1, self.num_visible do
    if self.active and self.index == i + scroll_offset then screen.level(15)
    else screen.level(3) end
    screen.move(self.x, self.y + 5 + (i - 1) * 11)
    local entry = self.entries[i + scroll_offset] or ""
    if self.text_align == "center" then
      screen.text_center(entry)
    elseif self.text_align == "right" then
      screen.text_right(entry)
    else
      screen.text(entry)
    end
  end
  screen.fill()
end

function draw_logo(x, y)
  screen.move(x, y)

  -- Top edge and right hook
  screen.line_rel(9, 0)
  screen.line_rel(0, 3)

  -- bottom-right arrow
  screen.move_rel(0, 2)
  screen.line_rel(0, 5)
  screen.move_rel(1, -3)
  screen.line_rel(-3, 0)
  screen.move_rel(2, 3)

  -- bottom edge and left hook
  screen.line_rel(-9, 0)
  screen.line_rel(0, -4)

  -- top left arrow
  screen.move_rel(0, -2)
  screen.line_rel(0, -5)
  screen.move_rel(-2, 4)
  screen.line_rel(3, 0)

  -- prompt
  screen.move_rel(2, -1)
  screen.line_rel(3, 3)
  screen.move_rel(-1, 0)
  screen.line_rel(-2, 2)

  screen.stroke()
end

function draw_mini_grid_mirror(x, y)
  local scale = 1
  screen.move(x, y)

  for col = 1, 16 do
    for row = 1, 8 do
      local val = grid_device.data[col][row]
      if val == 0 then
        val = 1
      end
      screen.level(val)
      screen.rect(x + (col - 1) * scale, y + (row - 1) * scale, scale, scale)
      screen.fill()
    end
  end
end

function redraw()

  screen.ping()
  screen.clear()

  local editor_height = editor:redraw()

  -- Nice horizontal line between history and prompt
  local divider_y = 64 - editor_height - 10
  screen.level(2)
  screen.move(0, divider_y)
  screen.line_width(1)
  screen.line(128, divider_y)
  screen.stroke()

  local history_line_height = math.floor((divider_y - 2) / 9)
  if history_line_height > 0 then
    local history_viz = {}
    for i, entry in result_history:ipairs() do
      history_viz[i] = entry.input
      if entry.output ~= "null" then
        history_viz[i] = history_viz[i] .. " → " .. entry.output
      end
    end

    screen.level(15)
    local lst = UI.ScrollingList.new(0, 0, (history_select or #history_viz), history_viz)
    if not history_select then
      lst.active = false
    end
    lst.num_above_selected = 0
    lst.num_visible = history_line_height
    lst:redraw()
  end

  -- Informational / cool displays
  screen.level(15)
  -- draw_logo(118, 1)
  draw_mini_grid_mirror(112, 1)

  screen.update()
end

function keyboard.char(character)
  history_select = nil
  editor:insert(character)
  redraw()
end

saved_content = ""

function keyboard.code(code, value)
  -- The grid logo is fun, but let's hide it once we have a keypress
  if showing_grid_logo then
    showing_grid_logo = false
    grid_device:all(0)
    grid_device:refresh()
  end

  if value == 1 or value == 2 then -- 1 is down, 2 is held, 0 is release
    print("keyboard code and value", code, value)

    -- History selection
    if code == "UP" then
      if not history_select then
        saved_content = editor.content
        history_select = result_history:count()
      else
        history_select = history_select - 1
        if history_select == 0 then
          history_select = nil
          editor:set_content(saved_content)
        end
      end
      if history_select then
        editor:set_content(result_history:peek(history_select).input)
      end
    elseif code == "DOWN" then
      if not history_select then
        saved_content = editor.content
        history_select = 1
      else
        history_select = history_select + 1
        if history_select > result_history:count() then
          history_select = nil
          editor:set_content(saved_content)
        end
      end
      if history_select then
        editor:set_content(result_history:peek(history_select).input)
      end
    else
      history_select = nil
      saved_content = ""
    end

    if code == "BACKSPACE" then
      editor:backspace()
    elseif code == "DELETE" then
      editor:delete()
    elseif code == "LEFT" then
      editor:move_cursor_left()
    elseif code == "RIGHT" then
      editor:move_cursor_right()
    elseif code == "HOME" then
      editor:move_cursor_to_start()
    elseif code == "END" then
      editor:move_cursor_to_end()
    elseif code == "ENTER" then
      if editor.content == "" then
        -- If there is no new input, send the most recent history entry
        editor:set_content(result_history:peek_back().input)
      end
      client_live_event(editor.content)
      editor:clear()
    elseif code == "TAB" then
      local comps = comp.complete(editor.content)
      editor:set_content(helper.longestPrefix(comps))
      if #comps > 1 then
        for i, v in ipairs(comps) do
          result_history:push_back({
            input = v,
            output = "..."
          })
        end
      end
    end
    redraw()
  end
end

selected_loop = 1
function select_next_loop()
  loops[selected_loop]:deselect()
  selected_loop = (selected_loop % #loops) + 1
  loops[selected_loop]:select()
end

function select_prev_loop()
  loops[selected_loop]:deselect()
  selected_loop = ((selected_loop - 2) % #loops) + 1
  loops[selected_loop]:select()
end

function select_nth_loop(n)
  loops[selected_loop]:deselect()
  selected_loop = ((n - 1) % #loops) + 1
  loops[selected_loop]:select()
end

recording_start = 0
recording_start_transport = 0

function start_record_sample(sync_to_loop)
  audio.level_adc_cut(1)
  softcut.buffer_clear()
  softcut.enable(1,1)
  softcut.buffer(1,1)
  softcut.level(1,1.0)
  softcut.loop(1,0)
  softcut.loop_start(1,0)
  softcut.loop_end(1,300)
  softcut.position(1,0)
  softcut.rate(1,1.0)

  -- set input rec level: input channel, voice, level
  softcut.level_input_cut(1,1,1.0)
  -- softcut.level_input_cut(2,1,1.0)
  -- set voice 1 record level
  softcut.rec_level(1,1.0)
  -- set voice 1 pre level
  softcut.pre_level(1,0.0)
  -- set record state of voice 1 to 1
  softcut.rec(1,1)

  recording_start = util.time()
  if sync_to_loop then
    recording_start_transport = sync_to_loop.lattice.transport
  else
    recording_start_transport = 0
  end

  print("Recording!")
  add_history_msg("Recording to loop " .. selected_loop)
end

function stop_record_sample()
  softcut.rec(1,0)
  local recording_length = util.time() - recording_start
  print("Recording stopping! Length:", recording_length)
  add_history_msg("Saving to loop " .. selected_loop)
  softcut.buffer_write_mono(_path.audio .. "repl-looper/loop-" .. selected_loop .. ".wav", 0, recording_length, 1)
  clock.run(function()
    -- Wait for disk to flush; TODO see if there is a better way
    clock.sleep(3)
    local s = Sample.new(_path.audio .. "repl-looper/loop-" .. selected_loop .. ".wav")
    -- Wait for sample to fully load; TODO see if there is a better way
    clock.sleep(1)
    samples[selected_loop] = s
    if selected_loop == 1 then
      bug("Filling loop " .. selected_loop)
      loops[selected_loop]:fill(samples[selected_loop])
    else
      bug("Slicing to loop " .. selected_loop)
      loops[selected_loop]:slice(samples[selected_loop])
      loops[selected_loop]:shift(recording_start_transport)
    end

    add_history_msg("Sliced into loop " .. selected_loop)
  end)
end

function handle_pedal_event(midi_data)
  local msg = midi.to_msg(midi_data)
  -- tab.print(msg)

  local button = 0
  if msg.note == 60 then
    button = 1
  elseif msg.note == 62 then
    button = 2
  elseif msg.note == 64 then
    button = 3
  end

  if msg.type == "note_on" then
    if button == 1 then
      start_record_sample()
    end
    if button == 2 then
      select_next_loop()
    end
    if button == 3 then
      select_prev_loop()
    end
  end

  if msg.type == "note_off" then
    if button == 1 then
      stop_record_sample()
    end
  end

end

function enc(n, d)
  if n == 3 then
    select_nth_loop(selected_loop + d)
  end
end

function key(n, z)
  if n == 2 and z == 1 then
    local loop = loops[selected_loop]
    if loop.mode == "stop" then
      loop:play()
    else
      loop:stop()
    end
  end
end

----------------------------------------------------------------------
-- REPL communication ------------------------------------------------
----------------------------------------------------------------------

function messageToServer(json_msg)
  local msg = JSON.decode(json_msg)
  if msg.command == "save_loop" then
    loops[msg.loop_num] = Loop.new(msg.loop)
  else
    print "UNKNOWN COMMAND\n"
  end
end

function messageFromServer(msg)
  local msg_json = JSON.encode(msg)
  print("SERVER MESSAGE: " .. msg_json .. "\n")
end

-- Look up a variable via dynamic scope
-- Code from https://leafo.net/guides/dynamic-scoping-in-lua.html
function dynamic(name)
  local level = 2
  -- iterate to the top
  while true do
    local i = 1
    -- iterate over each local by index
    while true do
      local found_name, found_val = debug.getlocal(level, i)
      if not found_name then break end
      if found_name == name then
        return found_val
      end
      i = i + 1
    end
    level = level + 1
  end
end


result_history = Deque.new()

function add_history_msg(msg)
  bug(msg)
  result_history:push_back({
    input = msg,
    output = JSON.encode(nil)
  })
  redraw()
end

function safe_json_encode(data)
  local status, response = pcall(JSON.encode, data)

  if status then
    return response
  else
    return JSON.encode(nil)
  end
end

last = "" -- the output from the last command

function client_live_event(command, from_playing_loop)
  clock.run(function()
    clock.sleep(0.001)
    print(live_event(command, from_playing_loop))
  end)
end

function live_event(command, from_playing_loop)
  local live_event_result, live_event_errors = eval(command)

  if live_event_errors then
    return live_event_errors
  else
    recent_command = command -- to display on the screen

    -- crazyness. If we got a function ... invoke it. This lets us do weird things.
    if type(live_event_result) == "function" then
      live_event_result = live_event_result()
    end

    for _, loop in ipairs(loops) do

      -- Don't record the "stop" command
      if loop.mode == "stop_recording" then
        loop.mode = "play"
      end

      if loop.mode == "recording" or loop.mode == "recording_step" then
        if not from_playing_loop or loop.record_feedback then
          loop:add_event_command(command)
          if loop.mode == "recording_step" then
            loop:nextStep()
          end
        end
      end

      -- Don't record the "rec" command
      if loop.mode == "start_recording" then
        loop.mode = "recording"
      end

      if loop.mode == "start_recording_step" then
        loop.mode = "recording_step"
      end
    end

    last = live_event_result

    if not from_playing_loop then
      -- if last ~= nil then
      --   result_history:push_back(JSON.encode(last))
      -- end
      result_history:push_back({
        input = command,
        output = safe_json_encode(last)
      })
    end

    redraw()

    -- Catch and ignore JSON encoding errors
    local status, response =
      pcall(JSON.encode, {
        action = "live_event",
        command = recent_command,
        result = live_event_result
      })

    if status then
      return "RESPONSE:" .. response
    else
      return "JSON ERROR"
    end
  end
end

function completions(command)
  local comps = comp.complete(command)
  return "RESPONSE:" .. JSON.encode({
    action = "completions",
    command = command,
    result = comps
  })
end

------------------------------------------------------------------
-- Music utilities -----------------------------------------------
------------------------------------------------------------------

-- Tiiiimmmmmbbbbeeerrrrr!!!!! PLUS MOLLY THE POLY!!!
-- .... PLUS GOLDENEYE!!!

ReplLooper = include("repl-looper/lib/repllooper_engine")

-- engine.load('ReplLooper')
engine.name = "ReplLooper"

Timber = include("repl-looper/lib/timber")
Molly = include("repl-looper/lib/molly")
Sample = include("repl-looper/lib/sample")

-- Play a note or a chord
-- The note can be either a midi number OR a note-string like "C3"
-- Or you can pass a table-list of notes that are played all at once
function p(note, voice_id, sample_id)
  local voice_id = voice_id or 0
  local sample_id = sample_id or 0
  local note = note or 60
  local freq = 0

  -- If we got an array, play them all!
  if type(note) == "table" then
    for i, n in ipairs(note) do
      p(n, voice_id + i, sample_id)
    end
    return
  end

  if string.match(note, "^%a") then
    if not string.find(note, "%d") then
      note = note .. "3"
    end
    note = string.upper(note)
    freq = musicutil.note_name_to_freq(note)
  else
    freq = musicutil.note_num_to_freq(note)
  end

  engine.playMode(sample_id, 3) -- one-shot
  engine.noteOn(current_context_loop_id, voice_id, freq, 1, sample_id)
end



---------------------------------------------------------------------
-- Load up and mess with some samples for performance ---------------
---------------------------------------------------------------------
function draw_grid_logo()
  showing_grid_logo = true
  local x = 3
  local y = 0
  local b = 15

  -- Top
  for i = 2, 9 do
    grid_device:led(x + i, y + 1, b)
  end

  -- Left-top
  for j = 1, 4 do
    grid_device:led(x + 2, j, b)
  end

  -- Right-top
  for j = 1, 2 do
    grid_device:led(x + 9, j, b)
  end

  -- Right-bottom
  for j = 4, 7 do
    grid_device:led(x + 9, j, b)
  end

  -- Bottom
  for i = 2, 9 do
    grid_device:led(x + i, y + 7, b)
  end

  -- Left-bottom
  for j = 6, 7 do
    grid_device:led(x + 2, j, b)
  end

  -- Left arrowhead
  grid_device:led(x + 1, 3, b)
  grid_device:led(x + 3, 3, b)

  -- Right arrowhead
  grid_device:led(x + 8, 5, b)
  grid_device:led(x + 10, 5, b)

  -- middle triangle
  grid_device:led(x + 5, 3, b)
  grid_device:led(x + 6, 4, b)
  grid_device:led(x + 5, 5, b)

  grid_device:refresh()
end

function init()

  -- Global Grid
  print "Loading grid"
  grid_device = Grid.new(handle_grid_key)

  draw_grid_logo()

  -- Global midi pedal
  print "Loading midi looper pedal"
  pedal_device = midi.connect()
  pedal_device.event = handle_pedal_event

  -- Get our file storage set up for live-recording
  os.execute("mkdir -p ".._path.audio.."repl-looper")

  -- Set up params
  -- MollyThePoly.add_params()
  -- params:add_separator()
  ReplLooper.add_params()

  -- Pre-create 8 loops
  -- Implicitly end up in `loops` with names `a`..`h`
  for n = 1, 8 do
    Loop.new()
  end

  -- Global mollys to start with
  molly = Molly.new()
  molly2 = Molly.new()
  molly3 = Molly.new()
  molly4 = Molly.new()
  molly5 = Molly.new()
  molly6 = Molly.new()
  molly7 = Molly.new()
  molly8 = Molly.new()

  mollies = { molly, molly2, molly3, molly4, molly5, molly6, molly7, molly8 }

  -- A lovely piano via timber
  piano = Timber.new("/home/we/dust/code/timber/audio/piano-c.wav")

  -- Kick out the jams
  s808 = {}

  -- Bass
  s808.BD = Sample.new("/home/we/dust/audio/common/808/808-BD.wav", "one-shot")
  s808.BS = Sample.new("/home/we/dust/audio/common/808/808-BS.wav", "one-shot")

  -- cowbell
  s808.CB = Sample.new("/home/we/dust/audio/common/808/808-CB.wav", "one-shot")

  -- closed/open hat
  s808.CH = Sample.new("/home/we/dust/audio/common/808/808-CH.wav", "one-shot")
  s808.OH = Sample.new("/home/we/dust/audio/common/808/808-OH.wav", "one-shot")

  -- Claves
  s808.CL = Sample.new("/home/we/dust/audio/common/808/808-CL.wav", "one-shot")

  -- Clap
  s808.CP = Sample.new("/home/we/dust/audio/common/808/808-CP.wav", "one-shot")

  -- Cymbols
  s808.CY = Sample.new("/home/we/dust/audio/common/808/808-CY.wav", "one-shot")

  -- Conga high, mid, low
  s808.HC = Sample.new("/home/we/dust/audio/common/808/808-HC.wav", "one-shot")
  s808.MC = Sample.new("/home/we/dust/audio/common/808/808-MC.wav", "one-shot")
  s808.LC = Sample.new("/home/we/dust/audio/common/808/808-LC.wav", "one-shot")

  -- Tom drum high, mid, low
  s808.HT = Sample.new("/home/we/dust/audio/common/808/808-HT.wav", "one-shot")
  s808.MT = Sample.new("/home/we/dust/audio/common/808/808-MT.wav", "one-shot")
  s808.LT = Sample.new("/home/we/dust/audio/common/808/808-LT.wav", "one-shot")

  -- Maracas
  s808.MA = Sample.new("/home/we/dust/audio/common/808/808-MA.wav", "one-shot")

  -- Rimshot and Snare
  s808.RS = Sample.new("/home/we/dust/audio/common/808/808-RS.wav", "one-shot")
  s808.SD = Sample.new("/home/we/dust/audio/common/808/808-SD.wav", "one-shot")
end

-- Handy 808 drum shortcuts
function BD() s808.BD:play() end
function CH() s808.CH:play() end
function CY() s808.CY:play() end
function LC() s808.LC:play() end
function MC() s808.MC:play() end
function RS() s808.RS:play() end
function BS() s808.BS:play() end
function CL() s808.CL:play() end
function HC() s808.HC:play() end
function LT() s808.LT:play() end
function MT() s808.MT:play() end
function SD() s808.SD:play() end
function CB() s808.CB:play() end
function CP() s808.CP:play() end
function HT() s808.HT:play() end
function MA() s808.MA:play() end
function OH() s808.OH:play() end


function random_sample(subdir)
  subdir = subdir or "folk"
  dir = '/home/we/dust/code/repl-looper/audio/' .. subdir .. "/"
  files = util.scandir(dir)
  random_file = dir .. files[math.random(#files)]
  return Sample.new(random_file, "one-shot")
end


