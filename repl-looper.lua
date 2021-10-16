-- repl-looper v0.0.1
-- Anagogical mash of code, time, sound
--
-- llllllll.co/t/repl-looper
--
-- Use in conjunction with laptop running the UI


-- Add repl-looper lib dir in to load .so files like cjson.so
if not string.find(package.cpath,"/home/we/dust/code/repl-looper/lib/") then
  package.cpath=package.cpath..";/home/we/dust/code/repl-looper/lib/?.so"
end

json = require("cjson")
lattice = require("lattice")

-- Global Grid
g = grid.connect()

local Loop = {}
Loop.__index = Loop

function Loop.new(init)
  local self = init or {}
  setmetatable(self, Loop)
  self:update_lattice()
  return self
end

function Loop:hi()
  print "hi!!!"
end

function Loop:update_lattice()
  self.lattice = self.lattice or lattice:new{}
  self.current_step = self.current_step or 1

  -- Convert milliseconds into pulse offset
  qn_per_ms = clock.get_tempo() / 60 / 1000
  pulse_per_ms = qn_per_ms * self.lattice.ppqn
  pulse_per_measure = self.lattice.ppqn * self.lattice.meter

  -- We use ceil here, so will grow loop-length to the next full quarter note
  self.loop_length_qn = math.ceil(self.duration * qn_per_ms)
  loop_length_measure = self.loop_length_qn / self.lattice.meter

  print("pulse/ms = " .. pulse_per_ms)
  print("qn/ms = " .. qn_per_ms)
  print("pulse/measure = " .. pulse_per_measure)
  print("loop length qn = " .. self.loop_length_qn)
  print("loop length measure = " .. loop_length_measure)

  for _, event in ipairs(self.events) do
    -- print("Converting event " .. json.encode(event))

    event.pulse_offset = pulse_per_ms * event.relativeTime
    print("pulse offset: " .. event.pulse_offset)

    event.step = event.pulse_offset / self.lattice.ppqn + 1
    print("event step: " .. event.step)

    action = function(t)
      print("@" .. t .. " (next @" .. (loop_length_measure * pulse_per_measure + t) .. ") command: " .. event.command)
      load(event.command)()
    end

    event.pattern = event.pattern or self.lattice:new_pattern{}

    event.pattern:set_action(action)
    event.pattern:set_division(loop_length_measure) -- division is in measures

    -- Forcing the initial phase is what sets the actual offset
    -- TODO: can this be updated while playing? Does it need to be relative to
    -- the current lattice time or something?
    event.pattern.phase = loop_length_measure * pulse_per_measure - event.pulse_offset
  end

  -- Basically a quarter-note metronome
  count = 0
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
      print("Row: " .. json.encode(row))
      g:all(0)
      for n = 1, self.loop_length_qn do
        g:led(n, 1, row[n] or 0)
        print("led " .. n .. " " .. (row[n] or 0))
      end
      g:refresh()

      print("step " .. (count + 1) .. " @" .. t)
      count = (count + 1) % self.loop_length_qn
    end,
    division = 1/4
  }

  return l
end

function Loop:quantize()
  qn_per_ms = clock.get_tempo() / 60 / 1000

  for _, event in ipairs(self.events) do
    event.step = math.floor(event.step + 0.5)
    event.relativeTime = event.step / qn_per_ms
  end

  self:update_lattice()
end

function Loop:print()
  print("Length length qn: " .. self.loop_length_qn)
  print("Current step: " .. self.current_step)
  for _, event in ipairs(self.events) do
    print("  " .. event.step .. ": " .. event.command)
  end
end

function Loop:to_grid_row()
  local row = {}
  print("Length length qn: " .. self.loop_length_qn)
  print("Current step: " .. self.current_step)
  for n = 1, self.loop_length_qn do
    if n == self.current_step then
      row[n] = 10
    else
      row[n] = 0
    end
  end
  for _, event in ipairs(self.events) do
    print("  " .. event.step .. ": " .. event.command)
    local step = math.floor(event.step)
    if step == self.current_step then
      row[step] = 15
    else
      row[step] = 5
    end
  end


  return row
end

function Loop:start()
  self.lattice:start()
end

-- Alias for start because I keep forgetting
function Loop:play()
  self:start()
end

function Loop:stop()
  self.lattice:stop()
end

------------------------------------------------------

loops = {}

-- g.key = function(x, y, z) ... end

-- REPL communication
function messageToServer(json_msg)
  local msg = json.decode(json_msg)
  if msg.command == "save_loop" then
    loops[msg.loop_num] = Loop.new(msg.loop)

    -- Kinda evil shortcut!
    loop_letter = string.char(string.byte("a") + msg.loop_num - 1)
    print("Setting loop shortcut " .. loop_letter)
    _G[loop_letter] = loops[msg.loop_num]
  else
    print "UNKNOWN COMMAND\n"
  end
end

function messageFromServer(msg)
  local msg_json = json.encode(msg)
  print("SERVER MESSAGE: " .. msg_json .. "\n")
end

-- Music utilities
engine.load('PolyPerc')

function beep(freq)
  engine.hz(freq or 440)
end
