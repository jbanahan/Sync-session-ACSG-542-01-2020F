#!/bin/bash

# This script will shut down the delayed job queue.  It is intended to be called from the project root
# (.ie script/kill_dj.sh).

restart_count=`cat config/dj_count.txt`
if [[ ! $restart_count > 0 ]]; then
  restart_count=1
fi

echo "$(date) - Stopping $restart_count jobs"

# Get a list of the actual job queues running so we know which ones we may need to kill later
# The reason we get the PID list now is because there's a slight chance the queue monitor may restart
# the process as the stop command is issued, so we don't want to kill those new queues.
ls_out=`lsof -t log/delayed_job.log`

# This call forwards through to the daemons gem codebase that runs delayed jobs.  It issues a TERM signal
# to each worker PID and then blocks for a certain amount of time waiting until the worker quits (which 
# should be nearly instantaneous as we have delayed jobs set up to trap TERM and raise out an interrupt error which
# will restart any running job).
script/delayed_job stop -n $restart_count

# Make sure we're killing any queues that we originally accounted for if they didn't get killed of their own accord
for PID in ${ls_out}
	do
    if [ -n "$(ps -p $PID -o pid=)" ]; then
		  echo "$(date) - Job Queue did not stop in a timely manner. Forcfully killing PID $PID."
		  kill -9 $PID
    fi
	done
