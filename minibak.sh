#! /bin/bash

# begin code section where the vars with initial data are declared

dir_src=""			# source data to backup
dir_dest=""			# destination where the data will be backed up
bool_verboseMode=0		# talk to me baby
bool_schedulerEnabled=0		# enable/disable scheduled execs
dir_log="/var/log"		# default directory for log files
dir_defaultConfig="/etc"	# default config dir
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


text_defaultConfigMissing="The default config $defaultConfig/minibak.conf does not exist! Exiting..."

text_configLocationEmpty="The argument containing the location of the configuration file is empty!"


read -d '' text_configErrorInfo << EOT
Please insert the location of a valid configuration file, for example <-c ~/my-minibak-config.conf>
or use <-c default> to use the default file $defaultConfig/minibak.conf
EOT


text_dirSrcStringEmpty="No directory to be backed up has been provided. Exiting..."

# end code section with vars for user facing information


# begin code section containing logic

# option handler along with arguments for options
while getopts ":s:d:vh:c:" flag; do
	#echo "flag -$flag, arg $OPTARG";
	case $flag in
		s) dir_src=$OPTARG ;;
		d) dir_dest=$OPTARG ;;
		v) bool_verboseMode=1 ;;
		h) if [ $OPTARG = "config" ]
			then
				echo "$text_configHelp" >&2
				exit 0
			fi ;;
		c) if [[ $OPTARG = "default" ]] 
			then
				if [[ -f "$defaultConfig/minibak.conf" ]]
					then
						source $defaultConfig/minibak.conf
					else
						echo "$0 ERROR: $text_defaultConfigMissing" >&2
						exit 1
			else
				if [[ -z "$OPTARG" ]]
					then
						echo "$0 ERROR: $text_configLocationEmpty" >&2
						echo "$text_configErrorInfo" >&2
						exit 1
				source $OPTARG
			fi ;;
		\?) echo "$text_help" >&2; exit 1;;
	esac
done

if [[ -z $dir_src ]]
then
	# source string empty
	echo "Error: $text_dirSrcStringEmpty" >&2
	echo "$text_help" >&2
	exit 1
elif [[ -f $dir_src ]]
	# source dir exists
else
	# source dir doesn't exist
fi

if [[ "$bool_verboseMode" -eq 1 ]] then echo "source = $dir_src"; fi
