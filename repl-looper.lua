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
  -- return "Step " .. self.step .. " @" .. self.pulse_offset .. " -- " .. self.command.string
  return "Step " .. self.step .. " (" .. self.pattern.phase .. ") -- " .. self.command.string
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
    loop_length_qn = 16,
    current_step = 1,
    duration = 10212,
    lattice = lattice:new{},
    record_feedback = false,
    auto_quantize = true,
    send_feedback = false
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

  if self.auto_quantize then
    event.step = math.floor(event.step + 0.5)
    event.relative_time = (event.step - 1) / self:qn_per_ms()
    event.pulse_offset = self:pulse_per_ms() * event.relative_time - self.lattice.transport
  end

  action = function(t)
    print("@" .. t .. " (next @" .. (self:loop_length_measure() * self:pulse_per_measure() + t) .. ") command: " .. event.command.string)
    event:eval(self.send_feedback) -- `true` to indicate we are a playback event
  end

  event.pattern = event.pattern or self.lattice:new_pattern{}

  event.pattern:set_action(action)
  event.pattern:set_division(self:loop_length_measure()) -- division is in measures

  -- Forcing the initial phase is what sets the actual offset
  -- TODO: can this be updated while playing? Does it need to be relative to
  -- the current lattice time or something?
  event.pattern.phase = self:loop_length_measure() * self:pulse_per_measure() - event.pulse_offset - self.lattice.transport
end

function Loop:update_lattice()
  -- We use ceil here, so will grow loop-length to the next full quarter note
  -- self.loop_length_qn = self.loop_length_qn or math.ceil(self.duration * self:qn_per_ms())
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
  self.status_pattern = self.status_pattern or self.lattice:new_pattern{
    action = function(t)
      self.current_step = (math.floor(t / self.lattice.ppqn) % self.loop_length_qn) + 1
      self:draw_grid_row()

      messageFromServer({
        action = "playback_step",
        step = self.current_step,
        stepCount = self.loop_length_qn
      })
    end,
    division = 1/4
  }

  return l
end

-- Let's get some GRID!!
function Loop:draw_grid_row()
  clear_grid_row(self.id)

  local row = self:to_grid_row()
  for n = 1, self.loop_length_qn do
    grrr:led(n, self.id, row[n] or 0)
  end

  grrr:refresh()
end

function Loop:quantize()
  for _, event in ipairs(self.events) do
    event.step = math.floor(event.step + 0.5)
    event.relative_time = (event.step - 1) / self:qn_per_ms()
    event.pulse_offset = self:pulse_per_ms() * event.relative_time - self.lattice.transport
  end

  self:update_lattice()
end

function Loop:print()
  print("ID:", self.id, "Step:", self.current_step .. "/" .. self.loop_length_qn, "@" .. self.lattice.transport)
  for _, event in ipairs(self.events) do
    print("  " .. event:to_string())
  end
end

function Loop:to_grid_row()
  local row = {}
  for n = 1, self.loop_length_qn do
    if n == self.current_step then
      row[n] = 10
    else
      row[n] = 2
    end
  end
  for _, event in ipairs(self.events) do
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
      -- print("Loop", self.id, "one-shot command:", event.command.string)
      event.command:eval()
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
      if self.events[i].pattern then
        self.events[i].pattern:destroy()
      end
      table.remove(self.events, i)
      found_commands = true
    end
  end

  if not found_commands then
    for _, command in ipairs(commands) do
      local new_event = Event.new({
        -- absolute_time = current_time,
        relative_time = (step - 1) / self:qn_per_ms(),
        command = command,
        step = step,
        pulse_offset = step * self.lattice.ppqn
      })

      table.insert(self.events, new_event)

      self:update_event(new_event)
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
    self:draw_grid_row()
  else
    self.lattice:stop()
  end
end

function Loop:rec()
  self.start_rec_time = util.time() * 1000
  self.start_rec_transport = self.lattice.transport
  self.mode = "start_recording"
end

function Loop:add_event_command(cmd)
  local current_time = util.time() * 1000
  local relative_time = current_time - self.start_rec_time
  event = Event.new({
    absolute_time = current_time,
    relative_time = relative_time,
    -- relative_pulse = self:pulse_per_ms() * relative_time + self.start_rec_transport
    command = Command.new({
      string = cmd
    })
  })
  self:update_event(event)
  table.insert(self.events, event)
  return event
