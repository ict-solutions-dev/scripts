#!/bin/bash

# Default cron schedule (every day at 01:00)
DEFAULT_SCHEDULE="0 1 * * *"

# Prompt user for custom schedule
read -p "Enter the cron schedule for running the download script (default: '$DEFAULT_SCHEDULE'): " CRON_SCHEDULE
CRON_SCHEDULE=${CRON_SCHEDULE:-$DEFAULT_SCHEDULE}

# Get the absolute path of the download.sh script
SCRIPT_PATH=$(realpath download.sh)

# Add the cron job
(crontab -l 2>/dev/null; echo "$CRON_SCHEDULE /bin/bash -c '$SCRIPT_PATH; logger -t download_script \"Download script ran at \$(date)\"'") | crontab -

echo "Cron job set to run the download script at the following schedule: $CRON_SCHEDULE"
