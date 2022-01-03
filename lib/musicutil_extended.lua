
local MusicUtil = require "musicutil"

-- Reverse note name -> num lookup
local note_name_num = {}

for num=1,127 do
  local name = MusicUtil.note_num_to_name(num, true)
  note_name_num[name] = num
end

-- Add these into MusicUtil because why not
function MusicUtil.note_name_to_num(name)
  return note_name_num[name]
end

function MusicUtil.note_name_to_freq(name)
  return MusicUtil.note_num_to_freq(MusicUtil.note_name_to_num(name))
end

return MusicUtil

