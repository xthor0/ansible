#!/bin/bash

# send message to Pushover indicating that this rip has completed
curl -s \
  --form-string "token={{ pushover_apptoken }}" \
  --form-string "user={{ pushover_usertoken }}" \
  --form-string "title=$(whoami)@${HOSTNAME}" \
  --form-string "message=Notification: $*" \
https://api.pushover.net/1/messages.json > /dev/null 2>&1

if [ $? -eq 0 ]; then
  echo "Message sent successfully."
else
  echo "Curl exited with a non-zero status."
fi

