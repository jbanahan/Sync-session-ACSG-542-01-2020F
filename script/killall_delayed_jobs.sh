#!/bin/bash

# This script will kill all delayed job processes running under every instance on the server it is called from.
# Generally you'll want to only utilize this if there is mainteance work that needs to be done.  In that case
# you should also make sure to stop the chainio-job-queue service. `sudo systemctl stop chainio-job-queue` prior
# to calling this script, otherwise all the job queues you kill will just restart (unless that's what you're after).

for D in $(find . -mindepth 1 -maxdepth 1 -type d -print0 | xargs -0 -n1 basename) ; do
  cd $D
  
  if [ -f script/kill_dj.sh ]; then
    echo "Killing all jobs in $D"
    script/kill_dj.sh &
  fi
  
  cd ..
done
