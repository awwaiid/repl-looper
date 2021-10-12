# Norns REPL-LOOPER

> Anagogically integrated UI for Norns / Matron / Grid

Experimental performance and creative tool, mashing together several things that I like. REPL for interactive code creating. Grid to have a tactile UI (maybe we'll throw in a midi pedal too). Dance between client and host, between recording loops and loops that can modify other loops and themselves.

# Usage

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
nodemon --exec ./util/sync.sh -w repl-looper.lua
```

# Journal
* 2021-09-19 <img src="docs/20210919-screenshot.png" align="right" width="50%" border=1 />
  * Sketched out basic idea last night
  * Have some diagrams in my notebook too
  * Can send/receive REPL commands via websockets
  * Next need to get (probably quantized) recording going
  * Idea is to maybe use Lattice, so I guess one pattern per event
  * Once a loop is recorded, make that a variable on the host itself (even though it was recorded on the client kinda)
* 2021-10-02
  * Messing with [websocketd](https://github.com/joewalnes/websocketd) for testing
  * Running `websocketd --port 5555 sh -c 'lua -i 2>&1'`
* 2021-10-09 <img src="docs/20211009-demo-basic-loop.gif" align="right" width="50%" border=1 />
  * Got some basic recording working in UI
  * Setting this up to start building the norns-lua side in the same repo
  * Just came up with a clever double-JSON-encoding to send loops client->server
  * I probably shouldn't be so pleased with myself
  * I got loops sending AND turned into lattice patterns!
  * A fun part of that was using negative time offsets for the pattern starts
  * I'm moving this toward assuming an overall 16-step sequence, but not necessarily quantized yet
  * Next some UX improvements; command history is definitely one
  * Sweet ... got it adjusted to play back on the first loop
  * Used [peek](https://github.com/phw/peek) to record this cool gif
* 2021-10-10
  * Last night I dreamed about loops playing loops. Good.
  * Made loops variable length (quantize later!)
  * Run `nodemon --exec ./util/sync.sh -w repl-looper.lua` to auto eval server code
  * Re-worked a bunch of calculations and gave them better labels
  * Next up is getting to record multiple loops, and then sync between them!
* 2021-10-11
  * Show the current loop position on The Grid!
  * Turn the lua Loop into an actual object, reorganize
  * Maybe instead of `loops[1]` I should flatten it to `l1`. Kinda evil but I kinda like it. We'll see
  * OK... while doing that I was looking at maybe using single-letter vars. Well I went through looking at their values one by one and typed in `q` and apparently that shuts down norns. Sooo I guess don't use that one
  * Now going to use 'a'..'h' for shortcuts (avoid 'q'!)

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
