#!/bin/bash

#################################################################
# Script: SSH Hardening Implementation
# Version: 1.0
# Description: Enforces SSH key-based authentication and hardens config
# Author: Jozef Rebjak
# Date: $(date +%Y-%m-%d)
# Usage: sudo ./ssh_key_only_hardening.sh
# OS: Ubuntu 22.04+
#################################################################

# Exit on any error
set -e

# Function for logging
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

# Check if running as root - required for modifying SSH config
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# Verify sshd is installed
if ! command -v sshd >/dev/null 2>&1; then
    log "Error: OpenSSH Server is not installed"
    exit 1
fi

# Backup original sshd config with timestamp
BACKUP_FILE="/etc/ssh/sshd_config.backup.$(date +%Y%m%d)"
if ! cp /etc/ssh/sshd_config "$BACKUP_FILE"; then
    log "Error: Failed to create backup"
    exit 1
fi
log "Created backup: $BACKUP_FILE"

# Create secure banner with legal warning
cat > /etc/ssh/banner << 'EOL'
********************* WARNING *********************
This system is restricted to authorized users only.
Unauthorized access attempts are prohibited and
will be prosecuted to the full extent of the law.
All activities may be monitored and recorded.
************************************************
EOL

# Apply SSH hardening configurations
log "Applying SSH security configurations..."
sed -i.bak '
    # Completely disable root login for maximum security
    s/#\?PermitRootLogin.*/PermitRootLogin no/

    # Disable password authentication to prevent brute force attacks
    s/#\?PasswordAuthentication.*/PasswordAuthentication no/

    # Enable public key authentication - enforce hardware key usage
    s/#\?PubkeyAuthentication.*/PubkeyAuthentication yes/

    # Disable keyboard-interactive authentication
    s/#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/

    # Set warning banner for legal compliance and deterrence
    s/#\?Banner.*/Banner \/etc\/ssh\/banner/

    # Disable X11 forwarding to prevent potential security risks
    s/#\?X11Forwarding.*/X11Forwarding no/

    # Limit authentication attempts to prevent brute force (CIS benchmark)
    s/#\?MaxAuthTries.*/MaxAuthTries 3/

    # Set login grace time to 60 seconds to prevent DoS attacks
    s/#\?LoginGraceTime.*/LoginGraceTime 60/

    # Explicitly disable empty passwords
    s/#\?PermitEmptyPasswords.*/PermitEmptyPasswords no/

    # Set idle timeout to 5 minutes (300 seconds)
    s/#\?ClientAliveInterval.*/ClientAliveInterval 300/

    # Maximum number of client alive messages sent without response
    s/#\?ClientAliveCountMax.*/ClientAliveCountMax 2/
' /etc/ssh/sshd_config

# Verify config syntax
if ! sshd -t; then
    log "Error: SSH configuration is invalid"
    cp "$BACKUP_FILE" /etc/ssh/sshd_config
    log "Restored original configuration"
    exit 1
fi

# Set correct permissions
chmod 600 /etc/ssh/sshd_config
chmod 644 /etc/ssh/banner

# Restart SSH service
if ! systemctl restart sshd; then
    log "Error: Failed to restart SSH service"
    cp "$BACKUP_FILE" /etc/ssh/sshd_config
    log "Restored original configuration"
    exit 1
fi

log "SSH hardening complete. Password authentication has been disabled."
log "IMPORTANT: Verify SSH key access before disconnecting!"
log "Backup saved at: $BACKUP_FILE"

# Keep existing connection open for testing
echo "Opening new terminal session recommended for testing..."
