// CroneEngine - ReplLooper - v2.0.0
// By Brock Wilcox <awwaiid@thelackthereof.org>
//
// Adapted from Timber by Mark Eats
// Adapted from Molly The Poly by Mark Eats
// Adapted from Internorns by InfiniteDigits
// Adapted from Goldeneye by tyleretters

Engine_ReplLooper : CroneEngine {

  var maxVoices = 7;
  var maxSamples = 256;
  var killDuration = 0.003;
  var waveformDisplayRes = 60;

  var voiceGroup;
  var voiceList;
  var samples;
  var replyFunc;

  var players;
  var synthNames;
  var lfos;
  // var mixer;

  var lfoBus;
  // var mixerBus;

  var loadQueue;
  var loadingSample = -1;

  var scriptAddress;
  var waveformQueue;
  var waveformRoutine;
  var generatingWaveform = -1; // -1 not running
  var abandonCurrentWaveform = false;

  var pitchBendAllRatio = 1;
  var pressureAll = 0;

  var defaultSample;

  // var debugBuffer;


  ///////// MOLLY THE POLY SLICE ////////////////////////

  classvar mollyMaxNumVoices = 10;

  var instMollyMixerBus;
  var instMollyMixerSynth;

  var instMollyVoiceGroup;
  var instMollyVoiceList;

  var instMollyLfoBus;
  var instMollyLfo;

  var instMollyRingModBus;
  var instMollySettings;

  // var mollyPitchBendRatio = 1;
  // var mollyOscWaveShape = 0;
  // var mollyPwMod = 0;
  // var mollyPwModSource = 0;
  // var mollyFreqModLfo = 0;
  // var mollyFreqModEnv = 0;
  // var mollyLastFreq = 0;
  // var mollyGlide = 0;
  // var mollyMainOscLevel = 1;
  // var mollySubOscLevel = 0;
  // var mollySubOscDetune = 0;
  // var mollyNoiseLevel = 0;
  // var mollyHpFilterCutoff = 10;
  // var mollyLpFilterType = 0;
  // var mollyLpFilterCutoff = 440;
  // var mollyLpFilterResonance = 0.2;
  // var mollyLpFilterCutoffEnvSelect = 0;
  // var mollyLpFilterCutoffModEnv = 0;
  // var mollyLpFilterCutoffModLfo = 0;
  // var mollyLpFilterTracking = 1;
  // var mollyLfoFade = 0;
  // var mollyEnv1Attack = 0.01;
  // var mollyEnv1Decay = 0.3;
  // var mollyEnv1Sustain = 0.5;
  // var mollyEnv1Release = 0.5;
  // var mollyEnv2Attack = 0.01;
  // var mollyEnv2Decay = 0.3;
  // var mollyEnv2Sustain = 0.5;
  // var mollyEnv2Release = 0.5;
  // var mollyAmpMod = 0;
  // var mollyChannelPressure = 0;
  // var mollyTimbre = 0;
  // var mollyRingModFade = 0;
  // var mollyRingModMix = 0;
  // var mollyChorusMix = 0;

  ///////// END MOLLY THE POLY SLICE ////////////////////////

  var synSample;
  var bufSample;
  var mainBus;

  // <Goldeneye>
  var bufGoldeneye;
  var synGoldeneye;

  // </Goldeneye>

  var trackMixer;
  var trackBus;

  *new { arg context, doneCallback;
    ^super.new(context, doneCallback);
  }

  alloc {



    /////////////////// TRACKS //////////////////////

    trackMixer = Dictionary.new(8);
    trackBus = Dictionary.new(8);

    // Molly per-instance things
    instMollyVoiceList  = Dictionary.new(8);
    instMollyVoiceGroup = Dictionary.new(8);
    instMollyMixerBus   = Dictionary.new(8);
    instMollyMixerSynth = Dictionary.new(8);
    instMollyLfoBus     = Dictionary.new(8);
    instMollyLfo        = Dictionary.new(8);
    instMollyRingModBus = Dictionary.new(8);
    instMollySettings   = Dictionary.new(8);

    // Mixer and FX
    SynthDef(\trackMixerSynth, {
      arg in, out, amp = 1, ampLag = 0;
      var signal;

      signal = In.ar(in, 2);

      // Compression etc
      signal = CompanderD.ar(in: signal, thresh: 0.7, slopeBelow: 1, slopeAbove: 0.4, clampTime: 0.008, relaxTime: 0.2);
      signal = tanh(signal).softclip;

      // lag the amp for doing fade out
      amp = Lag.kr(amp, ampLag);
      // use envelope for doing fade in
      amp = amp * EnvGen.ar(Env([0, 1], [ampLag]));

      // Final amplification
      signal = signal * amp;

      Out.ar(out, signal);

    }).add;

    this.addCommand("trackMod","iff", { arg msg;
      var track_id = msg[1];
      var amp = msg[2];
      var ampLag = msg[3];

      this.getTrackMixer(track_id).set(
        \amp, amp,
        \ampLag, ampLag
      );
    });
    /////////////////// END TRACKS //////////////////////


    ////////////////// TIMBER!!!! ////////////////

    // debugBuffer = Buffer.alloc(context.server, context.server.sampleRate * 4, 5);

    defaultSample = (

      streaming: 0,
      buffer: nil,
      filePath: nil,

      channels: 0,
      sampleRate: 0,
      numFrames: 0,

      transpose: 0,
      detuneCents: 0,
      pitchBendRatio: 1,
      pressure: 0,

      lfo1Fade: 0,
      lfo2Fade: 0,

      startFrame: 0,
      endFrame: 0,
      playMode: 0,
      loopStartFrame: 0,
      loopEndFrame: 0,

      freqMultiplier: 1,

      freqModLfo1: 0,
      freqModLfo2: 0,
      freqModEnv: 0,

      ampAttack: 0,
      ampDecay: 1,
      ampSustain: 1,
      ampRelease: 0.003,

      modAttack: 1,
      modDecay: 2,
      modSustain: 0.65,
      modRelease: 1,

      downSampleTo: 48000,
      bitDepth: 24,

      filterFreq: 20000,
      filterReso: 0,
      filterType: 0,
      filterTracking: 1,
      filterFreqModLfo1: 0,
      filterFreqModLfo2: 0,
      filterFreqModEnv: 0,
      filterFreqModVel: 0,
      filterFreqModPressure: 0,

      pan: 0,
      panModLfo1: 0,
      panModLfo2: 0,
      panModEnv: 0,
      amp: 0,
      ampModLfo1: 0,
      ampModLfo2: 0,
    );

    voiceGroup = Group.new(context.server);
    voiceList = List.new();

    lfoBus = Bus.control(context.server, 2);
    // mixerBus = Bus.audio(context.server, 2);
    players = Array.newClear(4);

    loadQueue = Array.new(maxSamples);
    scriptAddress = NetAddr("localhost", 10111);
    waveformQueue = Array.new(maxSamples);

    // Receive messages from server
    replyFunc = OSCFunc({
      arg msg;
      var id = msg[2];
      scriptAddress.sendBundle(0, ['/enginePlayPosition', msg[3].asInt, msg[4].asInt, msg[5]]);
    }, path: '/replyPlayPosition', srcID: context.server.addr);

    // Sample defaults
    samples = Array.fill(maxSamples, { defaultSample.deepCopy; });

    // Buffer players
    2.do({
      arg i;
      players[i] = {
        arg freqRatio = 1, sampleRate, gate, playMode, voiceId, sampleId, bufnum, numFrames, startFrame, i_lockedStartFrame, endFrame, loopStartFrame, loopEndFrame;

        var signal, progress, phase, offsetPhase, direction, rate, phaseStart, phaseEnd,
        firstFrame, lastFrame, shouldLoop, inLoop, loopEnabled, loopInf, duckDuration, duckNumFrames, duckNumFramesShortened, duckGate, duckControl;

        firstFrame = startFrame.min(endFrame);
        lastFrame = startFrame.max(endFrame);

        loopEnabled = InRange.kr(playMode, 0, 1);
        loopInf = InRange.kr(playMode, 1, 1);

        direction = (endFrame - startFrame).sign;
        rate = freqRatio * BufRateScale.ir(bufnum) * direction;

        progress = (Sweep.ar(1, SampleRate.ir * rate) + i_lockedStartFrame).clip(firstFrame, lastFrame);

        shouldLoop = loopEnabled * gate.max(loopInf);

        inLoop = Select.ar(direction > 0, [
          progress < (loopEndFrame - 40), // NOTE: This tiny offset seems odd but avoids some clicks when phasor start changes
          progress > (loopStartFrame + 40)
        ]);
        inLoop = PulseCount.ar(inLoop).clip * shouldLoop;

        phaseStart = Select.ar(inLoop, [
          K2A.ar(i_lockedStartFrame),
          K2A.ar(loopStartFrame)
        ]);
        // Let phase run over end so it is caught by FreeSelf below. 150 is chosen to work even with drastic re-pitching.
        phaseEnd = Select.ar(inLoop, [
          K2A.ar(endFrame + (BlockSize.ir * 150 * direction)),
          K2A.ar(loopEndFrame)
        ]);

        phase = Phasor.ar(trig: 0, rate: rate, start: phaseStart, end: phaseEnd, resetPos: 0);

        // Free if reached end of sample
        FreeSelf.kr(Select.kr(direction > 0, [
          phase < firstFrame,
          phase > lastFrame
        ]));

        // SendReply.kr(trig: Impulse.kr(15), cmdName: '/replyPlayPosition', values: [sampleId, voiceId, (phase / numFrames).clip]);

        signal = BufRd.ar(numChannels: i + 1, bufnum: bufnum, phase: phase, interpolation: 4);

        // Duck across loop points and near start/end to avoid clicks (3ms * 2, playback time)
        duckDuration = 0.003;
        duckNumFrames = duckDuration * BufSampleRate.ir(bufnum) * freqRatio * BufRateScale.ir(bufnum);

        // Start (these also mute one-shots)
        duckControl = Select.ar(firstFrame > 0, [
          phase > firstFrame,
          phase.linlin(firstFrame, firstFrame + duckNumFrames, 0, 1)
        ]);

        // End
        duckControl = duckControl * Select.ar(lastFrame < numFrames, [
          phase < lastFrame,
          phase.linlin(lastFrame - duckNumFrames, lastFrame, 1, 0)
        ]);

        duckControl = duckControl.max(inLoop);

        duckNumFramesShortened = duckNumFrames.min((loopEndFrame - loopStartFrame) * 0.45);
        duckDuration = (duckNumFramesShortened / duckNumFrames) * duckDuration;
        duckNumFrames = duckNumFramesShortened;

        duckGate = Select.ar(direction > 0, [
          InRange.ar(phase, loopStartFrame, loopStartFrame + duckNumFrames),
          InRange.ar(phase, loopEndFrame - duckNumFrames, loopEndFrame)
        ]) * inLoop;

        duckControl = duckControl * EnvGen.ar(Env.new([1, 0, 1], [A2K.kr(duckDuration)], \linear, nil, nil), duckGate);

        // Debug buffer
        /*BufWr.ar([
          phase.linlin(firstFrame, lastFrame, 0, 1),
          duckControl,
          K2A.ar(gate),
          inLoop,
          duckGate,
        ], debugBuffer.bufnum, Phasor.ar(1, 1, 0, debugBuffer.numFrames), 0);*/

        signal = signal * duckControl;
      };
    });

    // Streaming players
    2.do({
      arg i;
      players[i + 2] = {
        arg freqRatio = 1, sampleRate, gate, playMode, voiceId, sampleId, bufnum, numFrames, i_lockedStartFrame, endFrame, loopStartFrame, loopEndFrame;
        var signal, rate, progress, loopEnabled, oneShotActive, duckDuration, duckControl;

        loopEnabled = InRange.kr(playMode, 0, 1);

        rate = (sampleRate / SampleRate.ir) * freqRatio;

        signal = VDiskIn.ar(numChannels: i + 1, bufnum: bufnum, rate: rate, loop: loopEnabled);

        progress = Sweep.ar(1, SampleRate.ir * rate) + i_lockedStartFrame;
        progress = Select.ar(loopEnabled, [progress.clip(0, endFrame), progress.wrap(0, numFrames)]);

        // SendReply.kr(trig: Impulse.kr(15), cmdName: '/replyPlayPosition', values: [sampleId, voiceId, progress / numFrames]);

        // Ducking
        // Note: There will be some inaccuracies with the length of the duck for really long samples but tested fine at 1hr
        duckDuration = 0.003 * sampleRate * rate.reciprocal;

        // Start
        duckControl = Select.ar(i_lockedStartFrame > 0, [
          K2A.ar(1),
          progress.linlin(i_lockedStartFrame, i_lockedStartFrame + duckDuration, 0, 1) + (progress < i_lockedStartFrame)
        ]);

        // End
        duckControl = duckControl * Select.ar(endFrame < numFrames, [
          ((progress <= endFrame) + loopEnabled).min(1),
          progress.linlin(endFrame - duckDuration, endFrame, 1, loopEnabled)
        ]);

        // Duck at end of stream if loop is enabled and startFrame > 0
        duckControl = duckControl * Select.ar(loopEnabled * (i_lockedStartFrame > 0), [
          K2A.ar(1),
          progress.linlin(numFrames - duckDuration, numFrames, 1, 0)
        ]);

        // One shot freer
        FreeSelf.kr((progress >= endFrame) * (1 - loopEnabled));

        signal = signal * duckControl;
      };
    });


    // SynthDefs

    lfos = SynthDef(\lfos, {
      arg out, lfo1Freq = 2, lfo1WaveShape = 0, lfo2Freq = 4, lfo2WaveShape = 3;
      var lfos, i_controlLag = 0.005;

      var lfoFreqs = [Lag.kr(lfo1Freq, i_controlLag), Lag.kr(lfo2Freq, i_controlLag)];
      var lfoWaveShapes = [lfo1WaveShape, lfo2WaveShape];

      lfos = Array.fill(2, {
        arg i;
        var lfo, lfoOscArray = [
          SinOsc.kr(lfoFreqs[i]),
          LFTri.kr(lfoFreqs[i]),
          LFSaw.kr(lfoFreqs[i]),
          LFPulse.kr(lfoFreqs[i], mul: 2, add: -1),
          LFNoise0.kr(lfoFreqs[i])
        ];
        lfo = Select.kr(lfoWaveShapes[i], lfoOscArray);
        lfo = Lag.kr(lfo, 0.005);
      });

      Out.kr(out, lfos);

    }).play(target:context.xg, args: [\out, lfoBus], addAction: \addToHead);


    synthNames = Array.with(\monoBufferVoice, \stereoBufferVoice, \monoStreamingVoice, \stereoStreamingVoice);
    synthNames.do({

      arg name, i;

      SynthDef(name, {

        arg out, sampleRate, freq, transposeRatio, detuneRatio = 1, pitchBendRatio = 1, pitchBendSampleRatio = 1, playMode = 0, gate = 0, killGate = 1, vel = 1, pressure = 0, pressureSample = 0, amp = 1,
        lfos, lfo1Fade, lfo2Fade, freqModLfo1, freqModLfo2, freqModEnv, freqMultiplier,
        ampAttack, ampDecay, ampSustain, ampRelease, modAttack, modDecay, modSustain, modRelease,
        downSampleTo, bitDepth,
        filterFreq, filterReso, filterType, filterTracking, filterFreqModLfo1, filterFreqModLfo2, filterFreqModEnv, filterFreqModVel, filterFreqModPressure,
        pan, panModLfo1, panModLfo2, panModEnv, ampModLfo1, ampModLfo2;

        var i_nyquist = SampleRate.ir * 0.5, i_cFreq = 48.midicps, i_origFreq = 60.midicps, signal, freqRatio, freqModRatio, filterFreqRatio,
        killEnvelope, ampEnvelope, modEnvelope, lfo1, lfo2, i_controlLag = 0.005;

        // Lag inputs
        detuneRatio = Lag.kr(detuneRatio * pitchBendRatio * pitchBendSampleRatio, i_controlLag);
        pressure = Lag.kr(pressure + pressureSample, i_controlLag);
        amp = Lag.kr(amp, i_controlLag);
        filterFreq = Lag.kr(filterFreq, i_controlLag);
        filterReso = Lag.kr(filterReso, i_controlLag);
        pan = Lag.kr(pan, i_controlLag);

        // LFOs
        lfo1 = Line.kr(start: (lfo1Fade < 0), end: (lfo1Fade >= 0), dur: lfo1Fade.abs, mul: In.kr(lfos, 1));
        lfo2 = Line.kr(start: (lfo2Fade < 0), end: (lfo2Fade >= 0), dur: lfo2Fade.abs, mul: In.kr(lfos, 2)[1]);

        // Envelopes
        gate = gate.max(InRange.kr(playMode, 3, 3)); // Ignore gate for one shots
        killGate = killGate + Impulse.kr(0); // Make sure doneAction fires
        killEnvelope = EnvGen.ar(envelope: Env.asr(0, 1, killDuration), gate: killGate, doneAction: Done.freeSelf);
        ampEnvelope = EnvGen.ar(envelope: Env.adsr(ampAttack, ampDecay, ampSustain, ampRelease), gate: gate, doneAction: Done.freeSelf);
        modEnvelope = EnvGen.ar(envelope: Env.adsr(modAttack, modDecay, modSustain, modRelease), gate: gate);

        // Freq modulation
        freqModRatio = 2.pow((lfo1 * freqModLfo1) + (lfo2 * freqModLfo2) + (modEnvelope * freqModEnv));
        freq = freq * transposeRatio * detuneRatio;
        freq = (freq * freqModRatio).clip(20, i_nyquist);
        freqRatio = (freq / i_origFreq) * freqMultiplier;

        // Player
        signal = SynthDef.wrap(players[i], [\kr, \kr, \kr, \kr], [freqRatio, sampleRate, gate, playMode]);

        // Downsample and bit reduction
        if(i > 1, { // Streaming
          downSampleTo = downSampleTo.min(sampleRate);
        }, {
          downSampleTo = Select.kr(downSampleTo >= sampleRate, [
            downSampleTo,
            downSampleTo = context.server.sampleRate
          ]);
        });
        signal = Decimator.ar(signal, downSampleTo, bitDepth);

        // 12dB LP/HP filter
        filterFreqRatio = Select.kr((freq < i_cFreq), [
          i_cFreq + ((freq - i_cFreq) * filterTracking),
          i_cFreq - ((i_cFreq - freq) * filterTracking)
        ]);
        filterFreqRatio = filterFreqRatio / i_cFreq;
        filterFreq = filterFreq * filterFreqRatio;
        filterFreq = filterFreq * ((48 * lfo1 * filterFreqModLfo1) + (48 * lfo2 * filterFreqModLfo2) + (96 * modEnvelope * filterFreqModEnv) + (48 * vel * filterFreqModVel) + (48 * pressure * filterFreqModPressure)).midiratio;
        filterFreq = filterFreq.clip(20, 20000);
        filterReso = filterReso.linlin(0, 1, 1, 0.02);
        signal = Select.ar(filterType, [
          RLPF.ar(signal, filterFreq, filterReso),
          RHPF.ar(signal, filterFreq, filterReso)
        ]);

        // Panning
        pan = (pan + (lfo1 * panModLfo1) + (lfo2 * panModLfo2) + (modEnvelope * panModEnv)).clip(-1, 1);
        signal = Splay.ar(inArray: signal, spread: 1 - pan.abs, center: pan);

        // Amp
        signal = signal * lfo1.range(1 - ampModLfo1, 1) * lfo2.range(1 - ampModLfo2, 1) * ampEnvelope * killEnvelope * vel.linlin(0, 1, 0.1, 1);
        signal = tanh(signal * amp.dbamp * (1 + pressure)).softclip;

        Out.ar(out, signal);
      }).add;
    });


    // Mixer and FX
    // mixer = SynthDef(\mixer, {
    //
    //   arg in, out;
    //   var signal;
    //
    //   signal = In.ar(in, 2);
    //
    //   // Compression etc
    //   signal = CompanderD.ar(in: signal, thresh: 0.7, slopeBelow: 1, slopeAbove: 0.4, clampTime: 0.008, relaxTime: 0.2);
    //   signal = tanh(signal).softclip;
    //
    //   Out.ar(out, signal);
    //
    // }).play(target:context.xg, args: [\in, mixerBus, \out, context.out_b], addAction: \addToTail);


    this.addCommands;

    ///////////////////////////////////////////////////////
    ///////// MOLLY THE POLY SLICE ////////////////////////
    ///////////////////////////////////////////////////////


    // Synth voice
    SynthDef(\mollyVoice, {
      arg out, mollyLfoIn, mollyRingModIn, freq = 440, mollyPitchBendRatio = 1, gate = 0, killGate = 1, vel = 1, mollyPressure, mollyTimbre,
      mollyOscWaveShape, mollyPwMod, mollyPwModSource, mollyFreqModLfo, mollyFreqModEnv, mollyLastFreq, mollyGlide, mollyMainOscLevel, mollySubOscLevel, mollySubOscDetune, mollyNoiseLevel,
      mollyHpFilterCutoff, mollyLpFilterCutoff, mollyLpFilterResonance, mollyLpFilterType, mollyLpFilterCutoffEnvSelect, mollyLpFilterCutoffModEnv, mollyLpFilterCutoffModLfo, mollyLpFilterTracking,
      mollyLfoFade, mollyEnv1Attack, mollyEnv1Decay, mollyEnv1Sustain, mollyEnv1Release, mollyEnv2Attack, mollyEnv2Decay, mollyEnv2Sustain, mollyEnv2Release,
      mollyAmpMod, mollyRingModFade, mollyRingModMix;
      var i_nyquist = SampleRate.ir * 0.5, i_cFreq = 48.midicps, signal, killEnvelope, controlLag = 0.005,
      mollyLfo, mollyRingMod, oscArray, freqModRatio, mainOscDriftLfo, subOscDriftLfo, filterCutoffRatio, filterCutoffModRatio,
      envelope1, envelope2;

      // mollyLfo in
      mollyLfo = Line.kr(start: (mollyLfoFade < 0), end: (mollyLfoFade >= 0), dur: mollyLfoFade.abs, mul: In.kr(mollyLfoIn, 1));
      mollyRingMod = Line.kr(start: (mollyRingModFade < 0), end: (mollyRingModFade >= 0), dur: mollyRingModFade.abs, mul: In.ar(mollyRingModIn, 1));

      // Lag and map inputs

      freq = XLine.kr(start: mollyLastFreq, end: freq, dur: mollyGlide + 0.001);
      freq = Lag.kr(freq * mollyPitchBendRatio, 0.005);
      mollyPressure = Lag.kr(mollyPressure, controlLag);

      mollyPwMod = Lag.kr(mollyPwMod, controlLag);
      mollyMainOscLevel = Lag.kr(mollyMainOscLevel, controlLag);
      mollySubOscLevel = Lag.kr(mollySubOscLevel, controlLag);
      mollySubOscDetune = Lag.kr(mollySubOscDetune, controlLag);
      mollyNoiseLevel = Lag.kr(mollyNoiseLevel, controlLag);

      mollyHpFilterCutoff = Lag.kr(mollyHpFilterCutoff, controlLag);
      mollyLpFilterCutoff = Lag.kr(mollyLpFilterCutoff, controlLag);
      mollyLpFilterResonance = Lag.kr(mollyLpFilterResonance, controlLag);
      mollyLpFilterType = Lag.kr(mollyLpFilterType, 0.01);

      mollyRingModMix = Lag.kr((mollyRingModMix + mollyTimbre).clip, controlLag);

      // Envelopes
      killGate = killGate + Impulse.kr(0); // Make sure doneAction fires
      killEnvelope = EnvGen.kr(envelope: Env.asr( 0, 1, 0.01), gate: killGate, doneAction: Done.freeSelf);

      envelope1 = EnvGen.ar(envelope: Env.adsr( mollyEnv1Attack, mollyEnv1Decay, mollyEnv1Sustain, mollyEnv1Release), gate: gate);
      envelope2 = EnvGen.ar(envelope: Env.adsr( mollyEnv2Attack, mollyEnv2Decay, mollyEnv2Sustain, mollyEnv2Release), gate: gate, doneAction: Done.freeSelf);

      // Main osc

      // Note: Would be ideal to do this exponentially but its a surprisingly big perf hit
      freqModRatio = ((mollyLfo * mollyFreqModLfo) + (envelope1 * mollyFreqModEnv));
      freqModRatio = Select.ar(freqModRatio >= 0, [
        freqModRatio.linlin(-2, 0, 0.25, 1),
        freqModRatio.linlin(0, 2, 1, 4)
      ]);
      freq = (freq * freqModRatio).clip(20, i_nyquist);

      mainOscDriftLfo = LFNoise2.kr(freq: 0.1, mul: 0.001, add: 1);

      mollyPwMod = Select.kr(mollyPwModSource, [mollyLfo.range(0, mollyPwMod), envelope1 * mollyPwMod, mollyPwMod]);

      oscArray = [
        VarSaw.ar(freq * mainOscDriftLfo),
        Saw.ar(freq * mainOscDriftLfo),
        Pulse.ar(freq * mainOscDriftLfo, width: 0.5 + (mollyPwMod * 0.49)),
      ];
      signal = Select.ar(mollyOscWaveShape, oscArray) * mollyMainOscLevel;

      // Sub osc and noise
      subOscDriftLfo = LFNoise2.kr(freq: 0.1, mul: 0.0008, add: 1);
      signal = SelectX.ar(mollySubOscLevel * 0.5, [signal, Pulse.ar(freq * 0.5 * mollySubOscDetune.midiratio * subOscDriftLfo, width: 0.5)]);
      signal = SelectX.ar(mollyNoiseLevel * 0.5, [signal, WhiteNoise.ar()]);
      signal = signal + PinkNoise.ar(0.007);

      // HP Filter
      filterCutoffRatio = Select.kr((freq < i_cFreq), [
        i_cFreq + (freq - i_cFreq),
        i_cFreq - (i_cFreq - freq)
      ]);
      filterCutoffRatio = filterCutoffRatio / i_cFreq;
      mollyHpFilterCutoff = (mollyHpFilterCutoff * filterCutoffRatio).clip(10, 20000);
      signal = HPF.ar(in: signal, freq: mollyHpFilterCutoff);

      // LP Filter
      filterCutoffRatio = Select.kr((freq < i_cFreq), [
        i_cFreq + ((freq - i_cFreq) * mollyLpFilterTracking),
        i_cFreq - ((i_cFreq - freq) * mollyLpFilterTracking)
      ]);
      filterCutoffRatio = filterCutoffRatio / i_cFreq;
      mollyLpFilterCutoff = mollyLpFilterCutoff * (1 + (mollyPressure * 0.55));
      mollyLpFilterCutoff = mollyLpFilterCutoff * filterCutoffRatio;

      // Note: Again, would prefer this to be exponential
      filterCutoffModRatio = ((mollyLfo * mollyLpFilterCutoffModLfo) + ((Select.ar(mollyLpFilterCutoffEnvSelect, [envelope1, envelope2]) * mollyLpFilterCutoffModEnv) * 2));
      filterCutoffModRatio = Select.ar(filterCutoffModRatio >= 0, [
        filterCutoffModRatio.linlin(-3, 0, 0.08333333333, 1),
        filterCutoffModRatio.linlin(0, 3, 1, 12)
      ]);
      mollyLpFilterCutoff = (mollyLpFilterCutoff * filterCutoffModRatio).clip(20, 20000);

      signal = RLPF.ar(in: signal, freq: mollyLpFilterCutoff, rq: mollyLpFilterResonance.linexp(0, 1, 1, 0.05));
      signal = SelectX.ar(mollyLpFilterType, [signal, RLPF.ar(in: signal, freq: mollyLpFilterCutoff, rq: mollyLpFilterResonance.linexp(0, 1, 1, 0.32))]);

      // mollyAmp
      signal = signal * envelope2 * killEnvelope;
      signal = signal * vel * mollyLfo.range(1 - mollyAmpMod, 1);
      signal = signal * (1 + (mollyPressure * 1.15));


      // Ring mod
      signal = SelectX.ar(mollyRingModMix * 0.5, [signal, signal * mollyRingMod]);

      Out.ar(out, signal);
    }).add;

    // mollyLfo
    SynthDef(\mollyLfo, {
      arg mollyLfoOut, mollyRingModOut, mollyLfoFreq = 5, mollyLfoWaveShape = 0, mollyRingModFreq = 50;
      var mollyLfo, mollyLfoOscArray, mollyRingMod, controlLag = 0.005;

      // Lag inputs
      mollyLfoFreq = Lag.kr(mollyLfoFreq, controlLag);
      mollyRingModFreq = Lag.kr(mollyRingModFreq, controlLag);

      mollyLfoOscArray = [
        SinOsc.kr(mollyLfoFreq),
        LFTri.kr(mollyLfoFreq),
        LFSaw.kr(mollyLfoFreq),
        LFPulse.kr(mollyLfoFreq, mul: 2, add: -1),
        LFNoise0.kr(mollyLfoFreq)
      ];

      mollyLfo = Select.kr(mollyLfoWaveShape, mollyLfoOscArray);
      mollyLfo = Lag.kr(mollyLfo, 0.005);

      Out.kr(mollyLfoOut, mollyLfo);

      mollyRingMod = SinOsc.ar(mollyRingModFreq);
      Out.ar(mollyRingModOut, mollyRingMod);

    }).add;


    // mollyMixer and chorus
    SynthDef(\mollyMixer, {
      arg in, out, mollyAmp = 0.5, mollyChorusMix = 0;
      var signal, chorus, chorusPreProcess, chorusLfo, chorusPreDelay = 0.01, chorusDepth = 0.0053, chorusDelay, controlLag = 0.005;

      // Lag inputs
      mollyAmp = Lag.kr(mollyAmp, controlLag);
      mollyChorusMix = Lag.kr(mollyChorusMix, controlLag);

      signal = In.ar(in, 1) * 0.4 * mollyAmp;

      // Bass boost
      signal = BLowShelf.ar(signal, freq: 400, rs: 1, db: 2, mul: 1, add: 0);

      // Compression etc
      signal = LPF.ar(in: signal, freq: 14000);
      signal = CompanderD.ar(in: signal, thresh: 0.4, slopeBelow: 1, slopeAbove: 0.25, clAmpTime: 0.002, relaxTime: 0.01);
      signal = tanh(signal).softclip;

      // Chorus

      chorusPreProcess = signal + (signal * WhiteNoise.ar(0.004));

      chorusLfo = LFPar.kr(mollyChorusMix.linlin(0.7, 1, 0.5, 0.75));
      chorusDelay = chorusPreDelay + mollyChorusMix.linlin(0.5, 1, chorusDepth, chorusDepth * 0.75);

      chorus = Array.with(
        DelayC.ar(in: chorusPreProcess, maxdelaytime: chorusPreDelay + chorusDepth, delaytime: chorusLfo.range(chorusPreDelay, chorusDelay)),
        DelayC.ar(in: chorusPreProcess, maxdelaytime: chorusPreDelay + chorusDepth, delaytime: chorusLfo.range(chorusDelay, chorusPreDelay))
      );
      chorus = LPF.ar(chorus, 14000);

      Out.ar(out, channelsArray: SelectX.ar(mollyChorusMix * 0.5, [signal.dup, chorus]));

    }).add;


    // Commands

    // mollyNoteOn(id, freq, vel)
    this.addCommand(\mollyNoteOn, "iiffi", { arg msg;

      var inst_id = msg[1], id = msg[2], freq = msg[3], vel = msg[4], track_id = msg[5];
      var voiceToRemove, newVoice;

      // Remove voice if ID matches or there are too many
      voiceToRemove = this.getInstMollyVoiceList(inst_id).detect{arg item; item.id == id};
      if(voiceToRemove.isNil && (this.getInstMollyVoiceList(inst_id).size >= mollyMaxNumVoices), {
        voiceToRemove = this.getInstMollyVoiceList(inst_id).detect{arg v; v.gate == 0};
        if(voiceToRemove.isNil, {
          voiceToRemove = this.getInstMollyVoiceList(inst_id).last;
        });
      });
      if(voiceToRemove.notNil, {
        voiceToRemove.theSynth.set(\gate, 0);
        voiceToRemove.theSynth.set(\killGate, 0);
        this.getInstMollyVoiceList(inst_id).remove(voiceToRemove);
      });

      if(this.getInstMollySetting(inst_id, \mollyLastFreq) == 0, {
        this.setInstMollySetting(inst_id, \mollyLastFreq, freq);
      });

      // Add new voice
      context.server.makeBundle(nil, {
        newVoice = (id: id, theSynth: Synth.new(defName: \mollyVoice, args: [
          \out, this.getInstMollyMixerBus(inst_id, track_id),
          \mollyLfoIn, this.getInstMollyLfoBus(inst_id),
          \mollyRingModIn, this.getInstMollyRingModBus(inst_id),
          \freq, freq,
          \mollyPitchBendRatio, this.getInstMollySetting(inst_id, \mollyPitchBendRatio),
          \gate, 1,
          \vel, vel.linlin(0, 1, 0.3, 1),
          \mollyPressure, this.getInstMollySetting(inst_id, \mollyChannelPressure),
          \mollyTimbre, this.getInstMollySetting(inst_id, \mollyTimbre),
          \mollyOscWaveShape, this.getInstMollySetting(inst_id, \mollyOscWaveShape),
          \mollyPwMod, this.getInstMollySetting(inst_id, \mollyPwMod),
          \mollyPwModSource, this.getInstMollySetting(inst_id, \mollyPwModSource),
          \mollyFreqModLfo, this.getInstMollySetting(inst_id, \mollyFreqModLfo),
          \mollyFreqModEnv, this.getInstMollySetting(inst_id, \mollyFreqModEnv),
          \mollyLastFreq, this.getInstMollySetting(inst_id, \mollyLastFreq),
          \mollyGlide, this.getInstMollySetting(inst_id, \mollyGlide),
          \mollyMainOscLevel, this.getInstMollySetting(inst_id, \mollyMainOscLevel),
          \mollySubOscLevel, this.getInstMollySetting(inst_id, \mollySubOscLevel),
          \mollySubOscDetune, this.getInstMollySetting(inst_id, \mollySubOscDetune),
          \mollyNoiseLevel, this.getInstMollySetting(inst_id, \mollyNoiseLevel),
          \mollyHpFilterCutoff, this.getInstMollySetting(inst_id, \mollyHpFilterCutoff),
          \mollyLpFilterType, this.getInstMollySetting(inst_id, \mollyLpFilterType),
          \mollyLpFilterCutoff, this.getInstMollySetting(inst_id, \mollyLpFilterCutoff),
          \mollyLpFilterResonance, this.getInstMollySetting(inst_id, \mollyLpFilterResonance),
          \mollyLpFilterCutoffEnvSelect, this.getInstMollySetting(inst_id, \mollyLpFilterCutoffEnvSelect),
          \mollyLpFilterCutoffModEnv, this.getInstMollySetting(inst_id, \mollyLpFilterCutoffModEnv),
          \mollyLpFilterCutoffModLfo, this.getInstMollySetting(inst_id, \mollyLpFilterCutoffModLfo),
          \mollyLpFilterTracking, this.getInstMollySetting(inst_id, \mollyLpFilterTracking),
          \mollyLfoFade, this.getInstMollySetting(inst_id, \mollyLfoFade),
          \mollyEnv1Attack, this.getInstMollySetting(inst_id, \mollyEnv1Attack),
          \mollyEnv1Decay, this.getInstMollySetting(inst_id, \mollyEnv1Decay),
          \mollyEnv1Sustain, this.getInstMollySetting(inst_id, \mollyEnv1Sustain),
          \mollyEnv1Release, this.getInstMollySetting(inst_id, \mollyEnv1Release),
          \mollyEnv2Attack, this.getInstMollySetting(inst_id, \mollyEnv2Attack),
          \mollyEnv2Decay, this.getInstMollySetting(inst_id, \mollyEnv2Decay),
          \mollyEnv2Sustain, this.getInstMollySetting(inst_id, \mollyEnv2Sustain),
          \mollyEnv2Release, this.getInstMollySetting(inst_id, \mollyEnv2Release),
          \mollyAmpMod, this.getInstMollySetting(inst_id, \mollyAmpMod),
          \mollyRingModFade, this.getInstMollySetting(inst_id, \mollyRingModFade),
          \mollyRingModMix,this.getInstMollySetting(inst_id, \mollyRingModMix)
        ], target: this.getInstMollyVoiceGroup(inst_id)).onFree({ this.getInstMollyVoiceList(inst_id).remove(newVoice); }), gate: 1);

        this.getInstMollyVoiceList(inst_id).addFirst(newVoice);
        this.setInstMollySetting(inst_id, \mollyLastFreq, freq);
      });
    });

    // mollyNoteOff(id)
    this.addCommand(\mollyNoteOff, "ii", { arg msg;
      var inst_id = msg[1];
      var voice = this.getInstMollyVoiceList(inst_id).detect{arg v; v.id == msg[2]};
      if(voice.notNil, {
        voice.theSynth.set(\gate, 0);
        voice.gate = 0;
      });
    });

    // mollyNoteOffAll()
    this.addCommand(\mollyNoteOffAll, "i", { arg msg;
      var inst_id = msg[1];
      this.getInstMollyVoiceGroup(inst_id).set(\gate, 0);
      this.getInstMollyVoiceList(inst_id).do({ arg v; v.gate = 0; });
    });

    // mollyNoteKill(id)
    this.addCommand(\mollyNoteKill, "i", { arg msg;
      var inst_id = msg[1];
      var id = msg[2];
      var voice = this.getInstMollyVoiceList(inst_id).detect{arg v; v.id == id};
      if(voice.notNil, {
        voice.theSynth.set(\gate, 0);
        voice.theSynth.set(\killGate, 0);
        this.getInstMollyVoiceList(inst_id).remove(voice);
      });
    });

    // mollyNoteKillAll()
    this.addCommand(\mollyNoteKillAll, "i", { arg msg;
      var inst_id = msg[1];
      this.getInstMollyVoiceGroup(inst_id).set(\gate, 0);
      this.getInstMollyVoiceGroup(inst_id).set(\killGate, 0);
      this.getInstMollyVoiceList(inst_id).clear;
    });

    // mollyPitchBend(id, ratio)
    this.addCommand(\mollyPitchBend, "iif", { arg msg;
      var inst_id = msg[1];
      var voice = this.getInstMollyVoiceList(inst_id).detect{arg v; v.id == msg[2]};
      if(voice.notNil, {
        voice.theSynth.set(\mollyPitchBendRatio, msg[3]);
      });
    });

    // mollyPitchBendAll(ratio)
    this.addCommand(\mollyPitchBendAll, "if", { arg msg;
      var inst_id = msg[1];
      this.setInstMollySetting(inst_id, \mollyPitchBendRatio, msg[2]);
      this.getInstMollyVoiceGroup(inst_id).set(\mollyPitchBendRatio, this.getInstMollySetting(inst_id, \mollyPitchBendRatio));
    });

    // mollyPressure(id, mollyPressure)
    this.addCommand(\mollyPressure, "iif", { arg msg;
      var inst_id = msg[1];
      var voice = this.getInstMollyVoiceList(inst_id).detect{arg v; v.id == msg[2]};
      if(voice.notNil, {
        voice.theSynth.set(\mollyPressure, msg[3]);
      });
    });

    // mollyPressureAll(mollyPressure)
    this.addCommand(\mollyPressureAll, "if", { arg msg;
      var inst_id = msg[1];
      this.setInstMollySetting(inst_id, \mollyChannelPressure, msg[2]);
      this.getInstMollyVoiceGroup(inst_id).set(\mollyPressure, this.getInstMollySetting(inst_id, \mollyChannelPressure));
    });

    // mollyTimbre(id, mollyTimbre)
    this.addCommand(\mollyTimbre, "iif", { arg msg;
      var inst_id = msg[1];
      var voice = this.getInstMollyVoiceList(inst_id).detect{arg v; v.id == msg[2]};
      if(voice.notNil, {
        voice.theSynth.set(\mollyTimbre, msg[3]);
      });
    });

    // mollyTimbreAll(mollyTimbre)
    this.addCommand(\mollyTimbreAll, "if", { arg msg;
      var inst_id = msg[1];
      this.setInstMollySetting(inst_id, \mollyTimbre, msg[2]);
      this.getInstMollyVoiceGroup(inst_id).set(\mollyTimbre, this.getInstMollySetting(inst_id, \mollyTimbre));
    });

    this.addCommand(\mollyOscWaveShape, "ii", { arg msg;
      var inst_id = msg[1];
      this.setInstMollySetting(inst_id, \mollyOscWaveShape, msg[2]);
      this.getInstMollyVoiceGroup(inst_id).set(\mollyOscWaveShape, this.getInstMollySetting(inst_id, \mollyOscWaveShape));
    });

    this.addCommand(\mollyPwMod, "if", { arg msg;
      var inst_id = msg[1];
      this.setInstMollySetting(inst_id, \mollyPwMod, msg[2]);
      this.getInstMollyVoiceGroup(inst_id).set(\mollyPwMod, this.getInstMollySetting(inst_id, \mollyPwMod));
    });

    this.addCommand(\mollyPwModSource, "ii", { arg msg;
      var inst_id = msg[1];
      this.setInstMollySetting(inst_id, \mollyPwModSource, msg[2]);
      this.getInstMollyVoiceGroup(inst_id).set(\mollyPwModSource, this.getInstMollySetting(inst_id, \mollyPwModSource));
    });

    this.addCommand(\mollyFreqModLfo, "if", { arg msg;
      var inst_id = msg[1];
      this.setInstMollySetting(inst_id, \mollyFreqModLfo, msg[2]);
      this.getInstMollyVoiceGroup(inst_id).set(\mollyFreqModLfo, this.getInstMollySetting(inst_id, \mollyFreqModLfo));
    });

    this.addCommand(\mollyFreqModEnv, "if", { arg msg;
      var inst_id = msg[1];
      this.setInstMollySetting(inst_id, \mollyFreqModEnv, msg[2]);
      this.getInstMollyVoiceGroup(inst_id).set(\mollyFreqModEnv, this.getInstMollySetting(inst_id, \mollyFreqModEnv));
    });

    this.addCommand(\mollyGlide, "if", { arg msg;
      var inst_id = msg[1];
      this.setInstMollySetting(inst_id, \mollyGlide, msg[2]);
      this.getInstMollyVoiceGroup(inst_id).set(\mollyGlide, this.getInstMollySetting(inst_id, \mollyGlide));
    });

    this.addCommand(\mollyMainOscLevel, "if", { arg msg;
      var inst_id = msg[1];
      this.setInstMollySetting(inst_id, \mollyMainOscLevel, msg[2]);
      this.getInstMollyVoiceGroup(inst_id).set(\mollyMainOscLevel, this.getInstMollySetting(inst_id, \mollyMainOscLevel));
    });

    this.addCommand(\mollySubOscLevel, "if", { arg msg;
      var inst_id = msg[1];
      this.setInstMollySetting(inst_id, \mollySubOscLevel, msg[2]);
      this.getInstMollyVoiceGroup(inst_id).set(\mollySubOscLevel, this.getInstMollySetting(inst_id, \mollySubOscLevel));
    });

    this.addCommand(\mollySubOscDetune, "if", { arg msg;
      var inst_id = msg[1];
      this.setInstMollySetting(inst_id, \mollySubOscDetune, msg[2]);
      this.getInstMollyVoiceGroup(inst_id).set(\mollySubOscDetune, this.getInstMollySetting(inst_id, \mollySubOscDetune));
    });

    this.addCommand(\mollyNoiseLevel, "if", { arg msg;
      var inst_id = msg[1];
      this.setInstMollySetting(inst_id, \mollyNoiseLevel, msg[2]);
      this.getInstMollyVoiceGroup(inst_id).set(\mollyNoiseLevel, this.getInstMollySetting(inst_id, \mollyNoiseLevel));
    });

    this.addCommand(\mollyHpFilterCutoff, "if", { arg msg;
      var inst_id = msg[1];
      this.setInstMollySetting(inst_id, \mollyHpFilterCutoff, msg[2]);
      this.getInstMollyVoiceGroup(inst_id).set(\mollyHpFilterCutoff, this.getInstMollySetting(inst_id, \mollyHpFilterCutoff));
    });

    this.addCommand(\mollyLpFilterType, "ii", { arg msg;
      var inst_id = msg[1];
      this.setInstMollySetting(inst_id, \mollyLpFilterType, msg[2]);
      this.getInstMollyVoiceGroup(inst_id).set(\mollyLpFilterType, this.getInstMollySetting(inst_id, \mollyLpFilterType));
    });

    this.addCommand(\mollyLpFilterCutoff, "if", { arg msg;
      var inst_id = msg[1];
      this.setInstMollySetting(inst_id, \mollyLpFilterCutoff, msg[2]);
      this.getInstMollyVoiceGroup(inst_id).set(\mollyLpFilterCutoff, this.getInstMollySetting(inst_id, \mollyLpFilterCutoff));
    });

    this.addCommand(\mollyLpFilterResonance, "if", { arg msg;
      var inst_id = msg[1];
      this.setInstMollySetting(inst_id, \mollyLpFilterResonance, msg[2]);
      this.getInstMollyVoiceGroup(inst_id).set(\mollyLpFilterResonance, this.getInstMollySetting(inst_id, \mollyLpFilterResonance));
    });

    this.addCommand(\mollyLpFilterCutoffEnvSelect, "ii", { arg msg;
      var inst_id = msg[1];
      this.setInstMollySetting(inst_id, \mollyLpFilterCutoffEnvSelect, msg[2]);
      this.getInstMollyVoiceGroup(inst_id).set(\mollyLpFilterCutoffEnvSelect, this.getInstMollySetting(inst_id, \mollyLpFilterCutoffEnvSelect));
    });

    this.addCommand(\mollyLpFilterCutoffModEnv, "if", { arg msg;
      var inst_id = msg[1];
      this.setInstMollySetting(inst_id, \mollyLpFilterCutoffModEnv, msg[2]);
      this.getInstMollyVoiceGroup(inst_id).set(\mollyLpFilterCutoffModEnv, this.getInstMollySetting(inst_id, \mollyLpFilterCutoffModEnv));
    });

    this.addCommand(\mollyLpFilterCutoffModLfo, "if", { arg msg;
      var inst_id = msg[1];
      this.setInstMollySetting(inst_id, \mollyLpFilterCutoffModLfo, msg[2]);
      this.getInstMollyVoiceGroup(inst_id).set(\mollyLpFilterCutoffModLfo, this.getInstMollySetting(inst_id, \mollyLpFilterCutoffModLfo));
    });

    this.addCommand(\mollyLpFilterTracking, "if", { arg msg;
      var inst_id = msg[1];
      this.setInstMollySetting(inst_id, \mollyLpFilterTracking, msg[2]);
      this.getInstMollyVoiceGroup(inst_id).set(\mollyLpFilterTracking, this.getInstMollySetting(inst_id, \mollyLpFilterTracking));
    });

    this.addCommand(\mollyLfoFade, "if", { arg msg;
      var inst_id = msg[1];
      this.setInstMollySetting(inst_id, \mollyLfoFade, msg[2]);
      this.getInstMollyVoiceGroup(inst_id).set(\mollyLfoFade, this.getInstMollySetting(inst_id, \mollyLfoFade));
    });

    this.addCommand(\mollyEnv1Attack, "if", { arg msg;
      var inst_id = msg[1];
      this.setInstMollySetting(inst_id, \mollyEnv1Attack, msg[2]);
      this.getInstMollyVoiceGroup(inst_id).set(\mollyEnv1Attack, this.getInstMollySetting(inst_id, \mollyEnv1Attack));
    });

    this.addCommand(\mollyEnv1Decay, "if", { arg msg;
      var inst_id = msg[1];
      this.setInstMollySetting(inst_id, \mollyEnv1Decay, msg[2]);
      this.getInstMollyVoiceGroup(inst_id).set(\mollyEnv1Decay, this.getInstMollySetting(inst_id, \mollyEnv1Decay));
    });

    this.addCommand(\mollyEnv1Sustain, "if", { arg msg;
      var inst_id = msg[1];
      this.setInstMollySetting(inst_id, \mollyEnv1Sustain, msg[2]);
      this.getInstMollyVoiceGroup(inst_id).set(\mollyEnv1Sustain, this.getInstMollySetting(inst_id, \mollyEnv1Sustain));
    });

    this.addCommand(\mollyEnv1Release, "if", { arg msg;
      var inst_id = msg[1];
      this.setInstMollySetting(inst_id, \mollyEnv1Release, msg[2]);
      this.getInstMollyVoiceGroup(inst_id).set(\mollyEnv1Release, this.getInstMollySetting(inst_id, \mollyEnv1Release));
    });

    this.addCommand(\mollyEnv2Attack, "if", { arg msg;
      var inst_id = msg[1];
      this.setInstMollySetting(inst_id, \mollyEnv2Attack, msg[2]);
      this.getInstMollyVoiceGroup(inst_id).set(\mollyEnv2Attack, this.getInstMollySetting(inst_id, \mollyEnv2Attack));
    });

    this.addCommand(\mollyEnv2Decay, "if", { arg msg;
      var inst_id = msg[1];
      this.setInstMollySetting(inst_id, \mollyEnv2Decay, msg[2]);
      this.getInstMollyVoiceGroup(inst_id).set(\mollyEnv2Decay, this.getInstMollySetting(inst_id, \mollyEnv2Decay));
    });

    this.addCommand(\mollyEnv2Sustain, "if", { arg msg;
      var inst_id = msg[1];
      this.setInstMollySetting(inst_id, \mollyEnv2Sustain, msg[2]);
      this.getInstMollyVoiceGroup(inst_id).set(\mollyEnv2Sustain, this.getInstMollySetting(inst_id, \mollyEnv2Sustain));
    });

    this.addCommand(\mollyEnv2Release, "if", { arg msg;
      var inst_id = msg[1];
      this.setInstMollySetting(inst_id, \mollyEnv2Release, msg[2]);
      this.getInstMollyVoiceGroup(inst_id).set(\mollyEnv2Release, this.getInstMollySetting(inst_id, \mollyEnv2Release));
    });

    this.addCommand(\mollyAmpMod, "if", { arg msg;
      var inst_id = msg[1];
      this.setInstMollySetting(inst_id, \mollyAmpMod, msg[2]);
      this.getInstMollyVoiceGroup(inst_id).set(\mollyAmpMod, this.getInstMollySetting(inst_id, \mollyAmpMod));
    });

    this.addCommand(\mollyRingModFade, "if", { arg msg;
      var inst_id = msg[1];
      this.setInstMollySetting(inst_id, \mollyRingModFade, msg[2]);
      this.getInstMollyVoiceGroup(inst_id).set(\mollyRingModFade, this.getInstMollySetting(inst_id, \mollyRingModFade));
    });

    this.addCommand(\mollyRingModMix, "if", { arg msg;
      var inst_id = msg[1];
      this.setInstMollySetting(inst_id, \mollyRingModMix, msg[2]);
      this.getInstMollyVoiceGroup(inst_id).set(\mollyRingModMix, this.getInstMollySetting(inst_id, \mollyRingModMix));
    });

    this.addCommand(\mollyAmp, "if", { arg msg;
      var inst_id = msg[1];
      this.getInstMollyMixerSynth(inst_id).set(\mollyAmp, msg[2]);
    });

    this.addCommand(\mollyChorusMix, "if", { arg msg;
      this.getInstMollyMixerSynth(msg[1]).set(\mollyChorusMix, msg[2]);
    });

    this.addCommand(\mollyLfoFreq, "if", { arg msg;
      var inst_id = msg[1];
      this.getInstMollyLfo(inst_id).set(\mollyLfoFreq, msg[2]);
    });

    this.addCommand(\mollyLfoWaveShape, "ii", { arg msg;
      var inst_id = msg[1];
      this.getInstMollyLfo(inst_id).set(\mollyLfoWaveShape, msg[2]);
    });

    this.addCommand(\mollyRingModFreq, "if", { arg msg;
      var inst_id = msg[1];
      this.getInstMollyLfo(inst_id).set(\mollyRingModFreq, msg[2]);
    });

    ///////// END MOLLY THE POLY SLICE ////////////////////////


    //////// SAMPLER THING //////
    bufSample=Dictionary.new(8);
    synSample=Dictionary.new(8);
    //
    // mainBus=Bus.audio(context.server,2);
    //
    SynthDef("defSampler", {
      arg out=0, amp=0,bufnum=0, rate=1, start=0, end=1, reset=0, t_trig=0,
      loops=1, pan=0, ampLag=6;
      var snd,snd2,pos,pos2,frames,duration,env,finalsnd;
      var startA,endA,startB,endB,resetA,resetB,crossfade,aOrB;

      // latch to change trigger between the two
      amp=Lag.kr(amp,ampLag);
      aOrB=ToggleFF.kr(t_trig);
      startA=Latch.kr(start,aOrB);
      endA=Latch.kr(end,aOrB);
      resetA=Latch.kr(reset,aOrB);
      startB=Latch.kr(start,1-aOrB);
      endB=Latch.kr(end,1-aOrB);
      resetB=Latch.kr(reset,1-aOrB);
      crossfade=Lag.ar(K2A.ar(aOrB),0.05);


      rate = rate*BufRateScale.kr(bufnum);
      frames = BufFrames.kr(bufnum);
      duration = frames*(end-start)/rate.abs/context.server.sampleRate*loops;

      // envelope to clamp looping
      env=EnvGen.ar(
        Env.new(
          levels: [0,1,1,0],
          times: [0,duration-0.05,0.05],
        ),
        gate:t_trig,
      );

      pos=Phasor.ar(
        trig:aOrB,
        rate:rate,
        start:(((rate>0)*startA)+((rate<0)*endA))*frames,
        end:(((rate>0)*endA)+((rate<0)*startA))*frames,
        resetPos:(((rate>0)*resetA)+((rate<0)*endA))*frames,
      );
      snd=BufRd.ar(
        numChannels:2,
        bufnum:bufnum,
        phase:pos,
        interpolation:4,
      );

      // add a second reader
      pos2=Phasor.ar(
        trig:(1-aOrB),
        rate:rate,
        start:(((rate>0)*startB)+((rate<0)*endB))*frames,
        end:(((rate>0)*endB)+((rate<0)*startB))*frames,
        resetPos:(((rate>0)*resetB)+((rate<0)*endB))*frames,
      );
      snd2=BufRd.ar(
        numChannels:2,
        bufnum:bufnum,
        phase:pos2,
        interpolation:4,
      );

      finalsnd=(crossfade*snd)+((1-crossfade)*snd2) * env;
      Out.ar(out,Balance2.ar(finalsnd[0],finalsnd[1],-1*pan,amp))
    }).add;


    this.addCommand("samplerLoad","is", { arg msg;
      if (bufSample.at(msg[1])==nil,{
      },{
        bufSample.at(msg[1]).free;
      });
      Buffer.read(context.server,msg[2],action:{
        arg bufnum;
        ("loaded "++msg[2]++" into slot "++msg[1]++" frames: "++bufnum.numFrames).postln;
        bufSample.put(msg[1],bufnum);

        scriptAddress.sendBundle(0, ['/engineSamplerLoad', msg[1], bufnum.numFrames]);

        if (synSample.at(msg[1])==nil,{
          synSample.put(msg[1],Synth("defSampler",[
            \out,0,
            \bufnum,bufnum,
            \t_trig,1,\reset,0,\start,0,\end,1,\rate,1
          ],target:context.server));
        },{
          synSample.at(msg[1]).set(\bufnum,bufnum);
        });
      });
    });

    this.addCommand("samplerAmp","iff", { arg msg;
      synSample.at(msg[1]).set(\ampLag,msg[3],\amp,msg[2])
    });

    this.addCommand("samplerAmpLag","if", { arg msg;
      synSample.at(msg[1]).set(\ampLag,msg[2])
    });

    this.addCommand("samplerRelease","i", { arg msg;
      synSample.at(msg[1]).free;
      synSample.removeAt(msg[1]);
      bufSample.at(msg[1]).free;
      bufSample.removeAt(msg[1]);
    });

    this.addCommand("samplerPan","if", { arg msg;
      synSample.at(msg[1]).set(\pan,msg[2])
    });

    this.addCommand("samplerRate","if", { arg msg;
      synSample.at(msg[1]).set(\rate,msg[2])
    });

    this.addCommand("samplerPos","iff", {arg msg;
      synSample.at(msg[1]).set(\t_trig,1,\reset,msg[2],\start,0,\end,1,\rate,msg[3]);
    });

    this.addCommand("samplerLoop","ifff", {arg msg;
      synSample.at(msg[1]).set(\t_trig,1,\start,msg[2],\reset,msg[2],\end,msg[3],\loops,msg[4]);
    });

    this.addCommand("samplerStop","i", {arg msg;
      synSample.at(msg[1]).set(\t_trig,1,\start,0,\reset,0,\end,0);
    });

    this.addCommand("samplerStart","if", {arg msg;
      synSample.at(msg[1]).set(\t_trig,1,\start, msg[1]);
    });

    this.addCommand("samplerEnd","if", {arg msg;
      synSample.at(msg[1]).set(\t_trig,1,\end, msg[1]);
    });

    this.addCommand("samplerStop","if", {arg msg;
      synSample.at(msg[1]).set(\t_trig,0);
    });

    //////// END SAMPLER THING //////

    // <Goldeneye>
    bufGoldeneye = Dictionary.new(128);
    synGoldeneye = Dictionary.new(128);


    context.server.sync;

    SynthDef("playerGoldeneyeStereo",{
        arg bufnum, out, amp=0, ampLag=0, t_trig=0,
        sampleStart=0,sampleEnd=1,loop=0,
        rate=1;

        var snd;
        var frames = BufFrames.kr(bufnum);
        var duration;
        var slice;

        // lag the amp for doing fade out
        amp = Lag.kr(amp,ampLag);
        // use envelope for doing fade in
        amp = amp * EnvGen.ar(Env([0,1],[ampLag]));

        // playbuf
        snd = PlayBuf.ar(
          numChannels:2,
          bufnum:bufnum,
          rate:BufRateScale.kr(bufnum)*rate,
          startPos: ((sampleEnd*(rate<0))*(frames-10))+(sampleStart*frames*(rate>0)),
          trigger:t_trig,
          loop:loop,
          doneAction:2,
        );

        // multiple by amp and attenuate
        snd = snd * amp; //  / 20 ;

        duration = frames*(sampleEnd-sampleStart)/rate.abs/context.server.sampleRate;

        // envelope to set duration
        slice = snd * EnvGen.ar(
          Env.new(
            levels: [0,1,1,0],
            times: [0,duration,0],
            // times: [0.05,duration-0.1,0.05],
          ),
          gate: t_trig,
        );

        // if looping, free up synth if no output
        DetectSilence.ar(slice, doneAction: 2);

        Out.ar(out, slice)
    }).add;

    SynthDef("playerGoldeneyeMono",{
        arg bufnum, out, amp=0, ampLag=0, t_trig=0,
        sampleStart=0,sampleEnd=1,loop=0,
        rate=1;

        var snd;
        var frames = BufFrames.kr(bufnum);
        var duration;
        var slice;

        // lag the amp for doing fade in/out
        amp = Lag.kr(amp,ampLag);
        // use envelope for doing fade in
        amp = amp * EnvGen.ar(Env([0,1],[ampLag]));

        // playbuf
        snd = PlayBuf.ar(
          numChannels:1,
          bufnum:bufnum,
          rate:BufRateScale.kr(bufnum)*rate,
          startPos: ((sampleEnd*(rate<0))*(frames-10))+(sampleStart*frames*(rate>0)),
          trigger:t_trig,
          loop:loop,
          doneAction: 2,
        );

        snd = Pan2.ar(snd,0);

        // multiple by amp and attenuate
        snd = snd * amp; //  / 20;

        duration = frames*(sampleEnd-sampleStart)/rate.abs/context.server.sampleRate;

        // envelope to set duration
        slice = snd * EnvGen.ar(
          Env.new(
            levels: [0,1,1,0],
            times: [0,duration,0],
            // times: [0,duration-0.05,0.05],
            // times: [0.05,duration-0.1,0.05],
          ),
          gate: t_trig,
        );

        // if looping, free up synth if no output
        DetectSilence.ar(slice, doneAction: 2);

        Out.ar(out, slice)
    }).add;



    this.addCommand("goldeneyePlay","fsfffffffi", { arg msg;
      var voice=msg[1];
      var filename=msg[2];
      var synName="playerGoldeneyeMono";
      var track_id = msg[10];

      if (bufGoldeneye.at(voice)==nil,{
        // load buffer
        Buffer.read(context.server,filename,action:{
          arg bufnum;
          if (bufnum.numChannels>1,{
            synName="playerGoldeneyeStereo";
          });
          bufGoldeneye.put(voice,bufnum);
          scriptAddress.sendBundle(0, ['/engineGoldeneyeLoad', voice, bufnum.numFrames]);
          synGoldeneye.put(voice,Synth(synName,[
            \bufnum,bufnum,
            \amp,msg[3],
            \ampLag,msg[4],
            \sampleStart,msg[5],
            \sampleEnd,msg[6],
            \loop,msg[7],
            \rate,msg[8],
            \t_trig,msg[9],
            \out,this.getTrackBus(track_id),
          ],target:context.server).onFree({
            // ("freed "++voice).postln;
          }));
          NodeWatcher.register(synGoldeneye.at(voice));
        });
      },{
        // buffer already loaded, just play it
        if (bufGoldeneye.at(voice).numChannels>1,{
          synName="playerGoldeneyeStereo";
        });
        if (synGoldeneye.at(voice).isRunning==true,{
          synGoldeneye.at(voice).set(
            \bufnum,bufGoldeneye.at(voice),
            \amp,msg[3],
            \ampLag,msg[4],
            \sampleStart,msg[5],
            \sampleEnd,msg[6],
            \loop,msg[7],
            \rate,msg[8],
            \t_trig,msg[9],
            \out,this.getTrackBus(track_id),
          );
        },{
          synGoldeneye.put(voice,Synth(synName,[
            \bufnum,bufGoldeneye.at(voice),
            \amp,msg[3],
            \ampLag,msg[4],
            \sampleStart,msg[5],
            \sampleEnd,msg[6],
            \loop,msg[7],
            \rate,msg[8],
            \t_trig,msg[9],
            \out,this.getTrackBus(track_id),
          ],target:context.server).onFree({
            // ("freed "++voice).postln;
          }));
          NodeWatcher.register(synGoldeneye.at(voice));
        });
      });
    });

    this.addCommand("goldeneyeAmp","iff", { arg msg;
      synGoldeneye.at(msg[1]).set(\ampLag,msg[3],\amp,msg[2])
    });

    this.addCommand("goldeneyeRate","iff", { arg msg;
      synGoldeneye.at(msg[1]).set(\rate,msg[2])
    });
    // </Goldeneye>


  }



  // Functions


  getTrackBus {
    arg track_id;

    if (trackMixer.at(track_id) == nil, {
      ("Creating new track bus+mixer " ++ track_id).postln;

      trackBus.put(track_id, Bus.audio(context.server, 2));

      trackMixer.put(track_id, Synth(\trackMixerSynth, [
        \in, trackBus.at(track_id),
        \out, 0,
      ], target: context.server, addAction: \addAfter).onFree({
        ("freed track "++track_id).postln;
      }));
    });

    ^trackBus.at(track_id);
  }

  getTrackMixer {
    arg track_id;
    this.getTrackBus(track_id); // Force it to be created, ignore result
    ^trackMixer.at(track_id);
  }


  getInstMollyVoiceList {
    arg inst_id = 0;

    if(instMollyVoiceList.at(inst_id) == nil, {
      instMollyVoiceList.put(inst_id, List.new());
    });

    ^instMollyVoiceList.at(inst_id);
  }

  getInstMollyVoiceGroup {
    arg inst_id = 0;

    if(instMollyVoiceGroup.at(inst_id) == nil, {
      instMollyVoiceGroup.put(inst_id, Group.new(context.xg));
    });

    ^instMollyVoiceGroup.at(inst_id);
  }


  getInstMollyMixerBus {
    arg inst_id, track_id;

    if(instMollyMixerBus.at(inst_id) == nil, {
      ("Creating new molly inst bus+mixer " ++ inst_id ++ " track " ++ track_id).postln;

      instMollyMixerBus.put(inst_id, Bus.audio(context.server, 1));
      instMollySettings.put(inst_id, Dictionary.newFrom([
        \mollyPitchBendRatio, 1,
        \mollyOscWaveShape, 0,
        \mollyPwMod, 0,
        \mollyPwModSource, 0,
        \mollyFreqModLfo, 0,
        \mollyFreqModEnv, 0,
        \mollyLastFreq, 0,
        \mollyGlide, 0,
        \mollyMainOscLevel, 1,
        \mollySubOscLevel, 0,
        \mollySubOscDetune, 0,
        \mollyNoiseLevel, 0,
        \mollyHpFilterCutoff, 10,
        \mollyLpFilterType, 0,
        \mollyLpFilterCutoff, 440,
        \mollyLpFilterResonance, 0.2,
        \mollyLpFilterCutoffEnvSelect, 0,
        \mollyLpFilterCutoffModEnv, 0,
        \mollyLpFilterCutoffModLfo, 0,
        \mollyLpFilterTracking, 1,
        \mollyLfoFade, 0,
        \mollyEnv1Attack, 0.01,
        \mollyEnv1Decay, 0.3,
        \mollyEnv1Sustain, 0.5,
        \mollyEnv1Release, 0.5,
        \mollyEnv2Attack, 0.01,
        \mollyEnv2Decay, 0.3,
        \mollyEnv2Sustain, 0.5,
        \mollyEnv2Release, 0.5,
        \mollyAmpMod, 0,
        \mollyChannelPressure, 0,
        \mollyTimbre, 0,
        \mollyRingModFade, 0,
        \mollyRingModMix, 0,
        \mollyChorusMix, 0
      ]));

      instMollyMixerSynth.put(inst_id, Synth(\mollyMixer, [
        \in, instMollyMixerBus.at(inst_id),
        \out, this.getTrackBus(track_id),
      ], target: context.server, addAction: \addToTail).onFree({
        ("freed molly mixer synth inst "++inst_id).postln;
      }));

      ("Sending instMollyMixer -> " ++ this.getTrackBus(track_id)).postln;
    }, {

      if( track_id.notNil, {
        ("Updating existing molly inst bus+mixer " ++ inst_id ++ " track " ++ track_id).postln;

        instMollyMixerSynth.at(inst_id).set(
          \in, instMollyMixerBus.at(inst_id),
          \out, this.getTrackBus(track_id),
        );
        ("Re-setting instMollyMixerSynth in: " ++ instMollyMixerBus.at(inst_id) ++ " out " ++ this.getTrackBus(track_id)).postln;
      });
    });

    ^instMollyMixerBus.at(inst_id);
  }

  getInstMollyMixerSynth {
    arg inst_id;
    this.getInstMollyMixerBus(inst_id, 0); // Force it to be created, ignore result
    ^instMollyMixerSynth.at(inst_id);
  }

  getInstMollySetting {
    arg inst_id, setting;
    this.getInstMollyMixerBus(inst_id); // Force it to be created, ignore result
    ^instMollySettings.at(inst_id).at(setting);
  }

  setInstMollySetting {
    arg inst_id, setting, value;
    this.getInstMollyMixerBus(inst_id); // Force it to be created, ignore result
    ^instMollySettings.at(inst_id).put(setting, value);
  }


  getInstMollyLfoBus {
    arg inst_id;

    if(instMollyLfoBus.at(inst_id) == nil, {
      ("Creating new molly lfo inst bus+mixer " ++ inst_id).postln;

      instMollyLfoBus.put(inst_id, Bus.audio(context.server, 1));
      instMollyRingModBus.put(inst_id, Bus.audio(context.server, 1));

      instMollyLfo.put(inst_id, Synth(\mollyLfo, [
        \mollyLfoOut, instMollyLfoBus.at(inst_id),
        \mollyRingModOut, instMollyRingModBus.at(inst_id)
      ], target: context.server, addAction: \addToHead).onFree({
        ("freed molly mixer synth inst "++inst_id).postln;
      }));
    });

    ^instMollyLfoBus.at(inst_id);
  }

  getInstMollyLfo {
    arg inst_id;
    this.getInstMollyLfoBus(inst_id); // Force it to be created, ignore result
    ^instMollyLfo.at(inst_id);
  }

  getInstMollyRingModBus {
    arg inst_id;
    this.getInstMollyLfoBus(inst_id); // Force it to be created, ignore result
    ^instMollyRingModBus.at(inst_id);
  }

  queueLoadSample {
    arg sampleId, filePath;
    var item = (
      sampleId: sampleId,
      filePath: filePath
    );

    loadQueue = loadQueue.addFirst(item);
    if(loadingSample == -1, {
      this.loadSample()
    });
  }

  killVoicesPlaying {
    arg sampleId;
    var activeVoices;

    // Kill any voices that are currently playing this sampleId
    activeVoices = voiceList.select{arg v; v.sampleId == sampleId};
    activeVoices.do({
      arg v;
      if(v.startRoutine.notNil, {
        v.startRoutine.stop;
        v.startRoutine.free;
      }, {
        v.theSynth.set(\killGate, -1);
      });
      voiceList.remove(v);
    });
  }

  clearBuffer {
    arg sampleId;

    this.killVoicesPlaying(sampleId);

    if(samples[sampleId].buffer.notNil, {
      samples[sampleId].buffer.close;
      samples[sampleId].buffer.free;
      samples[sampleId].buffer = nil;
    });

    samples[sampleId].numFrames = 0;
  }

  moveSample {
    arg fromId, toId;
    var fromSample = samples[fromId];

    if(fromId != toId, {
      this.killVoicesPlaying(fromId);
      this.killVoicesPlaying(toId);
      samples[fromId] = samples[toId];
      samples[toId] = fromSample;
    });
  }

  copySample {
    arg fromId, toFirstId, toLastId;

    for(toFirstId, toLastId, {
      arg i;
      if(fromId != i, {
        this.killVoicesPlaying(fromId);
        this.killVoicesPlaying(i);
        samples[i] = samples[fromId].deepCopy;
      });
    });
  }

  copyParams {
    arg fromId, toFirstId, toLastId;

    for(toFirstId, toLastId, {
      arg i;
      var newSample;

      if((fromId != i).and(samples[i].numFrames > 0), {
        this.killVoicesPlaying(fromId);
        this.killVoicesPlaying(i);

        // Copies all except play mode and marker positions
        newSample = samples[fromId].deepCopy;

        newSample.streaming = samples[i].streaming;
        newSample.buffer = samples[i].buffer;
        newSample.filePath = samples[i].filePath;

        newSample.channels = samples[i].channels;
        newSample.sampleRate = samples[i].sampleRate;
        newSample.numFrames = samples[i].numFrames;

        newSample.startFrame = samples[i].startFrame;
        newSample.endFrame = samples[i].endFrame;
        newSample.playMode = samples[i].playMode;
        newSample.loopStartFrame = samples[i].loopStartFrame;
        newSample.loopEndFrame = samples[i].loopEndFrame;

        samples[i] = newSample;
      });
    });
  }

  loadFailed {
    arg sampleId, message;
    if(message.notNil, {
      (sampleId.asString ++ ":" + message).postln;
    });
    scriptAddress.sendBundle(0, ['/engineSampleLoadFailed', sampleId, message]);
  }

  loadSample {
    var item, sampleId, filePath, file, buffer, sample = ();

    if(loadQueue.notEmpty, {

      item = loadQueue.pop;
      sampleId = item.sampleId;
      filePath = item.filePath;

      loadingSample = sampleId;
      // ("Load" + sampleId + filePath).postln;

      this.clearBuffer(sampleId);

      if((sampleId < 0).or(sampleId >= samples.size), {
        ("Invalid sample ID:" + sampleId + "(must be 0-" ++ (samples.size - 1) ++ ").").postln;
        this.loadSample();

      }, {

        if(filePath.compare("-") != 0, {

          file = SoundFile.openRead(filePath);
          if(file.isNil, {
            this.loadFailed(sampleId, "Could not open file");
            this.loadSample();
          }, {

            sample = samples[sampleId];

            sample.filePath = filePath;
            sample.channels = file.numChannels.min(2);
            sample.sampleRate = file.sampleRate;
            sample.startFrame = 0;
            sample.endFrame = file.numFrames;
            sample.loopStartFrame = 0;
            sample.loopEndFrame = file.numFrames;

            // Max sample size of 2hr at 48kHz (aribtary number)
            if(file.numFrames > 345600000, {
              this.loadFailed(sampleId, "Too long, 2hr@48k max");
              this.loadSample();

            }, {

              // If file is over 5 secs stereo or 10 secs mono (at 48kHz) then prepare it for streaming instead.
              // This makes for max buffer memory usage of 500MB which seems to work out.
              // Streaming has fairly limited options for playback (no looping etc).

              // if(file.numFrames * sample.channels < 4800000, {
              if(1 < 2, {

                // Load into memory
                if(file.numChannels == 1, {
                  buffer = Buffer.read(server: context.server, path: filePath, action: {
                    arg buf;
                    if(buf.numFrames > 0, {
                      sample.numFrames = file.numFrames;
                      samples[sampleId] = sample;
                      scriptAddress.sendBundle(0, ['/engineSampleLoaded', sampleId, 0, file.numFrames, file.numChannels, file.sampleRate]);
                      ("Buffer" + sampleId + "loaded:" + buf.numFrames + "frames." + buf.duration.round(0.01) + "secs." + buf.numChannels + "channel.").postln;
                    }, {
                      this.loadFailed(sampleId, "Failed to load");
                    });
                    this.loadSample();
                  });
                }, {
                  buffer = Buffer.readChannel(server: context.server, path: filePath, channels: [0, 1], action: {
                    arg buf;
                    if(buf.numFrames > 0, {
                      sample.numFrames = file.numFrames;
                      samples[sampleId] = sample;
                      scriptAddress.sendBundle(0, ['/engineSampleLoaded', sampleId, 0, file.numFrames, file.numChannels, file.sampleRate]);
                      ("Buffer" + sampleId + "loaded:" + buf.numFrames + "frames." + buf.duration.round(0.01) + "secs." + buf.numChannels + "channels.").postln;
                    }, {
                      this.loadFailed(sampleId, "Failed to load");
                    });
                    this.loadSample();
                  });
                });
                sample.buffer = buffer;
                sample.streaming = 0;

              }, {
                if(file.numChannels > 2, {
                  this.loadFailed(sampleId, "Too many chans (" ++ file.numChannels ++ ")");
                  this.loadSample();
                }, {
                  // Prepare for streaming from disk
                  sample.streaming = 1;
                  sample.numFrames = file.numFrames;
                  samples[sampleId] = sample;
                  scriptAddress.sendBundle(0, ['/engineSampleLoaded', sampleId, 1, file.numFrames, file.numChannels, file.sampleRate]);
                  // ("Stream buffer" + sampleId + "prepared:" + file.numFrames + "frames." + file.duration.round(0.01) + "secs." + file.numChannels + "channels.").postln;
                  this.loadSample();
                });
              });
            });

            file.close;

          });
        }, {
          this.loadFailed(sampleId);
          this.loadSample();
        });
      });
    }, {
      // Done
      loadingSample = -1;
    });
  }

  clearSamples {
    arg firstId, lastId = firstId;

    this.stopWaveformGeneration(firstId, lastId);

    firstId.for(lastId, {
      arg i;
      var removeQueueIndex;

      if(samples[i].notNil, {

        // Remove from load queue
        removeQueueIndex = loadQueue.detectIndex({
          arg item;
          item.sampleId == i;
        });
        if(removeQueueIndex.notNil, {
          loadQueue.removeAt(removeQueueIndex);
        });

        this.clearBuffer(i);

        samples[i] = defaultSample.deepCopy;
      });

    });
  }

  queueWaveformGeneration {
    arg sampleId;
    var item;

    this.stopWaveformGeneration(sampleId);

    if(samples[sampleId].filePath.notNil, {

      item = (
        sampleId: sampleId,
        filePath: samples[sampleId].filePath
      );

      waveformQueue = waveformQueue.addFirst(item);

      if(generatingWaveform == -1, {
        this.generateWaveforms();
      });
    });
  }

  stopWaveformGeneration {
    arg firstId, lastId = firstId;

    // Clear from queue
    firstId.for(lastId, {
      arg i;
      var removeQueueIndex;

      // Remove any existing with same ID
      removeQueueIndex = waveformQueue.detectIndex({
        arg item;
        item.sampleId == i;
      });
      if(removeQueueIndex.notNil, {
        waveformQueue.removeAt(removeQueueIndex);
      });
    });

    // Stop currently in progress
    if((generatingWaveform >= firstId).and(generatingWaveform <= lastId), {
      abandonCurrentWaveform = true;
    });
  }

  generateWaveforms {

    var samplesPerSlice = 1000; // Changes the fidelity of each 'slice' of the waveform (number of samples it checks peaks of)
    var sendEvery = 3;
    var totalStartSecs = Date.getDate.rawSeconds;
    var waveformRoutine;

    generatingWaveform = waveformQueue.last.sampleId;
    "Started generating waveforms".postln;

    waveformRoutine = Routine.new({

      while({ waveformQueue.notEmpty }, {
        var startSecs = Date.getDate.rawSeconds;
        var file, rawData, waveform, numFramesRemaining, numChannels, chunkSize, numSlices, sliceSize, stride, framesInSliceRemaining;
        var frame = 0, slice = 0, offset = 0;
        var item = waveformQueue.pop;
        var sampleId = item.sampleId;

        generatingWaveform = sampleId;

        // Pause if we're loading samples
        while({ loadQueue.notEmpty }, {
          0.2.yield;
        });

        file = SoundFile.openRead(item.filePath);
        if(file.isNil, {
          ("File could not be opened for waveform generation:" + item.filePath).postln;
        }, {

          // ("Waveform" + sampleId + "started").postln;

          numFramesRemaining = file.numFrames;
          numChannels = file.numChannels;
          chunkSize = (1048576 / numChannels).floor * numChannels;
          numSlices = waveformDisplayRes.min(file.numFrames);
          sliceSize = file.numFrames / waveformDisplayRes;
          framesInSliceRemaining = sliceSize;
          stride = (sliceSize / samplesPerSlice).max(1);

          waveform = Int8Array.new((numSlices * 2) + (numSlices % 4));

          // Process in chunks
          while({
            (numFramesRemaining > 0).and({
              rawData = FloatArray.newClear(min(numFramesRemaining * numChannels, chunkSize));
              file.readData(rawData);
              rawData.size > 0;
            }).and(abandonCurrentWaveform == false)
          }, {

            var min = 0, max = 0;

            while({ (frame.round * numChannels + numChannels - 1 < rawData.size).and(abandonCurrentWaveform == false) }, {
              for(0, numChannels.min(2) - 1, {
                arg c;
                var sample = rawData[frame.round.asInt * numChannels + c];
                min = sample.min(min);
                max = sample.max(max);
              });

              frame = frame + stride;
              framesInSliceRemaining = framesInSliceRemaining - stride;

              // Slice done
              if(framesInSliceRemaining < 1, {

                framesInSliceRemaining = framesInSliceRemaining + sliceSize;

                // 0-126, 63 is center (zero)
                min = min.linlin(-1, 0, 0, 63).round.asInt;
                max = max.linlin(0, 1, 63, 126).round.asInt;
                waveform = waveform.add(min);
                waveform = waveform.add(max);
                min = 0;
                max = 0;

                if(((slice + 1) % sendEvery == 0).and(abandonCurrentWaveform == false), {
                  this.sendWaveform(sampleId, offset, waveform);
                  offset = offset + sendEvery;
                  waveform = Int8Array.new(((numSlices - offset) * 2) + (numSlices % 4));
                });
                slice = slice + 1;
              });

              // Let other sclang work happen if it's a long file
              if(file.numFrames > 1000000, {
                0.00004.yield;
              });
            });

            frame = frame - (rawData.size / numChannels);
            numFramesRemaining = numFramesRemaining - (rawData.size / numChannels);
          });

          file.close;

          if(abandonCurrentWaveform, {
            abandonCurrentWaveform = false;
            // ("Waveform" + sampleId + "abandoned after" + (Date.getDate.rawSeconds - startSecs).round(0.001) + "s").postln;
          }, {
            if(waveform.size > 0, {
              this.sendWaveform(sampleId, offset, waveform);
            });
            // ("Waveform" + sampleId + "generated in" + (Date.getDate.rawSeconds - startSecs).round(0.001) + "s").postln;
          });
        });

        // Let other sclang work happen
        0.002.yield;
      });

      ("Finished generating waveforms in" + (Date.getDate.rawSeconds - totalStartSecs).round(0.001) + "s").postln;
      generatingWaveform = -1;

    }).play;
  }

  sendWaveform {
    arg sampleId, offset, waveform;
    var padding = 0;

    // Pad to work around https://github.com/supercollider/supercollider/issues/2125
    while({ waveform.size % 4 > 0 }, {
      waveform = waveform.add(0);
      padding = padding + 1;
    });

    // ("Send waveform for" + sampleId + "offset" + offset + "size" + waveform.size).postln;
    scriptAddress.sendBundle(0, ['/engineWaveform', sampleId, offset, padding, waveform]);
  }

  assignVoice {
    arg trackId, voiceId, sampleId, freq, pitchBendRatio, vel;
    var voiceToRemove;

    // Remove a voice if ID matches or there are too many
    voiceToRemove = voiceList.detect{arg v; v.id == voiceId};
    if(voiceToRemove.isNil && (voiceList.size >= maxVoices), {
      voiceToRemove = voiceList.detect{arg v; v.gate == 0};
      if(voiceToRemove.isNil, {
        voiceToRemove = voiceList.last;
      });
    });

    if(voiceToRemove.notNil, {
      if(voiceToRemove.startRoutine.notNil, {
        voiceToRemove.startRoutine.stop;
        voiceToRemove.startRoutine.free;
        voiceList.remove(voiceToRemove);
        this.addVoice(voiceId, trackId, sampleId, freq, pitchBendAllRatio, vel, false);
      }, {
        voiceToRemove.theSynth.set(\killGate, 0);
        voiceList.remove(voiceToRemove);
        this.addVoice(voiceId, trackId, sampleId, freq, pitchBendAllRatio, vel, true);
      });
    }, {
      this.addVoice(voiceId, trackId, sampleId, freq, pitchBendAllRatio, vel, false);
    });
  }

  addVoice {
    arg voiceId, trackId, sampleId, freq, pitchBendRatio, vel, delayStart;
    var defName, sample = samples[sampleId], streamBuffer, delay = 0, cueSecs;

    if(delayStart, { delay = killDuration; });

    if(sample.numFrames > 0, {
      if(sample.streaming == 0, {
        if(sample.buffer.numChannels == 1, {
          defName = \monoBufferVoice;
        }, {
          defName = \stereoBufferVoice;
        });
        this.addSynth(defName, voiceId, trackId, sampleId, sample.buffer, freq, pitchBendRatio, vel, delay);

      }, {
        cueSecs = Date.getDate.rawSeconds;
        Buffer.cueSoundFile(server: context.server, path: sample.filePath, startFrame: sample.startFrame, numChannels: sample.channels, bufferSize: 65536, completionMessage: {
          arg streamBuffer;
          // ("Sound file cued. Chans:" + streamBuffer.numChannels + "size" + streamBuffer.size).postln;
          if(streamBuffer.numChannels == 1, {
            defName = \monoStreamingVoice;
          }, {
            defName = \stereoStreamingVoice;
          });
          delay = (delay - (Date.getDate.rawSeconds - cueSecs)).max(0);
          this.addSynth(defName, voiceId, trackId, sampleId, streamBuffer, freq, pitchBendRatio, vel, delay);
          0;
        });
      });
    });
  }

  addSynth {
    arg defName, voiceId, trackId, sampleId, buffer, freq, pitchBendRatio, vel, delay;
    var newVoice, sample = samples[sampleId];

    newVoice = (id: voiceId, trackId: trackId, sampleId: sampleId, gate: 1);

    // Delay adding a new synth until after killDuration if need be
    newVoice.startRoutine = Routine {
      delay.wait;

      newVoice.theSynth = Synth.new(defName: defName, args: [
        \out, this.getTrackBus(trackId),
        \bufnum, buffer.bufnum,

        \voiceId, voiceId,
        \sampleId, sampleId,

        \sampleRate, sample.sampleRate,
        \numFrames, sample.numFrames,
        \freq, freq,
        \transposeRatio, sample.transpose.midiratio,
        \detuneRatio, (sample.detuneCents / 100).midiratio,
        \pitchBendRatio, pitchBendRatio,
        \pitchBendSampleRatio, sample.pitchBendRatio,
        \gate, 1,
        \vel, vel,
        \pressure, pressureAll,
        \pressureSample, sample.pressure,

        \startFrame, sample.startFrame,
        \i_lockedStartFrame, sample.startFrame,
        \endFrame, sample.endFrame,
        \playMode, sample.playMode,
        \loopStartFrame, sample.loopStartFrame,
        \loopEndFrame, sample.loopEndFrame,

        \lfos, lfoBus,
        \lfo1Fade, sample.lfo1Fade,
        \lfo2Fade, sample.lfo2Fade,

        \freqMultiplier, sample.freqMultiplier,

        \freqModLfo1, sample.freqModLfo1,
        \freqModLfo2, sample.freqModLfo2,
        \freqModEnv, sample.freqModEnv,

        \ampAttack, sample.ampAttack,
        \ampDecay, sample.ampDecay,
        \ampSustain, sample.ampSustain,
        \ampRelease, sample.ampRelease,
        \modAttack, sample.modAttack,
        \modDecay, sample.modDecay,
        \modSustain, sample.modSustain,
        \modRelease, sample.modRelease,

        \downSampleTo, sample.downSampleTo,
        \bitDepth, sample.bitDepth,

        \filterFreq, sample.filterFreq,
        \filterReso, sample.filterReso,
        \filterType, sample.filterType,
        \filterTracking, sample.filterTracking,
        \filterFreqModLfo1, sample.filterFreqModLfo1,
        \filterFreqModLfo2, sample.filterFreqModLfo2,
        \filterFreqModEnv, sample.filterFreqModEnv,
        \filterFreqModVel, sample.filterFreqModVel,
        \filterFreqModPressure, sample.filterFreqModPressure,

        \pan, sample.pan,
        \panModLfo1, sample.panModLfo1,
        \panModLfo2, sample.panModLfo2,
        \panModEnv, sample.panModEnv,

        \amp, sample.amp,
        \ampModLfo1, sample.ampModLfo1,
        \ampModLfo2, sample.ampModLfo2,

      ], target: voiceGroup).onFree({

        if(sample.streaming == 1, {
          if(buffer.notNil, {
            buffer.close;
            buffer.free;
          });
        });
        voiceList.remove(newVoice);

        scriptAddress.sendBundle(0, ['/engineVoiceFreed', sampleId, voiceId]);

      });

      scriptAddress.sendBundle(0, ['/enginePlayPosition', sampleId, voiceId, sample.startFrame / sample.numFrames]);

      newVoice.startRoutine.free;
      newVoice.startRoutine = nil;
    }.play;

    voiceList.addFirst(newVoice);
  }



  // Commands

  setArgOnVoice {
    arg voiceId, name, value;
    var voice = voiceList.detect{arg v; v.id == voiceId};
    if(voice.notNil, {
      voice.theSynth.set(name, value);
    });
  }

  setArgOnSample {
    arg sampleId, name, value;
    if(samples[sampleId].notNil, {
      samples[sampleId][name] = value;
      this.setArgOnVoicesPlayingSample(sampleId, name, value);
    });
  }

  setArgOnVoicesPlayingSample {
    arg sampleId, name, value;
    var voices = voiceList.select{arg v; v.sampleId == sampleId};
    voices.do({
      arg v;
      v.theSynth.set(name, value);
    });
  }

  addCommands {

    // generateWaveform(id)
    this.addCommand(\generateWaveform, "i", {
      arg msg;
      this.queueWaveformGeneration(msg[1]);
    });

    // noteOn(id, freq, vel, sampleId)
    this.addCommand(\noteOn, "iiffi", {
      arg msg;
      var track_id = msg[1], id = msg[2], freq = msg[3], vel = msg[4] ?? 1, sampleId = msg[5] ?? 0,
      sample = samples[sampleId];

      // debugBuffer.zero();

      if(sample.notNil, {
        this.assignVoice(track_id, id, sampleId, freq, pitchBendAllRatio, vel);
      });
    });

    // noteOff(id)
    this.addCommand(\noteOff, "i", {
      arg msg;
      var voice = voiceList.detect{arg v; v.id == msg[1]};
      if(voice.notNil, {
        if(voice.startRoutine.notNil, {
          voice.startRoutine.stop;
          voice.startRoutine.free;
          voiceList.remove(voice);
        }, {
          voice.theSynth.set(\gate, 0);
          voice.gate = 0;
          // Move voice to end so that oldest gate-off voices are found first when stealing
          voiceList.remove(voice);
          voiceList.add(voice);
        });
      });
    });

    // noteOffAll()
    this.addCommand(\noteOffAll, "", {
      arg msg;
      voiceList.do({
        arg v;
        if(v.startRoutine.notNil, {
          v.startRoutine.stop;
          v.startRoutine.free;
          voiceList.remove(v);
        });
        v.gate = 0;
      });
      voiceGroup.set(\gate, 0);
    });

    // noteKill(id)
    this.addCommand(\noteKill, "i", {
      arg msg;
      var voice = voiceList.detect{arg v; v.id == msg[1]};
      if(voice.notNil, {
        if(voice.startRoutine.notNil, {
          voice.startRoutine.stop;
          voice.startRoutine.free;
        }, {
          voice.theSynth.set(\killGate, 0);
        });
        voiceList.remove(voice);
      });
    });

    // noteKillAll()
    this.addCommand(\noteKillAll, "", {
      arg msg;
      voiceList.do({
        arg v;
        if(v.startRoutine.notNil, {
          v.startRoutine.stop;
          v.startRoutine.free;
        });
        v.gate = 0;
      });
      voiceGroup.set(\killGate, 0);
      voiceList.clear;
    });

    // pitchBendVoice(id, ratio)
    this.addCommand(\pitchBendVoice, "if", {
      arg msg;
      this.setArgOnVoice(msg[1], \pitchBendRatio, msg[2]);
    });

    // pitchBendSample(id, ratio)
    this.addCommand(\pitchBendSample, "if", {
      arg msg;
      this.setArgOnSample(msg[1], \pitchBendSampleRatio, msg[2]);
    });

    // pitchBendAll(ratio)
    this.addCommand(\pitchBendAll, "f", {
      arg msg;
      pitchBendAllRatio = msg[1];
      voiceGroup.set(\pitchBendRatio, pitchBendAllRatio);
    });

    // pressureVoice(id, pressure)
    this.addCommand(\pressureVoice, "if", {
      arg msg;
      this.setArgOnVoice(msg[1], \pressure, msg[2]);
    });

    // pressureSample(id, pressure)
    this.addCommand(\pressureSample, "if", {
      arg msg;
      this.setArgOnSample(msg[1], \pressureSample, msg[2]);
    });

    // pressureAll(pressure)
    this.addCommand(\pressureAll, "f", {
      arg msg;
      pressureAll = msg[1];
      voiceGroup.set(\pressure, pressureAll);
    });

    this.addCommand(\lfo1Freq, "f", { arg msg;
      lfos.set(\lfo1Freq, msg[1]);
    });

    this.addCommand(\lfo1WaveShape, "i", { arg msg;
      lfos.set(\lfo1WaveShape, msg[1]);
    });

    this.addCommand(\lfo2Freq, "f", { arg msg;
      lfos.set(\lfo2Freq, msg[1]);
    });

    this.addCommand(\lfo2WaveShape, "i", { arg msg;
      lfos.set(\lfo2WaveShape, msg[1]);
    });


    // Sample commands

    // loadSample(id, filePath)
    this.addCommand(\loadSample, "is", {
      arg msg;
      this.queueLoadSample(msg[1], msg[2].asString);
    });

    this.addCommand(\clearSamples, "ii", {
      arg msg;
      this.clearSamples(msg[1], msg[2]);
    });

    this.addCommand(\moveSample, "ii", {
      arg msg;
      this.moveSample(msg[1], msg[2]);
    });

    this.addCommand(\copySample, "iii", {
      arg msg;
      this.copySample(msg[1], msg[2], msg[3]);
    });

    this.addCommand(\copyParams, "iii", {
      arg msg;
      this.copyParams(msg[1], msg[2], msg[3]);
    });

    this.addCommand(\transpose, "if", {
      arg msg;
      var sampleId = msg[1], value = msg[2];
      if(samples[sampleId].notNil, {
        samples[sampleId][\transpose] = value;
        this.setArgOnVoicesPlayingSample(sampleId, \transposeRatio, value.midiratio);
      });

      // TODO
      // debugBuffer.write('/home/we/dust/code/timber/lib/debug.wav');
    });

    this.addCommand(\detuneCents, "if", {
      arg msg;
      var sampleId = msg[1], value = msg[2];
      if(samples[sampleId].notNil, {
        samples[sampleId][\detuneCents] = value;
        this.setArgOnVoicesPlayingSample(sampleId, \detuneRatio, (value / 100).midiratio);
      });
    });

    this.addCommand(\startFrame, "ii", {
      arg msg;
      this.setArgOnSample(msg[1], \startFrame, msg[2]);
    });

    this.addCommand(\endFrame, "ii", {
      arg msg;
      this.setArgOnSample(msg[1], \endFrame, msg[2]);
    });

    this.addCommand(\playMode, "ii", {
      arg msg;
      this.setArgOnSample(msg[1], \playMode, msg[2]);
    });

    this.addCommand(\loopStartFrame, "ii", {
      arg msg;
      this.setArgOnSample(msg[1], \loopStartFrame, msg[2]);
    });

    this.addCommand(\loopEndFrame, "ii", {
      arg msg;
      this.setArgOnSample(msg[1], \loopEndFrame, msg[2]);
    });

    this.addCommand(\lfo1Fade, "if", {
      arg msg;
      this.setArgOnSample(msg[1], \lfo1Fade, msg[2]);
    });

    this.addCommand(\lfo2Fade, "if", {
      arg msg;
      this.setArgOnSample(msg[1], \lfo2Fade, msg[2]);
    });

    this.addCommand(\freqModLfo1, "if", {
      arg msg;
      this.setArgOnSample(msg[1], \freqModLfo1, msg[2]);
    });

    this.addCommand(\freqModLfo2, "if", {
      arg msg;
      this.setArgOnSample(msg[1], \freqModLfo2, msg[2]);
    });

    this.addCommand(\freqModEnv, "if", {
      arg msg;
      this.setArgOnSample(msg[1], \freqModEnv, msg[2]);
    });

    this.addCommand(\freqMultiplier, "if", {
      arg msg;
      this.setArgOnSample(msg[1], \freqMultiplier, msg[2]);
    });

    this.addCommand(\ampAttack, "if", {
      arg msg;
      this.setArgOnSample(msg[1], \ampAttack, msg[2]);
    });

    this.addCommand(\ampDecay, "if", {
      arg msg;
      this.setArgOnSample(msg[1], \ampDecay, msg[2]);
    });

    this.addCommand(\ampSustain, "if", {
      arg msg;
      this.setArgOnSample(msg[1], \ampSustain, msg[2]);
    });

    this.addCommand(\ampRelease, "if", {
      arg msg;
      this.setArgOnSample(msg[1], \ampRelease, msg[2]);
    });

    this.addCommand(\modAttack, "if", {
      arg msg;
      this.setArgOnSample(msg[1], \modAttack, msg[2]);
    });

    this.addCommand(\modDecay, "if", {
      arg msg;
      this.setArgOnSample(msg[1], \modDecay, msg[2]);
    });

    this.addCommand(\modSustain, "if", {
      arg msg;
      this.setArgOnSample(msg[1], \modSustain, msg[2]);
    });

    this.addCommand(\modRelease, "if", {
      arg msg;
      this.setArgOnSample(msg[1], \modRelease, msg[2]);
    });

    this.addCommand(\downSampleTo, "ii", {
      arg msg;
      this.setArgOnSample(msg[1], \downSampleTo, msg[2]);
    });

    this.addCommand(\bitDepth, "ii", {
      arg msg;
      this.setArgOnSample(msg[1], \bitDepth, msg[2]);
    });

    this.addCommand(\filterFreq, "if", {
      arg msg;
      this.setArgOnSample(msg[1], \filterFreq, msg[2]);
    });

    this.addCommand(\filterReso, "if", {
      arg msg;
      this.setArgOnSample(msg[1], \filterReso, msg[2]);
    });

    this.addCommand(\filterType, "ii", {
      arg msg;
      this.setArgOnSample(msg[1], \filterType, msg[2]);
    });

    this.addCommand(\filterTracking, "if", {
      arg msg;
      this.setArgOnSample(msg[1], \filterTracking, msg[2]);
    });

    this.addCommand(\filterFreqModLfo1, "if", {
      arg msg;
      this.setArgOnSample(msg[1], \filterFreqModLfo1, msg[2]);
    });

    this.addCommand(\filterFreqModLfo2, "if", {
      arg msg;
      this.setArgOnSample(msg[1], \filterFreqModLfo2, msg[2]);
    });

    this.addCommand(\filterFreqModEnv, "if", {
      arg msg;
      this.setArgOnSample(msg[1], \filterFreqModEnv, msg[2]);
    });

    this.addCommand(\filterFreqModVel, "if", {
      arg msg;
      this.setArgOnSample(msg[1], \filterFreqModVel, msg[2]);
    });

    this.addCommand(\filterFreqModPressure, "if", {
      arg msg;
      this.setArgOnSample(msg[1], \filterFreqModPressure, msg[2]);
    });

    this.addCommand(\pan, "if", {
      arg msg;
      this.setArgOnSample(msg[1], \pan, msg[2]);
    });

    this.addCommand(\panModLfo1, "if", {
      arg msg;
      this.setArgOnSample(msg[1], \panModLfo1, msg[2]);
    });

    this.addCommand(\panModLfo2, "if", {
      arg msg;
      this.setArgOnSample(msg[1], \panModLfo2, msg[2]);
    });

    this.addCommand(\panModEnv, "if", {
      arg msg;
      this.setArgOnSample(msg[1], \panModEnv, msg[2]);
    });

    this.addCommand(\amp, "if", {
      arg msg;
      this.setArgOnSample(msg[1], \amp, msg[2]);
    });

    this.addCommand(\ampModLfo1, "if", {
      arg msg;
      this.setArgOnSample(msg[1], \ampModLfo1, msg[2]);
    });

    this.addCommand(\ampModLfo2, "if", {
      arg msg;
      this.setArgOnSample(msg[1], \ampModLfo2, msg[2]);
    });




  }

  free {
    if(waveformRoutine.notNil, {
      waveformRoutine.stop;
      waveformRoutine.free;
    });
    samples.do({
      arg item, i;
      if(item.notNil, {
        if(item.buffer.notNil, {
          item.buffer.free;
        });
      });
    });
    // NOTE: Are these already getting freed elsewhere?
    scriptAddress.free;
    replyFunc.free;
    synthNames.free;
    voiceList.free;
    players.free;
    voiceGroup.free;
    lfos.free;
    // mixer.free;

    ///////// MOLLY THE POLY SLICE ////////////////////////


    instMollyMixerBus.keysValuesDo({ arg key, value; value.free; });
    instMollyMixerSynth.keysValuesDo({ arg key, value; value.free; });

    instMollyLfoBus.keysValuesDo({ arg key, value; value.free; });
    instMollyLfo.keysValuesDo({ arg key, value; value.free; });
    ///////// END MOLLY THE POLY SLICE ////////////////////////

    // Sampler thing
    synSample.keysValuesDo({ arg key, value; value.free; });
    bufSample.keysValuesDo({ arg key, value; value.free; });
    // END Sampler thing

    // <Goldeneye>
    synGoldeneye.keysValuesDo({ arg key, value; value.free; });
    bufGoldeneye.keysValuesDo({ arg key, value; value.free; });
    // </Goldeneye>

    trackMixer.keysValuesDo({ arg key, value; value.free; });
    trackBus.keysValuesDo({ arg key, value; value.free; });
  }
}
