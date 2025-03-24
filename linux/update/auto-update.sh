#!/bin/bash

# Script: auto-update.sh
# Description: Automated system update script with Telegram notifications
# Author: Your Name
# Last Modified: 2024-03-24

set -euo pipefail  # Exit on error, undefined vars and pipe failures

# Configuration
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"
HOSTNAME=$(hostname)
LOG_FILE="/var/log/auto-update.log"

# Logging function
log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" | tee -a "$LOG_FILE"
}

# Validate Telegram credentials
validate_telegram_config() {
    if [[ -z "$TELEGRAM_BOT_TOKEN" ]] || [[ -z "$TELEGRAM_CHAT_ID" ]]; then
        log "ERROR: Telegram credentials not configured"
        exit 1
    fi
}

# Enhanced Telegram message function with error handling
send_telegram_message() {
    local message="$1"
    local response

    response=$(curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d chat_id="${TELEGRAM_CHAT_ID}" \
        -d text="$message" \
        -d parse_mode="HTML")

    if ! echo "$response" | grep -q "\"ok\":true"; then
        log "ERROR: Failed to send Telegram message: $response"
        return 1
    fi
}

# Version comparison function
version_gt() {
    test "$(echo "$@" | tr " " "\n" | sort -V | head -n 1)" != "$1"
}

# Cleanup function
cleanup() {
    log "Cleaning up package cache..."
    apt-get clean
    log "Update process completed"
}

# Main update function
perform_updates() {
    local current_kernel=$(uname -r)
    local current_docker_version=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "not installed")

    log "Starting system update process..."

    # Update package lists
    if ! apt-get update; then
        log "ERROR: Failed to update package lists"
        return 1
    fi

    # Check for kernel updates
    local kernel_update=$(apt-get --just-print dist-upgrade 2>&1 | grep -i "linux-image" | grep "yet to be installed" || true)

    # Check for Docker updates if installed
    if [[ "$current_docker_version" != "not installed" ]]; then
        local available_docker_version=$(apt-cache policy docker-ce | grep Candidate | awk '{print $2}')

        if version_gt "$available_docker_version" "$current_docker_version"; then
            send_telegram_message "🔄 Server: ${HOSTNAME}
🐳 Docker update available!
Current version: ${current_docker_version}
Available version: ${available_docker_version}
Action required: Manual update needed"
        fi
    fi

    # Perform system upgrade
    if ! DEBIAN_FRONTEND=noninteractive apt-get upgrade -y; then
        log "ERROR: System upgrade failed"
        return 1
    fi

    # Notify about kernel updates
    if [[ -n "$kernel_update" ]]; then
        send_telegram_message "🔄 Server: ${HOSTNAME}
⚠️ New kernel update available!
Current version: ${current_kernel}
Action required: Manual reboot needed"
    fi
}

# Main execution
main() {
    validate_telegram_config
    perform_updates
    cleanup
}

# Trap for cleanup on script exit
trap cleanup EXIT

# Execute main function
main "$@"
