---------------------------------------------------------------------
-- Sample player based on GoldenEye ---------------------------------
---------------------------------------------------------------------

local Sample = {}
Sample.__index = Sample
Sample.next_id = 0

function Sample.new(filename, play_mode)
  local self = {
    params = {},
    filename = filename,
    loops = 100000,
    ampLevel = 1,
    ampLag = 0,
    playRate = 1,
    loop = 1
  }
  setmetatable(self, Sample)

  self.id = Sample.next_id
  Sample.next_id = Sample.next_id + 1

  if play_mode then
    if play_mode == "one-shot" then
      self.loops = 1
    end
  end

  -- Load it once to get the number of frames
  -- Runs as a 0-amp so doesn't make sound
  engine.goldeneyePlay(
    self.id,
    self.filename,
    0, -- amp
    0, -- ampLag
    0, --sampleStart (0..1)
    1, -- sampleEnd (0..1)
    0, -- loop?
    1, -- rate (0..1)
    1 -- t_trig
  )

  return self
end

function Sample:play(startFrame, endFrame)
  startFrame = startFrame or 0
  endFrame = endFrame or self:info().num_frames

  startAt = self:frame_to_fraction(startFrame)
  endAt = self:frame_to_fraction(endFrame)

  engine.goldeneyePlay(
    self.id,
    self.filename,
    self.ampLevel, -- amp
    self.ampLag, -- ampLag
    startAt, --sampleStart (0..1)
    endAt, -- sampleEnd (0..1)
    self.loops, -- loop?
    self.playRate, -- rate (0..1)
    1 -- t_trig
  )
end

function Sample:amp(ampLevel, ampLag)
  self.ampLevel = ampLevel or self.ampLevel
  self.ampLag = ampLag or self.ampLag
  engine.goldeneyeAmp(self.id, self.ampLevel, self.ampLag)
end

function Sample:pan(pan)
  engine.samplerPan(self.id, pan)
end

function Sample:rate(playRate)
  self.playRate = playRate or self.playRate
  engine.goldeneyeRate(self.id, self.playRate)
end

function Sample:pos(pos, rate)
  rate = rate or 1
  engine.samplerPos(self.id, pos, rate)
end

function Sample:loop(startAt, endAt, times)
  startAt = startAt or 0
  endAt = endAt or 1
  times = times or self.loops
  engine.samplerLoop(self.id, startAt, endAt, times)
end

function Sample:loopFrames(startAt, endAt, times)
  startAt = self:frame_to_fraction(startAt)
  endAt = self:frame_to_fraction(endAt)
  times = times or 100000
  engine.samplerLoop(self.id, startAt, endAt, times)
end

-- function Sample:play()
--   self:pos(0)
--   self:amp(1, 0)
-- end

function Sample:stop()
  engine.goldeneyeAmp(self.id, 0, self.ampLag)
end

function Sample:info()
  return ReplLooper.goldeneye_meta[self.id]
end

function Sample:frame_to_fraction(frame)
  return frame / self:info().num_frames
end

function Sample:startFrame(frame)
  engine.samplerStart(self.id, self:frame_to_fraction(frame) )
end

function Sample:endFrame(frame)
  engine.samplerEnd(self.id, self:frame_to_fraction(frame) )
end

return Sample

