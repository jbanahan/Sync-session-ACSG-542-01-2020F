#! /bin/bash

# This script is not intended to be run directly by systemd. It should be run by the chainio service.
#
# The chainio.sh script will run it if the EC2 instance it is running 
# on has a Role tag w/ a value of 'Job Queue'.
#
# This script will NOT run unless this instances is tagged with a Role of 'Job Queue'.
# 
# Should you need to start/stop this script manually:
#
# systemctl start chainio-job-queue
# systemctl stop chainio-job-queue

# Verify the script is being run on a machine labeled as an actual job queue
ROLE=`cat "${TAG_FS_BASE}"/Role`
if [ "$ROLE" != "Job Queue" ]; then
  echo "Chain IO job queue must be run from a machine tagged with a Role of 'Job Queue'.  Role was ${ROLE}"
  exit 1
else
  echo "$(date) - Starting chain-job-queue"

  if [ -f "/home/ubuntu/.rvm/scripts/rvm" ]; then
    source "/home/ubuntu/.rvm/scripts/rvm"
  fi

  export RAILS_ENV="production"
  cd "/home/ubuntu/chainio"

  exec "primary_instance/script/dj_monitor.sh" quiet
fi

