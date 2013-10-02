#!/bin/bash

if [ -z "$1" ]; then
  echo usage: $0 ticket_tag branch_tag
  exit
elif [ -z "$2" ]; then
  echo usage: $0 ticket_tag branch_tag
  exit
fi

set -e
# Any subsequent commands which fail will cause the shell script to exit immediately.
# We really don't want to merge, delete branches or push if anything prior to that didn't exit
# with a good exit code.

git checkout $2
git merge $1
git push origin $2
git branch -d $1
remote_branches=$(git branch -r | sed -n "s/.*origin\/$1$/$1/p")
if [ "$remote_branches"  == "$1" ]; then
  git push origin :$1
fi
