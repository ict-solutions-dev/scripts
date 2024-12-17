#!/bin/bash

# Load environment variables from .env file if it exists
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Check if Azure CLI is installed, if not install it
if ! command -v az &> /dev/null
then
    echo "Azure CLI not found, installing..."
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
fi

# Environment variables
ACCOUNT_NAME=${ACCOUNT_NAME}
SOURCE_CONTAINER=${SOURCE_CONTAINER}
DESTINATION_PATH=${DESTINATION_PATH:-.}
SAS_TOKEN="${SAS_TOKEN}"

# Check if required environment variables are set
if [ -z "$ACCOUNT_NAME" ] || [ -z "$SOURCE_CONTAINER" ] || [ -z "$DESTINATION_PATH" ] || [ -z "$SAS_TOKEN" ]; then
    echo "One or more required environment variables are not set."
    echo "Please set ACCOUNT_NAME, SOURCE_CONTAINER, DESTINATION_PATH, and SAS_TOKEN."
    exit 1
fi

# List blobs and download only if they have changed
blobs=$(az storage blob list \
    --account-name $ACCOUNT_NAME \
    --container-name $SOURCE_CONTAINER \
    --sas-token "$SAS_TOKEN" \
    --query "[].{name:name, lastModified:properties.lastModified}" \
    --output tsv)

while IFS=$'\t' read -r name lastModified; do
    localFile="$DESTINATION_PATH/$name"
    if [ -z "$lastModified" ]; then
        echo "Skipping $name due to invalid lastModified date."
        continue
    fi
    lastModifiedEpoch=$(date -d "$lastModified" +%s 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "Skipping $name due to invalid lastModified date."
        continue
    fi
    if [ ! -f "$localFile" ]; then
        echo "Downloading $name (last modified: $lastModified)..."
        az storage blob download \
            --account-name $ACCOUNT_NAME \
            --container-name $SOURCE_CONTAINER \
            --name "$name" \
            --file "$localFile" \
            --sas-token "$SAS_TOKEN" \
            --overwrite
    elif [ "$(date -r "$localFile" +%s)" -lt "$lastModifiedEpoch" ]; then
        echo "Downloading $name (last modified: $lastModified)..."
        az storage blob download \
            --account-name $ACCOUNT_NAME \
            --container-name $SOURCE_CONTAINER \
            --name "$name" \
            --file "$localFile" \
            --sas-token "$SAS_TOKEN" \
            --overwrite
    else
        echo "Skipping $name as it is up-to-date (last modified: $lastModified)."
    fi
done <<< "$blobs"

echo "Download completed."
