# Azure Blob Storage Download Script

This script automates the process of downloading blobs from an Azure Storage container to a local directory. It checks if the blobs have changed since the last download and only downloads the updated blobs.

## Prerequisites

- Azure CLI installed
- Bash shell
- `.env` file with the required environment variables

## Required Environment Variables

- `ACCOUNT_NAME`: The name of your Azure Storage account.
- `SOURCE_CONTAINER`: The name of the source container in Azure Storage.
- `DESTINATION_PATH`: The local path where you want to download the blobs (defaults to the current directory).
- `SAS_TOKEN`: The SAS token for accessing the Azure Storage container.

## How to Use

1. Clone the repository to a local directory:
    ```sh
    git clone --depth 1 --filter=blob:none --sparse https://github.com/ict-solutions-dev/scripts.git backups
    cd backups
    git sparse-checkout set azure/storage/blob
    mv azure/storage/blob/* .
    rm -rf azure
    ```

2. Create a `.env` file with the following content:
    ```sh
    echo "ACCOUNT_NAME=your_account_name" > .env
    echo "SOURCE_CONTAINER=your_source_container" >> .env
    echo "DESTINATION_PATH=" >> .env
    echo "SAS_TOKEN=your_sas_token" >> .env
    ```

3. Update the `.env` file with your actual account name, source container, destination path, and SAS token.

4. Run the script:
    ```sh
    ./download.sh
    ```

The script will download the blobs from the specified Azure Storage container to the local directory, only downloading blobs that have changed since the last download.

## Setting Up a Cron Job

To automate the download process, you can set up a cron job to run the `download.sh` script at a specified schedule.

1. Run the script:
    ```sh
    ./setup_cron.sh
    ```

2. The script will prompt you to enter a custom cron schedule or use the default schedule (every day at 01:00). Enter your desired schedule or press Enter to use the default.

The cron job will be added to your crontab and will run the `download.sh` script at the specified schedule.

## Notes

- Ensure you have the necessary permissions to access the Azure Storage container.
- The script will install the Azure CLI if it is not already installed.
- The `DESTINATION_PATH` defaults to the current directory if not specified.
