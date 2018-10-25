#! /bin/bash
#
# This is the main systemd script for starting up all dependant services 
# for all chainio servers.
#
# To install the script for systemd purposes, run the following command:
# sudo cp chainio.service /etc/systemd/system/chainio.service
# sudo systemctl enable chainio
# sudo chmod +x chainio.sh
#
# To start chainio services run:
# systemctl start chainio
# 
# NOTE: This script WILL NOT shutdown services.  You will need to 
# directly invoke the services started by this script: chainio-web or chainio-job-queue (depending on the server's role)
# `systemctl stop chainio-web` to shut down the web server
# `systemctl stop chainio-job-queue` to halt the job service
#
# FURTHER NOTE: Stopping the job-queue service will not actually shutdown the job queues, just terminate the watchdog service
# that ensures the max number of queues per instance are running.

TAG_FS="/etc/aws-fs"
TAG_FS_BASE="${TAG_FS}/tags"
  
RESOURCE_ID=`curl -s http://169.254.169.254/latest/meta-data/instance-id`

# Using the aws-cli (python) program, we can extract all the tag key values associated with the current instance
# this script is running on.  The query param below formats the output so that we only get the tag key and value back
# formatted in the easy to parse table formatting.
# We then run that through grep to extract the table lines that actually have key/value pairs

# Instructions for installing the aws-cli program are here:
# http://docs.aws.amazon.com/cli/latest/userguide/installing.html#install-bundle-other-os
# Then run `aws configure` to set up the access key / secret access key

# Since we're writing to /etc below, we want this script running as root user, but then since there's no
# root home directory the aws cli won't pick up the configuration (secret key, api token, etc).  
# So run as ubuntu user, and it should find the configuration at ~/.aws/config

TAGS=`sudo -H -u ubuntu aws ec2 describe-tags --filters "Name=resource-id,Values=${RESOURCE_ID}" --output "table" --query "Tags[].[Key, Value]" | grep -E "\|.*\|.*\|"`

# Delete any existing tags
if [ -d "$TAG_FS_BASE" ]; then
  `rm -rf ${TAG_FS_BASE}`
fi

# Create the tag base dir if it doesn't exist
if [ ! -d "$TAG_FS_BASE" ]; then
  `mkdir -p ${TAG_FS_BASE}`
fi

# Run the following in a sub-shell so we're not botching up IFS for anything running after the loop
(
  # Set the input field separator to a newline, otherwise it's a space and the for / in loop below doesn't work
  # the way we want it to.
  IFS=$'\n'
  for TAG in $TAGS
  do
    # At this point, $TAG looks like this: | TagName | Value |
    # There's probably some clever shell/sed thing we can do to turn that into a name value pair and then create files/contents 
    # directly from a single command, but this works fine too
    # Multiple sed passes strips all trailing space
    TAG_NAME=`echo "$TAG" | sed -r 's/^\|\s+([^\|]*)\s*\|.*/\1/' | sed -r 's/(\s+)$//'`
    TAG_VALUE=`echo "$TAG" | sed -r 's/^\|[^|]+\|\s+([^|]*)\s+\|$/\1/' | sed -r 's/(\s+)$//'`
    `echo "$TAG_VALUE" > "${TAG_FS_BASE}/${TAG_NAME}"`
  done
)

# Properly set permissions on the TAG_FS dir to allow accessing dirs and reading files below it for everyone
`find ${TAG_FS} -type d -print0 | xargs -0 chmod 755`
`find ${TAG_FS} -type f -print0 | xargs -0 chmod 644`

if [ -f "${TAG_FS_BASE}/Role" ]; then
  ROLE=`cat "${TAG_FS_BASE}"/Role`
  if [[ "$ROLE" == "Web" ]]; then
    echo "$(date) - Calling chain-web service"
    systemctl start chainio-web
  elif [[ "$ROLE" == "Job Queue" ]]; then
    echo "$(date) - Calling chain-job-queue service"
    systemctl start chainio-job-queue
  else
    echo "Unable to determine which service to start for Role ${ROLE}"
  fi
fi
