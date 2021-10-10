#!/bin/sh

rsync -avzP . --exclude .git --exclude ui --delete we@norns.local:/home/we/dust/code/repl-looper
#  maiden-remote-repl send 'norns.script.load("code/APP/APP.lua")'
