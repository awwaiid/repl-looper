```lua
-- Here are some examples of things you can do;
-- This can be used as a cookbook!
--
-- The idea is to copy/paste each of these one-line
-- things into the REPL OR press grid buttons to
-- trigger events
--
-- This is a REPL -- Read Eval Print Loop
-- You can run arbitrary lua commands and
-- see the result
2+2

-- First, play some built-in 808 samples
-- When you enter one of these and press <enter>
-- it immediately runs.
BD()
BD -- if you give JUST a function it is automatically evaluated (nonstandard lua)
CH
SD
-- Press <enter> again to run the most recent command
CP

-- Errors and other output show up on the right side
print "hello"
notreal()

-- Play an already-created piano sample (Timber)
-- with notes or midi-nums
piano:note('c')
-- Up-arrow to edit previous input/output
piano:note(60)

-- You can record these into a loop!
-- Loops a-h are already set up
a:rec() -- records manual events, both commands and button-press results
BD
BD
CP
piano:note('c')
piano:note('e')
a:stop() -- stop recording
a:stop() -- stop playing

-- The grid visuall shows where events are recorded.
-- Each row corresponds to a loop, 'a'-'h'
--
-- Press on grid buttons to execute all the events
-- for that step (all at once)

b:rec()
-- Events are recorded both from REPL events
-- AND from manual triggers. Press some of the
-- recorded drums and see them show up in loop-b
b:stop()
b:stop()

-- You can see events with `b:lua()`
b:lua()

-- You can clear out events any time
a:clear()
b:clear()

-- We can fill in a whole loop with this generator
-- Simple slow drums
a:play()
a:gen("BS") -- Bass Drum every beat
a:gen("CH", 1/2) -- Closed Hat every half beat
a:gen("SD", 2, 2) -- Snare Drum every other, offset
a:gen("CY", 4, 3) -- Cymbols 3rd beat of every 4

-- All the 808 sampels are under s808 (try `s808.<tab>`)
-- Amp up the kick
s808.BS:amp(3)

-- Drum break
-- Press <tab> to auto-complete!
a:setLength(3)
a:setLength(16)

-- Open hat a little after kick
b:setLength(4)
b:rec()
OH
b:stop()

-- Clap slightly after kick
b:rec()
CP
b:stop()

-- Playable piano on bottom row
-- Backticks are evaluated up front
-- n = step number (like 1..16)
-- m = step number minus one (like 0..15)
h:gen("p(`60+m`)")

-- Record some piano pattern
c:rec()
-- press some row-H buttons
-- The commands on the buttons get recorded as if
-- you ran them directly
c:stop()

-- Turn piano into cool synth thing
-- You can copy this whole multi-line thing in if
-- you want
piano:reverse()
piano:startFrame(20000)
piano:endFrame(1000)
piano:transpose(-10)
piano:bitDepth(4)
piano:filterFreq(800)

-- You could record these changes too
-- Easiest if you put them on a control row first
g:gen("piano:filterFreq(`100 * n`)")
d:rec()
-- Press row-g things, get some low-pass warble
d:stop()
g:clear()

-- Molly built-in!
molly:note('c')
molly:randomize()
molly:note('d')

-- Multiple mollies!
molly2:note('d')
molly2:randomize()

-- global audio control
g:gen("audio.level_dac(`(16-n)/32`)")
audio.rev_on()
audio.rev_off()

-- Loops ahve their own volume control
a:amp(0.25) -- Immediately set volume
a:amp(1, 10) -- Go to full volume over 10 seconds

-- The "all" helper can work across things
all{a,b}:amp(0, 10) -- 10 second fade-out
all{a,b}:amp(1, 10) -- 10 second fade-in

-- Built in list of all mollies and loops
all(loops):amp(0, 10) -- Fade out all loops!
all(mollies):stop() -- Fade out all mollies!

-- Generate a piano in a scale
blues = sequins(musicutil.generate_scale_of_length(56, "blues", 16))
h:gen("p(`blues()`)")


```
