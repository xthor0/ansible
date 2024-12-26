#!/bin/bash

# send message to Pushover indicating that this rip has completed
curl -s \
  --form-string "token={{ pushover_apptoken }}" \
  --form-string "user={{ pushover_usertoken }}" \
  --form-string "title=$(whoami)@${HOSTNAME}" \
  --form-string "message=Notification: $*" \
https://api.pushover.net/1/messages.json
