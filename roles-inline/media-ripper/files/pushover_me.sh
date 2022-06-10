#!/bin/bash

# send message to Pushover indicating that this rip has completed
curl -s \
  --form-string "token=a74zm3s7dc577532z2qet8fpkwuy6f" \
  --form-string "user=uiLUuynXsvF7UCQATr3j6j7pG7dGoh" \
  --form-string "message=Notification: $*" \
https://api.pushover.net/1/messages.json
