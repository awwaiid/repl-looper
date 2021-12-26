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
a:set_length(3)
a:set_length(16)

-- Open hat a little after kick
b:set_length(4)
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