end

------------------------------------------------------

loops = {}

-- Pre-create 8 loops
for n = 1, 8 do
  Loop.new()
end

function clear_grid_row(row)
  for n = 1, 16 do
    grrr:led(n, row, 0)
  end
end

grid_mode = "one-shot"
grrr:led(1, 8, 15)
local grid_data = {}

grrr.key = function(col, row, state)
  if state == 0 then
    return
  end
  if row == 8 then
    if col == 1 then
      grid_mode = "one-shot"
      print("grid: one-shot mode")
      clear_grid_row(8)
      grrr:led(1, 8, 15)
    elseif col == 2 then
      grid_mode = "sequence"
      print("grid: sequence mode")
      grid_data = {}
      clear_grid_row(8)
      grrr:led(2, 8, 15)
    end
    grrr:refresh()
    redraw()
  else
    local loop_id = row
    local step = col
    if grid_mode == "one-shot" then
      loops[loop_id]:play_events_at_step(col)
    elseif grid_mode == "sequence" then
      if not grid_data.commands then
        grid_data.commands = loops[loop_id]:commands_at_step(step)
        loops[loop_id]:draw_grid_row()
      else
        loops[loop_id]:toggle_commands_at_step(step, grid_data.commands)
        loops[loop_id]:draw_grid_row()
      end
    end
  end
end

recent_command = ""
function redraw()
  screen.ping()
  screen.clear()
  screen.move(0,5)
  screen.text("REPL-LOOPER")

  screen.move(0,62)
  screen.text(grid_mode)

  screen.move(63,34)
  screen.text_center(recent_command)

  screen.update()
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
  -- print("Got live_event: " .. command)
  local live_event_command, live_event_errors = load("return " .. command, "CMD")
  if not live_event_command then
    live_event_command, live_event_errors = load(command, "CMD")
  end
  if live_event_errors then
    return live_event_errors
  else
    recent_command = command
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
    redraw()
    return live_event_result
  end
end

-- Music utilities
-- engine.load('PolyPerc')

-- function beep(freq)
--   engine.hz(freq or 440)
-- end

-- The Other Way

Timber = include("timber/lib/timber_engine")
engine.load('Timber')
engine.name = "Timber"
Timber.add_params() -- Add the general params

-- Each sample needs params
Timber.add_sample_params(0)
Timber.load_sample(0, "/home/we/dust/code/timber/audio/piano-c.wav")

MusicUtil = require "musicutil"
note_name_num = {}
for num=1,127 do
  local name = MusicUtil.note_num_to_name(num, true)
  note_name_num[name] = num
end

MusicUtil.note_name_to_num = function(name) return note_name_num[name] end
MusicUtil.note_name_to_freq = function(name) return MusicUtil.note_num_to_freq(MusicUtil.note_name_to_num(name)) end

function piano_freq(hz, voice)
  engine.noteOn(voice, hz, 1, 0)
end

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
    freq = MusicUtil.note_name_to_freq(note)
  else
    freq = MusicUtil.note_num_to_freq(note)
  end

  engine.playMode(sample_id, 3) -- one-shot
  engine.noteOn(voice_id, freq, 1, sample_id)
end

-- p"C"
-- p"C#4"

-- engine.noteOn(0, 440, 0.75, 0) -- voice, freq, vol, sample_id
-- engine.noteOn(1, 220, 1, 0)

-- for i = 0, 9 do engine.playMode(i, 3) end -- 3 = one-shot playback instead of loop

-- engine.playMode(0, 0) -- loop (or should it be infinite-loop?)

-- percentage 55.9
-- start 0
-- end 0.75
-- loop-start 0.04
-- loop-end 0.42
-- freq mod lfo1 0.16
-- freq mod lfo2 0.11
-- filter type low-pass
-- filter cutoff 224 Hz
-- filter resonance 0.84
-- filter cutoff mod LFO1 0.27
-- filter cutoff mod LFO2 0.06
-- Filter cutoff mod Env 0.42
-- Filter cutoff mod Vel 0.18
-- Filter cutoff mod Pres 0.4
--

Timber.add_sample_params(1)
Timber.load_sample(1, "/home/we/dust/audio/common/808/808-BD.wav")
