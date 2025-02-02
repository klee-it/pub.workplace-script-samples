#!/bin/bash

#
## location: all client devices
#
## notes:
## |__ Rollout by Intune Custom Compliance Policy
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
StatusAptInstalled="False"
StatusAptIsOK="False"
StatusHostname="NOK"
StatusMdatpInstalled="False"
StatusMdatpLicensed="False"
StatusMdatpVersion="00.00"

###
### APT check
###
AptLogFile="/var/log/apt/system_update.log"

# check if APT is installed
if which apt-get > /dev/null; then
    StatusAptInstalled="True"
fi

# check if update process is working fine
if [ "$StatusAptInstalled" = "True" ]; then
    # run update process to check result
    if [ -f "$AptLogFile" ]; then
        #APT_check=$(/usr/bin/sudo /usr/bin/apt-get update 2>&1 | grep -Pc '^[WE]:') # apt-get update needs root permission, but intune runs as user
        APT_check=$(/usr/bin/grep -Pc '^(?:Err|E|W):' "$AptLogFile")
        if [ "$APT_check" = "0" ]; then
            StatusAptIsOK="True"
        else
            StatusAptIsOK="False:$APT_check"
        fi
    fi
fi

###
### Hostname check
###
# This variable represents the current host name of the device
COMPUTERNAME=$(/usr/bin/cat /etc/hostname | /usr/bin/tr "[:lower:]" "[:upper:]")

if [ -n "$COMPUTERNAME" ]; then
    if [[ "$COMPUTERNAME" =~ ^[a-zA-Z]{3,4}-L-[a-zA-Z0-9]{7,}$ ]]; then
        StatusHostname="OK"
    fi
fi

###
### MDATP check
###
# check if MDATP is installed
if which mdatp > /dev/null; then
    StatusMdatpInstalled="True"
fi

# If MDATP is installed, the script then checks to see what its version is and if MDATP is properly onboarded.
if [ "$StatusMdatpInstalled" = "True" ]; then
    # This sets the licensed variable equal to MDATP license status. 
    # If the device is properly onboarded, LICENSED=true
    IsLicensed="$(/usr/bin/mdatp health --field licensed)"
    if [ "$IsLicensed" = "true" ]; then
        StatusMdatpLicensed="True"
        StatusMdatpVersion="$(/usr/bin/mdatp version | cut -c 18- )"
    else
        StatusMdatpVersion="$(/usr/bin/mdatp version | sed '1d' | cut -c 18- )"
    fi
fi

###
### Output
###
# output the results
echo "{\"APT_installed\":\"$StatusAptInstalled\",\"APT_isOK\":\"$StatusAptIsOK\",\"linux_host_name\": \"$StatusHostname\",\"MDATP_installed\":\"$StatusMdatpInstalled\",\"MDATP_licensed\":\"$StatusMdatpLicensed\",\"MDATP_version\":\"$StatusMdatpVersion\"}"
