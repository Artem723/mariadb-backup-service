#!/usr/bin/bash


ENV_FILE="./.env"
# make the working directory the place where the script is located
SCRIPT_DIR=$(dirname "$(realpath "$0")")
cd "$SCRIPT_DIR"



sntx_error_handler() {
    local ERROR_TXT="[ERROR] An error occurred on line $1. COMMAND: $2"
    echo -e "$ERROR_TXT"
    report_error_and_exit "$ERROR_TXT"
}

trap 'sntx_error_handler $LINENO $BASH_COMMAND' ERR

log_info () {
    local iso_date=$(date -Iseconds)
    echo "[INFO][$iso_date] - $1"
}

report_error_and_exit () {
    local iso_date=$(date -Iseconds)
    echo "[ERROR][$iso_date] - $1"
    ./send_email.sh "$1"
    exit 1
}

# check if ENV exists
if [ -e "$ENV_FILE" ]; then 
    source $ENV_FILE
    if [ $? -gt 0 ]; then 
        report_error_and_exit "Error in reading ENV FILE"
    fi
else
    report_error_and_exit ".env file was not found!"  
fi

# export EMAIL_SMTP_ADDRESS=$EMAIL_SMTP_ADDRESS
# export EMAIL_SMTP_PORT=$EMAIL_SMTP_PORT
# export EMAIL_FROM_NAME=$EMAIL_FROM_NAME
# export EMAIL_FROM_ADDRESS=$EMAIL_FROM_ADDRESS
# export EMAIL_RECIPIENTS_ADDRESS_LIST=$EMAIL_RECIPIENTS_ADDRESS_LIST
# export EMAIL_AUTH_USER_NAME=$EMAIL_AUTH_USER_NAME
# export EMAIL_AUTH_USER_PASSWORD=$EMAIL_AUTH_USER_PASSWORD
# export PROJECT_NAME=$PROJECT_NAME
# echo "RECEPIENTS $EMAIL_RECIPIENTS_ADDRESS_LIST"

if [ -n "$REMOTE_SSH_PORT" ]; then
    REMOTE_SSH_PORT=22
fi

# inference the DB container name
if [ -z "$DB_CONTAINER_NAME" ]; then
    DB_CONTAINER_NAME=$(docker compose ps | grep  -G -o  "^[[:alpha:]e-]*$DB_SERVICE_NAME[[:alnum:]-]*")
    log_info "Found the container name [$DB_CONTAINER_NAME] to backup from"
    if [ -z "$DB_CONTAINER_NAME" ]; then
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
# [IMPORTANT] the user that runs this script should be in the docker group, otherwise the below command will fail with 'Permission denied'
# If it is insecure for the user to be in the 'docker' group, you can edit suders to allow the user to run a restricted set of sudo commands:
#   - Edit suders: sudo visudo -f /etc/sudoers.d/backup-ops
#   - Add the followng line:
#       # Allow backup-runner to run ONLY this specific command without a password
#       backup-runner ALL=(root) NOPASSWD: /usr/bin/docker exec <my-db-container> mariadb-dump *
# In the latter case, the command below should run with sudo: 
# sudo docker exec...
docker exec $DB_CONTAINER_NAME mariadb-dump -u $db_user -p$db_pwd $MARIADB_DATABASE_NAME > $backup_file_name 2>error.txt

if [ $? -gt 0 ]; then 
    report_error_and_exit "Could not make backup!"
fi
log_info "Backup is done. The resulted file is $backup_file_name"

# log_info "Ensuring the destination directory exists on the remote server..."
# ssh -p $REMOTE_SSH_PORT $REMOTE_USER@$REMOTE_HOST "mkdir -p $REMOTE_PATH"
# log_info "Copy the backup to $REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH PORT $REMOTE_SSH_PORT"
# scp -P $REMOTE_SSH_PORT $backup_file_name "$REMOTE_USER@$REMOTE_HOST:$REMOTE_PATH"

log_info "Compressing $backup_file_name ..."

archive=$backup_file_name".tar.gz"

tar -czf $archive $backup_file_name

if [ $? -gt 0 ]; then 
    report_error_and_exit "Could not compress $backup_file_name"
fi

rm $backup_file_name

log_info "Sending the backup to remote ($REMOTE_HOST)..."

ssh -p $REMOTE_SSH_PORT $REMOTE_USER@$REMOTE_HOST "$PROJECT_NAME" < "$archive"

if [ $? -gt 0 ]; then 
    report_error_and_exit "Could not send the backup file to the remote!"
fi

log_info "The backup file has been successfully copied!"
rm "$archive"