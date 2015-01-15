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
curl --header "Content-Type: application/json" -d '{}' --header "Accept: application/json" --header "Authorization: Token token=\"integration:IvXQKmtBbhVEkgOoWnfiSEfa9Gg\"" https://polo.vfitrack.net/api/v1/schedulable_jobs/run_jobs
curl --header "Content-Type: application/json" -d '{}' --header "Accept: application/json" --header "Authorization: Token token=\"integration:ObZi7bEM2Ek1i+3GXFsG/6S8K8A\"" https://ann.vfitrack.net/api/v1/schedulable_jobs/run_jobs
curl --header "Content-Type: application/json" -d '{}' --header "Accept: application/json" --header "Authorization: Token token=\"integration:5OuL5ttaMjJigH8ZCctgbvChgvI\"" https://das.vfitrack.net/api/v1/schedulable_jobs/run_jobs
curl --header "Content-Type: application/json" -d '{}' --header "Accept: application/json" --header "Authorization: Token token=\"integration:xyN2AkgXUswPiZSimaInv0cxH2g\"" https://pepsi.vfitrack.net/api/v1/schedulable_jobs/run_jobs
curl --header "Content-Type: application/json" -d '{}' --header "Accept: application/json" --header "Authorization: Token token=\"integration:0Y2yNPbZo6QmdIczuJEUl+MyXW8\"" https://jcrew.vfitrack.net/api/v1/schedulable_jobs/run_jobs
curl --header "Content-Type: application/json" -d '{}' --header "Accept: application/json" --header "Authorization: Token token=\"integration:3GER1VPIw8c42lW3Bj/WJL0QTOQ\"" https://underarmour.vfitrack.net/api/v1/schedulable_jobs/run_jobs
curl --header "Content-Type: application/json" -d '{}' --header "Accept: application/json" --header "Authorization: Token token=\"integration:SIdMkK/tqktyN+Rn3X3/Y8coDlI\"" https://warnaco.vfitrack.net/api/v1/schedulable_jobs/run_jobs
curl --header "Content-Type: application/json" -d '{}' --header "Accept: application/json" --header "Authorization: Token token=\"integration:Ds5+V+ezZg+S0Sij5cUNUCFys3I\"" https://ll.vfitrack.net/api/v1/schedulable_jobs/run_jobs
curl --header "Content-Type: application/json" -d '{}' --header "Accept: application/json" --header "Authorization: Token token=\"integration:+1SIkxZoICiY99UeAfoHpfXGThE\"" https://rhee.vfitrack.net/api/v1/schedulable_jobs/run_jobs
curl --header "Content-Type: application/json" -d '{}' --header "Accept: application/json" --header "Authorization: Token token=\"integration:3KZYaYECZd+K5eqBcI39gUQTfYs\"" https://bdemo.vfitrack.net/api/v1/schedulable_jobs/run_jobs
