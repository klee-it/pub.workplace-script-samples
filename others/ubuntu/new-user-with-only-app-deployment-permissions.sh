#!/bin/bash
#set -x

#
## basic information:
## |__ This script creates a new user with only app deployment permissions
#
## location: all client devices
#

# check if the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# Start of a bash "try-catch loop" that will safely exit the script if a command fails or causes an error. 
{
    # set script to "exit on first error"
    set -e

    ###
    ### NEW USER
    ###
    # set parameters
    read -p 'New username: ' NEW_USER
    #NEW_USER="newUser"

    # create new user by useradd
    echo 
    echo "# create new user: $NEW_USER"
    useradd -m -s $(which bash) "$NEW_USER"

    # create new user by useradd with sudo group
    #useradd -m -s $(which bash) -G sudo "$NEW_USER"

    # create new user by adduser
    # adduser --disabled-password --gecos "" "$NEW_USER" --ingroup sudo
    echo "|__ new user created successfully"

    # set default pw
    echo 
    echo "# set default password"
    echo "$NEW_USER:$NEW_USER" | chpasswd 
    echo "|__ default password successfully set"

    ###
    ### SUDOERS FILE
    ###
    # set parameters
    SUDOERS_DIR="/etc/sudoers.d"
    SUDOERS_FILE="/etc/sudoers"
    SUDOERS_PERMISSIONS="ALL=(ALL) NOPASSWD: /usr/sbin/reboot, /usr/bin/dpkg, /usr/bin/apt, /usr/bin/apt-get, /usr/bin/apt-key, /usr/bin/snap, /usr/lib/snapd/snapd, /usr/bin/update-manager, /usr/bin/software-center"

    # create sudoers file
    echo 
    echo "# create sudoers file and set permissions"
    echo "$NEW_USER $SUDOERS_PERMISSIONS" > "$SUDOERS_DIR/$NEW_USER"
    chmod 440 "$SUDOERS_DIR/$NEW_USER"
    echo "|__ sudoers file created successfully"

    # include custom sudoers files
    echo
    echo "# include custom sudoers files"
    sed -i 's/^# \?includedir \/etc\/sudoers\.d/includedir \/etc\/sudoers\.d/' "$SUDOERS_FILE"
    echo "|__ custom sudoers files included successfully"

    ###
    ### POLICYKIT FILE
    ###
    # set parameters
    FILE_POLICYKIT="/etc/polkit-1/localauthority/50-local.d/10-allow-user-installs.pkla"

    # create policykit file
    # |__ find rules in /usr/share/polkit-1/actions/
    echo 
    echo "# create PolicyKit file"
    echo "
[Untrusted Install]
Identity=unix-user:*
Action=org.debian.apt.install-or-remove-packages;org.debian.apt.upgrade-packages
ResultyAny=no
ResultInactive=no
ResultActive=auth_self

[Untrusted Update]
Identity=unix-user:*
Action=org.debian.apt.update-cache
ResultAny=no
ResultInactive=no
ResultActive=yes

[Untrusted Update]
Identity=unix-user:*
Action=io.snapcraft.snapd.manage
ResultAny=no
ResultInactive=no
ResultActive=yes
" > $FILE_POLICYKIT
    echo "|__ custom PolicyKit file created successfully"

    ###
    ### remove deployment user from login screen
    ###
    # set parameters
    FILE_LIGHTDM="/var/lib/AccountsService/users"

    # remove deployment user from login screen
    echo
    echo "# remove deployment user from login screen"
    echo "Available users: $(ls -la $FILE_LIGHTDM)"
    echo
    echo "Update following setting to remove the deployment user from the login screen:"
    echo "File: $FILE_LIGHTDM/<username>"
    echo "Content:"
    echo -e "[User]\nSystemAccount=true"
    echo
    echo "---"

} || { # catch any necessary errors to prevent the program from improperly exiting. 
    ExitCode=$?

    if [ $ExitCode -ne 0 ]; then
        echo "Error: There was an error. Please restart the script or contact your admin if the error persists."
        exit $ExitCode
    fi
}

# The script has finished checking host name. 