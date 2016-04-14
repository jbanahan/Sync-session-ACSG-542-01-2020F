#!/bin/bash

if [ -f config/dj_count.txt ]; then
  restart_count=`cat ./config/dj_count.txt`
  if [[ ! $restart_count > 0 ]]; then
    restart_count="1"
  fi
  if [ -f tmp/upgrade_running.txt ]; then
    echo "$(date) - Skipping $(pwd) because tmp/upgrade_running.txt exists."
  elif [ -f tmp/upgrade_error.txt ]; then
    echo "$(date) - Skipping $(pwd) because tmp/upgrade_error.txt exists."
  else
    # Don't bother running the start command if the # of queues running is greater than or matches the number
    # of expected queues
    running_queues=`lsof -t log/delayed_job.log | wc -l`
    if [[ ! $running_queues > 0 ]] || [ $restart_count -gt $running_queues ]; then
      if [ -z "$1" ] || [ "$1"  != "quiet" ]; then
        echo "$(date) - Starting DJ with $restart_count jobs."
      fi

      # Don't show any actual output..it's largely pointless and just a log clogger
      # Since 99.99% of the time, the output is going to be errors about how there's
      # already X processes running
      script/delayed_job start -n $restart_count > /dev/null 2>&1
    fi
  fi
else
  echo "$(date) - No $(pwd)/config/dj_count.txt file found.  Add one if you wish to run delayed jobs for this instance."
fi