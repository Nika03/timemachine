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

# pipefail is on for the whole script, so a pipe into tee reports the failure of the command before it, not of tee
set -o pipefail		# this enables pipefail, which will make the exit status of a pipeline the code of whatever failed
			# without this, the exit status of whatever was last (utmost right) will be returned

# arg1 decides what happens: "uninstall" -> removal, anything else (or nothing) -> installation
if [[ -z $1 || $1 != "uninstall" ]]
	then 	# do installation
		echo "$text_introInstallation"

		# read inside $( ) so the answer ends up in the comparison, anything but a literal "y" aborts
		if [[ $(read -r -p "Would you like to continue? (y/n) : " x; echo $x)  != "y" ]]
			then
				exit 1
		fi

		# everything the user sees from here on also goes into ./install.log
		echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Installation log created" | tee -a ./install.log

		echo "" >> ./install.log
		echo "$text_introInstallation" >> ./install.log
		echo "" >> ./install.log

		echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Installing rsync" | tee -a ./install.log
		# rsync is the only dependency, apt skips it by itself when it's already there
		apt-get -y -q=2 install rsync 2>&1 | tee -a ./install.log

		echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Copying the main script into /usr/bin" | tee -a ./install.log
		# copy the main script into its place, if cp fails there's no point in going on
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
		# cp keeps the permissions of the source, so just make sure it's executable
		chmod +x /usr/bin/minibak | tee -a ./install.log

		echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Copying the config template into /etc/minibak.conf.template" | tee -a ./install.log
		# the template stays untouched, so the user can always go back to the defaults
		if ! cp ./conf /etc/minibak.conf.template 2>&1 | tee -a ./install.log
			then
				echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [ERROR] Copy job failed. Exiting..." | tee -a ./install.log
				exit 1
		fi

		echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Changing mode for config files to 644" | tee -a ./install.log
		chmod 644 /etc/minibak.conf /etc/minibak.conf.template

		echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Fetching data from ./conf" | tee -a ./install.log
		# import the values (and the unit generating function) from the config that has just been copied
		source ./conf

		echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Saving systemd units in /tmp/minibak" | tee -a ./install.log
		# this writes minibak.service and minibak.timer into /tmp/minibak
		func_saveSystemdUnitsToTmp

		echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Copying the minibak.service unit from /tmp/minibak to /etc/systemd/system" | tee -a ./install.log
		# units are generated in /tmp first, then moved into /etc/systemd/system (same way as -x in minibak does it)
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
				echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [SUCCESS] Copy job finished" 2>&1 | tee -a ./install.log
				echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Removing the temporary copy of minibak.timer" 2>&1 | tee -a ./install.log
				if ! rm /tmp/minibak/minibak.timer 2>&1 | tee -a ./install.log
					then
						echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [WARNING] Deletion of the file failed" | tee -a ./install.log
					else 
						echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [SUCCESS] Deletion of the file successful" | tee -a ./install.log
				fi
		fi

		echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Reloading the systemd daemon" | tee -a ./install.log
		# systemd has to learn about the new unit files before they can be enabled
		systemctl daemon-reload | tee -a ./install.log

		# bool_timerEnabled comes from the config - enabled = timer starts on boot, disabled = only manual runs
		if [[ $bool_timerEnabled == true ]]
			then
				systemctl enable --now minibak.timer
				echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Scheduled execution has been enabled" | tee -a ./install.log
			else
				systemctl disable --now minibak.timer
				echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Scheduled execution has been disabled" | tee -a ./install.log
		fi

# ---- everything below is the removal ----
	else	# do deinstallation
		echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Deinstallation has been started" >> ./uninstall.log

		echo "" >> ./uninstall.log
		echo "$text_introRemoval" | tee -a ./uninstall.log
		# nothing is deleted before the user confirmed, the questions below are for the optional leftovers
		echo "" >> ./uninstall.log

		if [[ $(read -r -p "Would you like to continue? (y/N) : " x; echo $x) != "y" ]]
			then
				exit 1
		fi

		# everything is "no" by default, a question only flips its variable to true
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

		# the script itself goes first
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

		# timer goes before the service, otherwise it could just start a new job while this is running
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

		# if a backup is running right now, wait for it so it doesn't get killed in the middle
		echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Probing minibak.service unit" | tee -a ./uninstall.log
		if systemctl cat minibak.service >/dev/null 2>&1
			then
				echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] minibak.service exists" | tee -a ./uninstall.log
				echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Waiting for current job to finish" | tee -a ./uninstall.log
				while [[ $(systemctl is-active minibak.service) == "active" || $(systemctl is-active minibak.service) == "activating" ]]
					do 
						sleep 5
					done
				if systemctl is-enabled minibak.service
					then
						echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Stopping minibak.service" | tee -a ./uninstall.log
						systemctl stop minibak.service
				fi
			else
				# warning - unit doesn't exist, execution proceeds regardless
				echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [WARNING] systemd is unaware of a 'minibak.service' unit" | tee -a ./uninstall.log
		fi

		# unit files can only be deleted after systemd stopped using them (above)
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

		# tell systemd that the unit files are gone
		echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Restarting the systemctl daemon" | tee -a ./uninstall.log
		systemctl daemon-reload
		echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Clearing unit failure codes and resetting the unit start limit counter" | tee -a ./uninstall.log
		systemctl reset-failed

		# optional leftovers - only if the user said yes earlier
		if [[ $bool_uninstallRsync == true ]]
			then
				echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [CAUSION] Removal of rsync has been started" | tee -a ./uninstall.log
				apt-get -y -q=2 remove rsync 2>&1 | tee -a ./uninstall.log
		fi

		if [[ $bool_removeLogs == true ]]
			then
				# delete default logs
				if [[ -f /var/log/minibak.log ]]
					then 
						echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [CAUSION] Removal of minibak logs has been started" | tee -a ./uninstall.log
						if ! rm /var/log/minibak.log 2>&1 | tee -a ./uninstall.log
							then
								echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [WARNING] Deletion of the file failed" | tee -a ./uninstall.log
							else 
								echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [SUCCESS] Deletion of the file successful" | tee -a ./uninstall.log
						fi
					else
						echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [Warning] Log file does not exist" | tee -a ./uninstall.log
				fi
		fi

		if [[ $bool_removeConfig == true ]]
			then
				# delete default configs
				echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [CAUSION] Removal of default configuration file has been started" | tee -a ./uninstall.log
				# both files have to be there, otherwise there's nothing consistent to delete
				if [[ -f /etc/minibak.conf && -f /etc/minibak.conf.template ]]
					then
						if ! rm /etc/minibak.conf  2>&1 | tee -a ./uninstall.log
							then
								echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [WARNING] Deletion of the file failed" | tee -a ./uninstall.log
							else 
								echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [SUCCESS] Deletion of the file successful" | tee -a ./uninstall.log
						fi
						echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [CAUSION] Removal of template has been started" | tee -a ./uninstall.log
						if ! rm /etc/minibak.conf.template 2>&1 | tee -a ./uninstall.log
							then
								echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [WARNING] Deletion of the file failed" | tee -a ./uninstall.log
							else 
								echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [SUCCESS] Deletion of the file successful" | tee -a ./uninstall.log
						fi
				fi
		fi

		if [[ $bool_clearTmp == true ]]
			then
				# delete /tmp/minibak dir
				echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Removal of /tmp/minibak dir and its contents has been started" | tee -a ./uninstall.log
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




