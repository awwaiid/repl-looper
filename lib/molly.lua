
---------------------------------------------------------------------
-- Molly The Poly wrapper! ------------------------------------------
---------------------------------------------------------------------

local Molly = {}
Molly.__index = Molly
Molly.next_id = 0

function Molly.new(filename, play_mode)
  local self = {
    params = {}
  }
  setmetatable(self, Molly)

  self.id = Molly.next_id
  Molly.next_id = Molly.next_id + 1

  return self
end

local mollyVoiceFunctions = {
  noteOn = "mollyNoteOn",
  noteOff = "mollyNoteOff",
  pitchBend = "mollyPitchBend",
  noteKill = "mollyNoteKill",
  pressure = "mollyPressure",
  timbre = "mollyTimbre"
}

for funcName, engineFuncName in pairs(mollyVoiceFunctions) do
  Molly[funcName] = function(self, ...)
    engine[engineFuncName](self.id, ...)
  end
end

local mollyFunctions = {
  noteOffAll = "mollyNoteOffAll",
  noteKillAll = "mollyNoteKillAll",
  pitchBendAll = "mollyPitchBendAll",
  pressureAll = "mollyPressureAll",
  timbreAll = "mollyTimbreAll",
  oscWaveShape = "mollyOscWaveShape",
  pwMod = "mollyPwMod",
  pwModSource = "mollyPwModSource",
  freqModLfo = "mollyFreqModLfo",
  freqModEnv = "mollyFreqModEnv",
  glide = "mollyGlide",
  mainOscLevel = "mollyMainOscLevel",
  subOscLevel = "mollySubOscLevel",
  subOscDetune = "mollySubOscDetune",
  noiseLevel = "mollyNoiseLevel",
  hpFilterCutoff = "mollyHpFilterCutoff",
  lpFilterType = "mollyLpFilterType",
  lpFilterCutoff = "mollyLpFilterCutoff",
  lpFilterResonance = "mollyLpFilterResonance",
  lpFilterCutoffEnvSelect = "mollyLpFilterCutoffEnvSelect",
  lpFilterCutoffModEnv = "mollyLpFilterCutoffModEnv",
  lpFilterCutoffModLfo = "mollyLpFilterCutoffModLfo",
  lpFilterTracking = "mollyLpFilterTracking",
  lfoFade = "mollyLfoFade",
  env1Attack = "mollyEnv1Attack",
  env1Decay = "mollyEnv1Decay",
  env1Sustain = "mollyEnv1Sustain",
  env1Release = "mollyEnv1Release",
  env2Attack = "mollyEnv2Attack",
  env2Decay = "mollyEnv2Decay",
  env2Sustain = "mollyEnv2Sustain",
  env2Release = "mollyEnv2Release",
  ampMod = "mollyAmpMod",
  ringModFade = "mollyRingModFade",
  ringModMix = "mollyRingModMix",
  amp = "mollyAmp",
  chorusMix = "mollyChorusMix",
  lfoFreq = "mollyLfoFreq",
  lfoWaveShape = "mollyLfoWaveShape",
  ringModFreq = "mollyRingModFreq"
}

for funcName, engineFuncName in pairs(mollyFunctions) do
  Molly[funcName] = function(self, ...)
    engine[engineFuncName](...)
  end
end

function Molly:randomize_params(sound_type)
  sound_type = sound_type or "lead"
  MollyThePoly.randomize_params(sound_type)
end

function Molly:note(note)
  local voice_id = self.id
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

  engine.mollyNoteOn(voice_id, freq, 1)
end

function Molly:play() self:note() end
function Molly:stop() self:noteOff() end

return Molly

