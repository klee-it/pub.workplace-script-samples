#!/bin/bash

#
## location: all client devices
#
## restrictions:
## |__ Ubuntu v20.04
## |__ Ubuntu v22.04
#
## dependencies:
## |__ MS intune-portal
#
## help:
## |__ crontab
## |__|__ # intune-portal: display login
## |__|__ */5 * * * * /opt/microsoft/intune/show-intune-portal.sh > /home/user/show-intune-portal.log 2>&1
#

echo "# install prerequisites"
listOf_prereqs="jq coreutils grep"
apt-get install -y $listOf_prereqs

echo
echo "# output global environment variables..."
echo "|__ DATE/TIME: $(date)"
echo "|__ HOSTNAME: $(hostname)"
echo "|__ PATH: $PATH"
echo "|__ HOME: $HOME"
echo "|__ DISPLAY: $DISPLAY"
echo "|__ XAUTHORITY: $XAUTHORITY"

echo
echo "# list current logged-in users..."
who

echo
echo "# list /home directory..."
ls -la /home

echo
echo "# get current logged-in user..."
currentLoggedInUser=$(who | awk -F ' ' 'NR==1{print $1}')
echo "|__ username: $currentLoggedInUser"

echo
echo "# set script variables..."
IntuneRegistration_Dir="/home/$currentLoggedInUser/.config/intune"
IntuneRegistration_File="$IntuneRegistration_Dir/registration.toml"
IdentityBrokerCache_Dir="/home/$currentLoggedInUser/.local/state/microsoft-identity-broker"
IdentityBrokerCache_File="$IdentityBrokerCache_Dir/account-data.db"
Application_DesktopFile="/usr/share/applications/intune-portal.desktop"
XdgAutostart_Path="/etc/xdg/autostart"
XdgAutostart_File="$XdgAutostart_Path/intune-portal.desktop"
TmpAutostart_File="/tmp/intune-portal.desktop"
RegistrationLastModified=""
IdentityAccountHint=""
IdentityLastModified=""

# check if intune-portal is installed
echo
echo "# check if intune-portal is installed..."
if ! which intune-portal > /dev/null; then
    echo "# intune-portal is not installed. Exiting script..."
    exit 0
else
    echo "|__ intune-portal is installed"
fi

echo
echo "# list directory content: $IntuneRegistration_Dir"
ls -la "$IntuneRegistration_Dir"

echo
echo "# list directory content: $IdentityBrokerCache_Dir"
ls -la "$IdentityBrokerCache_Dir"
if test -L "$IdentityBrokerCache_Dir"; then
    echo "|__ identity-broker cache file is a symlink. Resolving link..."
    ls -la "$(readlink -f "$IdentityBrokerCache_Dir")"
fi

# get last registration date/time by checking intune-portal registration file
echo
echo "# get last registration date/time by checking intune-portal registration file..."
if [ -f "$IntuneRegistration_File" ]; then
    # get last modified date of file
    RegistrationLastModified=$(date +%F -r "$IntuneRegistration_File")
    # get file content for verification (key = "value")
    IdentityAccountHint=$(grep -oP 'account_hint\s*=\s*["]?\K.+' "$IntuneRegistration_File" | tr -d '"')
    echo "|__ IdentityAccountHint: $IdentityAccountHint"
else
    echo "|__ File does not exist: $IntuneRegistration_File"
    echo "|__ Set RegistrationLastUsage to current date - 7 days..."
    RegistrationLastModified=$(date -d "-7 days" +%F)
fi
echo "|__ last modified: $RegistrationLastModified"

# get last sign-in date/time by checking identity-broker cache files
echo
echo "# get last sign-in date/time by checking identity-broker cache files..."
if [ -f "$IdentityBrokerCache_File" ]; then
    # get last modified date of file
    IdentityLastModified=$(date +%F -r "$IdentityBrokerCache_File")
else
    echo "|__ File does not exist: $IdentityBrokerCache_File"
    echo "|__ Set RegistrationLastUsage to current date - 7 days..."
    IdentityLastModified=$(date -d "-7 days" +%F)
fi
echo "|__ last modified: $IdentityLastModified"

# get last check-in by syslog
echo
echo "# get last check-in by syslog..."
LastCheckin_Log=$(grep "Successfully checked in with Intune" /var/log/syslog | awk '{print $1}' | sort -r | head -n 1)
if [ -n "$LastCheckin_Log" ]; then
    echo "|__ last check-in log entry found: $LastCheckin_Log"
    SyslogLastModified=$(date -d "$LastCheckin_Log" +%F)
