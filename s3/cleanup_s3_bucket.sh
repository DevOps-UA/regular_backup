#!/bin/bash

# Usage: ./cleanup_s3_bucket "bucketname" "90 days"

# Removes backups older than N days from S3 bucket using s3cmd tool

s3cmd ls s3://$1 | while read -r line;
  do
    createDate=`echo $line|awk {'print $1" "$2'}`
    createDate=`date -d"$createDate" +%s`
    olderThan=`date -d"-$2" +%s`
    if [[ $createDate -lt $olderThan ]]
      then 
        fileName=`echo $line|awk {'print $4'}`
        echo $fileName
        if [[ $fileName != "" ]]
          then
            s3cmd del "$fileName"
        fi
    fi
  done;
