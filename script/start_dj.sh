#!/bin/bash

if [ -f config/dj_count.txt ]; then
  restart_count=`cat ./config/dj_count.txt`
  if [[ ! $restart_count > 0 ]]; then
    restart_count=1
  fi
  if [ -f tmp/upgrade_running.txt ]; then
    echo "$(date) - Skipping $(pwd) because tmp/upgrade_running.txt exists."
  elif [ -f tmp/upgrade_error.txt ]; then
    echo "$(date) - Skipping $(pwd) because tmp/upgrade_error.txt exists."
  else
    echo "$(date) - Starting DJ with $restart_count jobs."
    ./script/delayed_job start -n $restart_count
  fi
else
  echo "$(date) - No $(pwd)/config/dj_count.txt file found.  Add one if you wish to run delayed jobs for this instance."
fi