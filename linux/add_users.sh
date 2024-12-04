#!/bin/bash

# Load password from .env file
if [ ! -f .env ]; then
  echo ".env file not found!"
  exit 1
fi

source .env

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

for username in "${users[@]}"; do
  # Check if user already exists
  if id "$username" &>/dev/null; then
    echo "User $username already exists. Skipping..."
    continue
  fi

  # Add user
  adduser --disabled-password --gecos "" "$username"

  # Set password
  echo "$username:$(printf '%q' "$PASSWORD")" | chpasswd

  # Add user to sudo group
  usermod -aG sudo "$username"

  # Expire password
  passwd --expire "$username"
done

# Remove .env and .users.csv files
rm .env .users.csv

echo "Users added and configured successfully."
