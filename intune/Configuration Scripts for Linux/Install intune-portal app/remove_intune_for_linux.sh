#!/bin/bash

#
## location: all client devices
#
## restrictions:
## |__ Ubuntu v20.04
## |__ Ubuntu v22.04
## |__ Ubuntu v24.04
#
## dependencies:
## |__ MS Edge
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

        # Remove intune-portal related apps
        if which intune-portal > /dev/null; then
            echo "# Remove intune-portal related apps"
            /usr/bin/apt-get remove --purge -y intune-portal microsoft-edge-stable microsoft-identity-broker microsoft-identity-diagnostics

            # Remove intune-portal related folders
            echo "# Remove intune-portal related folders"
            /usr/bin/rm -r /home/*/.cache/intune-portal
            /usr/bin/rm -r /home/*/.config/intune
            /usr/bin/rm -r /home/*/.config/microsoft-identity-broker
            /usr/bin/rm -r /home/*/.local/state/microsoft-identity-broker
            /usr/bin/rm -r /var/lib/microsoft-identity-broker
            /usr/bin/rm -r /run/intune
            /usr/bin/rm -r /opt/microsoft/identity-broker
            /usr/bin/rm -r /opt/microsoft/intune
            /usr/bin/rm -r /opt/microsoft/microsoft-identity-diagnostics
            /usr/bin/rm -r /opt/microsoft/msedge

            # Remove symlink for autostart
            echo "# Remove application from autostart"
            /usr/bin/rm /etc/xdg/autostart/intune-portal.desktop
        fi
    else
        echo "# Distro not supported"
    fi
    echo

    # If installation is done, add post-installation tasks
    if which intune-portal > /dev/null; then
        echo "# MS Intune App installed"
    else
        echo "# MS Intune App is not installed"
    fi
    echo
else
    echo "# Linux system/distribution not supported"
fi
