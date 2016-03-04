#!/bin/bash
#
REMOTE_USER="slavko@192.168.0.31"
LOCAL_BACKUP_DIR="./backups"
REMOTE_BACKUP_DIR="/home/slavko/mongo_backups"


[ ! -d $LOCAL_BACKUP_DIR ] && mkdir -p $LOCAL_BACKUP_DIR || :

ssh $REMOTE_USER 'bash -s' < regular_mongo_backup.sh
scp $REMOTE_USER:$REMOTE_BACKUP_DIR/* $LOCAL_BACKUP_DIR

#From windows box: 

#plink remoteuser@MachineB  -m regular_mongo_backup.sh

