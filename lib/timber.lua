---------------------------------------------------------------------
-- Timber! ----------------------------------------------------------
---------------------------------------------------------------------

local Timber = {}
Timber.__index = Timber
Timber.next_id = 0

function Timber.new(filename, play_mode)
  local self = {
    params = {}
  }
  setmetatable(self, Timber)

  self.id = Timber.next_id
  Timber.next_id = Timber.next_id + 1

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
function Timber:pitchBend(n) self.params.pitchBend = n; engine.pitchBendSample(self.id, n) end
function Timber:pressure(n) self.params.pressure = n; engine.pressureSample(self.id, n) end
function Timber:transpose(n) self.params.transpose = n; engine.transpose(self.id, n) end
function Timber:detuneCents(n) self.params.detuneCents = n; engine.detuneCents(self.id, n) end
function Timber:startFrame(n) self.params.startFrame = n; engine.startFrame(self.id, n) end
function Timber:endFrame(n) self.params.endFrame = n; engine.endFrame(self.id, n) end
function Timber:playMode(n) self.params.playMode = n; engine.playMode(self.id, n) end
function Timber:loopStartFrame(n) self.params.loopStartFrame = n; engine.loopStartFrame(self.id, n) end
function Timber:loopEndFrame(n) self.params.loopEndFrame = n; engine.loopEndFrame(self.id, n) end
function Timber:lfo1Fade(n) self.params.lfo1Fade = n; engine.lfo1Fade(self.id, n) end
function Timber:lfo2Fade(n) self.params.lfo2Fade = n; engine.lfo2Fade(self.id, n) end
function Timber:freqModLfo1(n) self.params.freqModLfo1 = n; engine.freqModLfo1(self.id, n) end
function Timber:freqModLfo2(n) self.params.freqModLfo2 = n; engine.freqModLfo2(self.id, n) end
function Timber:freqModEnv(n) self.params.freqModEnv = n; engine.freqModEnv(self.id, n) end
function Timber:freqMultiplier(n) self.params.freqMultiplier = n; engine.freqMultiplier(self.id, n) end
function Timber:ampAttack(n) self.params.ampAttack = n; engine.ampAttack(self.id, n) end
function Timber:ampDecay(n) self.params.ampDecay = n; engine.ampDecay(self.id, n) end
function Timber:ampSustain(n) self.params.ampSustain = n; engine.ampSustain(self.id, n) end
function Timber:ampRelease(n) self.params.ampRelease = n; engine.ampRelease(self.id, n) end
function Timber:modAttack(n) self.params.modAttack = n; engine.modAttack(self.id, n) end
function Timber:modDecay(n) self.params.modDecay = n; engine.modDecay(self.id, n) end
function Timber:modSustain(n) self.params.modSustain = n; engine.modSustain(self.id, n) end
function Timber:modRelease(n) self.params.modRelease = n; engine.modRelease(self.id, n) end
function Timber:downSampleTo(n) self.params.downSampleTo = n; engine.downSampleTo(self.id, n) end
function Timber:bitDepth(n) self.params.bitDepth = n; engine.bitDepth(self.id, n) end
function Timber:filterFreq(n) self.params.filterFreq = n; engine.filterFreq(self.id, n) end
function Timber:filterReso(n) self.params.filterReso = n; engine.filterReso(self.id, n) end
function Timber:filterType(n) self.params.filterType = n; engine.filterType(self.id, n) end
function Timber:filterTracking(n) self.params.filterTracking = n; engine.filterTracking(self.id, n) end
function Timber:filterFreqModLfo1(n) self.params.filterFreqModLfo1 = n; engine.filterFreqModLfo1(self.id, n) end
function Timber:filterFreqModLfo2(n) self.params.filterFreqModLfo2 = n; engine.filterFreqModLfo2(self.id, n) end
function Timber:filterFreqModEnv(n) self.params.filterFreqModEnv = n; engine.filterFreqModEnv(self.id, n) end
function Timber:filterFreqModVel(n) self.params.filterFreqModVel = n; engine.filterFreqModVel(self.id, n) end
function Timber:filterFreqModPressure(n) self.params.filterFreqModPressure = n; engine.filterFreqModPressure(self.id, n) end
function Timber:pan(n) self.params.pan = n; engine.pan(self.id, n) end
function Timber:panModLfo1(n) self.params.panModLfo1 = n; engine.panModLfo1(self.id, n) end
function Timber:panModLfo2(n) self.params.panModLfo2 = n; engine.panModLfo2(self.id, n) end
function Timber:panModEnv(n) self.params.panModEnv = n; engine.panModEnv(self.id, n) end
function Timber:amp(n) self.params.amp = n; engine.amp(self.id, n) end
function Timber:ampModLfo1(n) self.params.ampModLfo1 = n; engine.ampModLfo1(self.id, n) end
function Timber:ampModLfo2(n) self.params.ampModLfo2 = n; engine.ampModLfo2(self.id, n) end

function Timber:noteOn(freq, vol, voice)
  freq = freq or 261.625
  vol = vol or 1
  voice = voice or self.id -- TODO: voice management
  engine.noteOn(voice, freq, vol, self.id)
end

function Timber:play() self:noteOn() end
function Timber:stop() self:noteOff() end

function Timber:noteOff() engine.noteOff(self.id) end
function Timber:noteKill() engine.noteKill(self.id) end

function Timber:load_sample(filename)
  ReplLooper.add_sample_params(self.id)
  ReplLooper.load_sample(self.id, filename)
  self.sample_filename = filename
end

function Timber:info()
  return ReplLooper.samples_meta[self.id]
end

function Timber:position()
  return self:info().positions[self.id]
end

function Timber:framePosition()
  return self:position() * 48000
end

function Timber:reverse()
  self:startFrame(self:info().num_frames - 1)
  self:endFrame(0)
end

function Timber:forward()
  self:startFrame(0)
  self:endFrame(self:info().num_frames - 1)
end

function Timber:note(note)
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

return Timber
