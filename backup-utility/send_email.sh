#!/usr/bin/bash


ENV_FILE="./.env"
EMAIL_FILE="email_body.txt"
RECIPIENT_PARAMS=""
RECIPIENT_EMAIL_BODY=""

# check if ENV exists
if [ -e "$ENV_FILE" ]; then 
    source $ENV_FILE
    if [ $? -gt 0 ]; then 
        report_error_and_exit "Error in reading ENV FILE"
    fi
else
    report_error_and_exit ".env file was not found!"  
fi

echo "RECEPIENTS EMAIL $EMAIL_RECIPIENTS_ADDRESS_LIST"
# Constructing recipient params list for CURL request 
for RECIPIENT in "${EMAIL_RECIPIENTS_ADDRESS_LIST[@]}"; do

    RECIPIENT_PARAMS+="--mail-rcpt $RECIPIENT "

done

# Constructing recipient list for the Email body  
for RECIPIENT in "${EMAIL_RECIPIENTS_ADDRESS_LIST[@]}"; do

    RECIPIENT_EMAIL_BODY+="$RECIPIENT, "

done

# Removing trailing comma ','
RECIPIENT_EMAIL_BODY=${RECIPIENT_EMAIL_BODY:0:-2}
echo "RECIPIENTS_BODY: $RECIPIENT_EMAIL_BODY"
echo "RECIPIENTS_PARAMS: $RECIPIENT_PARAMS"
echo "EMAIL_AUTH_USER_NAME: $EMAIL_AUTH_USER_NAME"
# Preparing email file
echo -e "From: $EMAIL_FROM_NAME  <$EMAIL_FROM_ADDRESS>
To: $RECIPIENT_EMAIL_BODY
Subject: [BACKUP - ERROR | $PROJECT_NAME]: Something went wrong with the backup..
Date: $(date)\n
Something went wrong with the backup for MariaDB database for $PROJECT_NAME.
Reported problem that might be useful: $1 \n\n
This is an automatic email.
Do not reply to it." > $EMAIL_FILE


curl --url "$EMAIL_SMTP_ADDRESS:$EMAIL_SMTP_PORT" \
 --ssl --ssl-reqd $RECIPIENT_PARAMS \
 --user $EMAIL_AUTH_USER_NAME:$EMAIL_AUTH_USER_PASSWORD \
 --upload-file $EMAIL_FILE