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

# i think making vars for each text is a lot nicer to edit down the line instead of hardcoding it in and having to search for it
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


text_defaultConfigMissing="The default config $defaultConfig/minibak.conf does not exist! - Exiting..."

text_configLocationEmpty="The argument containing the location of the configuration file is empty!"


read -d '' text_configErrorInfo << EOT
Please insert the location of a valid configuration file, for example <-c ~/my-minibak-config.conf>
or use <-c default> to use the default file $defaultConfig/minibak.conf
EOT


text_dirSrcStringEmpty="No directory to be backed up has been provided - Exiting..."

text_srcDirMissing="Source directory <$dir_src> does not exit! - Exiting..."

text_customConfigMissing="The config file in the provided location does not exist! Location:"

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
						echo "$0 ERROR: $text_defaultConfigMissing" >&2
						echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [ERROR] Default configuration file is missing. Exit code 1." >> /tmp/minibak.log
						exit 1
				fi
			else	# when arg is something else, likely custom config location
				if [[ -z "$OPTARG" ]]
					then
						# if its empty -> error
						echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [INFO] Arg $OPTARG set for option -c" >> /tmp/minibak.log
						echo "$0 ERROR: $text_configLocationEmpty" >&2
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
								echo "$text_customConfigMissing $OPTARG - Exiting..." >&2
								echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [ERROR] Custom configuration file doesn't exist. Exit code 1." >> /tmp/minibak.log
								exit 1
						fi
					fi
				fi
			fi ;;
		\?) echo "$text_help" >&2; exit 1;;
	esac
done

if [[ -z $dir_src ]]
	then
		# source string empty
		echo "Error: $text_dirSrcStringEmpty" >&2
		echo "$text_help" >&2
		echo "$(date +"%Y-%m-%d %H:%M:%S:%N") [ERROR] Source directory string is empty. Exit code 1" >> $dir_log/minibak.log
		exit 1
	elif [[ -d $dir_src ]]
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
		echo "$text_srcDirMissing" >&2
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

currentBackupDir="backup $(date +"%Y-%m-%d_%H-%M-%S")"

mkdir $dir_dest/$currentBackupDir

if [[ -z $(ls) ]]
	then
		rsync -aH $dir_src $currentBackupDir
	else
		# find last latest backup and set that as the --link-dest
fi

#if [[ "$bool_verboseMode" -eq 1 ]]
#	then
#		echo "source = $dir_src"
#fi
