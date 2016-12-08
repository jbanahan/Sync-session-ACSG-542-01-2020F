#!/usr/bin/env bash

# This script requires the AWS CLI to be installed on the server and have a default configuration set up for it.
# Errors are reported using the msmtp client, which must also be set with a config file in ~/.msmtprc

USAGE="Usage: $0 file1 ... fileN"

send_email() {
  MSG="Subject: Log Backup Failure on $HOSTNAME\nThe log backup to S3 failed due to the following problem:\n\n$1\n\nThe following files were queued for upload:\n$EXPECTED_FILES"
  echo -e $MSG | msmtp -a default it-admin@vandegriftinc.com
  exit 1
}

if [ "$#" == "0" ]; then
  echo "$USAGE"
  exit 1
fi

HOSTNAME=""

if [ -e /etc/aws-fs/tags/Name ]
then
  HOSTNAME=`cat /etc/aws-fs/tags/Name`
else
  HOSTNAME=`hostname`
fi

EXPECTED_FILES=""

for arg
do
  EXPECTED_FILES="$EXPECTED_FILES\n`readlink -f $arg`"
done

DATE=`date +"%Y/%m/%d"`

command -v aws >/dev/null 2>&1 || send_email "AWS executable not found."

while [ "$1" ]
do
  FULL_PATH=`readlink -f $1`
  FILE_NAME=`basename $1`
  PWD=`dirname $FULL_PATH`
  aws s3 cp $FULL_PATH s3://vfi-archived-logs/$HOSTNAME/$DATE$PWD/$FILE_NAME || send_email "S3 upload failed."
  shift
done