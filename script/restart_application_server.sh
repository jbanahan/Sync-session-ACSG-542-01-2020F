#!/bin/bash

# Passenger has a service that watches your application's tmp dir for a file named
# restart.txt.  If the mtime on the file changes, passenger will redeploy the application.
#
# This is handy from time to time when the application itself needs to be restarted to pick 
# up some config changes.
# 
# From a user perspective, there will be no downtime, any requests occurring during the redeploy
# are buffered in passenger until the app is finished deploying.

touch tmp/restart.txt