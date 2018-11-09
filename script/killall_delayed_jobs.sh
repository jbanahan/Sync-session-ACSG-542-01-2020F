#!/bin/bash

for D in $(find . -mindepth 1 -maxdepth 1 -type d -print0 | xargs -0 -n1 basename) ; do
  cd $D
  echo "Killing all jobs in $D"
  script/kill_dj.sh &
  cd ..
done
