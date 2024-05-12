#!/bin/sh
#set -x

#
## location: all client devices
#
## notes:
## |__ rollout by Intune Custom Compliance Policy
## |__ This script checks if MDATP is installed on a device
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
    LICENSED="False"
    VERSION="00.00"

    # The first variable of interest is whether or not MDATP is installed on the device. 
    # If MDATP is installed on the device (regardless of if it is licensed or not), the command "mdatp" will bring up the Microsoft Defender options menu
    # If not, the script will not find the phrase "Microsoft Defender."

    if which mdatp >/dev/null; then
        INSTALLED="True"
    fi

    # If MDATP is installed, the script then checks to see what its version is and if MDATP is properly onboarded.
    if [ "$INSTALLED" = "True" ]; then
        # This sets the licensed variable equal to MDATP license status. 
        # If the device is properly onboarded, LICENSED=true
        ISLICENSED="$(/usr/bin/mdatp health --field licensed)"
        if [ "$ISLICENSED" = "true" ]; then
            LICENSED="True"
            VERSION="$(/usr/bin/mdatp version | cut -c 18- )"
        else
            VERSION="$(/usr/bin/mdatp version | sed '1d' | cut -c 18- )"
        fi
    fi

    OUTPUT="{\"MDATP_installed\":\"$INSTALLED\",\"MDATP_licensed\":\"$LICENSED\",\"MDATP_version\":\"$VERSION\"}"
    echo "$OUTPUT"

} || { # catch any necessary errors to prevent the program from improperly exiting. 
    ExitCode=$?

    if [ $ExitCode -ne 0 ]; then
        echo "{\"MDATP_installed\":\"$INSTALLED\",\"MDATP_licensed\":\"$LICENSED\",\"MDATP_version\":\"$VERSION\",\"Error\":\"There was an error. Please restart the script or contact your admin if the error persists.\"}"
        # exit $ExitCode
    fi
}

# The script has finished checking if MDATP is installed, if MDATP is licensed properly on a given device, and what version of MDATP the device is running