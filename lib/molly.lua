
---------------------------------------------------------------------
-- Molly The Poly objectized! ---------------------------------------
---------------------------------------------------------------------

local ControlSpec = require "controlspec"
local musicutil = include("repl-looper/lib/musicutil_extended")

local specs = {}
local options = {}

options.OSC_WAVE_SHAPE = {"Triangle", "Saw", "Pulse"}
specs.PW_MOD = ControlSpec.new(0, 1, "lin", 0, 0.2, "")
options.PW_MOD_SRC = {"LFO", "Env 1", "Manual"}

specs.FREQ_MOD_LFO = ControlSpec.UNIPOLAR
specs.FREQ_MOD_ENV = ControlSpec.BIPOLAR
specs.GLIDE = ControlSpec.new(0, 5, "lin", 0, 0, "s")

specs.MAIN_OSC_LEVEL = ControlSpec.new(0, 1, "lin", 0, 1, "")
specs.SUB_OSC_LEVEL = ControlSpec.UNIPOLAR
specs.SUB_OSC_DETUNE = ControlSpec.new(-5, 5, "lin", 0, 0, "ST")
specs.NOISE_LEVEL = ControlSpec.new(0, 1, "lin", 0, 0.1, "")

specs.HP_FILTER_CUTOFF = ControlSpec.new(10, 20000, "exp", 0, 10, "Hz")
specs.LP_FILTER_CUTOFF = ControlSpec.new(20, 20000, "exp", 0, 300, "Hz")
specs.LP_FILTER_RESONANCE = ControlSpec.new(0, 1, "lin", 0, 0.1, "")
options.LP_FILTER_TYPE = {"-12 dB/oct", "-24 dB/oct"}
options.LP_FILTER_ENV = {"Env-1", "Env-2"}
specs.LP_FILTER_CUTOFF_MOD_ENV = ControlSpec.new(-1, 1, "lin", 0, 0.25, "")
specs.LP_FILTER_CUTOFF_MOD_LFO = ControlSpec.UNIPOLAR
specs.LP_FILTER_TRACKING = ControlSpec.new(0, 2, "lin", 0, 1, ":1")

specs.LFO_FREQ = ControlSpec.new(0.05, 20, "exp", 0, 5, "Hz")
options.LFO_WAVE_SHAPE = {"Sine", "Triangle", "Saw", "Square", "Random"}
specs.LFO_FADE = ControlSpec.new(-15, 15, "lin", 0, 0, "s")

specs.ENV_ATTACK = ControlSpec.new(0.002, 5, "lin", 0, 0.01, "s")
specs.ENV_DECAY = ControlSpec.new(0.002, 10, "lin", 0, 0.3, "s")
specs.ENV_SUSTAIN = ControlSpec.new(0, 1, "lin", 0, 0.5, "")
specs.ENV_RELEASE = ControlSpec.new(0.002, 10, "lin", 0, 0.5, "s")

specs.AMP = ControlSpec.new(0, 11, "lin", 0, 0.5, "")
specs.AMP_MOD = ControlSpec.UNIPOLAR

specs.RING_MOD_FREQ = ControlSpec.new(10, 300, "exp", 0, 50, "Hz")
specs.RING_MOD_FADE = ControlSpec.new(-15, 15, "lin", 0, 0, "s")
specs.RING_MOD_MIX = ControlSpec.UNIPOLAR

specs.CHORUS_MIX = ControlSpec.new(0, 1, "lin", 0, 0.8, "")

local Molly = {}
Molly.__index = Molly
Molly.next_id = 0

