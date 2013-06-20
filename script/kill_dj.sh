#!/bin/bash

ls_out=`lsof -t ./log/delayed_job.log`
restart_count=`cat ./config/dj_count.txt`

if [[ !$restart_count > 0 ]]; then
  restart_count=1
fi

echo "$(date) - Stopping $restart_count jobs"
./script/delayed_job stop -n $restart_count

#let the job finish
sleep 2

for i in ${ls_out}
	do
		echo "$(date) - Killing $i"
		kill -9 $i
	done
