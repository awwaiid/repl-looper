
local Granchild = {}
Granchild.__index = Granchild
Granchild.next_id = 1

Granchild.instances = {}

function Granchild.new(filename)
  local self = {}

  setmetatable(self, Granchild)

  self.id = Granchild.next_id
  Granchild.next_id = Granchild.next_id + 1

  Granchild.instances[self.id] = self

  if filename then
    self:load(filename)
  end

  return self
end

function Granchild:load(filename)
  if not string.find(filename, "/") then
    filename = "/home/we/dust/code/repl-looper/audio/" .. filename
  end
  self.filename = filename
  engine.zglut_read(self.id, filename)
end

function Granchild:play()
  self:track(current_context_loop_id)
  engine.zglut_gate(self.id, 1)
end

function Granchild:stop()
  engine.zglut_gate(self.id, 0)
end

function Granchild:seek(pos)
  self:track(current_context_loop_id)
  engine.zglut_seek(self.id, pos)
end

function Granchild:speed(speed)
  engine.zglut_speed(self.id, speed)
end

function Granchild:jitter(jitter)
  engine.zglut_jitter(self.id, jitter)
end

function Granchild:size(size)
  engine.zglut_size(self.id, size)
end

function Granchild:density(density)
  engine.zglut_density(self.id, density)
end

function Granchild:pan(pan)
  engine.zglut_pan(self.id, pan)
end

function Granchild:pitch(pitch)
  engine.zglut_pitch(self.id, pitch)
end

function Granchild:spread(spread)
  engine.zglut_spread(self.id, spread)
end

function Granchild:gain(gain)
  engine.zglut_gain(self.id, gain)
end

function Granchild:envscale(envscale)
  engine.zglut_envscale(self.id, envscale)
end

function Granchild:cutoff(cutoff)
  engine.zglut_cutoff(self.id, cutoff)
end

function Granchild:q(q)
  engine.zglut_q(self.id, q)
end

function Granchild:send(send)
  engine.zglut_send(self.id, send)
end

function Granchild:amp(volume)
  engine.zglut_volume(self.id, volume)
end

function Granchild:overtones(overtones)
  engine.zglut_overtones(self.id, overtones)
end

function Granchild:subharmonics(subharmonics)
  engine.zglut_subharmonics(self.id, subharmonics)
end

function Granchild:delay_time(delay_time)
  engine.zglut_delay_time(self.id, delay_time)
end

function Granchild:delay_damp(delay_damp)
  engine.zglut_delay_damp(self.id, delay_damp)
end

function Granchild:delay_size(delay_size)
  engine.zglut_delay_size(self.id, delay_size)
end

function Granchild:delay_diff(delay_diff)
  engine.zglut_delay_diff(self.id, delay_diff)
end

function Granchild:delay_fdbk(delay_fdbk)
  engine.zglut_delay_fdbk(self.id, delay_fdbk)
end

function Granchild:delay_mod_depth(delay_mod_depth)
  engine.zglut_delay_mod_depth(self.id, delay_mod_depth)
end

function Granchild:delay_mod_freq(delay_mod_freq)
  engine.zglut_delay_mod_freq(self.id, delay_mod_freq)
end

function Granchild:delay_volume(delay_volume)
  engine.zglut_delay_volume(self.id, delay_volume)
end

function Granchild:track(track_id)
  engine.zglut_track(self.id, track_id)
end

function Granchild._fileLoaded(id, numFrames)
  local self = Granchild.instances[id]
  if self then
    self.numFrames = numFrames
    if self.on_load then
      self:on_load()
    end
  end
end

return Granchild;

