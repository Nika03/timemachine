#! /bin/bash

# begin code section where the vars with initial data are declared

	dir_src=""				# source data to backup
	dir_dest=""				# destination where the data will be backed up
	bool_verboseMode=0			# talk to me baby
	bool_schedulerEnabled=0			# enable/disable scheduled execs
	dir_log="/var/log"			# default directory for log files
	dir_defaultConfig="/etc"		# default config dir
	# todo - an array that stores hours of the day when a scheduled exec should happen

# end code section with vars containing init data


# begin code section that declares vars containing user facing information

read -d '' text_help << EOT

Usage: $0 [ options ]

Either -s and -d, or just -c are required for the execution, as they provide the directory
needed for this script to backup.

Options:
-s <dir>	Source directory to be backed up
-d <dir>	Destination directory where the data will be saved
-v		Verbose; Debug messages of what's being done
-h		Show this help message
-h config	Show help for configuration file syntax
-c <file>	Location to a config file
-c default	Execute with the default config (located at /etc/minibak.conf)
 
EOT

read -d '' text_configHelp << EOT

Configuration file is the alternative to the options of the script.
Default configuration file is located at /etc/minibak.conf
It is recommended to make a copy of minibak.conf in another directory, and use that copy for changes.

Variables:
dir_src=<dir>			Source directory to be backed up, same as -s
dir_dest=<dir>			Destination directory where the data from source (dir_src) will be saved, same as -d
bool_schedulerEnabled=<0 or 1>	Enable/Disable scheduled backup of source (dir_src) files
dir_log=<dir>			Directory where the logs will be saved. By default, it's /var/log
 
EOT

read -d '' text_configErrorInfo << EOT
Please insert the location of a valid configuration file, for example <-c ~/my-minibak-config.conf>
or use <-c default> to use the default file $defaultConfig/minibak.conf
EOT

# end code section with vars for user facing information


# begin code section containing logic

echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] $0 started" >> /tmp/minibak.log

# option handler along with arguments for options
while getopts ":s:d:vh:c:" flag; do
	#echo "flag -$flag, arg $OPTARG";
	case $flag in
		s) dir_src=$OPTARG ;;
		d) dir_dest=$OPTARG ;;
		v) bool_verboseMode=1 ;;
		h) if [[ $OPTARG = "config" ]]	# if arg is invalid or empty, it will jump to \?) which has the help text
			then
				echo "$text_configHelp" >&2
				exit 0
			fi ;;
		c) echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Option -c has been called" >> /tmp/minibak.log
			if [[ $OPTARG = "default" ]]
				then
					# if arg is set to "default"
					echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Arg $OPTARG set for option -c" >> /tmp/minibak.log
					echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Fetching default config from $defaultConfig/minibak.conf" >> /tmp/minibak.log
					if [[ -f "$defaultConfig/minibak.conf" ]]
						then
							# if default config exists, import values for vars from it
							source $defaultConfig/minibak.conf

							if [[ -d $dir_log ]]
								then
									cat /tmp/minibak.log >> $dir_log/minibak.log
									rm /tmp/minibak.log
								else
									echo "Warning: Set log directory doesn't exist, setting the log directory to /var/log"
									echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [WARNING] Provided log directory doesn't exist, dir_log will be set to /var/log" >> /tmp/minibak.log
									dir_log="/var/log"
									cat /tmp/minibak.log >> $dir_log/minibak.log
									rm /tmp/minibak.log
							fi
						else
							# default config file does not exist -> error
							echo "$0 ERROR: The default config $defaultConfig/minibak.conf does not exist! - Exiting..." >&2
							echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [ERROR] Default configuration file is missing. Exit code 1." >> /tmp/minibak.log
							exit 1
					fi
				else	# when arg is something else, likely custom config location
					if [[ -z "$OPTARG" ]]
						then
							# if its empty -> error
							echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Arg $OPTARG set for option -c" >> /tmp/minibak.log
							echo "$0 ERROR: The argument containing the location of the configuration file is empty!" >&2
							echo "$text_configErrorInfo" >&2
							echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [ERROR] Config in $OPTARG not found. Exit code 1" >> /tmp/minibak.log
							exit 1
						else
							# existance check
							if [[ -f $OPTARG ]]
								then
									# if exists, import the values for vars from config
									source $OPTARG

									if [[ -d $dir_log ]]
										then
											cat /tmp/minibak.log >> $dir_log/minibak.log
											rm /tmp/minibak.log
										else
											echo "Warning: Set log directory doesn't exist, setting the log directory to /var/log"
											echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [WARNING] Provided log directory doesn't exist, dir_log will be set to /var/log" >> /tmp/minibak.log
											dir_log="/var/log"
											cat /tmp/minibak.log >> $dir_log/minibak.log
											rm /tmp/minibak.log
									fi
								else
									# config file doesn't exit
									echo "The config file in the provided location does not exist in location $OPTARG! - Exiting..." >&2
									echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [ERROR] Custom configuration file doesn't exist. Exit code 1." >> /tmp/minibak.log
									exit 1
							fi
					fi
			fi ;;
		\?) echo "$text_help" >&2; exit 1;;
	esac
