#! /bin/bash

# [[ if user id is not 0 ]] = true -> replace current process with script ran as root with same args
[[ $EUID -ne 0 ]] && exec sudo bash "$0" "$@"

# before any code, gotta plan it out a bit
# this script has to do the following:
# - copy files over to the fitting directories
# - create a systemd service and/or timer that will allow for timed execution of the script
# - do a guide of how this system operates
# - explain the changes that this script will do to the system
# - perhaps contain an deinstallation functionality that reverts changes

read -d '' text_introInstallation << EOT

Welcome to the install script for the Minibak backup script. 
SuperUser privileges are necessary for this script to function.
If ran as user, sudo will be invoked to provide the privileges.

This script will make the following changes to your system:

- Create an installation log in the same directory as the script itself that contains information shown during the installation
- Install rsync if not currently present on the system
- Copy the Minibak shell script to /usr/bin (/usr/bin/minibak)
- Copy the default configuration file to /etc (/etc/minibak.conf and /etc/minibak.conf.template)
- Create a systemd service and timer to allow for scheduled execution of the job


Changes that are not done by the installer but the main script:

- Save log data into /tmp then removed when no longer needed
- Save log data into /var/log by default
- Make changes to the systemd service and timer per user wish

Changes made by the installer can be reverted by invoking this script with "uninstall" argument:
./install.sh uninstall

EOT

read -d '' text_introRemoval << EOT

Welcome to the removal option of the installation script for the Minibak backup script.
Just like for the installation, SuperUser privileges are needed to proceed.
If ran as user, sudo will be invoked to provide privileged. 

Following changes to your system will be undone:

- Script </usr/bin/minibak> will be deleted
- systemd service and timer:
	- timer will be disabled and stopped
	- both files located in /etc/systemd/system/ (minibak.service and minibak.timer) will be deleted

In case rsync was present previously on the system due to it being used outside of Minibak, script won't remove it by default.
Removal of rsync and other miscellaneous files left by the scripts is in form of yes/no questions.

EOT

set -o pipefail		# this enables pipefail, which will make the exit status of a pipeline the code of whatever failed
			# without this, the exit status of whatever was last (utmost right) will be returned

