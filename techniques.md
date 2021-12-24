
-- Simple slow drums
a:gen("CH")
a:gen("BS", "(n - 1) % 4 == 0")
a:gen("SD", "(n - 1) % 4 == 2")
a:gen("RS", "(n - 1) % 4 == 3")

-- Playable piano on bottom row
h:gen("p(`55+n`)")

-- Amp up the kick
s808.BS:amp(10)

-- Turn piano into cool synth thing
piano:reverse()
piano:startFrame(20000)
piano:endFrame(1000)
piano:transpose(-30)
piano:filterFreq(800)
piano:bitdepth(4)

-- Drum break
a:set_length(3)
a:set_length(16)

-- Open hat a little after kick
c:set_length(4)
c:rec()
OH
c:stop()

-- Symbols crash slightly after kick
d:rec()
CY
CY
CY
CY
d:stop()

-- Record some piano pattern
e:rec()
e:stop()

-- global audio control
g:gen("audio.level_dac(`(16-n)/128`)")

-- fine-grained global audio, fade to silence
g:gen("audio.level_dac(`(16-n)/512`)")

-- Let's try some sample slicing
s4 = Sample.new("/home/we/dust/code/repl-looper/audio/excerpts/The-Call-of-the-Polar-Star_fma-115766_001_00-00-01.ogg")
s4:playMode(2)
a:gen("s4:startFrame(`29000 * (n-1) * 16`); s4:loopStartFrame(`29000 * (n-1) * 16`); s4:endFrame(`29000 * n * 16`); s4:loopEndFrame(`29000 * n * 16`); s4:play()")

a:gen("s4:startFrame(`29090 * m`); s4:loopStartFrame(`29090 * m`); s4:endFrame(`29090 * n`); s4:loopEndFrame(`29090 * n`); s4:play()")

----


files = util.scandir('/home/we/dust/code/repl-looper/audio/musicbox')
random_file = files[math.random(#files)]

s4 = Sample.new("/home/we/dust/code/repl-looper/audio/" .. random_file)

