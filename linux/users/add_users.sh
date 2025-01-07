#!/bin/bash

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

# Add users from .users.csv
for username in "${users[@]}"; do
  # Check if user already exists
  if id "$username" &>/dev/null; then
    echo "User $username already exists. Skipping..."
    continue
  fi

  # Add user
  adduser --disabled-password --gecos "" "$username"

  # Set password
  echo "$username:$PASSWORD" | chpasswd

  # Add user to sudo group
  usermod -aG sudo "$username"

  # Expire password
  passwd --expire "$username"
done

# Get list of existing users with UID 1000 or more
existing_users=$(awk -F: '$3 >= 1000 {print $1}' /etc/passwd)

# Delete users not in .users.csv
for existing_user in $existing_users; do
  # Skip system users like 'nobody'
  if [[ "$existing_user" == "nobody" ]]; then
    echo "Skipping system user $existing_user..."
    continue
  fi

  if [[ ! " ${users[@]} " =~ " ${existing_user} " ]]; then
    # Check if the user has running processes
    if pgrep -u "$existing_user" > /dev/null; then
      echo "User $existing_user has running processes. Skipping deletion..."
      continue
    fi

    echo "Deleting user $existing_user..."
    userdel -r "$existing_user"
  fi
done

# Remove .env and .users.csv files
rm .env .users.csv

echo "Users added and configured successfully."