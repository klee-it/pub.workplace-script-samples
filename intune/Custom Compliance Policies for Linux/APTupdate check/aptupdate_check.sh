#!/bin/sh
#set -x

#
## location: all client devices
#
## notes:
## |__ rollout by Intune Custom Compliance Policy
## |__ This script checks if apt update raises errors
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
    
    # Variables
    INSTALLED="False"
    IsOK="False"
    LogFile="/var/log/apt/system_update.log"

    # check if APT is installed
    if which apt-get > /dev/null; then
        INSTALLED="True"
    fi

    # check if update process is working fine
    if [ "$INSTALLED" = "True" ]; then
        # run update process to check result
        if [ -f "$LogFile" ]; then
            #APT_check=$(/usr/bin/apt-get update 2>&1 | grep -Pc '^[WE]:') # apt-get update needs root permission, but intune runs as user
            APT_check=$(/usr/bin/grep -Pc '^(?:Err|E|W):' "$LogFile")
            if [ "$APT_check" = "0" ]; then
                IsOK="True"
            else
                IsOK="False:$APT_check"
            fi
        else
            IsOK="False"
        fi
    fi

    OUTPUT="{\"APT_installed\":\"$INSTALLED\",\"APT_isOK\":\"$IsOK\"}"
    echo "$OUTPUT"
} || { # catch any necessary errors to prevent the program from improperly exiting. 
    ExitCode=$?

    if [ $ExitCode -ne 0 ]; then
        echo "{\"APT_installed\":\"$INSTALLED\",\"APT_isOK\":\"$IsOK\",\"Error\":\"There was an error. Please restart the script or contact your admin if the error persists.\"}"
        # exit $ExitCode
    fi
}

# The script has finished checking APT-GET UPDATE status