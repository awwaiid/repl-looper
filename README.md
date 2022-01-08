# Norns REPL-LOOPER

> Anagogically integrated UI for Norns / Matron / Grid

Experimental performance and creative tool, mashing together several things that I like. REPL for interactive code creating. Grid to have a tactile UI (maybe we'll throw in a midi pedal too). Dance between client and host, between recording loops and loops that can modify other loops and themselves.

# Installation and Usage

Install by running this on maiden:

  ;install https://github.com/awwaiid/repl-looper

Then start `repl-looper` on the norns. The norns screen will show some status information. Interaction is primarily done through a web-browser and grid. You can access the web interface at:

http://norns.local/api/v1/dust/code/repl-looper/ui/dist/repl-looper.html

The browser interface is an alternative to maiden's REPL with a few different features and style. The basic idea is the same -- you run Lua commands and see the results. Verify that everything is running with some simple math

  2+2

Which should output `4` (give or take). The built-in engine is a mash-up of Timber, Goldeneye, and Molly the Poly. There is a shortcut for a Timber-based piano sample, `p`. There is also an instance of Molly pre-defined. Try these:

  p'c'
  p'd'
  p(68)
  molly:note(60)
  molly:stop()

Next thing to play with is loops/sequences. There are 8 pre-defined 16-step loops, one for each row, put into variables `a`..`h`. Start by recording into loop `a`:

  a:rec()

  p'c'
  -- wait a bit
  p'd'
  -- the loop is playing and will wrap back around

  a:stop() -- this stops recording but keeps playing
  a:stop() -- stop again to also stop playing

Once you have the script running on norns and the local UI up in a browser, read through [Techniques](techniques.lua) to get some ideas!

UI Hints:
* On the right is output, including errors
* Use `<up>` and `<down>` arrows to select commands and output from history
* Press `<enter>` to execute the most recent item from history
* Use `<tab>` to see what functions/methods are available
* Simple functions with no parameters are automatically evaluated, so you use `p` instead of `p()`
* Loops on the grid will be visualized as they are played, and turn red in record mode
* Common 808 samples are loaded under `s808.<tab>` and have shortcuts like `CP`

# Resources

* [Techniques / Tutorial](techniques.lua) to get some ideas!
* [Development Journal / Changelog](journal.md) for a running log of experiments

# Development

Optimizing for my own local development currently, but you can give it a try if you want. Should be something like this:

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

# Ideas

* Code editor like maiden w/ ctrl+enter send
* Grid on screen
  * Buttons are spread out over spacetime
  * The grid is good at visualizing and selecting spacetime
  * Buttons contain events
  * Record a loop assigns the whole thing to a button or a row
  * Physical grid button triggers event
  * Maybe visualize grid on-screen too?
* Mash up editor and REPL
  * Like a notebook but worse
  * Let the code edit the code
  * Expand a variable into the actual values -- so like a random beat generator that then becomes a hard-coded beat
  * Constant fzf-style autocomplete
* Make this thing static so that it is easy to run
  * Keep all state on the Norns
* Loop Recording / Editing Modes
  * Live REPL: Record REPL timing, construct sequence of events
    * Playback: With or without fixed-length active loop playback
  * Step first: Pick a step and record an event
  * Event sequencing: Take an event and place (or edit) the location of the event
* Sync loops together better?

# Shout Outs

* [Grégory Montigny for initial logo (CC-BY)](https://thenounproject.com/simpleicon/)
* eigen on norns-study-group discord for suggesting Lattice
* Everyone on [lines (llllllll.co)](https://llllllll.co) for being awesome
* [Hoelzro for lua-repl](https://github.com/hoelzro/lua-repl) from which I've adopted bits
* [Ensequence for js2lua (MIT, embedded)](https://github.com/Ensequence/js2lua)
* [markwheeler](https://github.com/markwheeler) for [Timber](https://github.com/markwheeler/timber) and [Molly The Poly](https://github.com/markwheeler/molly_the_poly) which I've embedded
* [Library of Congress Citizen DJ Project](https://citizen-dj.labs.loc.gov/), both inspirational and a source of samples I've been playing with
* [Infinite Digits](https://github.com/schollz) for this inspirational [Flash Crash Performance of Internorns](https://www.youtube.com/watch?v=bJTnfvg153M) and some help slicing in some samplers
