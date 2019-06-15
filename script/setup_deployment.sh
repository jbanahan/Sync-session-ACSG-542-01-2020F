#!/bin/bash

# Copies configuration files from vfitrack-configurations repository into the current directory
# and setups up some simple things for a deployment

deployment_dir=${PWD##*/}
config_dir="../vfitrack-configurations/$deployment_dir"

if [ -d "$config_dir" ]; then
  echo "Copying configuration data from $config_dir to this directory."
  cp -R "$config_dir" ..
else
  echo "No configuration directory found at $config_dir."
fi

echo "Creating log and tmp dirs"
mkdir -p log 
mkdir -p tmp
touch tmp/restart.txt