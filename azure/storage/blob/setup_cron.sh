#!/bin/bash

# Default cron schedule (every day at 00:01)
DEFAULT_SCHEDULE="1 0 * * *"

# Prompt user for custom schedule
read -p "Enter the cron schedule for running the download script (default: '$DEFAULT_SCHEDULE'): " CRON_SCHEDULE
CRON_SCHEDULE=${CRON_SCHEDULE:-$DEFAULT_SCHEDULE}

# Get the absolute path of the download.sh script
SCRIPT_PATH=$(realpath download.sh)

# Add the cron job
(crontab -l 2>/dev/null; echo "$CRON_SCHEDULE /bin/bash $SCRIPT_PATH") | crontab -

echo "Cron job set to run the download script at the following schedule: $CRON_SCHEDULE"
