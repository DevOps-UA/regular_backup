#!/bin/bash
#
# Add to cron - daily at 01:00 AM
# 0 1 * * * /home/git/gitlab/cron_jobs/regular_gitlab_backup.sh > /dev/null
# returns 0 in case of success and 1 in case of failure

# Requires external tool s3cmd preconfigured for current user
# Dependency: sudo apt-get install s3cmd


NUMBER_OF_BACKUPS_TO_KEEP=10
S3_BUCKETNAME=
S3_KEEP="90 days"
GITLAB_HOME=/home/git/gitlab

#BACKUP_PATH="/path/to/backup/directory" # do not include trailing slash
BACKUP_PATH="/home/git/gitlab/tmp/backups"
#

# Create BACKUP_PATH directory if it does not exist
[ ! -d $BACKUP_PATH ] && mkdir -p $BACKUP_PATH || :

# Ensure directory exists before dumping to it
if [ -d "$BACKUP_PATH" ]; then

 ### Print out what we shall do
  echo "Starting Gitlab backup on `hostname -s` at `date +'%d-%b-%Y %H:%M:%S %Z'`"

  sudo -u git -H bundle exec rake gitlab:backup:create RAILS_ENV=production


  if [[ ! -z $S3_BUCKETNAME ]]; then

    echo "=> In progress: Uploading to S3"; echo;
    echo s3cmd sync $BACKUP_PATH --skip-existing s3://$S3_BUCKETNAME/
    s3cmd sync $BACKUP_PATH --skip-existing s3://$S3_BUCKETNAME/
    echo "=> command executed"

    echo "==> Cleaning up older one"
    s3cmd ls s3://$S3_BUCKETNAME/ | while read -r line;
      do
        createDate=`echo $line|awk {'print ${S3_BUCKETNAME}" "${S3_KEEP}'}`
        createDate=`date -d"$createDate" +%s`
        olderThan=`date -d"-${S3_KEEP}" +%s`
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

  fi
fi
