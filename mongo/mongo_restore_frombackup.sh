#!/bin/bash
#


HOST="localhost"
PORT="27017" # default mongoDb port is 27017
USERNAME=""
PASSWORD=""
DBNAME="db_name"

MONGO_RESTORE_BIN_PATH="$(which mongorestore)"

# run mongorestore on mongoDB
if [ "$USERNAME" != "" -a "$PASSWORD" != "" ]; then 
	$MONGO_RESTORE_BIN_PATH --drop --host $HOST --port $PORT -u $USERNAME -p $PASSWORD --db $DBNAME  $DBNAME
else 
	$MONGO_RESTORE_BIN_PATH --drop --host $HOST --port $PORT --db $DBNAME  $DBNAME
fi

