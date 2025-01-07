# add_users

This script automates the process of adding users to a Linux system, setting their passwords, adding them to the sudo group, and expiring their passwords to force a change on first login.

## Prerequisites

- Bash shell
- `adduser` command
- `chpasswd` command
- `usermod` command
- `passwd` command

## Required Files

- `.env`: A file containing the `PASSWORD` variable.
- `.users.csv`: A CSV file containing the usernames to be added.

## How to Clone and Use

1. Clone the repository to a temporary directory:
    ```sh
    git clone https://github.com/ict-solutions-dev/scripts.git /tmp/scripts
    cd /tmp/scripts/linux/
    ```

2. Create a `.env` file with the following content:
    ```sh
    echo "PASSWORD=your_password_here" > .env
    ```

3. Create a `.users.csv` file with the usernames, one per line:
    ```sh
    echo -e "user1\nuser2\nuser3" > .users.csv
    ```

4. Run the script:
    ```sh
    ./add_users.sh
    ```

The script will add the users, set their passwords, add them to the sudo group, expire their passwords, and then remove the `.env` and `.users.csv` files.

## Notes

- Ensure you have the necessary permissions to add users and modify their settings.
- The script will remove the `.env` and `.users.csv` files after execution for security reasons.
