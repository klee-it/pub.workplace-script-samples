#!/bin/bash

#
## location: all client devices
#
## notes:
## |__ rollout by Intune Custom Compliance Policy
## |__ This script checks if MDATP is installed on a device
## |__ https://github.com/microsoft/shell-intune-samples/tree/master/Linux/Custom%20Compliance
#
## Error Codes:
## |__ 65007: Script returned failure
## |__ 65008: Setting missing in the script result
## |__ 65009: Invalid json for the discovered setting
## |__ 65010: Invalid datatype for the discovered setting
#

# set script parameters
StatusMdatpInstalled="False"
StatusMdatpLicensed="False"
StatusMdatpVersion="00.00"

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

echo "{\"MDATP_installed\":\"$StatusMdatpInstalled\",\"MDATP_licensed\":\"$StatusMdatpLicensed\",\"MDATP_version\":\"$StatusMdatpVersion\"}"
