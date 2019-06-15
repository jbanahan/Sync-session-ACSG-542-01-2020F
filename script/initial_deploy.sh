#!/bin/bash

set -e

if [ -z "$1" ]; then
  echo "You must pass the tag to checkout."
  exit 1
fi

if [ -z "$2" ]; then
  echo "You must pass the primary company name to use."
  exit 1
fi

if [ -z "$3" ]; then
  echo "You must pass the sysadmin email address to use."
  exit 1
fi

if [ -z "$4" ]; then
  echo "You must pass the system code to use."
  exit 1
fi

if [ -z "$5" ]; then
  echo "You must pass the HTTP Host Name to use."
  exit 1
fi

git checkout $1
script/setup_deployment.sh
bundle install --frozen --without=development test
rake db:migrate
script/init_base_setup.rb "$2" "$3" "$4" "$5"
rake assets:precompile
