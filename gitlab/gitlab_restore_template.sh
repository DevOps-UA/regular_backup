#!/bin/bash -e
###
### Script to restore Gitlab data generated by gitlab backup script
###
### NOTE:
###   - Requires passwordless sudo
###   - Works on Debian/Ubuntu
###
###

### Display usage

if [ -z $1 ]
then
 echo please provide backup date signature like 1467807171
 exit 1
fi

GITLAB_HOME=/home/git/gitlab


### Keep environment clean
export LC_ALL="C"
readonly BACKUP_DIR_NAME="${GITLAB_HOME}/tmp/backups"

### Check if ${GITLAB_HOME} is accessible
if [[ ! -d "${GITLAB_HOME}" ]]; then
  echo "Cannot access ${GITLAB_HOME}, exiting..."
  exit 1
fi

### Check if we have gitlab user
if [[ ! `id git 2> /dev/null` ]]; then
  echo "User 'git' doesn't exist, please check Gitlab installation."
  exit 1
fi

### Print out what we shall do
echo "Starting Gitlab restore on `hostname -s` at `date +'%d-%b-%Y %H:%M:%S %Z'`"

### Stop Gitlab
echo "Stopping Gitlab service..."
sudo service gitlab stop || echo "Gitlab failed to stop or is not running, it's okay for now."

cd $GITLAB_HOME

sudo -u git -H bundle exec rake gitlab:backup:restore RAILS_ENV=production BACKUP=$1

### Start Gitlab
echo "Starting Gitlab service..."
sudo service gitlab start

### Done
echo "Finished Gitlab restore on `hostname -s` at `date +'%d-%b-%Y %H:%M:%S %Z'`"
exit 0

### EOF
