#!/bin/sh

rsync -avzP . --exclude .git --exclude ui --delete we@norns.local:/home/we/dust/code/repl-looper

# Reload code

# echo 'norns.script.reload()' | \
#   websocat ws://norns.local:5555 --protocol bus.sp.nanomsg.org -1

echo 'norns.script.load("code/repl-looper/repl-looper.lua")' | \
  websocat ws://norns.local:5555 --protocol bus.sp.nanomsg.org -1

