#!/bin/bash

# Telegram settings
TELEGRAM_BOT_TOKEN="YOUR_BOT_TOKEN"
TELEGRAM_CHAT_ID="YOUR_CHAT_ID"
HOSTNAME=$(hostname)

# Function to send Telegram message
send_telegram_message() {
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d chat_id="${TELEGRAM_CHAT_ID}" \
        -d text="$1" \
        -d parse_mode="HTML"
}

# Check current kernel version
CURRENT_KERNEL=$(uname -r)

# Check current Docker version
CURRENT_DOCKER_VERSION=$(docker version --format '{{.Server.Version}}' 2>/dev/null)

# Update package lists
apt-get update

# Check for kernel updates
KERNEL_UPDATE=$(apt-get --just-print dist-upgrade 2>&1 | grep -i "linux-image" | grep "yet to be installed")

# Check for available Docker updates
AVAILABLE_DOCKER_VERSION=$(apt-cache policy docker-ce | grep Candidate | awk '{print $2}')

# Perform system upgrade excluding docker packages (due to pin)
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Check if kernel update is available
if [ ! -z "$KERNEL_UPDATE" ]; then
    MESSAGE="🔄 Server: ${HOSTNAME}
⚠️ New kernel update available!
Current version: ${CURRENT_KERNEL}
Action required: Manual reboot needed"
    send_telegram_message "$MESSAGE"
fi

# Check if Docker update is available
if [ ! -z "$CURRENT_DOCKER_VERSION" ] && [ "$CURRENT_DOCKER_VERSION" != "$AVAILABLE_DOCKER_VERSION" ]; then
    MESSAGE="🔄 Server: ${HOSTNAME}
🐳 Docker update available!
Current version: ${CURRENT_DOCKER_VERSION}
Available version: ${AVAILABLE_DOCKER_VERSION}
Action required: Manual update needed"
    send_telegram_message "$MESSAGE"
fi

# Clean up downloaded package files
apt-get clean
