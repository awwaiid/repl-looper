
local musicutil = require "musicutil"

-- Reverse note name -> num lookup
local note_name_num = {}

for num=1,127 do
  local name = musicutil.note_num_to_name(num, true)
  note_name_num[name] = num
end

-- Add these into musicutil because why not
function musicutil.note_name_to_num(name)
  return note_name_num[name]
end

function musicutil.note_name_to_freq(name)
  return musicutil.note_num_to_freq(musicutil.note_name_to_num(name))
end

return musicutil