else
    echo "|__ no check-in log entry found"
    echo "|__ Set SyslogLastModified to current date - 7 days..."
    SyslogLastModified=$(date -d "-7 days" +%F)
fi
echo "|__ last modified: $SyslogLastModified"

# check if last usage was more than 5 days ago
echo
echo "# check if last usage was more than 5 days ago..."
currentDate=$(date +%s)
daysSinceLastRegistration=$(( ($currentDate - $(date -d "$RegistrationLastModified" +%s)) / (60*60*24) ))
daysSinceLastSignIn=$(( ($currentDate - $(date -d "$IdentityLastModified" +%s)) / (60*60*24) ))
daysSinceLastCheckIn=$(( ($currentDate - $(date -d "$SyslogLastModified" +%s)) / (60*60*24) ))

echo "|__ days since last registration: $daysSinceLastRegistration"
echo "|__ days since last sign-in: $daysSinceLastSignIn"
echo "|__ days since last check-in: $daysSinceLastCheckIn"

# check if daysSinceLastRegistration or daysSinceLastSignIn was more than 5 days ago
if [ $daysSinceLastRegistration -gt 5 ] || [ $daysSinceLastSignIn -gt 5 ] || [ $daysSinceLastCheckIn -gt 5 ]; then
    echo "# last login was more than 5 days ago. Proceeding with script..."

    echo "# add application to autostart..."
    if [ -f "$Application_DesktopFile" ]; then
        echo "|__ create new temp autostart file..."
        # echo -e "$(cat "/usr/share/applications/intune-portal.desktop")\nX-GNOME-Autostart-Delay=30" > "$TmpAutostart_File" # -e does not work in POSIX sh only in bash
        printf "$(cat "/usr/share/applications/intune-portal.desktop")\\nX-GNOME-Autostart-Delay=30" > "$TmpAutostart_File" # works in POSIX sh and bash

        echo "|__ check hash of temp autostart file..."
        TmpAutostartFileHash=$(sha256sum "$TmpAutostart_File" | awk '{print $1}')
        echo "|__|__ hash: $TmpAutostartFileHash"

        # check if autostart file already exists
        if [ ! -e "$XdgAutostart_File" ]; then
            echo "|__ autostart file does not exist: $XdgAutostart_File"
            CreateAutostartFile="true"
        else
            echo "|__ autostart file already exists: $XdgAutostart_File"

            echo "|__ check hash of autostart file..."
            AutostartFileHash=$(sha256sum "$XdgAutostart_File" | awk '{print $1}')
            echo "|__|__ hash: $AutostartFileHash"

            if [ "$TmpAutostartFileHash" != "$AutostartFileHash" ]; then
                echo "|__ autostart file is different from temp autostart file"
                CreateAutostartFile="true"
            else
                echo "|__ autostart file is identical to temp autostart file"
                CreateAutostartFile="false"
            fi
        fi

        # create autostart file if required
        echo "|__ create autostart file if required: $CreateAutostartFile"
        if [ "$CreateAutostartFile" == "true" ]; then
            if [ -d "$XdgAutostart_Path" ]; then
                mv "$TmpAutostart_File" "$XdgAutostart_File"

                if [ $? -eq 0 ]; then
                    echo "|__ autostart file created: $XdgAutostart_File"
                fi
            else
                echo "|__ xdg Autostart directory does not exist: $XdgAutostart_Path"
            fi
        else
            echo "|__ no need to create autostart file"
        fi

        # remove temp autostart file
        if [ -e "$TmpAutostart_File" ]; then
            rm "$TmpAutostart_File"
            if [ $? -eq 0 ]; then
                echo "|__ temp autostart file removed: $TmpAutostart_File"
            fi
        fi
    else
        echo "|__ application desktop file does not exist: $Application_DesktopFile"
    fi
else
    echo "# last login to intune-portal was less than 5 days ago. No action required."
    if [ -e "$XdgAutostart_File" ]; then
        echo "# remove application from autostart..."
        rm "$XdgAutostart_File"
        if [ $? -eq 0 ]; then
            echo "|__ Autostart file removed: $XdgAutostart_File"
        fi
    fi
fi

echo "# script end"

exit 0
