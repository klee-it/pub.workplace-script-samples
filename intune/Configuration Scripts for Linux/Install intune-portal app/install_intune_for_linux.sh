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

        # check if apt-key is installed
        echo
        echo "# invoke gpg key update process"
        if which apt-key > /dev/null; then
            echo "|__ update gpg keys"
            /usr/bin/apt-key adv --refresh-keys
        else
            echo "|__ apt-key is not installed"
        fi

        # Prepare the system for the installation
        echo
        echo "# invoke update process by apt-get"
        /usr/bin/apt-get update

        echo
        echo "# fix dpkg configuration"
        /usr/bin/dpkg --configure -a
        
        echo
        echo "# fix broken dependencies"
        /usr/bin/apt --fix-broken install

        echo
        echo "run system upgrade by apt-get"
        /usr/bin/apt-get -y upgrade && /usr/bin/apt-get -y autoremove && /usr/bin/apt-get -y autoclean

        # Install prerequisites
        echo 
        echo "# Install prerequisites"
        resultInstallation=true

        listOf_prereqs="curl wget zip unzip nano cifs-utils libplist-utils libnss3-tools gpg apt-transport-https libpam-pwquality ubuntu-restricted-addons"
        for appname in $listOf_prereqs; do
            echo "# Installation of: ${appname}"
            /usr/bin/apt-get install -y $appname
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
            MSgpgFileName='microsoft-prod.gpg'
            MSgpgFilePath="/usr/share/keyrings"
            MSgpgFullFileName="$MSgpgFilePath/$MSgpgFileName"

            if [ ! -f "$MSgpgFullFileName" ]; then
                echo "# Microsoft GPG public key not installed, start with installation process"

                # Install Microsoft GPG public key
                if [ "$resultMEMSetup" = true ]; then
                    echo "# Install Microsoft GPG public key"
                    { # try
                        # download Microsoft GPG public key
                        /usr/bin/curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > "./$MSgpgFileName"
                        # install Microsoft GPG public key
                        /usr/bin/install -o root -g root -m 644 "./$MSgpgFileName" "$MSgpgFilePath/"
                        /usr/bin/rm "./$MSgpgFileName"
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
                if /usr/bin/cat "$MSEdgeRepositoryFile" | /usr/bin/grep '# disabled' >/dev/null; then
                    /usr/bin/rm "$MSEdgeRepositoryFile"
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
                    /usr/bin/sh -c "echo 'deb [arch=amd64 signed-by=$MSgpgFullFileName] https://packages.microsoft.com/repos/edge stable main' > $MSEdgeRepositoryFile"
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
            MSrepositoryGpgFile=$(echo "$MSgpgFullFileName" | /usr/bin/sed 's,\/,\\\/,g')

            if [ -f "$MSrepositoryFullFileName" ]; then
                # Check if MS Repository is disabled
                if /usr/bin/cat "$MSrepositoryFullFileName" | /usr/bin/grep '# disabled' > /dev/null; then
                    /usr/bin/rm "$MSrepositoryFullFileName"
                elif ! /usr/bin/grep -i "$MSrepositoryVersion" "$MSrepositoryFullFileName"; then
                    /usr/bin/rm "$MSrepositoryFullFileName"
                elif ! /usr/bin/grep -iEq '^deb \[.*(signed-by=.*)\]' "$MSrepositoryFullFileName"; then
                    /usr/bin/rm "$MSrepositoryFullFileName"
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
                    { # try
                        # download source list
                        /usr/bin/curl -o "$MSrepositoryFileName" https://packages.microsoft.com/config/$distroName/$distroVersion/prod.list
                        # if missed, add signed-by
                        /usr/bin/sed -i -E '/^deb \[.*signed-by=/!s/(^deb \[.*arch=.*)\]/\1 signed-by='"$MSrepositoryGpgFile"'\]/g' "./$MSrepositoryFileName"
                        # move to source.list.d
                        /usr/bin/mv "./$MSrepositoryFileName" "$MSrepositoryFullFileName"
                    } || { # catch
                        resultMEMSetup=false
                    }
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
                /usr/bin/apt-get update
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
                    /usr/bin/apt-get install -y microsoft-edge-stable
                    if [ "$?" -ne 0 ]; then
                        resultMEMSetup=false
                        /usr/bin/rm "$MSEdgeRepositoryFile"*
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
                /usr/bin/rm -r /home/*/.config/intune/*
                /usr/bin/rm -r /home/*/.cache/intune-portal/*
                /usr/bin/rm -r /home/*/.config/microsoft-identity-broker/*
                /usr/bin/rm -r /home/*/.local/state/microsoft-identity-broker/*
                /usr/bin/rm -r /var/lib/microsoft-identity-broker/*

                # Application installation
                if [ "$resultMEMSetup" = true ]; then
                    echo "# Install MS Intune App for Linux"
                    /usr/bin/apt-get install -y intune-portal
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
    else
        echo "# Distro not supported"
    fi
    echo

    # If installation is done, add post-installation tasks
    if which intune-portal > /dev/null; then
        echo "# MS Intune App installed"

        # check if microsoft-identity-broker is installed
        if /usr/bin/dpkg -l | /usr/bin/grep microsoft-identity-broker | /usr/bin/grep '^ii' | /usr/bin/awk '{print $2 "\t" $3}' > /dev/null; then
            echo "# Microsoft Identity Broker is installed"
        else
            echo "# Microsoft Identity Broker is not installed"
            echo "# Install Microsoft Identity Broker"
            /usr/bin/apt-get install -y microsoft-identity-broker
        fi

        # check if microsoft-identity-diagnostics is installed
        if /usr/bin/dpkg -l | /usr/bin/grep microsoft-identity-diagnostics | /usr/bin/grep '^ii' | /usr/bin/awk '{print $2 "\t" $3}' > /dev/null; then
            echo "# Microsoft Identity Diagnostics is installed"
        else
            echo "# Microsoft Identity Diagnostics is not installed"
            echo "# Install Microsoft Identity Diagnostics"
            /usr/bin/apt-get install -y microsoft-identity-diagnostics
        fi

        # echo "# create symlink for autostart..."
        # IntunePortal_Path="/usr/share/applications/intune-portal.desktop"
        # IntunePortal_SymlinkPath="/etc/xdg/autostart"
        # IntunePortal_SymlinkFile="$IntunePortal_SymlinkPath/intune-portal.desktop"

        # if [ -f "$IntunePortal_Path" ]
        # then
        #     if [ ! -e "$IntunePortal_SymlinkFile" ]
        #     then
        #         if [ -d "$IntunePortal_SymlinkPath" ]
        #         then
        #             ln -s "$IntunePortal_Path" "$IntunePortal_SymlinkFile"
        #             echo "|__ Symlink created: $IntunePortal_SymlinkFile"
        #         else
        #             echo "|__ Directory does not exist: $IntunePortal_SymlinkPath"
        #         fi
        #     else
        #         echo "|__ Symlink already exists: $IntunePortal_SymlinkFile"
        #     fi
        # else
        #     echo "|__ File does not exist: $IntunePortal_Path"
        # fi
    else
        echo "# MS Intune App is not installed"
    fi
    echo
else
    echo "# Linux system/distribution not supported"
fi
