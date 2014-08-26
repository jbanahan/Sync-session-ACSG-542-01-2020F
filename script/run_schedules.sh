#!/bin/bash

# This simple curl script is intended to be run via cron job on the delayed job server.
# The requests it makes are what intitiate and drive/enable the scheduling backend.
# In other words, if this script doesn't run, then no scheduled jobs or reports run.
#
# To have this script run every minute:
# 1) Copy this file to: /home/ubuntu/chainio
# 2) Create a file in /etc/cron.d (`sudo vi /etc/cron.d/run_vfitrack_schedules`) containing the following (no leading space)
# * * * * * ubuntu /home/ubuntu/chainio/run_schedules.sh

# Add new lines for each instance as they are migrated to the new scheduling interface
# Each new line will need to have the host updated to point to the instance (obviously) and the Authorization header line will need the integration user's api_auth_token for the 
# specific instance changed.  Everything else should stay the same between curl lines.
curl --header "Content-Type: application/json" -d '{}' --header "Accept: application/json" --header "Authorization: Token token=\"integration:c27a535ffdb7ef47bb9d7e7c88ca1a61e963eb72\"" https://www.vfitrack.net/api/v1/schedulable_jobs/run_jobs
curl --header "Content-Type: application/json" -d '{}' --header "Accept: application/json" --header "Authorization: Token token=\"integration:3KZYaYECZd+K5eqBcI39gUQTfYs\"" https://bdemo.vfitrack.net/api/v1/schedulable_jobs/run_jobs
