#!/bin/bash
#
# Add to cron 
# */15 * * * * /home/slavko/mongo_backup.sh
# returns 0 in case of success and 1 in case of failure

# Requires external tool s3cmd preconfigured for current user
# Dependency: sudo apt-get install s3cmd

HOST="localhost"
PORT="27017" # default mongoDb port is 27017
USERNAME=""
PASSWORD=""
DBNAME="local" #DB Name to backup
NUMBER_OF_BACKUPS_TO_KEEP=10
S3_BUCKETNAME=

#BACKUP_PATH="/path/to/backup/directory" # do not include trailing slash
BACKUP_PATH="/home/slavko/mongo_backups/"
#
FILE_NAME="DATE" #defaults to [currentdate].tar.gz ex: 2011-12-19_hh-mm.tar.gz

MONGO_DUMP_BIN_PATH="$(which mongodump)"
TAR_BIN_PATH="$(which tar)"

# Get todays date to use in filename of backup output
TODAYS_DATE=`date "+%Y-%m-%d"`
TODAYS_DATETIME=`date "+%Y-%m-%d_%H-%M-%S"`

# replace DATE with todays date in the backup path
BACKUP_PATH="${BACKUP_PATH//DATE/$TODAYS_DATETIME}"

# Create BACKUP_PATH directory if it does not exist
[ ! -d $BACKUP_PATH ] && mkdir -p $BACKUP_PATH || :

# Ensure directory exists before dumping to it
if [ -d "$BACKUP_PATH" ]; then

	cd $BACKUP_PATH

	# initialize temp backup directory
	TMP_BACKUP_DIR="mongodb-$TODAYS_DATE"

	echo; echo "=> Backing up db $DBNAME on Mongo Server: $HOST:$PORT "; echo -n '   ';

	# run dump on mongoDB
	if [ "$USERNAME" != "" -a "$PASSWORD" != "" ]; then 
		$MONGO_DUMP_BIN_PATH --host $HOST:$PORT  --username $USERNAME --password $PASSWORD --db $DBNAME --out $TMP_BACKUP_DIR >> /dev/null
	else 
		$MONGO_DUMP_BIN_PATH --host $HOST:$PORT  --db $DBNAME --out $TMP_BACKUP_DIR >> /dev/null
	fi

	# check to see if mongoDb was dumped correctly
	if [ -d "$TMP_BACKUP_DIR" ]; then

		# if file name is set to nothing then make it todays date
		if [ "$FILE_NAME" == "" ]; then
			FILE_NAME="$TODAYS_DATETIME"
		fi

		touch $TMP_BACKUP_DIR/restore.sh
        echo "#!/bin/bash" >> $TMP_BACKUP_DIR/restore.sh
        echo "#" >> $TMP_BACKUP_DIR/restore.sh
        echo HOST="localhost" >> $TMP_BACKUP_DIR/restore.sh
        echo PORT="27017" >> $TMP_BACKUP_DIR/restore.sh
        echo USERNAME="" >> $TMP_BACKUP_DIR/restore.sh
        echo PASSWORD="" >> $TMP_BACKUP_DIR/restore.sh
        echo DBNAME="$DBNAME" >> $TMP_BACKUP_DIR/restore.sh
        echo MONGO_RESTORE_BIN_PATH='$(which mongorestore)' >> $TMP_BACKUP_DIR/restore.sh

        echo 'if [ "$USERNAME" != "" -a "$PASSWORD" != "" ]; then' >> $TMP_BACKUP_DIR/restore.sh
	    echo '  $MONGO_RESTORE_BIN_PATH --drop --host $HOST --port $PORT  --username $USERNAME --password $PASSWORD --db $DBNAME  $DBNAME' >> $TMP_BACKUP_DIR/restore.sh
	    echo ' else ' >> $TMP_BACKUP_DIR/restore.sh
	    echo '  $MONGO_RESTORE_BIN_PATH --drop --host $HOST --port $PORT --db $DBNAME  $DBNAME' >> $TMP_BACKUP_DIR/restore.sh
	    echo 'fi' >> $TMP_BACKUP_DIR/restore.sh

        chmod +x $TMP_BACKUP_DIR/restore.sh

		# replace DATE with todays date in the filename
		FILE_NAME="${FILE_NAME//DATE/$TODAYS_DATETIME}"

		# turn dumped files into a single tar file
		$TAR_BIN_PATH --remove-files -czf $FILE_NAME.tar.gz $TMP_BACKUP_DIR >> /dev/null

		# verify that the file was created
		if [ -f "$FILE_NAME.tar.gz" ]; then
			echo "=> Success: `du -sh $FILE_NAME.tar.gz`"; echo;

			if [ -d "$BACKUP_PATH/$TMP_BACKUP_DIR" ]; then
				rm -rf "$BACKUP_PATH/$TMP_BACKUP_DIR"
			fi

			( cd $BACKUP_PATH ; ls -1tr | head -n -$NUMBER_OF_BACKUPS_TO_KEEP | xargs -d '\n' rm -f )

                        if [[ ! -z $S3_BUCKETNAME ]]; then

                          echo "=> In progress: Uploading to S3"; echo;
                          echo s3cmd put $FILE_NAME.tar.gz s3://$S3_BUCKETNAME/
                          s3cmd put $FILE_NAME.tar.gz s3://$S3_BUCKETNAME/
                          echo "=> command executed"

                        fi

			exit 0
		else
			 echo "!!!=> Failed to create backup file: $BACKUP_PATH/$FILE_NAME.tar.gz"; echo;
			 exit 1
		fi
	else
		echo; echo "!!!=> Failed to backup mongoDB"; echo;
		exit 1
	fi
else

	echo "!!!=> Failed to create backup path: $BACKUP_PATH"
	exit 1

fi
