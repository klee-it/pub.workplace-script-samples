#!/bin/sh

#
## basic information:
## |__ This script performs system upgrades on client devices.
#
## location: all client devices
#

# set parameters
LogFile="/var/log/apt/system_update.log"

# check if curl is installed
if ! which curl > /dev/null; then
    echo "# curl not found, start installation"
    /usr/bin/apt-get update
    /usr/bin/apt-get install -y curl
fi

# check if network connection exists
echo
echo "# check if network connection exists"
{ #try
   /usr/bin/curl -I https://www.google.at > /dev/null
   echo "|__ internet connection exists"
} || { #catch
   echo "|__ no internet connection"
   exit 0
}

# check if apt-key is installed
echo
echo "# invoke gpg key update process"
if which apt-key > /dev/null; then
    echo "|__ update gpg keys"
    /usr/bin/apt-key adv --refresh-keys
else
    echo "|__ apt-key is not installed"
fi

# check if apt-get is installed
echo
echo "# invoke update process by apt-get"
if which apt-get > /dev/null; then
    
    echo "|__ update apt-get lists"
    /usr/bin/apt-get update > "$LogFile" 2>&1
    
    echo "|__ check if source lists are broken"
    APT_check=$(/usr/bin/grep -Pc '^(?:Err|E):' "$LogFile")
    
    if [ "$APT_check" = "0" ]; then
        echo "|__ fix dpkg configuration"
        /usr/bin/dpkg --configure -a

        echo "|__ fix broken dependencies"
        /usr/bin/apt --fix-broken install
        
        echo "|__ run system upgrade by apt-get"
        /usr/bin/apt-get -y upgrade && /usr/bin/apt-get -y autoremove && /usr/bin/apt-get -y autoclean
    else
        echo "|__ source lists are broken, skip update process"
        /usr/bin/cat "$LogFile"
    fi
else
    echo "|__ apt-get is not installed"
fi

# check if snap is installed
echo
echo "# invoke update process by snap"
if which snap > /dev/null; then
    echo "|__ start system upgrade with snap"
    /usr/bin/snap refresh
else
    echo "|__ snap is not installed"
fi

exit 0