function Molly.new(play_mode)
  local self = {
    mode = play_mode or "single", -- single note at a time or multi (deal with note-off)
    track_id = 0,
    params = {
      pitchBendRatio = 1,
      oscWaveShape = 0,
      pwMod = 0,
      pwModSource = 0,
      freqModLfo = 0,
      freqModEnv = 0,
      lastFreq = 0,
      glide = 0,
      mainOscLevel = 1,
      subOscLevel = 0,
      subOscDetune = 0,
      noiseLevel = 0,
      hpFilterCutoff = 10,
      lpFilterType = 0,
      lpFilterCutoff = 440,
      lpFilterResonance = 0.2,
      lpFilterCutoffEnvSelect = 0,
      lpFilterCutoffModEnv = 0,
      lpFilterCutoffModLfo = 0,
      lpFilterTracking = 1,
      lfoFade = 0,
      env1Attack = 0.01,
      env1Decay = 0.3,
      env1Sustain = 0.5,
      env1Release = 0.5,
      env2Attack = 0.01,
      env2Decay = 0.3,
      env2Sustain = 0.5,
      env2Release = 0.5,
      ampMod = 0,
      channelPressure = 0,
      timbre = 0,
      ringModFade = 0,
      ringModMix = 0,
      chorusMix = 0,
    }
  }
  setmetatable(self, Molly)

  self.id = Molly.next_id
  Molly.next_id = Molly.next_id + 1

  return self
end

function Molly:setParam(funcName, ...)
  local arg = table.pack(...)
  if arg.n > 1 then
    self.params[funcName] = {...}
  else
    self.params[funcName] = ...
  end
end

local mollyVoiceFunctions = {
  noteOn = "mollyNoteOn",
  -- noteOff = "mollyNoteOff",
  pitchBend = "mollyPitchBend",
  noteKill = "mollyNoteKill",
  pressure = "mollyPressure",
  timbre = "mollyTimbre",
  trace = "mollyTrace"
}

for funcName, engineFuncName in pairs(mollyVoiceFunctions) do
  Molly[funcName] = function(self, ...)

    local id;
    if self.mode == "single" then
      id = self.id
    else
      local freq = ...
      id = musicutil.freq_to_note_num(freq)
    end

    -- print("calling", funcName, engineFuncName, self.id, id, ...)
    engine[engineFuncName](self.id, id, ...)
    self:setParam(funcName, ...)
  end
end

function Molly:noteOff(freq)
  -- print("noteOff", freq)
  local id;
  if self.mode == "single" then
    id = self.id
  else
    id = musicutil.freq_to_note_num(freq)
  end
  -- print("calling mollyNoteOff", self.id, id)
  engine.mollyNoteOff(self.id, id)
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
  -- lfoFade = "mollyLfoFade",
  env1Attack = "mollyEnv1Attack",
  env1Decay = "mollyEnv1Decay",
  env1Sustain = "mollyEnv1Sustain",
  env1Release = "mollyEnv1Release",
  env2Attack = "mollyEnv2Attack",
  env2Decay = "mollyEnv2Decay",
  env2Sustain = "mollyEnv2Sustain",
  env2Release = "mollyEnv2Release",
  ampMod = "mollyAmpMod",
  -- ringModFade = "mollyRingModFade",
  ringModMix = "mollyRingModMix",
  amp = "mollyAmp",
  chorusMix = "mollyChorusMix",
  lfoFreq = "mollyLfoFreq",
  lfoWaveShape = "mollyLfoWaveShape",
  ringModFreq = "mollyRingModFreq"
}

for funcName, engineFuncName in pairs(mollyFunctions) do
  Molly[funcName] = function(self, ...)
    -- print("calling", funcName, engineFuncName, self.id, ...)
    engine[engineFuncName](self.id, ...)
    self:setParam(funcName, ...)
  end
end

function Molly:note(note, voice_id)
  local voice_id = voice_id or self.id
  local note = note or 60
  local freq = 0

  -- If we got an array, play them all!
  if type(note) == "table" then
    for i, n in ipairs(note) do
      self:note(n)
    end
    return
  end

  if string.match(note, "^%a") then
    if not string.find(note, "%d") then
      note = note .. "3"
    end
    note = string.upper(note)
    freq = musicutil.note_name_to_freq(note)
    note = musicutil.note_name_to_num(note)
  else
    freq = musicutil.note_num_to_freq(note)
  end

  self.track_id = current_context_loop_id
  self:noteOn(freq, 1, self.track_id)
