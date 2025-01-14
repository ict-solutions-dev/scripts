#!/bin/bash

# Version
VERSION="1.0"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Emojis
ROCKET="🚀"
CHECK="✅"
WARNING="⚠️"
INFO="ℹ️"
ERROR="❌"
USER="👤"
GROUP="👥"

# Counters
users_added=0
users_existed=0
groups_added=0

# Define required groups
REQUIRED_GROUPS=("sudo")
if command -v docker &>/dev/null; then
    REQUIRED_GROUPS+=("docker")
fi

# Load password from .env file
if [ ! -f .env ]; then
  echo ".env file not found!"
  exit 1
fi

# Source the .env file
export $(grep -v '^#' .env | xargs)

if [ -z "$PASSWORD" ]; then
  echo "PASSWORD not set in .env file!"
  exit 1
fi

# Load users from .users.csv file
if [ ! -f .users.csv ]; then
  echo ".users.csv file not found!"
  exit 1
fi

users=()
while IFS=, read -r username; do
  users+=("$username")
done < .users.csv

# Print header
echo -e "\n${BLUE}═══════════════════════════════════════════${NC}"
echo -e "${BLUE}${ROCKET} User Management Script v${VERSION}${NC}"
echo -e "${BLUE}═══════════════════════════════════════════${NC}"
echo -e "Started: ${TIMESTAMP}\n"

# Process users from .users.csv
for username in "${users[@]}"; do
    echo -e "${BLUE}┌─── Processing User ───────────────────┐${NC}"
    echo -e "${BLUE}│${NC} ${USER} ${username}"
    echo -e "${BLUE}├────────────────────────────────────────┤${NC}"

    # Check if user exists
    if ! id "$username" &>/dev/null; then
        echo -e "${BLUE}│${NC} ${GREEN}${ROCKET} Status: Created new user${NC}"
        adduser --disabled-password --gecos "" "$username"
        echo "$username:$PASSWORD" | chpasswd
        passwd --expire "$username"
        ((users_added++))
    else
        echo -e "${BLUE}│${NC} ${BLUE}${INFO} Status: Existing user${NC}"
        ((users_existed++))
    fi

    # Manage group memberships
    for group in "${REQUIRED_GROUPS[@]}"; do
        if ! groups "$username" | grep -q "\b${group}\b"; then
            usermod -aG "$group" "$username"
            echo -e "${BLUE}│${NC} ${GREEN}${CHECK} Added to group: ${group}${NC}"
            ((groups_added++))
        else
            echo -e "${BLUE}│${NC} ${YELLOW}${WARNING} Already in group: ${group}${NC}"
        fi
    done
    echo -e "${BLUE}└────────────────────────────────────────┘${NC}\n"
done

# Get list of existing users with UID 1000 or more
existing_users=$(awk -F: '$3 >= 1000 {print $1}' /etc/passwd)

# User cleanup section
echo -e "${BLUE}┌─── User Cleanup ────────────────────────┐${NC}"
for existing_user in $existing_users; do
    if [[ "$existing_user" == "nobody" ]]; then
        echo -e "${BLUE}│${NC} ${YELLOW}${WARNING} Skipping system user: ${existing_user}${NC}"
        continue
    fi

    if [[ ! " ${users[@]} " =~ " ${existing_user} " ]]; then
        if pgrep -u "$existing_user" > /dev/null; then
            echo -e "${BLUE}│${NC} ${RED}${ERROR} Active user (skipped): ${existing_user}${NC}"
            continue
        fi
        echo -e "${BLUE}│${NC} ${RED}${ERROR} Removed user: ${existing_user}${NC}"
        userdel -r "$existing_user"
    fi
done
echo -e "${BLUE}└────────────────────────────────────────┘${NC}\n"

# Summary box with padding
echo -e "${BLUE}╔═══════════════════ Summary ═══════════════════╗${NC}"
printf "${BLUE}║${NC} %-44s ${BLUE}║${NC}\n" "${GREEN}${CHECK} New users added:    ${users_added}"
printf "${BLUE}║${NC} %-44s ${BLUE}║${NC}\n" "${BLUE}${INFO} Existing users:     ${users_existed}"
printf "${BLUE}║${NC} %-44s ${BLUE}║${NC}\n" "${GREEN}${GROUP} Groups modified:    ${groups_added}"
echo -e "${BLUE}╚═══════════════════════════════════════════════╝${NC}\n"

# Cleanup
rm .env .users.csv

echo -e "${GREEN}${ROCKET} Operation completed successfully!${NC}\n"
