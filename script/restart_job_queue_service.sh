#!/bin/bash

# The expectation is that this script is run as a privileged user capable of issuing systemctl commands.
# Primarily this would be executed from AWS SSM (.ie root).  It could also be executed manually
# by using sudo.

# Ensure this script only ever is allowed to run on an instance that is tagged as a job queue instance
if [ -f "/etc/aws-fs/tags/Role" ]; then
  ROLE=`cat "/etc/aws-fs/tags/Role"`

  if [[ "$ROLE" == "Job Queue" ]]; then
    systemctl restart chainio-job-queue
    exit 0
  else
    # Write a message to standard error indicating service couldn't be started for the role indicated.
    echo "Job queue could not be restarted because this server is not tagged with a Role of 'Job Queue'." >&2
    exit 1
  fi
fi