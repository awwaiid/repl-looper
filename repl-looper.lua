-- repl-looper v0.0.1
-- Anagogical mash of code, time, sound
--
-- llllllll.co/t/repl-looper
--
-- Use in conjunction with laptop running the UI


-- Add repl-looper lib dir in to load .so files like cjson.so
if not string.find(package.cpath, "/home/we/dust/code/repl-looper/lib/", 1, true) then
  package.cpath=package.cpath..";/home/we/dust/code/repl-looper/lib/?.so"
end

json = require("cjson")
lattice = require("lattice")

-- Global Grid
grrr = grid.connect()

local Command = {}
Command.__index = Command
Command.last_id = 0

function Command.new(init)
  local self = init or {
    string = ""
    -- fn = function () end
  }
  setmetatable(self, Command)

  Command.last_id = Command.last_id + 1
  self.id = Command.last_id

  return self
end

-- Not sure, but what we COULD do here is cache the result of the `load` in
-- `self.fn` or something
function Command:eval(from_playing_loop)
  return live_event(self.string, from_playing_loop)
end

---------------------------------------

local Event = {}
Event.__index = Event
Event.last_id = 0

function Event.new(init)
  local self = init or {
    command = Command.new(),
    relative_time = 0,
    pulse_offset = 0,
    step = 0
  }
  setmetatable(self, Event)

  Event.last_id = Event.last_id + 1
  self.id = Event.last_id

  return self
end

function Event:to_string()
  return "Step " .. self.step .. " @" .. self.pulse_offset .. " -- " .. self.command.string
end

function Event:eval(from_playing_loop)
  return self.command:eval(from_playing_loop)
end

---------------------------------------

Loop = {}
Loop.__index = Loop
Loop.last_id = 0

function Loop.new(init)
  local self = init or {
    events = {},
    loop_length_qn = 1,
    current_step = 1,
    duration = 1,
    lattice = lattice:new{},
    record_feedback = false
  }

  setmetatable(self, Loop)

  Loop.last_id = Loop.last_id + 1
  self.id = Loop.last_id

  -- Register with global list of loops
  loops[self.id] = self

  -- Kinda evil shortcut!
  -- for loops 1..8 make global var 'a' .. 'h'
  if self.id < 9 then
    local loop_letter = string.char(string.byte("a") + self.id - 1)
    print("Setting loop shortcut " .. loop_letter)
    _G[loop_letter] = self
  end

  self:update_lattice()
  return self
end

function Loop:qn_per_ms()
  return clock.get_tempo() / 60 / 1000
end

function Loop:pulse_per_ms()
  return self:qn_per_ms() * self.lattice.ppqn
end

function Loop:pulse_per_measure()
  return self.lattice.ppqn * self.lattice.meter
end

function Loop:loop_length_measure()
  return self.loop_length_qn / self.lattice.meter
end

function Loop:update_event(event)
  event.pulse_offset = self:pulse_per_ms() * event.relative_time
  print("pulse offset: " .. event.pulse_offset)

  event.step = event.pulse_offset / self.lattice.ppqn + 1
  print("event step: " .. event.step)

  action = function(t)
    print("@" .. t .. " (next @" .. (self:loop_length_measure() * self:pulse_per_measure() + t) .. ") command: " .. event.command.string)
    event:eval(true) -- `true` to indicate we are a playback event
    -- live_event(event.command)
  end

  event.pattern = event.pattern or self.lattice:new_pattern{}

  event.pattern:set_action(action)
  event.pattern:set_division(self:loop_length_measure()) -- division is in measures

  -- Forcing the initial phase is what sets the actual offset
  -- TODO: can this be updated while playing? Does it need to be relative to
  -- the current lattice time or something?
  event.pattern.phase = self:loop_length_measure() * self:pulse_per_measure() - event.pulse_offset
end

