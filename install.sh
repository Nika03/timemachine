#! /bin/bash

# before any code, gotta plan it out a bit
# this script has to do the following:
# - copy files over to the fitting directories
# - create a systemd service and/or timer that will allow for timed execution of the script
# - do a guide of how this system operates
# - explain the changes that this script will do to the system
# - perhaps contain an deinstallation functionality that reverts changes

read -d '' text_intro << EOT

Welcome to the install script for the Minibak backup script.
This script will make the following changes to your system:

- Create an installation log in the same directory as the script itself that contains information shown during the installation
- Performs "apt-get update" and "apt-get upgrade" to make sure that the system is up to date
- Install rsync if not currently present on the system
- Copy the Minibak shell script to /usr/bin (/usr/bin/minibak)
- Copy the default configuration file to /etc (/etc/minibak.conf and /etc/minibak.conf.template)
- Create a systemd service and timer to allow for scheduled execution of the job


Changes that are not done by the installer but the main script:

- Save log data into /tmp then removed when no longer needed
- Save log data into /var/log by default
- Make changes to the systemd service and timer per user wish

EOT

set -e

echo $text_intro

if [[ $(read -r -p "Would you like to continue? (y/n)") != "y" ]]
	then
		exit 1
fi

echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Installation log created" | tee -a ./install.log

echo "" >> ./install.log
echo "$text_intro" >> ./install.log
echo "" >> ./install.log

echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Performing <apt-get update>" | tee -a ./install.log
apt-get -q=2 update 2>&1 | tee -a ./install.log

echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Performing <apt-get upgrade>" | tee -a ./install.log
apt-get -q=2 upgrade 2>&1 | tee -a ./install.log

echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Installing rsync" | tee -a ./install.log
apt-get -q=2 install rsync 2>&1 | tee -a ./install.log

echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Copying the main script into /usr/bin" | tee -a ./install.log
cp ./minibak.sh /usr/bin/minibak 2>&1 | tee -a ./install.log
if [[ $? -ne 0 ]]
	then
		echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [ERROR] Copy job failed. Exiting..." | tee -a ./install.log
		exit 1
fi


