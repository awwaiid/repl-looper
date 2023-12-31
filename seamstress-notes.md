
* copied core/engine.lua from the example engine import
* copied lib/container in since that isn't included by seamstress
* switched to lib/json.lua since lib/cjson.so dosn't work
* start with `~/local/seamstress/bin/seamstress -l 8888 -s repl-looper.lua`
* modified engine OSC port from 10111 to 8888, not sure if that can be the same
* deleted a bunch of dead code from SC engine and lua bindings
* Switched from `math.pow(a,b)` to `a^b` in lua code (this should be compatible)
* Chain `ReplLooper.osc_event` to be called from chained event in main script
  * The main `osc_event` callback needs to load engine info
* Re-write keyboard handling
* Significant modify screen-drawing
  * The methods aren't all the same, some are not there, and others are 1-based instead of 0-based coordinates
* Most all file-path stuff needs to be tweaked
* 
