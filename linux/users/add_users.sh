#!/bin/bash

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

# Process users from .users.csv
for username in "${users[@]}"; do
    # Check if user exists
    if ! id "$username" &>/dev/null; then
        echo -e "${GREEN}${ROCKET} Creating new user ${USER} ${username}...${NC}"
        adduser --disabled-password --gecos "" "$username"
        echo "$username:$PASSWORD" | chpasswd
        passwd --expire "$username"
        ((users_added++))
    else
        echo -e "${BLUE}${INFO} User ${USER} ${username} exists${NC}"
        ((users_existed++))
    fi

    # Manage group memberships
    for group in "${REQUIRED_GROUPS[@]}"; do
        if ! groups "$username" | grep -q "\b${group}\b"; then
            usermod -aG "$group" "$username"
            echo -e "${GREEN}${CHECK} Added ${USER} ${username} to ${GROUP} ${group} group${NC}"
            ((groups_added++))
        else
            echo -e "${YELLOW}${WARNING} User ${username} already in group ${group}${NC}"
        fi
    done
done

# Get list of existing users with UID 1000 or more
existing_users=$(awk -F: '$3 >= 1000 {print $1}' /etc/passwd)

# Delete users not in .users.csv
for existing_user in $existing_users; do
    if [[ "$existing_user" == "nobody" ]]; then
        echo -e "${YELLOW}${WARNING} Skipping system user ${existing_user}...${NC}"
        continue
    fi

    if [[ ! " ${users[@]} " =~ " ${existing_user} " ]]; then
        if pgrep -u "$existing_user" > /dev/null; then
            echo -e "${RED}${ERROR} User ${existing_user} has running processes. Skipping deletion...${NC}"
            continue
        fi
        echo -e "${RED}${ERROR} Deleting user ${existing_user}...${NC}"
        userdel -r "$existing_user"
    fi
done

# Summary
echo -e "\n${BLUE}${ROCKET} Summary:${NC}"
echo -e "${GREEN}${CHECK} New users added: ${users_added}${NC}"
echo -e "${BLUE}${INFO} Existing users: ${users_existed}${NC}"
echo -e "${GREEN}${GROUP} Group additions: ${groups_added}${NC}"

# Remove .env and .users.csv files
rm .env .users.csv

echo -e "\n${GREEN}${ROCKET} Users added and configured successfully!${NC}"
