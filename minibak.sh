#! /bin/bash

bakDir=""		# wheres data to be secured?
verboseMode=0		# talk to me baby
schedulerEnabled=0	# enable/disable scheduled execs
logDir="/var/log"	# default directory for log files
defaultConfig="/etc"	# default config dir
# todo - an array that stores hours of the day when a scheduled exec should happen

# text for invalid syntax when using options
read -d '' helpText << EOT

Usage: $0 [ options ]

Either -d or -c are required for the execution, as they provide the directory
needed for this script to backup.

Options:
-d <dir>	Directory to backup
-v		Verbose; Debug messages of what's being done
-h		Show this help message
-h config	Show help for configuration file syntax
-c <file>	Location to a config file
-c default	Execute with the default config (located at /etc/minibak.conf)
 
EOT

# extra help entry explaining how the config file works
read -d '' configHelpText << EOT

Configuration file is the alternative to the options of the script.
Default configuration file is located at /etc/minibak.conf
It is recommended to make a copy of minibak.conf in another directory, and use that copy for changes.

Variables:
bakDir=[dir]		Directory to backup, same as -d
schedulerEnabled=(0/1)	Enable/Disable scheduled backup of files within the directory provided in bakDir
logDir=[dir]		Directory where the logs will be saved. By default, it's /var/log
 
EOT

# option handler along with arguments for options
while getopts ":d:vh:c:" flag; do
	#echo "flag -$flag, arg $OPTARG";
	case $flag in
		d) bakDir=$OPTARG ;;
		v) verboseMode=1 ;;
		h) if [ $OPTARG = "config" ]
			then
				echo "$configHelpText" >&2
				exit 0
			fi ;;
		c) if [[ $OPTARG = default ]] then source $defaultConfig/minibak.conf; else source $OPTARG; fi ;;
		\?) echo "$helpText" >&2; exit 1;;
	esac
done

if [[ -z $bakDir ]]; then
	echo "$helpText" >&2
	exit 1
fi

if [[ "$verboseMode" -eq 1 ]] then echo "dir = $bakDir"; fi
