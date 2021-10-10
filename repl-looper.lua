-- repl-looper v0.0.1
-- Anagogical mash of code, time, sound
--
-- llllllll.co/t/repl-looper
--
-- Use in conjunction with laptop running the UI

json = require("cjson")
lattice = require("lattice")

loops = {}

-- REPL communication
function messageToServer(json_msg)
  local msg = json.decode(json_msg)
  if msg.command == "save_loop" then
    loops[msg.loop_num] = msg.loop
  else
    print "UNKNOWN COMMAND\n"
  end
end

function messageFromServer(msg)
  local msg_json = json.encode(msg)
  print("SERVER MESSAGE: " .. msg_json .. "\n")
end

function loopToLattice(loop)
  l = lattice:new{}

  -- Convert milliseconds into pulse offset
  qn_per_ms = clock.get_tempo() / 60 / 1000
  pulse_per_ms = qn_per_ms * l.ppqn
  pulse_per_measure = l.ppqn * l.meter

  -- We use ceil here, so will grow loop-length to the next full quarter note
  loop_length_qn = math.ceil(loop.duration * qn_per_ms)
  loop_length_measure = loop_length_qn / l.meter

  print("pulse/ms = " .. pulse_per_ms)
  print("qn/ms = " .. qn_per_ms)
  print("pulse/measure = " .. pulse_per_measure)
  print("loop length qn = " .. loop_length_qn)
  print("loop length measure = " .. loop_length_measure)

  for _, event in ipairs(loop.events) do
    print("Converting event " .. json.encode(event))

    event_pulse_offset = pulse_per_ms * event.relativeTime
    print("pulse offset: " .. event_pulse_offset)

    action = function(t)
      print("Command @" .. t .. " next @" .. (loop_length_measure * pulse_per_measure + t) .. " -- " .. event.command)
      load(event.command)()
    end

    pattern = l:new_pattern{
      action = action,
      -- division = 16 / 4,
      division = loop_length_measure, -- division is in measures
      enabled = true
    }

    pattern.phase = loop_length_measure * pulse_per_measure - event_pulse_offset
  end

  count = 0
  l:new_pattern{
    action = function(t)
      messageFromServer({ action = "playback_step", step = count, stepCount = loop_length_qn })
      print("step " .. (count + 1) .. " @" .. t)
      count = (count + 1) % loop_length_qn
    end,
    division = 1/4,
    enabled = true
  }

  return l
end

lattices = {}

function play_loop(n)
  loop_num = n or 1
  -- lattices[n or 1] = lattices[n or 1] or loopToLattice(loop[n])
  lattices[loop_num] = loopToLattice(loops[loop_num])
  lattices[loop_num]:start()
end

function stop_loop(n)
  loop_num = n or 1
  lattices[loop_num]:stop()
end

-- Music utilities
engine.load('PolyPerc')

function beep(freq)
  engine.hz(freq or 440)
end
