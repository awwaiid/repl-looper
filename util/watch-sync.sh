#!/bin/sh

# One time send
echo 'norns.script.load("code/repl-looper/repl-looper.lua")' | \
  websocat ws://norns.local:5555 --protocol bus.sp.nanomsg.org -1

# Then reload when the file changes
nodemon --exec ./util/sync.sh -w repl-looper.lua
