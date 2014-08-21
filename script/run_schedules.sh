#!/bin/bash

# This simple curl script is intended to be run via cron job on the delayed job server.
# The requests it makes are what intitiate and drive/enable the scheduling backend.
# In other words, if this script doesn't run, then no scheduled jobs or reports run.
#curl --header "Content-Type: application/json" -d '{}' --header "Accept: application/json" --header "Authorization: Token token=\"integration:c27a535ffdb7ef47bb9d7e7c88ca1a61e963eb72\"" https://www.vfitrack.net/api/v1/schedulable_jobs/run_jobs
#curl --header "Content-Type: application/json" -d '{}' --header "Accept: application/json" --header "Authorization: Token token=\"integration:IvXQKmtBbhVEkgOoWnfiSEfa9Gg\"" https://polo.vfitrack.net/api/v1/schedulable_jobs/run_jobs

curl --header "Content-Type: application/json" -d '{}' --header "Accept: application/json" --header "Authorization: Token token=\"integration:3KZYaYECZd+K5eqBcI39gUQTfYs\"" https://bdemo.vfitrack.net/api/v1/schedulable_jobs/run_jobs

# Add other instances when API columns exist in user table for the instance