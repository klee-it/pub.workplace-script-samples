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
echo "# Distro: ${distroName} ${distroVersion} (${distroCodeName})"

# show current script path
echo "# Current script location: $(pwd)"

# check if apt-key is installed
echo
echo "# invoke gpg key update process"
if which apt-key > /dev/null; then
    echo "|__ update gpg keys"
    apt-key adv --refresh-keys
else
    echo "|__ apt-key is not installed"
fi

# Prepare the system for the installation
echo
echo "# invoke update process by apt-get"
apt-get update

echo
echo "# fix dpkg configuration"
dpkg --configure -a

echo
echo "# fix broken dependencies"
apt --fix-broken install

echo
echo "run system upgrade by apt-get"
apt-get -y upgrade && apt-get -y autoremove && apt-get -y autoclean

# Install prerequisites
echo
echo "# Install prerequisites"
resultInstallation=true

listOf_prereqs="curl wget zip unzip nano cifs-utils libplist-utils libnss3-tools gpg apt-transport-https libpam-pwquality ubuntu-restricted-addons jq coreutils grep sed software-properties-common"
for appname in $listOf_prereqs; do
    echo "# Installation of: ${appname}"
    apt-get install -y $appname
    if [ "$?" -ne 0 ]; then
        resultInstallation=false
    fi
done
echo

