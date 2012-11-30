#!/bin/bash
if [ -z "$1" ]; then
  echo usage: $0 ticket_tag branch_tag
  exit
elif [ -z "$2" ]; then
  echo usage: $0 ticket_tag branch_tag
  exit
fi

git checkout $2
git merge $1
git branch -d $1
git push origin $2
remotes=$(git branch -r)
if [ "$remotes" == *origin/"$1"* ]; then
  git push origin :$1
fi
