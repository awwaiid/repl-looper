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

  for _, event in ipairs(loop.events) do
    print("Converting event " .. json.encode(event))
    event_phase_scalar = clock.get_tempo() * l.ppqn / 60 / 1000
    event_phase = event_phase_scalar * event.relativeTime
    print("Phase offset: " .. event_phase)

    action = function(t)
      print("Action! @" .. t .. " next @" .. (l.ppqn * l.meter * 4 + t))
      load(event.command)()
    end

    pattern = l:new_pattern{
      action = action,
      division = 16 / 4,
      enabled = true
    }
    pattern.phase = (-1 * event_phase) + (l.ppqn * l.meter * 4)
  end

  count = 0
  l:new_pattern{
    action = function(t)
      messageFromServer({ action = "playback_step", step = count })
      -- print("boom! " .. (count + 1))
      count = (count + 1) % 16
    end,
    division = 1/4,
    enabled = true
  }

  return l
end

-- Music utilities
engine.load('PolyPerc')

function beep(freq)
  engine.hz(freq or 440)
end
