#!/bin/bash

xrandr -q | grep -q ^eDP-1
if [ $? -eq 1 ]; then
  echo "Display eDP-1 not found. Can't undock!"
  exit 255
fi

xrandr --output eDP-1 --off --output DP-1 --primary --mode 3840x2160 --pos 0x0 --rotate normal --output DP-2 --mode 3840x2160 --pos 3840x0 --rotate normal

killall -SIGUSR1 conky

nitrogen --head=0 --set-centered ~/Pictures/DB/4k/hexagram1uhd.jpg
nitrogen --head=1 --set-centered ~/Pictures/DB/4k/hexagram1uhd.jpg

exit 0
