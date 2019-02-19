#!/bin/bash

if [ -f tmp/upgrade_error.txt ]; then
  echo "Removing tmp/upgrade_error.txt"
  rm tmp/upgrade_error.txt
fi

if [ -f tmp/upgrade_running.txt ]; then
  echo "Removing tmp/upgrade_running.txt"
  rm tmp/upgrade_running.txt
fi
