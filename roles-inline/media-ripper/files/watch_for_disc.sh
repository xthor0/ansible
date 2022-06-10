#!/bin/bash

function discpresent() {
  echo
  tput sc
  while true; do
    file -s /dev/sr0 >& /dev/null
    if [ $? -eq 0 ]; then
      tput el
      echo "Disc loaded!"
      return
    else
      echo -n "Waiting for disc..."
      tput rc
      sleep 5
    fi
  done
}

while true; do
    discpresent
    ripdisc.sh
    eject cdrom
done

# it loops. forever.