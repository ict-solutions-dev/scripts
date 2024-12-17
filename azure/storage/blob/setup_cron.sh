#!/bin/bash

# Default cron schedule (every day at 01:00)
DEFAULT_SCHEDULE="0 1 * * *"

# Prompt user for custom schedule
read -p "Enter the cron schedule for running the download script (default: '$DEFAULT_SCHEDULE'): " CRON_SCHEDULE
CRON_SCHEDULE=${CRON_SCHEDULE:-$DEFAULT_SCHEDULE}

# Get the absolute path of the download.sh script and its directory
SCRIPT_PATH=$(realpath download.sh)
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")

# Add the cron job with logging to syslog
(crontab -l 2>/dev/null; echo "$CRON_SCHEDULE cd $SCRIPT_DIR && /bin/bash download.sh && logger -t azure-blob-download \"Azure Blob download script ran at \$(date)\"") | crontab -

echo "Cron job set to run the download script at the following schedule: $CRON_SCHEDULE"
echo "Output will be logged to syslog with the tag 'azure-blob-download'"
