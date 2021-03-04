#!/bin/bash

xrandr -q | grep -q ^eDP-1
if [ $? -eq 1 ]; then
  echo "Display eDP-1 not found. Can't undock!"
  exit 255
fi

xrandr --output eDP-1 --mode 1920x1080 --pos 0x0 --rotate normal --primary --output DP-1 --off --output DP-2 --off

killall -SIGUSR1 conky

nitrogen --head=0 --set-centered ~/Pictures/DB/1080p/hexagram11080p.jpg

exit 0
