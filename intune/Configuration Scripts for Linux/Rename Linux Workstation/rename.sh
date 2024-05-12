#!/bin/bash

#
## basic information:
## |__ This script renames the device to our naming convention.
#
## location: all client devices
#
## restrictions:
## |__ Ubuntu v20.04
## |__ Ubuntu v22.04
#

distroName=''
distroVersion=''
distroCodeName=''

# get distribution name and version
if [ -f /etc/os-release ]; then
    # freedesktop.org and systemd
    . /etc/os-release
    distroName=$NAME
    distroVersion=$VERSION_ID
    distroCodeName=$UBUNTU_CODENAME
elif type lsb_release >/dev/null 2>&1; then
    # linuxbase.org
    distroName=$(lsb_release -si)
    distroVersion=$(lsb_release -sr)
elif [ -f /etc/lsb-release ]; then
    # For some versions of Debian/Ubuntu without lsb_release command
    . /etc/lsb-release
    distroName=$DISTRIB_ID
    distroVersion=$DISTRIB_RELEASE
    distroCodeName=$DISTRIB_CODENAME
elif [ -f /etc/debian_version ]; then
    # Older Debian/Ubuntu/etc.
    distroName=Debian
    distroVersion=$(cat /etc/debian_version)
else
    # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
    distroName=$(uname -s)
    distroVersion=$(uname -r)
fi

# convert all uppercase letters to lowercase letters
distroName=$(echo $distroName | tr '[:upper:]' '[:lower:]')
distroVersion=$(echo $distroVersion | tr '[:upper:]' '[:lower:]')
distroCodeName=$(echo $distroCodeName | tr '[:upper:]' '[:lower:]')

# check if name and version is available
if [ "$distroName" != '' ] && [ "$distroVersion" != '' ] && [ "$distroCodeName" != '' ]; then
    echo "# Distro: ${distroName} ${distroVersion} (${distroCodeName})"

    if [ "$distroName" = "debian gnu/linux" ]; then
        distroName="debian"
    fi

    ###
    ### Ubuntu
    ###
    if ( [ "$distroName" = "ubuntu" ] && [ "$distroVersion" \> "20.00.00" ] ); then
        # show current script path
        echo "# Current script location: $(pwd)"
        echo 

        # get current hostname
        COMPUTERNAME=$(hostname | tr "[:lower:]" "[:upper:]")
        echo "# Current computer name: $COMPUTERNAME"

        ### Check if current computer name matches naming convention
        if [[ ! "$COMPUTERNAME" =~ ^[a-zA-Z]{3}-[a-zA-Z0-9]{7,}$ ]]; then
            if [[ "$COMPUTERNAME" =~ ^[a-zA-Z]{3}-.*$ ]]; then

                # set new hostname
                NEWCOMPUTERNAME=$(echo "$(echo "$COMPUTERNAME" | cut -c 1-3)-$(dmidecode -s system-serial-number)" | tr "[:lower:]" "[:upper:]")
                echo "# New computer name: $NEWCOMPUTERNAME"

                if [[ "$NEWCOMPUTERNAME" =~ ^[a-zA-Z]{3}-[a-zA-Z0-9]{7,}$ ]]; then
                    # set new hostname
                    hostnamectl set-hostname ${NEWCOMPUTERNAME}
                    echo "|__ New computer name set successfully"
                else
                    echo "|__ New computer name doesn't fit naming convention - maybe because of virtual machine or other reasons"
                fi
            else
                echo "|__ Current computer name miss location shortcut"
            fi
        else
            echo "|__ Computer name already fits naming convention"
        fi
    else
        echo "# Distro not supported"
    fi
    echo

else
    echo "# Linux system/distribution not supported"
fi
