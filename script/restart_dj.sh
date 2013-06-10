#!/bin/bash

ls_out=`lsof -t ./log/delayed_job.log`
restart_count=`cat ./config/dj_count.txt`
if [[ $restart_count > 0 ]]; then
  echo "Restarting with $restart_count jobs."
else
  restart_count=1
  echo "Restarting with $restart_count jobs."
fi

for i in ${ls_out}
	do
		echo "Killing $i"
		kill -9 $i
	done

./script/delayed_job start -n $restart_count
