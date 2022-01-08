```lua
-- Here are some examples of things you can do
-- This can be used as a cookbook
-- The idea is to copy/paste each of these one-line things into the REPL
-- Or press buttons to trigger events

-- This is a REPL -- Read Eval Print Loop
-- You can run arbitrary lua commands and see the result
2+2

-- First, play some built-in 808 samples
-- When you enter one of these and press <enter> it immediately runs
-- Press <enter> again to run the most recent command
BD()
BD -- if you give JUST a function it is automatically evaluated
CH
SD
CP

-- Errors and other output show up on the right side
print "hello"
notreal()

-- Play a piano sample with notes or midi-nums
-- Up-arrow to edit previous input/output
piano:note('c')
piano:note(60)

-- You can record these into a loop!
a:rec() -- records manual events, both commands and button-press results
BD
BD
CP
piano:note('c')
piano:note('e')
a:stop() -- stop recording
a:stop() -- stop playing

-- Loops a-h are already set up; you can rec and play and stop and clear
a:clear()

-- We can fill in a whole loop with this generator
-- Simple slow drums
a:play()
a:gen("CH")
a:gen("BS", 1, 4) -- 1 of every 4
a:gen("SD", 3, 4)
a:gen("RS", 4, 4)

-- Samples can be tuned via Timber params
-- All the 808 sampels are under s808 (try `s808.<tab>`)
-- Amp up the kick
s808.BS:amp(10)

-- Drum break
-- Press <tab> to auto-complete!
a:setLength(3)
a:setLength(16)

-- Open hat a little after kick
b:setLength(4)
b:rec()
OH
b:stop()

-- Symbols crash slightly after kick
b:rec()
CY
b:stop()

-- Playable piano on bottom row
-- Backticks are evaluated up front
-- n = step number (like 1..16)
-- m = step number minus one (like 0..15)
h:gen("p(`55+n`)")

-- Record some piano pattern
c:rec()
-- press some row-H buttons
-- The commands on the buttons get recorded as if you ran them directly
c:stop()

-- Turn piano into cool synth thing
-- You can copy this whole multi-line thing in if you want
piano:reverse()
piano:startFrame(20000)
piano:endFrame(1000)
piano:transpose(-20)
piano:filterFreq(800)
piano:bitdepth(4)

-- You could record these changes too
-- Easiest if you put them on a control row first
g:gen("piano:filterFreq(`100 * n`)")
d:rec()
-- Press row-g things, get some low-pass warble
d:stop()
g:clear()

-- global audio control
g:gen("audio.level_dac(`(16-n)/32`)")
audio.rev_on()
audio.rev_off()

-- Let's try some sample slicing
s4 = Sample.new("/home/we/dust/code/repl-looper/audio/mfa/The-Call-of-the-Polar-Star_fma-115766_001_00-00-01.ogg")
s4:playMode(2) -- One-shot
-- Each button selects and then plays a slice of the sample
-- 29090 is about 1 quarter note worth of 48000 frames. Give or take.
e:gen("s4:startFrame(`29090 * m`); s4:loopStartFrame(`29090 * m`); s4:endFrame(`29090 * n`); s4:loopEndFrame(`29090 * n`); s4:play()")
e:play() -- Listen to each slice, or push buttons to trigger

-- Pick a random sample! Then you can splice or play it or filter it
files = util.scandir('/home/we/dust/code/repl-looper/audio/musicbox')
random_file = files[math.random(#files)]
s4 = Sample.new("/home/we/dust/code/repl-looper/audio/musicbox/" .. random_file)
b:gen("s4:startFrame(`29090 * m`); s4:loopStartFrame(`29090 * m`); s4:endFrame(`29090 * n`); s4:loopEndFrame(`29090 * n`); s4:play()")

--
random_file = "Rocking-Chair-Blues_DR001434_003_00-02-20.ogg"
s4 = Sample.new("/home/we/dust/code/repl-looper/audio/musicbox/" .. random_file)

--

-- Hip Hop Beat
a:setLength(4)
a:gen("BS", {1, 2.75, 3.5, 4.25, 4.75})
a:gen("SD", {2, 4})
a:gen("CH", {1,1.5,2,2.5,3,3.5,4,4.5})

-- Cool song, let's layer it
s1 = Sample.new("/home/we/dust/code/repl-looper/audio/musicbox/Wouldnt-Mind-Workin-From-Sun-To-Sun_2011121108_001_00-01-05.ogg", "one-shot")
s2 = Sample.new("/home/we/dust/code/repl-looper/audio/musicbox/Wouldnt-Mind-Workin-From-Sun-To-Sun_2011121108_002_00-01-32.ogg", "one-shot")
s3 = Sample.new("/home/we/dust/code/repl-looper/audio/musicbox/Wouldnt-Mind-Workin-From-Sun-To-Sun_2011121108_003_00-01-52.ogg", "one-shot")

b:slice("s1", 1, 8)
c:slice("s2", 1, 8)
d:slice("s3", 1, 8)


-- More Molly
molly2 = Molly.new()
molly3 = Molly.new()

---

vocal_songs = {
  "Banjo-Pickin-Girl_2011121106_001_00-01-13.ogg",
  "A-Whole-Heap-of-Little-Horses_2011121113_003_00-01-28.ogg",
  "Bosco-Stomp_DR000181_002_00-03-20.ogg",
  "Banjo-Pickin-Girl_2011121106_001_00-01-13.ogg",
  "Banjo-Pickin-Girl_2011121106_003_00-04-18.ogg",
  "Banjo-Pickin-Girl_2011121106_002_00-01-33.ogg",
  "Bull-Doze-Blues_2012081025_001_00-01-24.ogg",
  "Bull-Doze-Blues_2012081025_002_00-02-58.ogg",
  "Cant-Get-The-Stuff_DR001437_001_00-02-14.ogg",
  "Darling-Corey_20100918183941_002_00-02-46.ogg",
  "Darling-Corey_20100918183941_003_00-03-16.ogg",
  "Drunk-Mans-Blues_2012011453_003_00-06-00.ogg",
  "Green-Icey-Mountain_20100929202651_001_00-01-59.ogg",
  "Green-Icey-Mountain_20100929202651_002_00-02-30.ogg",
  "Green-Icey-Mountain_20100929202651_003_00-04-01.ogg",
  "Ill-Fly-Away_20100919165839_001_00-00-27.ogg",
  "Ill-Fly-Away_20100919165839_002_00-02-28.ogg",
  "Ill-Fly-Away_20100919165839_003_00-02-58.ogg",
  "Land-of-Calypso_DR001443_001_00-00-47.ogg",
  "Land-of-Calypso_DR001443_002_00-01-48.ogg",
  "Land-of-Calypso_DR001443_003_00-02-18.ogg",
  "Little-Maggie_20100919171130_001_00-00-22.ogg",
  "Little-Maggie_20100919171130_002_00-01-01.ogg",
  "Little-Maggie_20100919171130_003_00-03-25.ogg",
  "Old-Kimball_2011121105_001_00-02-24.ogg",
  "Old-Kimball_2011121105_002_00-02-54.ogg",
  "Old-Kimball_2011121105_003_00-03-24.ogg",
  "Richmond-Blues_2012081041_002_00-01-25.ogg",
  "Richmond-Blues_2012081041_003_00-02-29.ogg",
  "Rocking-Chair-Blues_DR001434_001_00-00-20.ogg",
  "Rocking-Chair-Blues_DR001434_002_00-01-20.ogg",
  "Rocking-Chair-Blues_DR001434_003_00-02-20.ogg",
  "She-Never_DR001438_001_00-00-32.ogg",
  "She-Never_DR001438_002_00-01-36.ogg",
  "She-Never_DR001438_003_00-03-25.ogg",
  "Tapping-That-Thing_DR001425_001_00-00-29.ogg",
  "Tapping-That-Thing_DR001425_002_00-00-59.ogg",
  "Tapping-That-Thing_DR001425_003_00-02-30.ogg",
  "Texas-Twist_DR001431_001_00-02-15.ogg",
  "Texas-Twist_DR001431_002_00-02-45.ogg",
  "Texas-Twist_DR001431_003_00-04-06.ogg",
  "The-Ballad-of-Lord-Bateman-and-the-Turkish-Lady_2011121109_001_00-01-17.ogg",
  "The-Ballad-of-Lord-Bateman-and-the-Turkish-Lady_2011121109_002_00-02-07.ogg",
  "The-Ballad-of-Lord-Bateman-and-the-Turkish-Lady_2011121109_003_00-03-25.ogg",
  "Wouldnt-Mind-Workin-From-Sun-To-Sun_2011121108_001_00-01-05.ogg",
  "Wouldnt-Mind-Workin-From-Sun-To-Sun_2011121108_002_00-01-32.ogg",
  "Wouldnt-Mind-Workin-From-Sun-To-Sun_2011121108_003_00-01-52.ogg",
}
s4 = Sample.new("/home/we/dust/code/repl-looper/audio/musicbox/" .. random_file)

cool = {
  "Brazilian-Tune_DR001442_001_00-00-00.ogg",
  "Darling-Corey_20100918183941_001_00-01-35.ogg",
}



engine.wav(0, "/home/we/dust/code/repl-looper/audio/musicbox/Wouldnt-Mind-Workin-From-Sun-To-Sun_2011121108_001_00-01-05.ogg")
engine.samplerLoop(0, 0, 1)

s1 = Sample.new("/home/we/dust/code/repl-looper/audio/musicbox/Wouldnt-Mind-Workin-From-Sun-To-Sun_2011121108_001_00-01-05.ogg")
```
