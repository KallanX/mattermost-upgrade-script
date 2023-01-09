# Mattermost Upgrade Script (BASH)

The mattermost-upgrade-script.sh is used to update a Mattermost instance to a specified version.

## Supported Features

As of right now, the script only works on the machine for which the Mattermost instance is running. User will need to manually enter in the version of Mattermost they wish to download and install. Script requires root permissions. 

## How to Run

    git clone https://github.com/KallanX/mattermost-upgrade-script.git
    cd mattermost-upgrade-script
    chmod +x mattermost-upgrade-script.sh
    ./mattermost-upgrade-script.sh

## Future Enhancements

- Built-in support to update remote Mattermost systems.

- Additional options support to adhere to various deployment setups.

## Notes on Cron Script

The cron script should be fully automated. Requires the ROOT account to function. Script also assumes the 'mmctl' location is '/opt/mattermost/bin'. It is also recommened to save the output from the script to a custom log file as shown in the example.

Root Crontab Example:

```bash
crontab -l

0       4       *       *       1       /home/<USER>/cron-mm-upgrade-script.sh > /var/log/mm-upgrade.log
```
