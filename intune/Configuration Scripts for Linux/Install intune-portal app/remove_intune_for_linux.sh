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

# show current script path
echo "# Current script location: $(pwd)"
echo

# Remove intune-portal related apps
if which intune-portal > /dev/null; then
    echo "# Remove intune-portal related apps"
    apt-get remove --purge -y intune-portal microsoft-edge-stable microsoft-identity-broker microsoft-identity-diagnostics
fi

# If installation is done, add post-installation tasks
echo
if which intune-portal > /dev/null; then
    echo "# MS Intune App installed"
else
    echo "# MS Intune App is not installed"

    # Remove intune-portal related folders
    echo "# Remove intune-portal related folders"
    listOfDirs="""\
    /home/*/.cache/intune-portal \
    /home/*/.config/intune \
    /home/*/.config/microsoft-identity-broker \
    /home/*/.local/state/microsoft-identity-broker \
    /var/lib/microsoft-identity-broker \
    /var/lib/microsoft-identity-device-broker \
    /run/intune \
    /opt/microsoft/identity-broker \
    /opt/microsoft/intune \
    /opt/microsoft/microsoft-identity-diagnostics \
    /opt/microsoft/msedge \
    """
    for dir in $listOfDirs; do
        echo "|__ Remove directory: $dir"
        if [ -d "$dir" ]; then
            rm -r "$dir"
            echo "|__|__ Directory removed successfully"
        else
            echo "|__|__ Directory does not exist anymore"
        fi
    done

    # Remove source list files
    echo "# Remove source list files"
    listOfFiles="""\
    /etc/apt/sources.list.d/microsoft-edge.list \
    /etc/apt/sources.list.d/microsoft-prod.list \
    """
    for file in $listOfFiles; do
        echo "|__ Remove file: $file"
        if [ -f "$file" ]; then
            rm "$file"
            echo "|__|__ File removed successfully"
        else
            echo "|__|__ File does not exist anymore"
        fi
    done

    # Remove application from autostart
    echo "# Remove application from autostart"
    autostartFile="/etc/xdg/autostart/intune-portal.desktop"
    if [ -f "$autostartFile" ]; then
        echo "|__ Remove file: $autostartFile"
        rm "$autostartFile"
        echo "|__|__ File removed successfully"
    else
        echo "|__|__ File does not exist anymore"
    fi
fi
