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
## notes:
## |__ rollout by Intune
#
## help:
## |__ crontab
## |__|__ # intune-portal: display login
## |__|__ */5 * * * * /opt/microsoft/intune/show-intune-portal.sh > /home/<user>/show-intune-portal.log 2>&1
#

echo "# output global environment variables..."
echo "|__ DATE/TIME: $(date)"
echo "|__ HOSTNAME: $(hostname)"
echo "|__ PATH: $PATH"
echo "|__ HOME: $HOME"
echo "|__ DISPLAY: $DISPLAY"
echo "|__ XAUTHORITY: $XAUTHORITY"

echo "# list current logged-in users..."
/usr/bin/who

echo "# list /home directory..."
/usr/bin/ls -la /home

echo "# get current logged-in user..."
#currentLoggedInUser=$(/usr/bin/who | /usr/bin/grep tty | /usr/bin/awk -F ' ' '{print $1}')
currentLoggedInUser=$(/usr/bin/who | /usr/bin/awk -F ' ' 'NR==1{print $1}')
echo "|__ username: $currentLoggedInUser"

# if [ -z "$currentLoggedInUser" ]; then
#     echo "# no user logged in. Exiting script..."
#     exit 0
# fi

# echo "# set environment variables..."
# if [ -z "$HOME" ]; then
#     export HOME="/home/$currentLoggedInUser"
#     echo "|__ HOME: $HOME"
# fi
# if [ -z "$DISPLAY" ]; then
#     export DISPLAY=":0"
#     echo "|__ DISPLAY: $DISPLAY"
# fi
# if [ -z "$XAUTHORITY" ]; then
#     export XAUTHORITY="/run/user/1000/.mutter-Xwaylandauth.N3PFQ2"
#     echo "|__ XAUTHORITY: $XAUTHORITY"
# fi

echo "# set script variables..."
IntuneRegistration_File="/home/$currentLoggedInUser/.config/intune/registration.toml"
Application_DesktopFile="/usr/share/applications/intune-portal.desktop"
XdgAutostart_Path="/etc/xdg/autostart"
XdgAutostart_File="$XdgAutostart_Path/intune-portal.desktop"

# check if intune-portal is installed
echo "# check if intune-portal is installed..."
if ! which intune-portal > /dev/null; then
    echo "# intune-portal is not installed. Exiting script..."
    exit 0
else
    echo "|__ intune-portal is installed"
fi

# get last execution date/time of intune-portal
echo "# get last execution date/time of intune-portal..."
if [ -f "$IntuneRegistration_File" ]; then
    # lastModified=$(/usr/bin/stat -c %y "$IntuneRegistration_File" | /usr/bin/cut -d' ' -f1)
    lastModified=$(/usr/bin/date +%F -r "$IntuneRegistration_File")
else
    echo "|__ File does not exist: $IntuneRegistration_File"
    echo "|__ Set lastUsageDate to current date - 7 days..."
    lastModified=$(/usr/bin/date -d "-7 days" +%F)
fi
echo "|__ last modified: $lastModified"

# check if last usage was more than 5 days ago
echo "# check if last usage was more than 5 days ago..."
lastUsageDate=$(/usr/bin/date -d "$lastModified" +%s)
currentDate=$(/usr/bin/date +%s)
daysSinceLastUsage=$(( ($currentDate - $lastUsageDate) / (60*60*24) ))
echo "|__ days since last login: $daysSinceLastUsage"

# check if last login was more than 5 days ago
if [ $daysSinceLastUsage -gt 5 ]; then
    echo "# last login was more than 5 days ago. Proceeding with script..."
    
    # echo "# execute intune-portal..."
    # use current logged-in user
    # /usr/sbin/runuser -u $currentLoggedInUser -- /usr/bin/gtk-launch intune-portal &

    # use runtime user
    # /usr/bin/gtk-launch intune-portal

    echo "# add application to autostart..."
    if [ -f "$Application_DesktopFile" ]; then
        if [ ! -e "$XdgAutostart_File" ]; then
            if [ -d "$XdgAutostart_Path" ]; then
                #/usr/bin/ln -s "$Application_DesktopFile" "$XdgAutostart_File"

                echo -e "$(cat "/usr/share/applications/intune-portal.desktop")\nX-GNOME-Autostart-Delay=30" > "$XdgAutostart_File"

                if [ $? -eq 0 ]; then
                    echo "|__ Autostart file created: $XdgAutostart_File"
                fi
            else
                echo "|__ Directory does not exist: $XdgAutostart_Path"
            fi
        else
            echo "|__ Autostart file already exists: $XdgAutostart_File"
        fi
    else
        echo "|__ File does not exist: $Application_DesktopFile"
    fi
else
    echo "# last login to intune-portal was less than 5 days ago. No action required."
    if [ -e "$XdgAutostart_File" ]; then
        echo "# remove application from autostart..."
        /usr/bin/rm "$XdgAutostart_File"
        if [ $? -eq 0 ]; then
            echo "|__ Autostart file removed: $XdgAutostart_File"
        fi
    fi
fi

echo "# script end"

exit 0