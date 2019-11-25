#!/bin/bash

# This script is intended to be run in the project root (.ie as `script/restart_delayed_jobs.sh`)
# It simply wraps two other scripts that stop and start the job queue.  
# It is intended to be called primarily by the AWS SSM service as means for remotely restarting the queue.
#
# NOTE: Any job that is currently running will be interrupted and restarted when this script is utilized.
# Be careful that you don't execute it during long running jobs where this behavior is undesirable.  The 
# vast majority of our jobs this shouldn't be an issue, but some jobs (like product uploads via the search screens)
# may result in duplicate loads reported the user.  Just be judicious about when you load this.

# The following script stops the delayed job instances.  It blocks while it issues a kill command until the job
# ends (or until a timeout is reached).  It then issues kill -9 to anything left running to ensure they're actually dead.
script/kill_dj.sh

# This starts up the job queue
script/start_dj.sh