#!/bin/bash

################################################################################################
# The following script updates the local Mattermost instance to the newest version via cron.   #
# A backup of the instance will be taken.                                                      #
################################################################################################

# Establsh deployed Mattermost version via mmctl
deployedVersion=$(/opt/mattermost/bin/mattermost version | grep -w "Version:" | awk '{print $2}' | tr -d 'v')

# Establish latest Mattermost version via GitHub URL
latestVersion=$(curl -s https://github.com/mattermost/mattermost-server/releases | grep 'mattermost-server/releases/tag' | awk '{print $7}' | cut -d/ -f6 | tr -d '"' | sort -rV | uniq | head -1 | tr -d 'v')

# Echo out versions for logging
echo -e "Date/Time:" $(date)
echo -e "Deployed Mattermost version: $deployedVersion"
echo -e "Latest Mattermost version: $latestVersion"

# Establish date/time variable
date=$(date +'%F-%H-%M')

# Establish database variables from Mattermost config.json
DATABASE=$(cat /opt/mattermost/config/config.json | jq --raw-output '.SqlSettings.DriverName')
DB_USER=$(cat /opt/mattermost/config/config.json | jq --raw-output '.SqlSettings.DataSource' | cut -d: -f2 | tr -d '/')
DB_PASS=$(cat /opt/mattermost/config/config.json | jq --raw-output '.SqlSettings.DataSource' | cut -d: -f3 | cut -d@ -f1)

# Define version function
function version { echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'; }

# Define database backup function
function dbbackup () {
    if [[ $DATABASE == "mysql" ]]; then
        echo -e "Database is MySQL. Conducting database backup..."
        mysqldump -u $DB_USER -p $DB_PASS mattermost > /opt/mattermost-back-$date/database-backup-$date.sql
        echo -e "Database backup complete."
    elif [[ $DATABASE == "postgres" ]]; then
        echo -e "Database is PostgreSQL. Conducting database backup..."
        su postgres -c "pg_dump -U $DB_USER mattermost > /var/lib/postgresql/dump/mattermost-back-$date.sql"
        echo -e "Removing old PostgreSQL backup..."
        rm -rf /var/lib/postgresql/dump/$(ls /var/lib/postgresql/dump/ | grep 'mattermost-back' | sort | head -1)
        echo -e "Database backup complete."
    else
        echo -e "Unable to determine database type. A backup will not be conducted."
    fi
}

# Define upgrade function
function upgrade () {
    if curl -I "https://releases.mattermost.com/$latestVersion/mattermost-$latestVersion-linux-amd64.tar.gz" 2>&1 | grep -q -w "200\|301" ; then
        echo -e "CURL: Response OKAY! Continuing upgrade..."
    else
        echo -e "CURL: URL REPORTS DOWN!!! Please check Mattermost version URL and try again. Exiting upgrade..." && exit 1
    fi
    wget https://releases.mattermost.com/$latestVersion/mattermost-$latestVersion-linux-amd64.tar.gz -P /tmp/
    cd /tmp/ && tar -xf mattermost-$latestVersion-linux-amd64.tar.gz --transform='s,^[^/]\+,\0-upgrade,'
    rm /tmp/mattermost-$latestVersion-linux-amd64.tar.gz
    systemctl stop mattermost
    dbbackup
    cp -ra /opt/mattermost/ /opt/mattermost-back-$date/
    find /opt/mattermost/ /opt/mattermost/client/ -mindepth 1 -maxdepth 1 \! \( -type d \( -path /opt/mattermost/client -o -path /opt/mattermost/client/plugins -o -path /opt/mattermost/config -o -path /opt/mattermost/logs -o -path /opt/mattermost/plugins -o -path /opt/mattermost/data \) -prune \) | sort | sudo xargs rm -r
    mv /opt/mattermost/plugins/ /opt/mattermost/plugins~ && mv /opt/mattermost/client/plugins/ /opt/mattermost/client/plugins~
    chown -hR mattermost:mattermost /tmp/mattermost-upgrade/
    cp -an /tmp/mattermost-upgrade/. /opt/mattermost/
    rm -r /tmp/mattermost-upgrade/
    # Active CAP_NET_BIND_SERVICE to allow Mattermost to bind to low ports - uncomment the below commands if the Mattermost instance is serving web requests
    #cd /opt/mattermost && setcap cap_net_bind_service=+ep ./bin/mattermost
    cd /opt/mattermost && rsync -au plugins~/ plugins && rm -rf plugins~ && rsync -au client/plugins~/ client/plugins && rm -rf client/plugins~
    systemctl start mattermost
    echo -e "Removing old Mattermost backup..."
    rm -rf /opt/$(ls /opt/ | grep 'mattermost-back' | sort | head -1)
    if [[ -n $MM_TEAM && -n $MM_CHANNEL ]]; then
        sleep 300
        echo -e "Mattermost team and channel variables are set. Posting notification..."
        /opt/mattermost/bin/mmctl post create $MM_TEAM:$MM_CHANNEL --message "@all The Mattermost instance has been upgraded to $latestVersion. Please report any issues to the System Administration channel."
    fi
    echo -e "Upgrade complete."
}

# Compare versions
if [[ $(version $deployedVersion) -lt $(version $latestVersion) ]]; then
    echo -e "Deployed Mattermost version is behind latest. Conducting upgrade..."
    upgrade
    exit 0
elif [[ $(version $deployedVersion) -gt $(version $latestVersion) ]]; then
    echo -e "Deployed Mattermost version is ahead of latest. Exiting..."
    exit 0
elif [[ $(version $deployedVersion) -eq $(version $latestVersion) ]]; then
    echo -e "Deployed Mattermost version matches latest. Exiting..."
    exit 0
else
    echo -e "Unable to compare Mattermost versions. Exiting..."
    exit 1
fi