function Loop:update_lattice()
  -- We use ceil here, so will grow loop-length to the next full quarter note
  self.loop_length_qn = math.ceil(self.duration * self:qn_per_ms())

  print("pulse/ms = " .. self:pulse_per_ms())
  print("qn/ms = " .. self:qn_per_ms())
  print("pulse/measure = " .. self:pulse_per_measure())
  print("loop length qn = " .. self.loop_length_qn)
  print("loop length measure = " .. self:loop_length_measure())

  for _, event in ipairs(self.events) do
    self:update_event(event)
  end

  -- Basically a quarter-note metronome
  count = count or 0
  self.status_pattern = self.status_pattern or self.lattice:new_pattern{
    action = function(t)
      self.current_step = (math.floor(t / self.lattice.ppqn) % self.loop_length_qn) + 1

      messageFromServer({
        action = "playback_step",
        step = count,
        stepCount = self.loop_length_qn
      })

      -- Let's get some GRID!!
      local row = self:to_grid_row()
      -- print("Row: " .. json.encode(row))

      -- Clear the whole row
      for n = 1, 16 do
        -- print("grrr:led(", g, n, self.id, 0, ")")
        grrr:led(n, self.id, 0)
      end

      for n = 1, self.loop_length_qn do
        grrr:led(n, self.id, row[n] or 0)
        -- print("led " .. n .. " " .. (row[n] or 0))
      end
      grrr:refresh()

      -- print("step " .. (count + 1) .. " @" .. t)
      count = (count + 1) % self.loop_length_qn
    end,
    division = 1/4
  }

  return l
end

function Loop:quantize()
  for _, event in ipairs(self.events) do
    event.step = math.floor(event.step + 0.5)
    event.relative_time = event.step / self:qn_per_ms()
  end

  self:update_lattice()
end

function Loop:print()
  print("Length length qn: " .. self.loop_length_qn)
  print("Current step: " .. self.current_step)
  for _, event in ipairs(self.events) do
    print("  " .. event:to_string())
  end
end

function Loop:to_grid_row()
  local row = {}
  -- print("Length length qn: " .. self.loop_length_qn)
  -- print("Current step: " .. self.current_step)
  for n = 1, self.loop_length_qn do
    if n == self.current_step then
      row[n] = 10
    else
      row[n] = 0
    end
  end
  for _, event in ipairs(self.events) do
    -- print("  " .. event.step .. ": " .. event.command)
    local step = math.floor(event.step)
    if step == self.current_step then
      row[step] = 15
    else
      row[step] = 5
    end
  end

  return row
end

function Loop:play_events_at_step(step)
  for _, event in ipairs(self.events) do
    local event_step = math.floor(event.step)
    if event_step == step then
      print("command: " .. event.command.string)
      event.command:eval()
      -- live_event(event.command)
    end
  end
end

function Loop:play()
  self.lattice:start()
end

function Loop:stop()
  if self.mode == "recording" then
    self.end_rec_time = util.time() * 1000
    self.mode = "stop_recording"
    self.duration = self.end_rec_time - self.start_rec_time
    self:update_lattice()
  else
    self.lattice:stop()
  end
end

function Loop:rec()
  self.start_rec_time = util.time() * 1000
  self.mode = "start_recording"
end

function Loop:add_event_command(cmd)
  local current_time = util.time() * 1000
  event = Event.new({
    absolute_time = current_time,
    relative_time = current_time - self.start_rec_time,
    command = Command.new({
      string = cmd
    })
  })
  -- self:update_event(event)
  table.insert(self.events, event)
  return event
end

------------------------------------------------------

loops = {}

-- Pre-create 8 loops
for n = 1, 8 do
  Loop.new()
end

grrr.key = function(col, row, state)
  -- print("Key: ", col, row, state)
  -- loops[1]:print()
  if state == 1 then
    loops[row]:play_events_at_step(col)
  end
end

-- REPL communication
function messageToServer(json_msg)
  local msg = json.decode(json_msg)
  if msg.command == "save_loop" then
    loops[msg.loop_num] = Loop.new(msg.loop)
  else
    print "UNKNOWN COMMAND\n"
  end
end

function messageFromServer(msg)
  local msg_json = json.encode(msg)
  print("SERVER MESSAGE: " .. msg_json .. "\n")
end

-- Doing the eval w/ `return` first and then falling back to without
-- https://github.com/hoelzro/lua-repl/blob/master/repl/plugins/autoreturn.lua
function live_event(command, from_playing_loop)
  print("Got live_event: " .. command)
  local live_event_command, live_event_errors = load("return " .. command, "CMD")
  if not live_event_command then
    live_event_command, live_event_errors = load(command, "CMD")
  end
  if live_event_errors then
    return live_event_errors
  else
    local live_event_result = live_event_command()
    for _, loop in ipairs(loops) do
      if loop.mode == "stop_recording" then
        loop.mode = "stopped"
      end
      if loop.mode == "recording" then
        if not from_playing_loop or loop.record_feedback then
          print("Recording event")
          loop:add_event_command(command)
        end
      end
      if loop.mode == "start_recording" then
        loop.mode = "recording"
      end
    end
    return live_event_result
  end
end

-- Music utilities
engine.load('PolyPerc')

function beep(freq)
  engine.hz(freq or 440)
end
