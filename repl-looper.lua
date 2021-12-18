-- repl-looper v0.0.1
-- Anagogical mash of code, time, sound
--
-- llllllll.co/t/repl-looper
--
-- Use in conjunction with laptop running the UI


-- Add repl-looper lib dir in to load .so files like cjson.so
if not string.find(package.cpath, "/home/we/dust/code/repl-looper/lib/", 1, true) then
  package.cpath = package.cpath .. ";/home/we/dust/code/repl-looper/lib/?.so"
  package.path = package.path .. ";/home/we/dust/code/repl-looper/lib/?.lua"
end

json = require("cjson")
-- json = require("lib/dkjson")
lattice = require("lattice")

-- Global Grid
grid_device = grid.connect()


---------------------------------------------------------------------
-- Loop-related objects ---------------------------------------------
---------------------------------------------------------------------

local Command = {}
Command.__index = Command
Command.last_id = 0

function Command.new(init)
  local self = init or {
    string = ""
  }
  setmetatable(self, Command)

  Command.last_id = Command.last_id + 1
  self.id = Command.last_id

  return self
end

-- Not sure, but what we COULD do here is cache the result of the `load` in
-- `self.fn` or something instead of re-parsing it each time
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
  return "Step " .. self.step .. " (" .. self.pattern.phase .. ") -- " .. self.command.string
end

function Event:lua()
  return {
    pulse = self.pulse, -- The absolute time
    pulse_offset = self.pulse_offset, -- loop relative time
    phase = self.pattern.phase, -- current countdown in pulses
    step = self.step,
    command = self.command.string
  }
end

function Event:eval(from_playing_loop)
  return self.command:eval(from_playing_loop)
end

function Event:destroy()
  self.pattern:destroy()
end

function Event:clone()
  return Event.new({
    pulse = self.pulse,
    command = Command.new({
      string = self.command.string
    })
  })
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
    auto_quantize = false,
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
    self.loop_letter = string.char(string.byte("a") + self.id - 1)
    -- print("Setting loop shortcut " .. loop_letter)
    _G[self.loop_letter] = self
  end

  -- Basically a quarter-note metronome
  -- This is used to update the grid and client
  self.status_pattern = self.status_pattern or self.lattice:new_pattern {
    action = function(t)
      self:send_status(t)
    end,
    division = 1/4
  }

  return self
end

function Loop:send_status(t)
  t = t or 0
  self.current_step = (math.floor(t / self.lattice.ppqn) % self.loop_length_qn) + 1
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
  return self.lattice.ppqn * self.lattice.meter
end

function Loop:loop_length_measure()
  return self.loop_length_qn / self.lattice.meter
end

function Loop:loop_length_pulse()
  return self.loop_length_qn * self.lattice.ppqn
end

function Loop:set_length(qn)
  self.loop_length_qn = qn
  self:update_lattice()
end

function Loop:update_event(event)
  event.pulse_offset = event.pulse % self:loop_length_pulse()
  event.step = event.pulse_offset / self.lattice.ppqn + 1

  if self.auto_quantize then
    event.step = math.floor(event.step + 0.5) -- nearest whole step
    event.pulse_offset = (event.step - 1) * self.lattice.ppqn
  end

  local action = function(t)
    -- print("@" .. t .. " (next @" .. (event.pulse_offset + t) .. ") command: " .. event.command.string)
    self.recent_command = event.command.string
    event:eval(not self.send_feedback) -- `true` to indicate we are a playback event
  end

  event.pattern = event.pattern or self.lattice:new_pattern{}

  event.pattern:set_action(action)
  event.pattern:set_division(self:loop_length_measure()) -- division is in measures

  -- Forcing the phase is what sets the actual offset for this pattern based on
  -- the current transport (play position). The phase is a count-down until the
  -- event is fired
  local loop_phase = self.lattice.transport % self:loop_length_pulse()
  local phase_distance = (event.pulse_offset - loop_phase) % self:loop_length_pulse()
  event.pattern.phase = self:loop_length_pulse() - phase_distance
end

-- Update all events; this is handy for re-working the loop length
function Loop:update_lattice()
  for _, event in ipairs(self.events) do
    self:update_event(event)
  end
end

function Loop:remove_event(event_to_remove)
  -- Go backwards so that when we remove nothing weird happens
  for i = #self.events, 1, -1 do
    local event = self.events[i]
    if event == event_to_remove then
      event.pattern:destroy()
      event.pattern = nil
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
  for n = 1, self.loop_length_qn do
    -- Mod-16 so we can show long sequences overlaid; maybe confusing
    grid_device:led((((n-1) % 16)+1), self.id, row[n] or 0)
  end

  grid_device:refresh()
