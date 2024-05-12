#!/bin/sh
#set -x

#
## location: all client devices
#
## notes:
## |__ rollout by Intune Custom Compliance Policy
## |__ This script checks the host name of a device
## |__ https://github.com/microsoft/shell-intune-samples/tree/master/Linux/Custom%20Compliance
#

#############################################################################################################################
################### POSIX-compliant shell script for Linux
################### |__ Test: shellcheck --shell sh <filename>
################### keep in mind that the syntax is using very old bash version
################### |__ synonym like "==" of "=" is not supported)
################### |__ [[ "$a" =~ <regex> ]] <= not supported
#############################################################################################################################

# Start of a bash "try-catch loop" that will safely exit the script if a command fails or causes an error. 
{
    # set script to "exit on first error"
    #set -e     
    
    # This variable represents the current host name of the device
    COMPUTERNAME=$(/usr/bin/cat /etc/hostname | tr "[:lower:]" "[:upper:]")

    IsOK=$(echo "$COMPUTERNAME" | grep -iPc '^[a-zA-Z]{3,4}[0-9]?-[a-zA-Z0-9]{7,}$')

    if [ "$IsOK" -eq "0" ]; then
        # Report (false) for linux devices which doesn't meet the naming convention
        echo '{"linux_host_name": "NOK"}'
    else
        # Report (true) for linux devices which meets the naming convention.
        echo '{"linux_host_name": "OK"}'
    fi
} || { # catch any necessary errors to prevent the program from improperly exiting. 
    ExitCode=$?

    if [ $ExitCode -ne 0 ]; then
        echo '{"linux_host_name":"FAILED","Error":"There was an error. Please restart the script or contact your admin if the error persists."}'
        # exit $ExitCode
    fi
}

# The script has finished checking host name. 