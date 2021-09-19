# Norns REPL-LOOPER

> Mystically integrated UI for Norns / Matron / Grid

Experimental performance and creative tool, mashing together several things that I like. REPL for interactive code creating. Grid to have a tactile UI (maybe we'll throw in a midi pedal too). Dance between client and host, between recording loops and loops that can modify other loops and themselves.

# Usage

Optimizing for my own local development currently, but you can give it a try if you want. Should be something like this:

```sh
npm install
npm run dev`
```

Eventually maybe I'll run it on a public website -- I'm not sure if using `norns.local` from a random other page will work or not (CORS and all that). Might serve it from Norns.

# Journal
* 2021-09-19 <img src="docs/20210919-screenshot.png" align="right" width="50%" border=1 />
  * Sketched out basic idea last night
  * Have some diagrams in my notebook too
  * Can send/receive REPL commands via websockets
  * Next need to get (probably quantized) recording going
  * Idea is to maybe use Lattice, so I guess one pattern per event
  * Once a loop is recorded, make that a variable on the host itself (even though it was recorded on the client kinda)

# Ideas

* Code editor like maiden w/ ctrl+enter send
* Grid on screen
  * Buttons are spread out over spacetime
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

# Shout Outs

* [Grégory Montigny for initial logo (CC-BY)](https://thenounproject.com/simpleicon/)
* eigen on norns-study-group discord for suggesting Lattice
* Everyone on [lines (llllllll.co)](https://llllllll.co) for being awesome