end

function Loop:to_string()
  local output = ""
  output = output .. "ID:" .. self.id .. "Step:" .. self.current_step .. "/" .. self.loop_length_qn .. "@" .. self.lattice.transport .. "\n"
  for _, event in ipairs(self.events) do
    output = output .. "  " .. event:to_string() .. "\n"
  end
  return output
end

function Loop:lua()
  local output = {}
  output.current_step = self.current_step
  output.loop_length_qn = self.loop_length_qn
  output.transport = self.lattice.transport
  output.events = {}
  for _, event in ipairs(self.events) do
    table.insert(output.events, event:lua())
  end
  return output
end

function Loop:print()
  print(self:to_string())
end

function Loop:to_grid_row()
  local row = {}

  -- Highlight the current step even if we're not
  -- on an event; all the rest are dark by default
  for n = 1, self.loop_length_qn do
    if n == self.current_step then
      row[n] = 10
    else
      row[n] = 0
    end
  end

  -- Entries with events glow. Event+current glow a lot
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
        command = command,
        pulse = step * self.lattice.ppqn
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
    self.mode = "stop_recording"
    self:draw_grid_row()
  else
    self.lattice:stop()
  end
end

function Loop:rec()
  self.mode = "start_recording"
  self.lattice:start()
end

function Loop:add_event_command(cmd)
  local event = Event.new({
    pulse = self.lattice.transport,
    command = Command.new({
      string = cmd
    })
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

-- Copy all of the events to another loop
function Loop:clone(other_loop)
  other_loop:clear()
  for _, event in ipairs(self.events) do
    other_loop:add_event(event:clone())
  end
  self:draw_grid_row()
end

-- a:gen("CH") puts the "CH" function on every step
-- a:gen("CH", "n >= 8") puts the "CH" on the second half of steps
-- a:gen("CH", 1, 4) puts the "CH" on 1 of ever 4 steps
function Loop:gen(code_string, condition, mod_base)
  if mod_base then
    condition = "(n-1) % " .. mod_base .. " == (" .. (condition - 1) .. ")"
  end
  condition = condition or "true"
  for n = 1, self.loop_length_qn do
    local condition_met = eval("local n = dynamic('n'); return " .. condition);
    if condition_met then
      local expanded_code_string =
        string.gsub(
          code_string,
          "`([^`]+)`",
          function (snippet)
            local injected_snippet = "local n = dynamic('n'); return " .. snippet
            -- print("FROM:", snippet, "EVAL:", injected_snippet)
            return eval(injected_snippet)
          end
        )
      local event = Event.new({
        pulse = (n - 1) * self.lattice.ppqn,
        command = Command.new({
          string = expanded_code_string
        })
      })
      self:update_event(event)
      table.insert(self.events, event)
    end
  end
  self:draw_grid_row()
end

function Loop:clear()
  for _, event in ipairs(self.events) do
    event:destroy()
  end
  self.events = {}
  self:draw_grid_row()
end

function Loop:merge(other_loop)
  for _, event in ipairs(other_loop.events) do
    self:add_event(event:clone())
  end
  other_loop:clear()
  self:draw_grid_row()
end

-- Helper string distance function
function leven(s,t)
  if s == '' then return t:len() end
  if t == '' then return s:len() end

  local s1 = s:sub(2, -1)
  local t1 = t:sub(2, -1)

  if s:sub(0, 1) == t:sub(0, 1) then
    return leven(s1, t1)
  end

  return 1 + math.min(
    leven(s1, t1),
    leven(s,  t1),
    leven(s1, t )
  )
end

function Loop:split(other_loop)
  if #self.events < 2 then
    return
  end

  local events = {}
  for _, event in ipairs(self.events) do
    table.insert(events, event:clone())
  end

  local base_command = events[1].command.string
  local distances = {}
  local total_dist = 0
  for _, event in ipairs(events) do
    local dist = leven(base_command, event.command.string)
    total_dist = total_dist + dist

    -- for debugging and to minimize sort calcs
    distances[event.command.string] = dist
  end

  table.sort(events, function(a, b)
    local a_dist = distances[a.command.string]
    local b_dist = distances[b.command.string]
    return a_dist < b_dist
  end)

  local mean_dist = total_dist / #events

  self:clear()
  other_loop:clear()

  for _, event in ipairs(events) do
    local event_dist = leven(base_command, event.command.string)
    if event_dist <= mean_dist then
      self:add_event(event)
    else
      other_loop:add_event(event)
    end
  end

  self:draw_grid_row()
  other_loop:draw_grid_row()

  return {
    mean_dist = mean_dist,
    distances = distances
  }
end

------------------------------------------------------

loops = {}

-- Pre-create 8 loops
for n = 1, 8 do
  Loop.new()
end

function clear_grid_row(row)
  for n = 1, 16 do
    grid_device:led(n, row, 0)
  end
end

grid_mode = "one-shot"
local grid_data = {}

grid_device.key = function(col, row, state)
  if state == 0 then
    return
  end
  -- Experiment with using bottom-row as a set of controls,
  -- like having a copy/paste mode
  --
  -- if row == 8 then
  --   if col == 1 then
  --     grid_mode = "one-shot"
  --     print("grid: one-shot mode")
  --     clear_grid_row(8)
  --     grid_device:led(1, 8, 15)
  --   elseif col == 2 then
  --     grid_mode = "sequence"
  --     print("grid: sequence mode")
  --     grid_data = {}
  --     clear_grid_row(8)
  --     grid_device:led(2, 8, 15)
  --   end
  --   grid_device:refresh()
  --   redraw()
  -- else
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
  -- end
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

----------------------------------------------------------------------
-- REPL communication ------------------------------------------------
----------------------------------------------------------------------

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

-- TODO: Consider memoizing
function eval(code_string)
  -- This little trick tries to eval first in expression context with a
  -- `return`, and if that doesn't parse (shouldn't even get executed) then try
  -- again in regular command context. Got this method from
  -- https://github.com/hoelzro/lua-repl/blob/master/repl/plugins/autoreturn.lua
  --
  -- Either way we get a function back that we then invoke
  local eval_command, eval_errors = load("return " .. code_string, "EVAL")
  if not eval_command then
    eval_command, eval_errors = load(code_string, "EVAL")
  end

  if eval_errors then
    return nil, eval_errors
  end

  return eval_command()
end

last = nil -- the output from the last command

function live_event(command, from_playing_loop)
  -- print("Got live_event: " .. command)

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
        loop.mode = "stopped_recording"
      end

      if loop.mode == "recording" then
        if not from_playing_loop or loop.record_feedback then
          loop:add_event_command(command)
        end
      end

      -- Don't record the "rec" command
      if loop.mode == "start_recording" then
        loop.mode = "recording"
      end
    end

    redraw()

    last = live_event_result
    return "RESPONSE:" .. json.encode({
      action = "live_event",
      command = recent_command,
      result = live_event_result
    })
  end
end

comp = require("completion")
function completions(command)
  local comps = comp.complete(command)
  return "RESPONSE:" .. json.encode({
    action = "completions",
    command = command,
    result = comps
  })
end

-- Script utilities

-- function hard_reset()
--   norns.script.reload()
-- end


------------------------------------------------------------------
-- Music utilities -----------------------------------------------
------------------------------------------------------------------

-- engine.load('PolyPerc')

-- function beep(freq)
--   engine.hz(freq or 440)
-- end

-- Tiiiimmmmmbbbbeeerrrrr!!!!!

TimberMod = include("repl-looper/lib/timbermod_engine")
engine.load('TimberMod')
engine.name = "TimberMod"
TimberMod.add_params() -- Add the general params


MusicUtil = require "musicutil"

-- Reverse note name -> num lookup
note_name_num = {}
for num=1,127 do
  local name = MusicUtil.note_num_to_name(num, true)
  note_name_num[name] = num
end

-- Add these into MusicUtil because why not
MusicUtil.note_name_to_num = function(name) return note_name_num[name] end
MusicUtil.note_name_to_freq = function(name) return MusicUtil.note_num_to_freq(MusicUtil.note_name_to_num(name)) end

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

Sample = {}
Sample.__index = Sample
Sample.next_id = 0

function Sample.new(filename, play_mode)
  local self = {
    params = {}
  }
  setmetatable(self, Sample)

  self.id = Sample.next_id
  Sample.next_id = Sample.next_id + 1


  if filename then
    self:load_sample(filename)
  end

  if play_mode then
    if play_mode == "one-shot" then
      self:playMode(2)
    end
  end

  return self
end

-- Control a sample from Timber
function Sample:pitchBend(n) self.params.pitchBend = n; engine.pitchBendSample(self.id, n) end
function Sample:pressure(n) self.params.pressure = n; engine.pressureSample(self.id, n) end
function Sample:transpose(n) self.params.transpose = n; engine.transpose(self.id, n) end
function Sample:detuneCents(n) self.params.detuneCents = n; engine.detuneCents(self.id, n) end
function Sample:startFrame(n) self.params.startFrame = n; engine.startFrame(self.id, n) end
function Sample:endFrame(n) self.params.endFrame = n; engine.endFrame(self.id, n) end
function Sample:playMode(n) self.params.playMode = n; engine.playMode(self.id, n) end
function Sample:loopStartFrame(n) self.params.loopStartFrame = n; engine.loopStartFrame(self.id, n) end
function Sample:loopEndFrame(n) self.params.loopEndFrame = n; engine.loopEndFrame(self.id, n) end
function Sample:lfo1Fade(n) self.params.lfo1Fade = n; engine.lfo1Fade(self.id, n) end
function Sample:lfo2Fade(n) self.params.lfo2Fade = n; engine.lfo2Fade(self.id, n) end
function Sample:freqModLfo1(n) self.params.freqModLfo1 = n; engine.freqModLfo1(self.id, n) end
function Sample:freqModLfo2(n) self.params.freqModLfo2 = n; engine.freqModLfo2(self.id, n) end
function Sample:freqModEnv(n) self.params.freqModEnv = n; engine.freqModEnv(self.id, n) end
function Sample:freqMultiplier(n) self.params.freqMultiplier = n; engine.freqMultiplier(self.id, n) end
function Sample:ampAttack(n) self.params.ampAttack = n; engine.ampAttack(self.id, n) end
function Sample:ampDecay(n) self.params.ampDecay = n; engine.ampDecay(self.id, n) end
function Sample:ampSustain(n) self.params.ampSustain = n; engine.ampSustain(self.id, n) end
function Sample:ampRelease(n) self.params.ampRelease = n; engine.ampRelease(self.id, n) end
function Sample:modAttack(n) self.params.modAttack = n; engine.modAttack(self.id, n) end
function Sample:modDecay(n) self.params.modDecay = n; engine.modDecay(self.id, n) end
function Sample:modSustain(n) self.params.modSustain = n; engine.modSustain(self.id, n) end
function Sample:modRelease(n) self.params.modRelease = n; engine.modRelease(self.id, n) end
function Sample:downSampleTo(n) self.params.downSampleTo = n; engine.downSampleTo(self.id, n) end
function Sample:bitDepth(n) self.params.bitDepth = n; engine.bitDepth(self.id, n) end
function Sample:filterFreq(n) self.params.filterFreq = n; engine.filterFreq(self.id, n) end
function Sample:filterReso(n) self.params.filterReso = n; engine.filterReso(self.id, n) end
function Sample:filterType(n) self.params.filterType = n; engine.filterType(self.id, n) end
function Sample:filterTracking(n) self.params.filterTracking = n; engine.filterTracking(self.id, n) end
function Sample:filterFreqModLfo1(n) self.params.filterFreqModLfo1 = n; engine.filterFreqModLfo1(self.id, n) end
function Sample:filterFreqModLfo2(n) self.params.filterFreqModLfo2 = n; engine.filterFreqModLfo2(self.id, n) end
function Sample:filterFreqModEnv(n) self.params.filterFreqModEnv = n; engine.filterFreqModEnv(self.id, n) end
function Sample:filterFreqModVel(n) self.params.filterFreqModVel = n; engine.filterFreqModVel(self.id, n) end
function Sample:filterFreqModPressure(n) self.params.filterFreqModPressure = n; engine.filterFreqModPressure(self.id, n) end
function Sample:pan(n) self.params.pan = n; engine.pan(self.id, n) end
function Sample:panModLfo1(n) self.params.panModLfo1 = n; engine.panModLfo1(self.id, n) end
function Sample:panModLfo2(n) self.params.panModLfo2 = n; engine.panModLfo2(self.id, n) end
function Sample:panModEnv(n) self.params.panModEnv = n; engine.panModEnv(self.id, n) end
function Sample:amp(n) self.params.amp = n; engine.amp(self.id, n) end
function Sample:ampModLfo1(n) self.params.ampModLfo1 = n; engine.ampModLfo1(self.id, n) end
function Sample:ampModLfo2(n) self.params.ampModLfo2 = n; engine.ampModLfo2(self.id, n) end

function Sample:noteOn(freq, vol, voice)
  freq = freq or 200
  vol = vol or 1
  voice = voice or self.id -- TODO: voice management
  engine.noteOn(voice, freq, vol, self.id)
end

function Sample:play() self:noteOn() end
function Sample:stop() self:noteOff() end

function Sample:noteOff() engine.noteOff(self.id) end
function Sample:noteKill() engine.noteKill(self.id) end

function Sample:load_sample(filename)
  TimberMod.add_sample_params(self.id)
  TimberMod.load_sample(self.id, filename)
  self.sample_filename = filename
end

function Sample:info()
  return TimberMod.samples_meta[self.id]
end

function Sample:reverse()
  self:startFrame(self:info().num_frames - 1)
  self:endFrame(0)
end

function Sample:forward()
  self:startFrame(0)
  self:endFrame(self:info().num_frames - 1)
end

function Sample:note(note)
  local voice_id = self.id
  local sample_id = self.id
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

---------------------------------------------------------------------
-- Load up and mess with some samples for performance ---------------
---------------------------------------------------------------------

piano = Sample.new("/home/we/dust/code/timber/audio/piano-c.wav")

s808 = {}

s808.BD = Sample.new("/home/we/dust/audio/common/808/808-BD.wav", "one-shot")
s808.CH = Sample.new("/home/we/dust/audio/common/808/808-CH.wav", "one-shot")
s808.CY = Sample.new("/home/we/dust/audio/common/808/808-CY.wav", "one-shot")
s808.LC = Sample.new("/home/we/dust/audio/common/808/808-LC.wav", "one-shot")
s808.MC = Sample.new("/home/we/dust/audio/common/808/808-MC.wav", "one-shot")
s808.RS = Sample.new("/home/we/dust/audio/common/808/808-RS.wav", "one-shot")
s808.BS = Sample.new("/home/we/dust/audio/common/808/808-BS.wav", "one-shot")
s808.CL = Sample.new("/home/we/dust/audio/common/808/808-CL.wav", "one-shot")
s808.HC = Sample.new("/home/we/dust/audio/common/808/808-HC.wav", "one-shot")
s808.LT = Sample.new("/home/we/dust/audio/common/808/808-LT.wav", "one-shot")
s808.MT = Sample.new("/home/we/dust/audio/common/808/808-MT.wav", "one-shot")
s808.SD = Sample.new("/home/we/dust/audio/common/808/808-SD.wav", "one-shot")
s808.CB = Sample.new("/home/we/dust/audio/common/808/808-CB.wav", "one-shot")
s808.CP = Sample.new("/home/we/dust/audio/common/808/808-CP.wav", "one-shot")
s808.HT = Sample.new("/home/we/dust/audio/common/808/808-HT.wav", "one-shot")
s808.MA = Sample.new("/home/we/dust/audio/common/808/808-MA.wav", "one-shot")
s808.OH = Sample.new("/home/we/dust/audio/common/808/808-OH.wav", "one-shot")

-- Handy shortcuts
function BD() s808.BD:noteOn() end
function BD() s808.BD:noteOn() end
function CH() s808.CH:noteOn() end
function CY() s808.CY:noteOn() end
function LC() s808.LC:noteOn() end
function MC() s808.MC:noteOn() end
function RS() s808.RS:noteOn() end
function BS() s808.BS:noteOn() end
function CL() s808.CL:noteOn() end
function HC() s808.HC:noteOn() end
function LT() s808.LT:noteOn() end
function MT() s808.MT:noteOn() end
function SD() s808.SD:noteOn() end
function CB() s808.CB:noteOn() end
function CP() s808.CP:noteOn() end
function HT() s808.HT:noteOn() end
function MA() s808.MA:noteOn() end
function OH() s808.OH:noteOn() end

-- s4 = Sample.new("/home/we/dust/code/repl-looper/audio/excerpts/The-Call-of-the-Polar-Star_fma-115766_001_00-00-01.ogg")
s3 = Sample.new("/home/we/dust/code/repl-looper/audio/one_shots/The-Call-of-the-Polar-Star_fma-115766_001_00-00-01.ogg")

function tabkeys(tab)
  local keyset={}
  local n=0

  for k,v in pairs(tab) do
    n=n+1
    keyset[n]=k
  end
  return keyset
end

function ls(o)
  return tabkeys(getmetatable(o))
end

-- this.addCommand(\generateWaveform, "i", {
-- this.addCommand(\noteOffAll, "", {
-- this.addCommand(\noteKillAll, "", {
-- this.addCommand(\pitchBendVoice, "if", {
-- this.addCommand(\pitchBendAll, "f", {
-- this.addCommand(\pressureVoice, "if", {
-- this.addCommand(\pressureAll, "f", {

-- this.addCommand(\lfo1Freq, "f", { arg msg;
-- this.addCommand(\lfo1WaveShape, "i", { arg msg;
-- this.addCommand(\lfo2Freq, "f", { arg msg;
-- this.addCommand(\lfo2WaveShape, "i", { arg msg;

-- this.addCommand(\loadSample, "is", {
-- this.addCommand(\clearSamples, "ii", {
-- this.addCommand(\moveSample, "ii", {
-- this.addCommand(\copySample, "iii", {
-- this.addCommand(\copyParams, "iii", {

