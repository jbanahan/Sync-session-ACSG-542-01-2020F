#!/bin/bash

# This script runs in a sleep loop every 10 minutes and ensures that the correct number of 
# delayed job queues are running for each chainio instance that has a config/dj_count.txt
# file in it.
#
# It is invoked directly by an upstart job...you don't need to run this directly

while [[ ! -f ./dj_stop ]]; do
  for D in $(find . -mindepth 1 -maxdepth 1 -type d -print0 | xargs -0 -n1 basename) ; do
    cd $D
    if [ -f script/start_dj.sh ]; then
      if [[ ! -f tmp/upgrade_running.txt ]]; then
        if [ -z "$1" ] || [ "$1"  != "quiet" ]; then
          echo "$(date) - Starting jobs for $D"
          script/start_dj.sh
        else
          script/start_dj.sh quiet
        fi
        
      else
        echo "$(date) - Skipping $D because tmp/upgrade_running.txt exists."
      fi
    fi
    cd .. 
  done
  sleep 600 #wait 10 minutes between runs
done
echo "$(date) - dj_stop file found, exiting."
