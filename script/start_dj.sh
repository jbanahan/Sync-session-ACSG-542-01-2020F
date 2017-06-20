#!/bin/bash

if [ -f config/dj_count.txt ]; then
  restart_count=`cat ./config/dj_count.txt`
  if [[ ! $restart_count > 0 ]]; then
    restart_count="1"
  fi

  if [ -f config/dj_count.txt ]; then
    default_queue=`cat ./config/dj_queue.txt 2>/dev/null`
    # If the queue is blank, set it to "default"...
    # If we don't do this, then delayed jobs just picks up everything, regardless of the queue it's in,
    # which we really don't want, since the main purpose of the queue usage is isolation of background jobs
    # between queues.
    if [[ $default_queue =~ ^[:space:]*$ ]]; then
      default_queue="default"
    else
      # remove leading/trailing whitespace characters
      default_queue="${default_queue#"${default_queue%%[![:space:]]*}"}"
      default_queue="${default_queue%"${default_queue##*[![:space:]]}"}"   
    fi
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
        echo "$(date) - Starting DJ with $restart_count jobs monitoring the $default_queue job queue."
      fi

      # Don't show any actual output..it's largely pointless and just a log clogger
      # Since 99.99% of the time, the output is going to be errors about how there's
      # already X processes running
      script/delayed_job start -n $restart_count --queues=$default_queue > /dev/null 2>&1
    fi
  fi
else
  echo "$(date) - No $(pwd)/config/dj_count.txt file found.  Add one if you wish to run delayed jobs for this instance."
fi