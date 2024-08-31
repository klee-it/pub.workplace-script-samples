#!/bin/bash

#
## location: all client devices
#
## notes:
## |__ rollout by Intune Custom Compliance Policy
## |__ This script checks the host name of a device
## |__ https://github.com/microsoft/shell-intune-samples/tree/master/Linux/Custom%20Compliance
#
## Error Codes:
## |__ 65007: Script returned failure
## |__ 65008: Setting missing in the script result
## |__ 65009: Invalid json for the discovered setting
## |__ 65010: Invalid datatype for the discovered setting
#

# set script parameters
StatusHostname="NOK"

# This variable represents the current host name of the device
COMPUTERNAME=$(/usr/bin/cat /etc/hostname | /usr/bin/tr "[:lower:]" "[:upper:]")

if [ -n "$COMPUTERNAME" ]; then
    if [[ "$COMPUTERNAME" =~ ^[a-zA-Z]{3,4}-[a-zA-Z0-9]{7,}$ ]]; then
        StatusHostname="OK"
    fi
fi

echo "{\"linux_host_name\": \"$StatusHostname\"}"
