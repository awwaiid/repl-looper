# Norns REPL-LOOPER

> Anagogically integrated UI for Norns / Matron / Grid

<img src="docs/20211227-demo-running.gif" align="right" width="50%" border=1 />Experimental performance and creative tool, mashing together several things that I like. REPL for interactive code creating. Grid to have a tactile UI (maybe we'll throw in a midi pedal too). Dance between client and host, between recording loops and loops that can modify other loops and themselves.

Check out the [dev branch](https://github.com/awwaiid/repl-looper/tree/dev) and [dev branch development journal](https://github.com/awwaiid/repl-looper/tree/dev/journal.md) for ongoing development work. The `main` branch is the current "stable" (haha) version.

# Recent Releases
* 0.1 - Initial release, generally working!
* 0.2 - Multiple Mollies, per-loop amp/fade, `ALL` helper

# Installation and Usage

Install directly from maiden or by running this in the maiden/matron console:

```lua
;install https://github.com/awwaiid/repl-looper
```

Then start `repl-looper` on the norns. The norns screen will show some status information. Interaction is primarily done through a web-browser and grid. You can access the web interface at:

http://norns.local/api/v1/dust/code/repl-looper/ui/dist/repl-looper.html (or http://bit.ly/norns-repl-looper)

The browser interface is an alternative to maiden's REPL with a few different features and style. The basic idea is the same -- you run Lua commands and see the results. Verify that everything is running with some simple math

```lua
2+2
```

Which should output `4` (give or take). The built-in engine is a mash-up of Timber, Goldeneye, and Molly the Poly. There is a shortcut for a Timber-based piano sample, `p`. There is also an instance of Molly pre-defined. Try these:

```lua
-- Timber piano
p'c'
p'd'
p(68)

molly:note(60)
molly:randomize_params()
molly:note(62)
molly:stop()
```

Next thing to play with is loops/sequences. There are 8 pre-defined 16-step loops, one for each row, put into variables `a`..`h`. Start by recording into loop `a`:

```lua
a:rec()
-- loop 'a' is now playing and recording! You can see the steps
-- both on the grid

p'c'
-- now wait a bit
p'd'
-- the loop is playing and will wrap back around

a:stop() -- this stops recording but keeps playing
a:stop() -- stop again to also stop playing

-- At this point press some of the grid buttons to trigger all the
-- events recorded at that step immediately (ignoring their sub-step timing)

a:lua() -- show the loop contents

a:play() -- start loop again
a:clear() -- erase loop contents
```

Now that you have the script running on norns and the local UI up in a browser and everything working together, read through [Techniques](techniques.lua) to get some ideas!

# Resources

* [Techniques / Tutorial](techniques.md) to get some ideas!
* [Youtube video walk-through of the techniques](https://youtu.be/FPE5DOlScIY)
* [Development Journal / Changelog](journal.md) for a running log of experiments

# Reference

## UI
* On the right is output, including errors
* Use `<up>` and `<down>` arrows to select commands and output from history
* Press `<enter>` to execute the most recent item from history
* Use `<tab>` to see what functions/methods are available
* Simple functions with no parameters are automatically evaluated, so you use `p` instead of `p()`
* Loops on the grid will be visualized as they are played, and turn red in record mode
* Common 808 samples are loaded under `s808.<tab>` and have shortcuts like `CP`

# Library and Live-Coding Helpers

* Pre-defined variables/functions
  * `a`..`h` -- loops, one per grid-row
  * `p` -- a Timber-based piano sample player
  * `piano` -- the underlying piano sample (via Timber)
    * You can do things like `piano:reverse()`
  * `molly` -- an instance of Molly, which wraps Molly The Poly
    * `molly2` .. `molly8` -- more pre-defined Mollys
  * Pre-loaded 808 samples in `s808.*` with these shortcuts
    * `BD`, `BD`, `CH`, `CY`, `LC`, `MC`, `RS`, `BS`, `CL`, `HC`, `LT`, `MT`, `SD`, `CB`, `CP`, `HT`, `MA`, `OH`
    * Call with `CP` or `CP()` or `s808.CP:play()`
    * Modify with `s808.BS:amp(2)`
* Loop (using loop `a` as the example)
  * `Loop.new()` -- Create a new Loop (I usually use `a`..`h` pre-defined loops instead)
  * `a.current_step` -- current step (integer)
  * `a:setLength(steps)` -- Set the number of steps (quarter-notes)
  * `a:setStep(step)` -- Set the current step
  * `a:lua()` -- Convert into a lua-style string
  * `a:play()` -- Start playing
  * `a:stop()` -- Stop recording or stop playing
  * `a:rec()` -- Start recording
  * `a:clear()` -- Remove all events
  * `a:put(step, command)` -- Assign a command at a specific step
    * This is handy for building up a set of controls
  * `a:gen(code_string, condition, offset)` -- Generate events in a loop programmatically, with macro expansion
    * `a:gen("CH")` -- puts the "CH" function on every step
    * `a:gen("CH", 1/2)` -- puts the "CH" on every half step
    * `a:gen("CH", "n >= 8")` -- puts the "CH" on the second half of steps
    * `a:gen("CH", 2, 2)` -- puts the "CH" on every other step starting with step 2
    * `a:gen("CH", { 1, 3, 4.5 })` -- puts the "CH" on the given steps (even fractional)
    * `a:gen({"BD","SD","CP"})` -- puts each one on each step
    * macro expansion: Backticks are evaluated for each generated event. Use `n` for the one-based step/column and `m` for the zero-based step/colum
      * ```a:gen("p(`50+m`)")``` -- Generates `p(50)`, `p(51)`, `p(52)`, etc
      * ```a:gen("piano:filterFreq(`100 * n`)")``` -- Generates low-pass for 100 hz, 200 hz, 300 hz, etc
  * `a:quantize()` -- Events are recorded at sub-steps by default; this immediately rounds them to the nearest step
  * `a:nextStep()` -- Increment the current step to the next step
  * `a:prevStep()` -- Decrement the current step to the previous step
  * `a:clone(other_loop)` -- Copy this loop onto another (empty the other out)
  * `a:merge(other_loop)` -- Merge other_loop into this one. New loop is the longest of the two, (TODO: merged timings based on playhead)
  * `a:split(other_loop)` -- EXPERIMENTAL! Split the current loop, putting some events into `other_loop` and keeping some
  * `a:slice(sample_name, step_offset, step_count, width)` -- Take a Goldeneye sample and slice it (TODO: Also support Timber)
    * This is effectively a complex generator of frame-offsets in the sample playback
    * Weirdly this is the variable NAME of the sample, like `a:slice("s1")` (NOT `a:slice(s1)`)
  * `a:amp(level)` -- Set the amp (0..1) for the whole loop; the included engine loops everything through the triggered loop!
    * `a:amp(level, lag_time)` -- Fade to the given volume over the given number of seconds
    * Example: `a:amp(0, 10)` will fade out
* Engine wrappers; once you have an instance use `t1:<tab>` to explore! Generally does what the engine does
  * `t1 = Timber.new("path/to/file.wav")` -- Timber wrapper (works with .ogg too!)
  * `s1 = Sample.new("path/to/file.wav")` -- Goldeneye wrapper (works with .ogg too!)
  * `m1 = Molly.new()` -- Molly the Poly wrapper (you can have several!)
  * You could of course use any engine you like! Only the `Loop:slice(...)` method particularly cares. Otherwise this is arbitrary lua code getting sequenced
* BONUS: `ALL` object wrapper. This can be used on a table of objects and then call a given method on each of them. Examples:
  * `ALL{a,b,c}:play()` -- Play all three loops, equivalent of `a:play();b:play();c:play()`
  * `ALL{a,b,c}:play(1):amp(1, 10)` -- Chained command that both plays and fades-in the loops
  * `ALL(loops):amp(0, 10)` -- All the pre-created loops are stored in `loops`, this fades them all out!
  * `ALL(mollies):stop()` -- All the pre-created mollies are stored in `mollies`, this stops them all!

# Development

When developing you can run the UI directly on your laptop, but you'll need to use docker or install dependencies (nodejs/npm). You get live-reload of changes and such. Slightly-evil the `dist` dir is then checked in to git for serving from the norns/maiden webserver. For the UI (a VueJS app):

```sh
cd ui

# Direct
npm install
npm run dev

# OR Docker, if you like
docker-compose up
```

On the norns side we need to run the lua server-side. During dev I do it this way:

```sh
# Auto-push to norns
./util/watch-sync.sh
```

# Future Ideas

* Grid on screen
  * Show events
  * Click to do the same thing as the grid button press?
* Mash up editor and REPL
  * Like a notebook but worse
  * Let the code edit the code
  * Constant fzf-style autocomplete
* Loop Recording / Editing Modes
  * Step first: Pick a step and record an event
  * Event sequencing: Take an event and place (or edit) the location of the event
  * Edit mode where a button-press loads all (timed) events for editing
* Sync loops together better?
* Add half-loops, like a2..h2 that span coluns 9..16 on grid

# Shout Outs!

* [Grégory Montigny for initial logo (CC-BY)](https://thenounproject.com/simpleicon/)
* eigen on norns-study-group discord for suggesting Lattice
* Everyone on [lines (llllllll.co)](https://llllllll.co) for being awesome
* [Hoelzro for lua-repl](https://github.com/hoelzro/lua-repl) from which I've adopted bits
* [Ensequence for js2lua (MIT, embedded)](https://github.com/Ensequence/js2lua)
* [markwheeler](https://github.com/markwheeler) for [Timber](https://github.com/markwheeler/timber) and [Molly The Poly](https://github.com/markwheeler/molly_the_poly) which I've embedded
* [Library of Congress Citizen DJ Project](https://citizen-dj.labs.loc.gov/), both inspirational and a source of samples I've been playing with
* [Infinite Digits](https://github.com/schollz) for this inspirational [Flash Crash Performance of Internorns](https://www.youtube.com/watch?v=bJTnfvg153M) and some help slicing in some samplers
