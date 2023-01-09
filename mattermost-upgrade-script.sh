#!/bin/bash

################################################################################################
# The following script updates the local Mattermost instance to a version entered by the user. #
# A backup of the instance will be taken.                                                      #
################################################################################################

# Define prompts and colors
function prompts () {
    case $1 in
        info)
            echo -e "\e[33m[ INFO ]\e[0m"
            ;;
        input)
            echo -e "\e[32m[ INPUT ]\e[0m"
            ;;
        error)
            echo -e "\e[31m[ ERROR ]\e[0m"
            ;;
        command)
            echo -e "\e[36m[ COMMAND ]\e[0m"
            ;;
        finish)
            echo -e "\e[92m[ COMPLETE ]\e[0m"
            ;;
    esac
}

# Initial script check
prompts info
echo -e "The following script updates the local Mattermost instance. A backup will be taken.\n"
prompts input
read -p "Do you wish to continue? (Y/N): " ans
echo

answer=${ans^^}

if [[ $answer == 'N' || $answer == 'NO' ]]; then
	prompts error
	echo -e "Stopping script..."
	exit 1
fi

# Take user input for Mattermost version
prompts info
echo -e "Please provide the Mattermost version you wish to upgrade to.\n"

prompts input
read -p "Enter Mattermost version number: " MMVERSION
echo

# Check input is correct
prompts info
echo -e "Mattermost Version: $MMVERSION\n"

prompts input
read -p "Is this correct? (Y/N): " ans
echo

answer=${ans^^}

if [[ $answer == 'N' || $answer == 'NO' ]]; then
	prompts error
	echo -e "Mattermost version entered deemed incorrect. Exiting..."
	exit 1
fi

# Check to make sure URL is up before continuing
prompts info
echo -e "Checking download URL before continuing.\n"

prompts command
echo -e "curl -I https://releases.mattermost.com/$MMVERSION/mattermost-$MMVERSION-linux-amd64.tar.gz\n"

if curl -I "https://releases.mattermost.com/$MMVERSION/mattermost-$MMVERSION-linux-amd64.tar.gz" 2>&1 | grep -q -w "200\|301" ; then
	prompts info
	echo -e "CURL: Response OKAY! Continuing upgrade...\n"
else
	prompts error
	echo -e "CURL: URL REPORTS DOWN!!! Please check Mattermost version URL and try again. Exiting upgrade..." && exit 1
fi

# Download Mattermost
prompts info
echo -e "Downloading Mattermost.\n"

prompts command
echo -e "wget https://releases.mattermost.com/$MMVERSION/mattermost-$MMVERSION-linux-amd64.tar.gz\n"
wget https://releases.mattermost.com/$MMVERSION/mattermost-$MMVERSION-linux-amd64.tar.gz

# Extract downloaded file
prompts info
echo -e "Extracting downloaded Mattermost file.\n"

prompts command
echo "tar -xf mattermost-$MMVERSION-linux-amd64.tar.gz --transform='s,^[^/]\+,\0-upgrade,'"
echo
tar -xf mattermost-$MMVERSION-linux-amd64.tar.gz --transform='s,^[^/]\+,\0-upgrade,'

# Remove downloaded file
prompts info
echo -e "Removing downloaded Mattermost file.\n"

prompts command
echo "rm mattermost-$MMVERSION-linux-amd64.tar.gz"
rm mattermost-$MMVERSION-linux-amd64.tar.gz

# Stop Mattermost service via SystemCTL
prompts info
echo -e "Processing upgrade of Mattermost. Mattermost service going down.\n"

prompts command
echo -e "sudo systemctl stop mattermost\n"
sudo systemctl stop mattermost

# Backup data and application
prompts info
echo -e "Backing up Mattermost data and application.\n"

prompts command
echo -e "cd /opt/ && sudo cp -ra mattermost/ mattermost-back-$(date +'%F-%H-%M')/\n"
cd /opt/ && sudo cp -ra mattermost/ mattermost-back-$(date +'%F-%H-%M')/

# Remove all files except special directories in the current Mattermost directory
prompts info
echo -e "Removing all files except special directories in the current Mattermost directory.\n"

prompts command
echo "sudo find mattermost/ mattermost/client/ -mindepth 1 -maxdepth 1 \! \( -type d \( -path mattermost/client -o -path mattermost/client/plugins -o -path mattermost/config -o -path mattermost/logs -o -path mattermost/plugins -o -path mattermost/data \) -prune \) | sort | sudo xargs rm -r"
echo
sudo find mattermost/ mattermost/client/ -mindepth 1 -maxdepth 1 \! \( -type d \( -path mattermost/client -o -path mattermost/client/plugins -o -path mattermost/config -o -path mattermost/logs -o -path mattermost/plugins -o -path mattermost/data \) -prune \) | sort | sudo xargs rm -r

# Rename the plugins directory as to not interfere with the new installation
prompts info
echo -e "Renaming the plugins directory as to not interfere with the new installation.\n"

prompts command
echo -e "sudo mv mattermost/plugins/ mattermost/plugins~ && sudo mv mattermost/client/plugins/ mattermost/client/plugins~\n"
sudo mv mattermost/plugins/ mattermost/plugins~ && sudo mv mattermost/client/plugins/ mattermost/client/plugins~

# Change ownership of new Mattermost files to Mattermost user
prompts info
echo -e "Changing ownership of new Mattermost files to Mattermost user.\n"

prompts command
echo -e "sudo chown -hR mattermost:mattermost ~/mattermost-upgrade/\n"
sudo chown -hR mattermost:mattermost ~/mattermost-upgrade/

# Copy new files to installation directory and remove temporary files
prompts info
echo -e "Copy new files to installation directory and remove temporary files.\n"

prompts command
echo -e "sudo cp -an ~/mattermost-upgrade/. mattermost/"
echo -e "sudo rm -r ~/mattermost-upgrade/\n"
sudo cp -an ~/mattermost-upgrade/. mattermost/
sudo rm -r ~/mattermost-upgrade/

# Active CAP_NET_BIND_SERVICE to allow Mattermost to bind to low ports - uncomment the below commands if the Mattermost instance is serving web requests
#prompts info
#echo -e "Activating CAP_NET_BIND_SERVICE.\n"

#prompts command
#echo -e "cd /opt/mattermost && sudo setcap cap_net_bind_service=+ep ./bin/mattermost\n"
#cd /opt/mattermost && sudo setcap cap_net_bind_service=+ep ./bin/mattermost

# Reinstate plugins directories
prompts info
echo -e "Reinstating plugins directories.\n"

prompts command
echo -e "cd /opt/mattermost && sudo rsync -au plugins~/ plugins && sudo rm -rf plugins~ && sudo rsync -au client/plugins~/ client/plugins && sudo rm -rf client/plugins~\n"
cd /opt/mattermost && sudo rsync -au plugins~/ plugins && sudo rm -rf plugins~ && sudo rsync -au client/plugins~/ client/plugins && sudo rm -rf client/plugins~

# Start Mattermost service via SystemCTL
prompts info
echo -e "Starting Mattermost service.\n"

prompts command
echo -e "sudo systemctl start mattermost\n"
sudo systemctl start mattermost

# Upgrade complete
prompts complete
echo -e "Upgrade complete!\n"
echo -e "Please check your Mattermost instance for version: $MMVERSION."
