#!/bin/bash

# Log file
LOG_FILE="log.txt"

# Log function
log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $1" >> "$LOG_FILE"
}

# Function to check log file size and clean up if it exceeds 100 MB
check_log_size() {
    MAX_SIZE=$((100 * 1024 * 1024)) # 100 MB in bytes
    if [ -f "$LOG_FILE" ]; then
        FILE_SIZE=$(stat -c%s "$LOG_FILE")
        if [ "$FILE_SIZE" -gt "$MAX_SIZE" ]; then
            > "$LOG_FILE"
            log_info "Log file exceeded 100 MB and was cleaned up."
        fi
    fi
}

# Start logging
check_log_size
log_info "Download script started."

# Load environment variables from .env file if it exists
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
    log_info ".env file loaded."
else
    log_info ".env file not found."
fi

# Check if Azure CLI is installed, if not install it
if ! command -v az &> /dev/null
then
    log_info "Azure CLI not found, installing..."
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
    log_info "Azure CLI installed."
else
    log_info "Azure CLI is already installed."
fi

# Environment variables
ACCOUNT_NAME=${ACCOUNT_NAME}
SOURCE_CONTAINER=${SOURCE_CONTAINER}
DESTINATION_PATH=${DESTINATION_PATH:-.}
SAS_TOKEN="${SAS_TOKEN}"

# Check if required environment variables are set
if [ -z "$ACCOUNT_NAME" ] || [ -z "$SOURCE_CONTAINER" ] || [ -z "$DESTINATION_PATH" ] || [ -z "$SAS_TOKEN" ]; then
    log_info "One or more required environment variables are not set."
    log_info "Please set ACCOUNT_NAME, SOURCE_CONTAINER, DESTINATION_PATH, and SAS_TOKEN."
    exit 1
fi

log_info "Environment variables are set."

# List blobs and download only if they have changed
blobs=$(az storage blob list \
    --account-name $ACCOUNT_NAME \
    --container-name $SOURCE_CONTAINER \
    --sas-token "$SAS_TOKEN" \
    --query "[].{name:name, lastModified:properties.lastModified}" \
    --output tsv)

log_info "Blob list retrieved."

while IFS=$'\t' read -r name lastModified; do
    localFile="$DESTINATION_PATH/$name"
    if [ -z "$lastModified" ]; then
        log_info "Skipping $name due to invalid lastModified date."
        continue
    fi
    lastModifiedEpoch=$(date -d "$lastModified" +%s 2>/dev/null)
    if [ $? -ne 0 ]; then
        log_info "Skipping $name due to invalid lastModified date."
        continue
    fi
    if [ ! -f "$localFile" ]; then
        log_info "Downloading $name (last modified: $lastModified)..."
        az storage blob download \
            --account-name $ACCOUNT_NAME \
            --container-name $SOURCE_CONTAINER \
            --name "$name" \
            --file "$localFile" \
            --sas-token "$SAS_TOKEN" \
            --overwrite
        log_info "$name downloaded."
    elif [ "$(date -r "$localFile" +%s)" -lt "$lastModifiedEpoch" ]; then
        log_info "Downloading $name (last modified: $lastModified)..."
        az storage blob download \
            --account-name $ACCOUNT_NAME \
            --container-name $SOURCE_CONTAINER \
            --name "$name" \
            --file "$localFile" \
            --sas-token "$SAS_TOKEN" \
            --overwrite
        log_info "$name downloaded."
    else
        log_info "Skipping $name as it is up-to-date (last modified: $lastModified)."
    fi
done <<< "$blobs"

log_info "Download completed."
