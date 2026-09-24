#! /bin/bash

#defaultBackDir=$(echo ~)
bakDir=""
verboseMode=0

helpText=$(cat << EOT
Usage: $0 [ options ] -d <directory>

Options:
-d - Directory to backup
-v - Verbose; Debug messages of what's being done
-h - Show this help message
EOT
)

#if [ -n $(grep backupDir conf) ]
#then
#	grep '#' $(grep backupDir conf)
#fi

#superIdol="test!"

#echo "$superIdol"
#echo "$defaultBackDir"

while getopts "d:vh" flag; do
	echo "flag -$flag, arg $OPTARG";
	case $flag in
		d) bakDir=$OPTARG ;;
		v) verboseMode=1 ;;
		h) echo "$helpText" >&2; exit 0 ;;
		\?) echo "Unknown option: -$flag" >&2; exit 1;;
	esac
done

if [[ -z $bakDir ]]; then
	echo "$helpText" >&2
	exit 1
fi

if [[ "$verboseMode" -eq 1 ]] then echo "dir = $bakDir"; fi
