#!/bin/bash

restart_count=`cat ./config/dj_count.txt`
if [[ !$restart_count > 0 ]]; then
  restart_count=1
fi
if [ -f tmp/upgrade_running.txt ]; then
  echo Skipping `pwd` because tmp/upgrade_running.txt exists.
else
  echo "Starting DJ with $restart_count jobs."
  ./script/delayed_job start -n $restart_count
fi
