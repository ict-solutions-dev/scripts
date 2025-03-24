## APT preference

Create the preferences file using sudo:

```console
mkdir -p /etc/apt/preferences.d
```

Create and edit the docker-pin file:

```console
nano /etc/apt/preferences.d/docker-pin
```

Copy and paste this content into the file:

```console
Package: docker-ce*
Pin: release *
Pin-Priority: -1

Package: docker-compose*
Pin: release *
Pin-Priority: -1

Package: containerd.io
Pin: release *
Pin-Priority: -1
```

## Script

Create `auto-update.sh` script and paste content from folder here:

```console
nano /usr/local/sbin/auto-update.sh
```

Before using this script:

* Create a Telegram bot using BotFather and get your bot token
* Get your chat ID (you can use @getidsbot on Telegram)
* Replace YOUR_BOT_TOKEN with your actual bot token
* Replace YOUR_CHAT_ID with your actual chat ID

The script will:

* Check for kernel updates
* Check for Docker version updates
* Send Telegram notifications if:
    * A new kernel version is available (requiring a reboot)
    * A new Docker version is available (requiring manual update)
* Perform regular system updates excluding Docker (as per the pin configuration)

The notifications will include:

* The hostname of the server
* Current and available versions
* Required action (reboot or manual update)

You can test the Telegram notification by running:

```console
/usr/local/sbin/auto-update.sh
```

## Systemd

Create a systemd service and timer for automatic updates:

```console
[Unit]
Description=Automatic System Updates (excluding Docker)
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/auto-update.sh

[Install]
WantedBy=multi-user.target

[Unit]
Description=Timer for Automatic System Updates

[Timer]
OnCalendar=daily
RandomizedDelaySec=3600
Persistent=true

[Install]
WantedBy=timers.target
```

Enable and start the timer:

```console
systemctl daemon-reload
systemctl enable auto-update.timer
systemctl start auto-update.timer
```

Make the script executable:

```console
chmod +x /usr/local/sbin/auto-update.sh
```

This setup will:

* Run system updates daily at a random time
* Exclude all Docker-related packages from automatic updates
* Keep Docker services running without unexpected restarts
* Allow you to manually update Docker when needed using:

```console
apt install docker-ce docker-ce-cli containerd.io docker-compose-plugin
```

To check the timer status:

```console
systemctl status auto-update.timer
```

To check when the next update will run:

```console
systemctl list-timers auto-update.timer
```
