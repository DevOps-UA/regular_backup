#!/bin/bash
#
# Add to cron
# */15 * * * * /home/jenkins/regular_jenkins_backup.sh
# returns 0 in case of success and 1 in case of failure

# Requires external tool s3cmd preconfigured for current user
# Dependency: sudo apt-get install s3cmd


NUMBER_OF_BACKUPS_TO_KEEP=10
S3_BUCKETNAME=
JENKINS_HOME=/var/lib/jenkins
RESTORE_SCRIPT_PATH="$PWD/jenkins_restore_frombackup.sh"

#BACKUP_PATH="/path/to/backup/directory" # do not include trailing slash
BACKUP_PATH="/home/jenkins/jenkins_backups"
#
FILE_NAME="DATE" #defaults to [currentdate].tar.gz ex: 2011-12-19_hh-mm.tar.gz

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
	TMP_BACKUP_DIR="jenkins-$TODAYS_DATE"

  ### Print out what we shall do
  echo "Starting Jenkins backup on `hostname -s` at `date +'%d-%b-%Y %H:%M:%S %Z'`"

  ### Create backup directories
  mkdir -p "${TMP_BACKUP_DIR}/"{plugins,users,userContent,secrets,jobs,.ssh}

  ### Backup $JENKINS_HOME/*.xml
  echo -n "Backing up ${JENKINS_HOME}/*.xml... "
  xml_count=$(find ${JENKINS_HOME}/ -maxdepth 1 -name "*.xml" |wc -l |tr -d ' ')
  if [ $xml_count -ne 0 ]; then
    cp "${JENKINS_HOME}/"*.xml "${TMP_BACKUP_DIR}"
    echo "done."
  else
    echo "no files found."
  fi

  ### Backup $JENKINS_HOME/plugins/*.[hj]pi{.pinned}
  echo -n "Backing up ${JENKINS_HOME}/plugins/... "
  # Check if plugin directory exists
  if [[ -d "${JENKINS_HOME}/plugins/" ]]; then
    # Check number of *.[hj]pi files and backup if any
    hpi_count=$(find "${JENKINS_HOME}/plugins/" -name "*.hpi" 2> /dev/null |wc -l |tr -d ' ')
    jpi_count=$(find "${JENKINS_HOME}/plugins/" -name "*.jpi" 2> /dev/null |wc -l |tr -d ' ')
    if [ $hpi_count -ne 0 -o $jpi_count -ne 0 ]; then
      cp "${JENKINS_HOME}/plugins/"*.[hj]pi "${TMP_BACKUP_DIR}/plugins"
      echo -n "*.[hj]pi done. "
    else
      echo -n "no *.[hj]pi found. "
    fi
    # Check number of *.[hj]pi.pinned files and backup if any
    hpi_pinned_count=$(find ${JENKINS_HOME}/plugins/ -name *.hpi.pinned |wc -l |tr -d ' ')
    jpi_pinned_count=$(find ${JENKINS_HOME}/plugins/ -name *.jpi.pinned |wc -l |tr -d ' ')
    if [ $hpi_pinned_count -ne 0 -o $jpi_pinned_count -ne 0 ]; then
      cp "${JENKINS_HOME}/plugins/"*.[hj]pi.pinned "${TMP_BACKUP_DIR}/plugins"
      echo "*.[hj]pi.pinned done."
    else
      echo "no *.[hj]pi.pinned found."
    fi
  else
    echo "no plugin directory found."
  fi

  ### Backup $JENKINS_HOME/users/*
  echo -n "Backing up ${JENKINS_HOME}/users/... "
  if [[ -d "${JENKINS_HOME}/users/" ]]; then
    cp -R "${JENKINS_HOME}/users/"* "${TMP_BACKUP_DIR}/users"
    echo "done."
  else
    echo "no users directory found."
  fi

  ### Backup $JENKINS_HOME/userContent/*
  echo -n "Backing up ${JENKINS_HOME}/userContent/... "
  if [[ -d "${JENKINS_HOME}/userContent/" ]]; then
    cp -R "${JENKINS_HOME}/userContent/"* "${TMP_BACKUP_DIR}/userContent"
    echo "done."
  else
    echo "no userContent directory found."
  fi

  ### Backup $JENKINS_HOME/secrets/*
  echo -n "Backing up ${JENKINS_HOME}/secrets/... "
  if [[ -d "${JENKINS_HOME}/secrets/" ]]; then
    cp -R "${JENKINS_HOME}/secrets/"* "${TMP_BACKUP_DIR}/secrets"
    echo "done"
  else
    echo "no secrets directory found."
  fi

  ### Backup $JENKINS_HOME/jobs/*
  echo -n "Backing up ${JENKINS_HOME}/jobs/... "
  if [[ -d "${JENKINS_HOME}/jobs/" ]]; then
    cd "${JENKINS_HOME}/jobs/"
    ls -1 | while read JOB_NAME; do
			echo "Backing up $JOB_NAME"
      mkdir -p "${TMP_BACKUP_DIR}/jobs/${JOB_NAME}/"
      find "${JENKINS_HOME}/jobs/${JOB_NAME}/" -maxdepth 1 -name "*.xml" | xargs -I {} cp {} "${TMP_BACKUP_DIR}/jobs/${JOB_NAME}/"
    done
    echo "done"
  else
    echo "no jobs directory found."
  fi



	# check to see if jenkins was dumped correctly
	if [ -d "$TMP_BACKUP_DIR" ]; then

		# if file name is set to nothing then make it todays date
		if [ "$FILE_NAME" == "" ]; then
			FILE_NAME="$TODAYS_DATETIME"
		fi

    cp $RESTORE_SCRIPT_PATH $TMP_BACKUP_DIR/restore.sh
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