# check if installation of pre-requisites are successfully
echo "# Pre-requisites installed: ${resultInstallation}"
if [ "$resultInstallation" = true ]; then
    resultMEMSetup=true

    ###
    ### Microsoft GPG public key
    ###

    # check if Microsoft GPG public key is already installed
    MSgpgFileName='microsoft.gpg'
    MSgpgFilePath="/usr/share/keyrings"
    MSgpgFullFileName="$MSgpgFilePath/$MSgpgFileName"

    if [ ! -f "$MSgpgFullFileName" ]; then
        echo "# Microsoft GPG public key not installed, start with installation process"

        # Install Microsoft GPG public key
        if [ "$resultMEMSetup" = true ]; then
            echo "# Install Microsoft GPG public key"
            { # try
                # download Microsoft GPG public key
                curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > "./$MSgpgFileName"
                # install Microsoft GPG public key
                install -o root -g root -m 644 "./$MSgpgFileName" "$MSgpgFilePath/"
                rm "./$MSgpgFileName"
            } || { # catch
                resultMEMSetup=false
            }
        else
            echo "# Previous Failure => Dont install Microsoft GPG public key"
        fi
        echo
    else
        echo "# Microsoft GPG public key already installed"
    fi

    ###
    ### Microsoft Edge repository
    ###

    # Check if MS Edge repository is already installed
    MSEdgeRepositoryFile='/etc/apt/sources.list.d/microsoft-edge.list'

    if [ -f "$MSEdgeRepositoryFile" ]; then
        # Check if MS Repository is disabled
        if cat "$MSEdgeRepositoryFile" | grep '# disabled' > /dev/null; then
            rm "$MSEdgeRepositoryFile"
        elif cat "$MSEdgeRepositoryFile" | grep -P '^# deb .* https://packages\.microsoft\.com/repos/edge' > /dev/null; then
            rm "$MSEdgeRepositoryFile"
        else
            echo "# MS Edge repository already installed and enabled"
        fi
    fi

    # Check if MS Edge repository is already installed
    if [ ! -f "$MSEdgeRepositoryFile" ]; then
        echo "# MS Edge repository not installed, start with installation process"

        # Install MS Edge repository
        if [ "$resultMEMSetup" = true ]; then
            echo "# Install MS Edge repository"
            sh -c "echo 'deb [arch=amd64 signed-by=$MSgpgFullFileName] https://packages.microsoft.com/repos/edge stable main' > $MSEdgeRepositoryFile"
            if [ "$?" -ne 0 ]; then
                resultMEMSetup=false
            fi
        else
            echo "# Previous Failure => Dont install MS Edge repository"
        fi
        echo
    else
        echo "# MS Edge repository already available"
    fi

    ###
    ### Microsoft Prod repository
    ###

    # Check if MS repository is already installed
    MSrepositoryVersion="/$distroName/$distroVersion/"
    MSrepositoryFileName='microsoft-prod.list'
    MSrepositoryFullFileName="/etc/apt/sources.list.d/$MSrepositoryFileName"
    MSrepositoryGpgFile=$(echo "$MSgpgFullFileName" | sed 's,\/,\\\/,g')

    if [ -f "$MSrepositoryFullFileName" ]; then
        # Check if MS Repository is disabled
        if cat "$MSrepositoryFullFileName" | grep '# disabled' > /dev/null; then
            rm "$MSrepositoryFullFileName"
        elif cat "$MSrepositoryFullFileName" | grep -P '^# deb .* https://packages\.microsoft\.com/' > /dev/null; then
            rm "$MSrepositoryFullFileName"
        elif ! grep -i "$MSrepositoryVersion" "$MSrepositoryFullFileName"; then
            rm "$MSrepositoryFullFileName"
        elif ! grep -iEq '^deb \[.*(signed-by=.*)\]' "$MSrepositoryFullFileName"; then
            rm "$MSrepositoryFullFileName"
        else
            echo "# MS repository already installed, enabled and signed"
        fi
    fi

    # Check if MS repository is already installed
    if [ ! -f "$MSrepositoryFullFileName" ]; then
        echo "# MS repository not installed, start with installation process"

        # Download and deploy source list for MS package deployment
        if [ "$resultMEMSetup" = true ]; then
            echo "# Download source list for MS package deployment"
            # download source list
            curl -o "$MSrepositoryFileName" https://packages.microsoft.com/config/$distroName/$distroVersion/prod.list

            if grep -q '404: Not Found' "$MSrepositoryFileName"; then
                echo "|__ The downloaded repository file is not available for this distribution"
                rm "$MSrepositoryFileName"
                resultMEMSetup=false
            else
                # if missed, add signed-by
                sed -i -E '/^deb \[.*signed-by=/!s/(^deb \[.*arch=.*)\]/\1 signed-by='"$MSrepositoryGpgFile"'\]/g' "./$MSrepositoryFileName"

                # update gpg file name
                sed -i "s|microsoft-prod.gpg|microsoft.gpg|g" "./$MSrepositoryFileName"

                # move to source.list.d
                mv "./$MSrepositoryFileName" "$MSrepositoryFullFileName"
            fi
        else
            echo "# Previous Failure => Dont download source list for MS package deployment"
        fi
        echo
    else
        echo "# MS repository already available"
    fi

    # Update the repository metadata
    if [ "$resultMEMSetup" = true ]; then
        echo "# Update APT list again"
        apt-get update
        if [ "$?" -ne 0 ]; then
            resultMEMSetup=false
        fi
    else
        echo "# Previous Failure => Dont update APT list again"
    fi
    echo

    # Check if MS Edge is already installed
    if ! which microsoft-edge-stable >/dev/null; then
        # Application installation
        if [ "$resultMEMSetup" = true ]; then
            echo "# Install MS Edge for Linux"
            apt-get install -y microsoft-edge-stable
            if [ "$?" -ne 0 ]; then
                resultMEMSetup=false
                rm "$MSEdgeRepositoryFile"*
            fi
        else
            echo "# Previous Failure => Dont install MS Edge for Linux"
        fi
        echo
    fi

    # Check if MEM is already installed
    if ! which intune-portal >/dev/null; then
        # remove old configuration
        echo "# Remove old configuration"
        listOfDirs="""\
        /home/*/.cache/intune-portal \
        /home/*/.config/intune \
        /home/*/.config/microsoft-identity-broker \
        /home/*/.local/state/microsoft-identity-broker \
        /var/lib/microsoft-identity-broker \
        /var/lib/microsoft-identity-device-broker \
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

        # Application installation
        if [ "$resultMEMSetup" = true ]; then
            echo "# Install MS Intune App for Linux"
            apt-get install -y intune-portal
            if [ "$?" -ne 0 ]; then
                resultMEMSetup=false
            fi
        else
            echo "# Previous Failure => Dont install MS Intune App for Linux"
        fi
        echo
    fi
else
    echo "# Failure by install pre-requisites"
fi

# If installation is done, add post-installation tasks
if which intune-portal > /dev/null; then
    echo "# MS Intune App installed"

    # check if intune-portal service is enabled
    if systemctl is-enabled intune-daemon.socket > /dev/null 2>&1; then
        echo "# intune-portal service is enabled"
    else
        echo "# Enable intune-portal service"
        systemctl enable intune-daemon.socket
    fi

    # check if microsoft-identity-broker is installed
    if dpkg -l | grep microsoft-identity-broker | grep '^ii' | awk '{print $2 "\t" $3}' > /dev/null; then
        echo "# Microsoft Identity Broker is installed"
    else
        echo "# Microsoft Identity Broker is not installed"
        echo "# Install Microsoft Identity Broker"
        apt-get install -y microsoft-identity-broker
    fi

    # check if microsoft-identity-diagnostics is installed
    if dpkg -l | grep microsoft-identity-diagnostics | grep '^ii' | awk '{print $2 "\t" $3}' > /dev/null; then
        echo "# Microsoft Identity Diagnostics is installed"
    else
        echo "# Microsoft Identity Diagnostics is not installed"
        echo "# Install Microsoft Identity Diagnostics"
        apt-get install -y microsoft-identity-diagnostics
    fi
else
    echo "# MS Intune App is not installed"
fi