done

if [[ -z $dir_src ]]
	then
		# source string empty
		echo "Error: No directory to be backed up has been provided - Exiting..." >&2
		echo "$text_help" >&2
		echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [ERROR] Source directory string is empty. Exit code 1" >> $dir_log/minibak.log
		exit 1
	elif [[ -d $dir_src ]]
		then
			# source dir exists
			echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Source directory exists" >> $dir_log/minibak.log
			if [[ -z $dir_dest ]]
				then
					# destination string empty
					echo "Error: Destination directory string is empty - Exiting..." >&2
					echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [ERROR] Destination directory string is empty. Exit code 1" >> $dir_log/minibak.log
					exit 1
			fi
	else
		# source dir doesn't exist
		echo "Source directory <$dir_src> does not exit! - Exiting..." >&2
		echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [ERROR] Source directory doesn't exist. Exit code 1" >> $dir_log/minibak.log
		exit 1
fi

if ! [[ -d $dir_dest ]]
	then
		# destination doesn't exist
		echo "Warning: Destination directory doesn't exist, attempting to create the directory $dir_dest"
		echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [WARNING] Destination directory doesn't exist, attempting to create $dir_dest" >> $dir_log/minibak.log
		if mkdir --parents $dir_dest
			then
				# destination directory created successfully
				echo "Success: Destination directory has been created successfully"
				echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [SUCCESS] Destination directory has been created successfully" >> $dir_log/minibak.log
			else
				# creation of the destination directory failed
				echo "Failure: Creation of the destination directory has failed with status $?" >&2
				echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [FAILURE] Creation of the destination directory has failed with status $?. Exit code 1" >> $dir_log/minibak.log
				exit 1
		fi
fi

#backupTimeAndDate="$(date +%Y-%m-%d_%H-%M-%S)"
currentBackupDir="$dir_dest/backup_$(date +%Y-%m-%d_%H-%M-%S)"

printf '<%s>\n' $currentBackupDir
echo "Creating directory $currentBackupDir"
echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Creating the backup directory $currentBackupDir" >> $dir_log/minibak.log

lastBackup=$(find $dir_dest -mindepth 1 -maxdepth 1 | sort -r | head -n 1)

#mkdir $currentBackupDir