if [[ -z $1 || $1 != "uninstall" ]]
	then 	# do installation
		echo "$text_introInstallation"

		if [[ $(read -r -p "Would you like to continue? (y/n) : " x; echo $x)  != "y" ]]
			then
				exit 1
		fi

		echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Installation log created" | tee -a ./install.log

		echo "" >> ./install.log
		echo "$text_introInstallation" >> ./install.log
		echo "" >> ./install.log

		echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Installing rsync" | tee -a ./install.log
		apt-get -q=2 install rsync 2>&1 | tee -a ./install.log

		echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Copying the main script into /usr/bin" | tee -a ./install.log
		if ! cp ./minibak.sh /usr/bin/minibak 2>&1 | tee -a ./install.log
			then
				echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [ERROR] Copy job failed. Exiting..." | tee -a ./install.log
				exit 1
		fi

		echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Copying the config into /etc/minibak.conf" | tee -a ./install.log
		if ! cp ./conf /etc/minibak.conf 2>&1 | tee -a ./install.log
			then
				echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [ERROR] Copy job failed. Exiting..." | tee -a ./install.log
				exit 1
		fi

		echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Adding execute permissions to the copy" | tee -a ./install.log
		chmod +x /usr/bin/minibak | tee -a ./install.log

		echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Reloading the systemd daemon" | tee -a ./install.log
		systemctl daemon-reload | tee -a ./install.log

		echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Copying the config template into /etc/minibak.conf.template" | tee -a ./install.log
		if ! cp ./conf /etc/minibak.conf.template 2>&1 | tee -a ./install.log
			then
				echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [ERROR] Copy job failed. Exiting..." | tee -a ./install.log
				exit 1
		fi

		echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Fetching data from ./conf" | tee -a ./install.log
		source ./conf

		echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Saving systemd units in /tmp/minibak" | tee -a ./install.log
		func_saveSystemdUnitsToTmp

		echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Copying the minibak.service unit from /tmp/minibak to /etc/systemd/system" | tee -a ./install.log
		if ! cp /tmp/minibak/minibak.service /etc/systemd/system/minibak.service 2>&1 | tee -a ./install.log
			then
				echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [ERROR] Copy job failed. Exiting..." | tee -a ./install.log
				exit 1
			else
				echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [SUCCESS] Copy job finished" | tee -a ./install.log
				echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Removing the temporary copy of minibak.service" | tee -a ./install.log
				if ! rm /tmp/minibak/minibak.service 2>&1 | tee -a ./install.log
					then
						echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [WARNING] Deletion of the file failed" | tee -a ./install.log
					else 
						echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [SUCCESS] Deletion of the file successful" | tee -a ./install.log
				fi
		fi

		echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Copying the minibak.timer unit from /tmp/minibak to /etc/systemd/system" | tee -a ./install.log
		if ! cp /tmp/minibak/minibak.timer /etc/systemd/system/minibak.timer 2>&1 | tee -a ./install.log
			then
				echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [ERROR] Copy job failed. Exiting..." 2>&1 | tee -a ./install.log
				exit 1
			else
				echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [SUCCESS] Copy job finished"
				echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Removing the temporary copy of minibak.timer"
				if ! rm /tmp/minibak/minibak.timer 2>&1 | tee -a ./install.log
					then
						echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [WARNING] Deletion of the file failed" | tee -a ./install.log
					else 
						echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [SUCCESS] Deletion of the file successful" | tee -a ./install.log
				fi
		fi

		if [[ bool_timerEnabled ]]
			then
				systemctl enable minibak.timer
				echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Scheduled execution has been enabled" | tee -a ./install.log
			else
				systemctl disable minibak.timer
				echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Scheduled execution has been disabled" | tee -a ./install.log
		fi

	else	# do deinstallation
		echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Deinstallation has been started" >> ./uninstall.log

		echo "" >> ./uninstall.log
		echo "$text_introRemoval" | tee -a ./uninstall.log
		echo "" >> ./uninstall.log

		if [[ $(read -r -p "Would you like to continue? (y/N) : " x; echo $x) != "y" ]]
			then
				exit 1
		fi

		bool_uninstallRsync=false
		bool_removeLogs=false
		bool_removeConfig=false
		bool_clearTmp=false

		if [[ $(read -r -p "Would you like to uninstall rsync? (y/N) : " x; echo $x) = "y" ]]
			then
				bool_uninstallRsync=true
		fi

		if [[ $(read -r -p "Would you like to delete the logs generated by minibak? (y/N) : " x; echo $x) = "y" ]]
			then
				bool_removeLogs=true
		fi

		if [[ $(read -r -p "Would you like to delete the default config and the template? (y/N) : " x; echo $x) = "y" ]]
			then
				bool_removeConfig=true
		fi

		if [[ $(read -r -p "Would you like to clear any remaning data generated from this or the minibak script in /tmp? (y/N) : " x; echo $x) = "y" ]]
			then
				bool_clearTmp=true
		fi

		if [[ -f "/usr/bin/minibak" ]]
			then
				echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Deleting /usr/bin/minibak" | tee -a ./uninstall.log
				if ! rm /usr/bin/minibak 2>&1 | tee -a ./uninstall.log
					then
						echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [WARNING] Deletion of the file failed" | tee -a ./uninstall.log
					else 
						echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [SUCCESS] Deletion of the file successful" | tee -a ./uninstall.log
				fi
			else
				echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [WARNING] File /usr/bin/minibak doesn't exit" | tee -a ./uninstall.log
		fi

		echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Probing minibak.timer unit" | tee -a ./uninstall.log
		if systemctl cat minibak.timer >/dev/null 2>&1
			then
				# unit exists 
				echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] minibak.timer exists" | tee -a ./uninstall.log

				if systemctl is-enabled minibak.timer
					then
						echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Disabling and stopping minibak.timer" | tee -a ./uninstall.log
						systemctl disable --now minibak.timer
				fi
			else
				# warning - unit doesn't exist, execution proceeds regardless
				echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [WARNING] systemd is unaware of a 'minibak.timer' unit" | tee -a ./uninstall.log
		fi

		echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Probing minibak.service unit" | tee -a ./uninstall.log
		if systemctl cat minibak.service >/dev/null 2>&1
			then
				echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] minibak.service exists" | tee -a ./uninstall.log
				echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Waiting for current job to finish" | tee -a ./uninstall.log
				while systemctl is-active minibak.service
					do 
						sleep 5
					done
				if systemctl is-enabled minibak.service
					then
						echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Disabling and stopping minibak.service" | tee -a ./uninstall.log
						systemctl disable --now minibak.service
				fi
			else
				# warning - unit doesn't exist, execution proceeds regardless
				echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [WARNING] systemd is unaware of a 'minibak.service' unit" | tee -a ./uninstall.log
		fi

		echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Probing the minibak.timer unit file" | tee -a ./uninstall.log
		if [[ -f /etc/systemd/system/minibak.timer ]]
			then 
				echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] minibak.timer file exists - deleting..." | tee -a ./uninstall.log
				if ! rm /etc/systemd/system/minibak.timer 2>&1 | tee -a ./uninstall.log
					then
						echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [WARNING] Deletion of the file failed" | tee -a ./uninstall.log
					else 
						echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [SUCCESS] Deletion of the file successful" | tee -a ./uninstall.log
				fi
			else
				# warning - doesn't exist
				echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [WARNING] minibak.timer file doesn't exist" | tee -a ./uninstall.log
		fi

		echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Probing the minibak.service unit file" | tee -a ./uninstall.log
		if [[ -f /etc/systemd/system/minibak.service ]]
			then 
				echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] minibak.service file exists - deleting..." | tee -a ./uninstall.log
				if ! rm /etc/systemd/system/minibak.service 2>&1 | tee -a ./uninstall.log
					then
						echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [WARNING] Deletion of the file failed" | tee -a ./uninstall.log
					else 
						echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [SUCCESS] Deletion of the file successful" | tee -a ./uninstall.log
				fi
			else
				# warning - doesn't exist
				echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [WARNING] minibak.service file doesn't exist" | tee -a ./uninstall.log
		fi

		echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Restarting the systemctl daemon" | tee -a ./uninstall.log
		systemctl daemon-reload
		echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Clearing unit failure codes and resetting the unit start limit counter" | tee -a ./uninstall.log
		systemctl reset-failed

		if [[ bool_uninstallRsync ]]
			then
				echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [CAUSION] Removal of rsync has been started" | tee -a ./uninstall.log
				apt-get -q=2 remove rsync 2>&1 | tee -a ./uninstall.log
		fi

		if [[ bool_removeLogs ]]
			then
				# delete logs
				echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [CAUSION] Removal of minibak logs has been started" | tee -a ./uninstall.log
				if ! rm $dir_log/minibak.log 2>&1 | tee -a ./uninstall.log
					then
						echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [WARNING] Deletion of the file failed" | tee -a ./uninstall.log
					else 
						echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [SUCCESS] Deletion of the file successful" | tee -a ./uninstall.log
				fi
		fi

		if [[ bool_removeConfig ]]
			then
				# delete default configs
				echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [CAUSION] Removal of default configuration file and template has been started" | tee -a ./uninstall.log
				if ! rm /etc/minibak.conf  2>&1 | tee -a ./uninstall.log && rm /etc/minibak.conf.template 2>&1 | tee -a ./uninstall.log
					then
						echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [WARNING] Deletion of the file failed" | tee -a ./uninstall.log
					else 
						echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [SUCCESS] Deletion of the file successful" | tee -a ./uninstall.log
				fi
		fi

		if [[ bool_clearTmp ]]
			then
				# delete /tmp/minibak dir
				echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Removal of /etc/minibak dir and its contents has been started" | tee -a ./uninstall.log
				if [[ -d /tmp/minibak ]]
					then
						if ! rm -r /tmp/minibak 2>&1 | tee -a ./uninstall.log
							then
								echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [WARNING] Deletion of the directory failed" | tee -a ./uninstall.log
							else 
								echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [SUCCESS] Deletion of the directory successful" | tee -a ./uninstall.log
						fi
					else 
						echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [WARNING] Directory doesn't exist" | tee -a ./uninstall.log
				fi
				
		fi
fi