end

function Molly:offNote(note, voice_id)
  local voice_id = voice_id or self.id
  local note = note or 60
  local freq = 0

  -- If we got an array, play them all!
  if type(note) == "table" then
    for i, n in ipairs(note) do
      self:offNote(n)
    end
    return
  end

  if string.match(note, "^%a") then
    if not string.find(note, "%d") then
      note = note .. "3"
    end
    note = string.upper(note)
    freq = musicutil.note_name_to_freq(note)
    note = musicutil.note_name_to_num(note)
  else
    freq = musicutil.note_num_to_freq(note)
  end

  self:noteOff(freq)
end

function Molly:play() self:note() end
function Molly:stop() self:noteOffAll() end
function Molly:kill() self:noteKillAll() end

function Molly:lfoFade(value)
  if value < 0 then value = specs.LFO_FADE.minval - 0.00001 + math.abs(value) end
  engine.mollyLfoFade(self.id, value)
  self:setParam("lfoFade", value)
end

function Molly:ringModFade(value)
  if value < 0 then value = specs.RING_MOD_FADE.minval - 0.00001 + math.abs(value) end
  engine.mollyRingModFade(self.id, value)
  self:setParam("ringModFade", value)
end

function Molly:randomize(sound_type, save_seed)
  sound_type = sound_type or "lead"

  self:oscWaveShape(math.random(#options.OSC_WAVE_SHAPE) - 1)
  self:pwMod(math.random())
  self:pwModSource(math.random(#options.PW_MOD_SRC) - 1)

  self:lpFilterType(math.random(#options.LP_FILTER_TYPE) - 1)
  self:lpFilterCutoffEnvSelect(math.random(#options.LP_FILTER_ENV) - 1)
  self:lpFilterTracking(util.linlin(0, 1, specs.LP_FILTER_TRACKING.minval, specs.LP_FILTER_TRACKING.maxval, math.random()))

  self:lfoFreq(util.linlin(0, 1, specs.LFO_FREQ.minval, specs.LFO_FREQ.maxval, math.random()))
  self:lfoWaveShape(math.random(#options.LFO_WAVE_SHAPE) - 1)
  self:lfoFade(util.linlin(0, 1, specs.LFO_FADE.minval, specs.LFO_FADE.maxval, math.random()))

  self:env1Decay(util.linlin(0, 1, specs.ENV_DECAY.minval, specs.ENV_DECAY.maxval, math.random()))
  self:env1Sustain(math.random())
  self:env1Release(util.linlin(0, 1, specs.ENV_RELEASE.minval, specs.ENV_RELEASE.maxval, math.random()))

  self:ringModFreq(util.linlin(0, 1, specs.RING_MOD_FREQ.minval, specs.RING_MOD_FREQ.maxval, math.random()))
  self:chorusMix(math.random())

  if sound_type == "lead" then

    self:freqModLfo(util.linexp(0, 1, 0.0000001, 0.1, (math.random() ^ 2)))
    if math.random() > 0.95 then
      self:freqModEnv(util.linlin(0, 1, -0.06, 0.06, math.random()))
    else
      self:freqModEnv(0)
    end

    self:glide(util.linexp(0, 1, 0.0000001, 1, (math.random() ^ 2)))

    if math.random() > 0.8 then
      self:mainOscLevel(1)
      self:subOscLevel(0)
    else
      self:mainOscLevel(math.random())
      self:subOscLevel(math.random())
    end
    if math.random() > 0.9 then
      self:subOscDetune(util.linlin(0, 1, specs.SUB_OSC_DETUNE.minval, specs.SUB_OSC_DETUNE.maxval, math.random()))
    else
      local detune = {0, 0, 0, 4, 5, -4, -5}
      self:subOscDetune(detune[math.random(1, #detune)] + math.random() * 0.01)
    end
    self:noiseLevel(util.linexp(0, 1, 0.0000001, 1, math.random()))

    if math.abs(self.params.subOscDetune) > 0.7 and self.params.subOscLevel > self.params.mainOscLevel and self.params.subOscLevel > self.params.noiseLevel then
      self:mainOscLevel(self.params.subOscLevel + 0.2)
    end

    self:lpFilterCutoff(util.linexp(0, 1, 100, specs.LP_FILTER_CUTOFF.maxval, (math.random() ^ 2)))
    self:lpFilterResonance(math.random() * 0.9)
    self:lpFilterCutoffModEnv(util.linlin(0, 1, math.random(-1, 0), 1, math.random()))
    self:lpFilterCutoffModLfo(math.random() * 0.2)

    self:env2Attack(util.linexp(0, 1, specs.ENV_ATTACK.minval, 0.5, math.random()))
    self:env2Decay(util.linlin(0, 1, specs.ENV_DECAY.minval, specs.ENV_DECAY.maxval, math.random()))
    self:env2Sustain(math.random())
    self:env2Release(util.linlin(0, 1, specs.ENV_RELEASE.minval, 3, math.random()))

    if(math.random() > 0.8) then
      self:env1Attack(self.params.env2Attack)
    else
      self:env1Attack(util.linlin(0, 1, specs.ENV_ATTACK.minval, 1, math.random()))
    end

    if self.params.env2Decay < 0.2 and self.params.env2Sustain < 0.15 then
      self:env2Decay(util.linlin(0, 1, 0.2, specs.ENV_DECAY.maxval, math.random()))
    end

    local amp_max = 0.9
    if math.random() > 0.8 then amp_max = 11 end
    self:amp(util.linlin(0, 1, 0.75, amp_max, math.random()))
    self:ampMod(util.linlin(0, 1, 0, 0.5, math.random()))

    self:ringModFade(util.linlin(0, 1, specs.RING_MOD_FADE.minval * 0.8, specs.RING_MOD_FADE.maxval * 0.3, math.random()))
    if(math.random() > 0.8) then
      self:ringModMix((math.random() ^ 2))
    else
      self:ringModMix(0)
    end


  elseif sound_type == "pad" then

    self:freqModLfo(util.linexp(0, 1, 0.0000001, 0.2, (math.random() ^ 4)))
    if math.random() > 0.8 then
      self:freqModEnv(util.linlin(0, 1, -0.1, 0.2, (math.random() ^ 4)))
    else
      self:freqModEnv(0)
    end

    self:glide(util.linexp(0, 1, 0.0000001, specs.GLIDE.maxval, (math.random() ^ 2)))

    self:mainOscLevel(math.random())
    self:subOscLevel(math.random())
    if math.random() > 0.7 then
      self:subOscDetune(util.linlin(0, 1, specs.SUB_OSC_DETUNE.minval, specs.SUB_OSC_DETUNE.maxval, math.random()))
    else
      self:subOscDetune(math.random(specs.SUB_OSC_DETUNE.minval, specs.SUB_OSC_DETUNE.maxval) + math.random() * 0.01)
    end
    self:noiseLevel(util.linexp(0, 1, 0.0000001, 1, math.random()))

    if math.abs(self.params.subOscDetune) > 0.7 and self.params.subOscLevel > self.params.mainOscLevel  and self.params.subOscLevel > self.params.noiseLevel then
      self:mainOscLevel(self.params.subOscLevel + 0.2)
    end

    self:lpFilterCutoff(util.linexp(0, 1, 100, specs.LP_FILTER_CUTOFF.maxval, math.random()))
    self:lpFilterResonance(math.random())
    self:lpFilterCutoffModEnv(util.linlin(0, 1, -1, 1, math.random()))
    self:lpFilterCutoffModLfo(math.random())

    self:env1Attack(util.linlin(0, 1, specs.ENV_ATTACK.minval, specs.ENV_ATTACK.maxval, math.random()))

    self:env2Attack(util.linlin(0, 1, specs.ENV_ATTACK.minval, specs.ENV_ATTACK.maxval, math.random()))
    self:env2Decay(util.linlin(0, 1, specs.ENV_DECAY.minval, specs.ENV_DECAY.maxval, math.random()))
    self:env2Sustain(0.1 + math.random() * 0.9)
    self:env2Release(util.linlin(0, 1, 0.5, specs.ENV_RELEASE.maxval, math.random()))

    self:amp(util.linlin(0, 1, 0.5, 0.8, math.random()))
    self:ampMod(math.random())

    self:ringModFade(util.linlin(0, 1, specs.RING_MOD_FADE.minval, specs.RING_MOD_FADE.maxval, math.random()))
    if(math.random() > 0.8) then
      self:ringModMix(math.random())
    else
      self:ringModMix(0)
    end

  else -- Perc

    self:freqModLfo(util.linexp(0, 1, 0.0000001, 1, (math.random() ^ 2)))
    self:freqModEnv(util.linlin(0, 1, specs.FREQ_MOD_ENV.minval, specs.FREQ_MOD_ENV.maxval, (math.random() ^ 4)))

    self:glide(util.linexp(0, 1, 0.0000001, specs.GLIDE.maxval, (math.random() ^ 2)))

    self:mainOscLevel(math.random())
    self:subOscLevel(math.random())
    self:subOscDetune(util.linlin(0, 1, specs.SUB_OSC_DETUNE.minval, specs.SUB_OSC_DETUNE.maxval, math.random()))
    self:noiseLevel(util.linlin(0, 1, 0.1, 1, math.random()))

    self:lpFilterCutoff(util.linexp(0, 1, 100, 6000, math.random()))
    if math.random() > 0.6 then
      self:lpFilterResonance(util.linlin(0, 1, 0.5, 1, math.random()))
    else
      self:lpFilterResonance(math.random())
    end
    self:lpFilterCutoffModEnv(util.linlin(0, 1, -0.3, 1, math.random()))
    self:lpFilterCutoffModLfo(math.random())

    self:env1Attack(util.linlin(0, 1, specs.ENV_ATTACK.minval, specs.ENV_ATTACK.maxval, math.random()))

    self:env2Attack(specs.ENV_ATTACK.minval)
    self:env2Decay(util.linlin(0, 1, 0.008, 1.8, (math.random() ^ 4)))
    self:env2Sustain(0)
    self:env2Release(self.params.env2Decay)

    if self.params.env2Decay < 0.15 and self.params.env1Attack > 1 then
      self:env1Attack(self.params.env2Decay)
    end

    local amp_max = 1
    if math.random() > 0.7 then amp_max = 11 end
    self:amp(util.linlin(0, 1, 0.75, amp_max, math.random()))
    self:ampMod(util.linlin(0, 1, 0, 0.2, math.random()))

    self:ringModFade(util.linlin(0, 1, specs.RING_MOD_FADE.minval, 2, math.random()))
    if(math.random() > 0.4) then
      self:ringModMix(math.random())
    else
      self:ringModMix(0)
    end

  end

  if self.params.mainOscLevel < 0.6 and self.params.subOscLevel < 0.6 and self.params.noiseLevel < 0.6 then
    self:mainOscLevel(util.linlin(0, 1, 0.6, 1, math.random()))
  end

  if self.params.lpFilterCutoff > 12000 and math.random() > 0.7 then
    self:hpFilterCutoff(util.linexp(0, 1, specs.HP_FILTER_CUTOFF.minval, self.params.lpFilterCutoff * 0.05, math.random()))
  else
    self:hpFilterCutoff(specs.HP_FILTER_CUTOFF.minval)
  end

  if self.params.lpFilterCutoff < 600 and self.params.lpFilterCutoffModEnv < 0 then
    self:lpFilterCutoffModEnv(math.abs(self.params.lpFilterCutoffModEnv))
  end
end

function Molly:notRandom(seed, sound_type)
  if not seed then seed = math.random(100000) end
  math.randomseed(seed)
  math.random() -- Seems unecessary :shrug:
  self:randomize(sound_type)
  return seed
end

return Molly