func_rsyncExitCode() 
{
	case $1 in
		0) echo "Success: Backup performed successfully"
			echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [SUCCESS] Backup job completed successfully. rsync quit with exit code $1" >> $dir_log/minibak.log ;;
		1) echo "Failure: Syntax or usage error"
			echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [FAILURE] Syntax or usage error within the script. rsync quit with exit code $1" >> $dir_log/minibak.log ;;
		2) echo "Failure: Protocol incompatibility"
			echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [FAILURE] Protocol incompatibility. rsync quit with exit code $1" >> $dir_log/minibak.log ;;
		3) echo "Failure: Errors selecting input/output files, directories, or permissions"
			echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [FAILURE] Errors selecting input/output files, directories, or permissions. rsync quit with exit code $1" >> $dir_log/minibak.log ;;
		4) echo "Failure: Requested action not supported"
			echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [FAILURE] Requested action not supported. rsync quit with exit code $1" >> $dir_log/minibak.log ;;
		5) echo "Failure: Error starting the client-server protocol"
			echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [FAILURE] Error starting the client-server protocol. rsync quit with exit code $1" >> $dir_log/minibak.log ;;
		6) echo "Failure: Daemon unable to append to log file"
			echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [FAILURE] Daemon unable to append to log file. rsync quit with exit code $1" >> $dir_log/minibak.log ;;
		10) echo "Failure: Socket I/O error"
			echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [FAILURE] Socket I/O error. rsync quit with exit code $1" >> $dir_log/minibak.log ;;
		11) echo "Failure: File I/O error"
			echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [FAILURE] File I/O error. rsync quit with exit code $1" >> $dir_log/minibak.log ;;
		12) echo "Failure: Error in rsync protocol data stream"
			echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [FAILURE] Error in rsync protocol data stream. rsync quit with exit code $1" >> $dir_log/minibak.log ;;
		13) echo "Failure: Errors with diagnostics"
			echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [FAILURE] Errors with diagnostics. rsync quit with exit code $1" >> $dir_log/minibak.log ;;
		14) echo "Failure: Error in IPC code"
			echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [FAILURE] Error in IPC code. rsync quit with exit code $1" >> $dir_log/minibak.log ;;
		20) echo "Failure: Received SIGUSR1 or SIGINT"
			echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [FAILURE] Received SIGUSR1 or SIGINT. rsync quit with exit code $1" >> $dir_log/minibak.log ;;
		23) echo "Failure: Partial transfer due to error"
			echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [FAILURE] Partial transfer due to error. rsync quit with exit code $1" >> $dir_log/minibak.log ;;
		24) echo "Failure: Partial transfer due to vanished source files"
			echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [FAILURE] Partial transfer due to vanished source files. rsync quit with exit code $1" >> $dir_log/minibak.log ;;
		30) echo "Failure: Timeout in data send/receive"
			echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [FAILURE] Timeout in data send/receive. rsync quit with exit code $1" >> $dir_log/minibak.log ;;
		35) echo "Failure: Timeout waiting for daemon connection"
			echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [FAILURE] Timeout waiting for daemon connection. rsync quit with exit code $1" >> $dir_log/minibak.log ;;
		\?) echo "Failure: An unlisted error has occurred. rsync quit with error code $1"
			echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [FAILURE] Unlisted error occurred. rsync quit with exit code $1" >> $dir_log/minibak.log ;;
	esac
}

if [[ -z "$(ls $dir_dest)" ]]
	then
		echo "No previous backups found"
		echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] No previous backups found" >> $dir_log/minibak.log
		mkdir $currentBackupDir
		rsync -aH $dir_src $currentBackupDir
		func_rsyncExitCode "$?"
		
	else
		# find last latest backup and set that as the --link-dest
		echo "Searching for last latest backup to compare with latest changes"
		echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Searching for lastest directory to compare changes" >> $dir_log/minibak.log
		echo "lastBackup = $lastBackup"
		echo "currentBackupDir = $currentBackupDir"
		mkdir $currentBackupDir
		rsync -aHv --link-dest=$lastBackup $dir_src $currentBackupDir
		func_rsyncExitCode "$?"
fi

#if [[ "$bool_verboseMode" -eq 1 ]]
#	then
#		echo "source = $dir_src"
#fi
