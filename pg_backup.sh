#!/bin/sh

###########################
####### LOAD CONFIG #######
###########################

while [ $# -gt 0 ]; do
    case "$1" in
        "-c")
            CONFIG_FILE_PATH="$2"
            shift 2
            ;;
        *)
            printf "Unknown option '$1'. Try 'pg_backup.sh -c /path/to/config'\n"
            exit 1
            ;;
    esac
done

if [ -z "$CONFIG_FILE_PATH" ] ; then
    SCRIPT_PATH=`cd ${0%/*} && pwd -P`
    CONFIG_FILE_PATH="$SCRIPT_PATH/pg_backup.conf"
fi

if [ ! -r "$CONFIG_FILE_PATH" ] ; then
    printf "Could not load config from file '$CONFIG_FILE_PATH'\n"
    exit 1
fi

. $CONFIG_FILE_PATH

# Make sure we're running as the required backup user
if [ "$BACKUP_USER" != "" ] && [ `id -un` != "$BACKUP_USER" ] ; then
	printf "This script must be run as a user '$BACKUP_USER'.\n"
	exit 1
fi

#######################
#### BACKUP GLOBALS ###
#######################

BACKUP_TIME=`date +\%Y_\%m_\%d_\%s`

if [ "$BACKUP_GLOBALS_ENABLED" = "yes" ]
then
    printf "Try to backup global objects ... "

    BACKUP_FILENAME="$BACKUP_DIR/$BACKUP_FILENAME_PREFIX$BACKUP_TIME.GLOBALS.sql.gz"

	if ! pg_dumpall -g -h $PG_HOST -p $PG_PORT -U $PG_USER | gzip > "$BACKUP_FILENAME.in_progress"; then
	    printf "Failed\n"
	else
	    mv "$BACKUP_FILENAME.in_progress" $BACKUP_FILENAME
	    printf "Success\n"
	fi
else
    printf "Global objects backup are disabled. Skipping.\n"
fi

###########################
#### BACKUP DATABASES #####
###########################

for DATABASE in $DATABASES
do
    printf "Try to backup database '$DATABASE' ... "

    BACKUP_FILENAME="$BACKUP_DIR/$BACKUP_FILENAME_PREFIX$BACKUP_TIME.$DATABASE.custom"

    if ! pg_dump -Fc -h $PG_HOST -p $PG_PORT -U $PG_USER -f "$BACKUP_FILENAME.in_progress" $DATABASE; then
	    printf "Failed\n"
    else
	    mv "$BACKUP_FILENAME.in_progress" $BACKUP_FILENAME
	    printf "Success\n"
    fi
done

# Delete old backups
find "$BACKUP_DIR" -maxdepth 1 -mtime +"$DAYS_TO_KEEP" -name "$BACKUP_FILENAME_PREFIX*" -exec rm -f '{}' ';'