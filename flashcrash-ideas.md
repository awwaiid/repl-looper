```lua

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

notes = sequins(musicutil.generate_scale_of_length(56, "Blues Scale", 16))
h:gen("p(`notes()`)")

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

clock.internal.set_tempo(80)
d:gen("clock.internal.set_tempo( util.wrap(clock:get_tempo()+1, 60, 140))")



```
