#!/usr/bin/bash

ENV_FILE="./.env"
# make the working directory the place where the script is located
SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"

sntx_error_handler() {
    echo -e "[ERROR] An error occurred on line $1. \nCOMMAND: $2"
    exit 1
}

trap 'sntx_error_handler $LINENO $BASH_COMMAND' ERR

log_info () {
    local iso_date=$(date -Iseconds)
    echo "[INFO][$iso_date] - $1"
}

report_error_and_exit () {
    local iso_date=$(date -Iseconds)
    echo "[ERROR][$iso_date] - $1"
    exit 1
}

# check if ENV exists
if [ -e "$ENV_FILE" ]; then 
    source $ENV_FILE
else
    report_error_and_exit ".env file was not found!"  
fi

if [ -n "$REMOTE_SSH_PORT" ]; then
    REMOTE_SSH_PORT=22
fi

# inference the DB container name
if [ -n "$DB_CONTAINER_NAME" ]; then
    DB_CONTAINER_NAME=$(docker compose ps | grep  -G -o  "^[[:alpha:]e-]*$DB_SERVICE_NAME[[:alnum:]-]*")
    log_info "Found the container name [$DB_CONTAINER_NAME] to backup from"
    if [ -n "$DB_CONTAINER_NAME" ]; then
        report_error_and_exit "Could not infer the DB container name"
    fi
else
    log_info "Back up from [$DB_CONTAINER_NAME]"
fi

db_user=$(cat $MARIADB_USER_FILE)
db_pwd=$(cat $MARIADB_PASSWORD_FILE)

backup_file_name=$BACKUP_FILE_PREFIX"_dump_$MARIADB_DATABASE_NAME""_$(date +%F).sql"
log_info "Making backup..."
# make the backup 
docker exec $DB_CONTAINER_NAME mariadb-dump -u $db_user -p$db_pwd $MARIADB_DATABASE_NAME > $backup_file_name 2>error.txt

if [ $? -gt 0 ]; then 
    report_error_and_exit "Could not make backup!"
fi
log_info "Backup is done. The resulted file is $backup_file_name"

log_info "Ensuring the destination directory exists on the remote server..."
ssh -p $REMOTE_SSH_PORT $REMOTE_USER@$REMOTE_HOST "mkdir -p $REMOTE_PATH"

log_info "Copy the backup to $REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH PORT $REMOTE_SSH_PORT"

scp -P $REMOTE_SSH_PORT $backup_file_name "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH"

if [ $? -gt 0 ]; then 
    report_error_and_exit "Could not copy the backup file to the remote!"
fi

log_info "The backup file has been successfully copied!"