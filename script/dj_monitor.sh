#!/bin/bash

while [[ ! -f ./dj_stop ]]; do
  for D in $(find . -mindepth 1 -maxdepth 1 -type d -exec basename '{}' \;) ; do
    cd $D
    if [ -f script/start_dj.sh ]; then
      if [[ ! -f tmp/upgrade_running.txt ]]; then
        echo Starting jobs for $D
        ./script/start_dj.sh
      else
        echo Skipping $D because tmp/upgrade_running.txt exists. 
      fi
    fi
    cd .. 
  done
  sleep 600 #wait 10 minutes between runs
done
echo dj_stop file found, exiting.
