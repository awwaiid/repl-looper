#!/bin/sh

# Filename as first argument is optional
DIRECTORY=${1:-/home/we/dust/code/repl-looper}
FILENAME=${2:-repl-looper.lua}

# Sync the whole project directory
rsync -avzP . \
  --exclude .git \
  --exclude ui/node_modules \
  --delete \
  we@norns.local:$DIRECTORY

# Reload "current"
# echo 'norns.script.reload()' | \
#   websocat ws://norns.local:5555 --protocol bus.sp.nanomsg.org -1

# Reload our script specifically
echo 'norns.script.load("code/repl-looper/repl-looper.lua")' | \
  websocat ws://norns.local:5555 --protocol bus.sp.nanomsg.org -1

# Reload, but without restart
# echo "dofile('$DIRECTORY/$FILENAME')" | \
#   websocat ws://norns.local:5555 --protocol bus.sp.nanomsg.org -1

