#! /bin/bash

defaultBackDir=$(echo ~)

if [ -n $(grep backupDir conf) ]
then
	grep '#' $(grep backupDir conf)
fi

superIdol="test!"

echo "$superIdol"
echo "$defaultBackDir"
