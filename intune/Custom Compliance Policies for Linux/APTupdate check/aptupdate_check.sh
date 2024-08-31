#!/bin/bash

#
## location: all client devices
#
## notes:
## |__ rollout by Intune Custom Compliance Policy
## |__ This script checks if apt update raises errors
## |__ https://github.com/microsoft/shell-intune-samples/tree/master/Linux/Custom%20Compliance
#
## Error Codes:
## |__ 65007: Script returned failure
## |__ 65008: Setting missing in the script result
## |__ 65009: Invalid json for the discovered setting
## |__ 65010: Invalid datatype for the discovered setting
#

# set script parameters
LogFile="/var/log/apt/system_update.log"

StatusAptInstalled="False"
StatusAptIsOK="False"

# check if APT is installed
if which apt-get > /dev/null; then
    StatusAptInstalled="True"
fi

# check if update process is working fine
if [ "$StatusAptInstalled" = "True" ]; then
    # run update process to check result
    if [ -f "$LogFile" ]; then
        #APT_check=$(/usr/bin/sudo /usr/bin/apt-get update 2>&1 | grep -Pc '^[WE]:') # apt-get update needs root permission, but intune runs as user
        APT_check=$(/usr/bin/grep -Pc '^(?:Err|E|W):' "$LogFile")
        if [ "$APT_check" = "0" ]; then
            StatusAptIsOK="True"
        else
            StatusAptIsOK="False:$APT_check"
        fi
    fi
fi

echo "{\"APT_installed\":\"$StatusAptInstalled\",\"APT_isOK\":\"$StatusAptIsOK\"}"
