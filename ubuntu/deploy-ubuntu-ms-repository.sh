#!/bin/sh

#
## basic information:
## |__ This script is used to deploy apps and configure new client devices
#
## location: all client devices
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
if [ "$distroName" = "debian gnu/linux" ]; then
    distroName="debian"
fi
distroVersion=$(echo $distroVersion | tr '[:upper:]' '[:lower:]')
distroCodeName=$(echo $distroCodeName | tr '[:upper:]' '[:lower:]')

echo "# Distro: ${distroName} ${distroVersion} (${distroCodeName})"

###
### check if network connection exists
###
{ #try
   curl -I https://www.google.at > /dev/null
} || { #catch
   echo "no internet connection"
   exit 0
}

###
### update the apt-get lists
###
if which apt-get > /dev/null; then
    echo "# update the apt-get lists"
    apt-get update
else
    echo "# apt-get is not installed"
    exit 0
fi

###
### deploy Microsoft repositories
###
if which gpg > /dev/null; then
    ###
    ### add Microsoft GPG public key
    ###
    echo "# add Microsoft GPG public key"
    MSgpgFileName='microsoft.gpg'
    MSgpgFilePath="/usr/share/keyrings"
    MSgpgFullFileName="$MSgpgFilePath/$MSgpgFileName"

    # download Microsoft GPG public key
    curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > "./$MSgpgFileName"

    # install Microsoft GPG public key
    install -o root -g root -m 644 "./$MSgpgFileName" "$MSgpgFilePath/"
    rm "./$MSgpgFileName"

    ###
    ### add Microsoft repositories
    ###

    ### Microsoft Prod
    echo "# add Microsoft Prod repository"
    MSrepositoryFileName='microsoft-prod.list'
    MSrepositoryFullFileName="/etc/apt/sources.list.d/$MSrepositoryFileName"
    MSrepositoryGpgFile=$(echo "$MSgpgFullFileName" | sed 's,\/,\\\/,g')

    # download source list
    curl -o "$MSrepositoryFileName" https://packages.microsoft.com/config/$distroName/$distroVersion/prod.list

    if grep -q '404: Not Found' "$MSrepositoryFileName"; then
        echo "|__ The downloaded repository file is not available for this distribution"
        rm "$MSrepositoryFileName"
    else
        # if missed, add signed-by
        sed -i -E '/^deb \[.*signed-by=/!s/(^deb \[.*arch=.*)\]/\1 signed-by='"$MSrepositoryGpgFile"'\]/g' "./$MSrepositoryFileName"

        # update gpg file name
        sed -i "s|microsoft-prod.gpg|microsoft.gpg|g" "./$MSrepositoryFileName"

        # move to source.list.d
        mv "./$MSrepositoryFileName" "$MSrepositoryFullFileName"
    fi

    ### Microsoft Edge
    echo "# add Microsoft Edge repository"
    MSEdgeRepositoryFile='/etc/apt/sources.list.d/microsoft-edge.list'

    # create source list file
    sh -c "echo 'deb [arch=amd64 signed-by=$MSgpgFullFileName] https://packages.microsoft.com/repos/edge stable main' > $MSEdgeRepositoryFile"
#     cat << EOF > $MSEdgeRepositoryFile
# Types: deb
# URIs: https://packages.microsoft.com/repos/edge
# Suites: stable
# Components: main
# Architectures: amd64,arm64,armhf
# Signed-By: $MSgpgFullFileName
# EOF

    ### Microsoft VSCode
    echo "# add Microsoft VSCode repository"
    MSVSCodeRepositoryFile='/etc/apt/sources.list.d/vscode.list'
    # MSVSCodeRepositoryFile='/etc/apt/sources.list.d/vscode.sources'

    # create source list file
    sh -c "echo 'deb [arch=amd64 signed-by=$MSgpgFullFileName] https://packages.microsoft.com/repos/code stable main' > $MSVSCodeRepositoryFile"
#     cat << EOF > $MSVSCodeRepositoryFile
# Types: deb
# URIs: https://packages.microsoft.com/repos/code
# Suites: stable
# Components: main
# Architectures: amd64,arm64,armhf
# Signed-By: $MSgpgFullFileName
# EOF

    ###
    ### update the apt-get lists
    ###
    echo "# update the apt-get lists"
    apt-get update
    
else
    echo "# gpg is not installed"
fi

###
### update the apt-get lists
###
if which apt-get > /dev/null; then
    echo "# update the apt-get lists"
    apt-get update
fi

echo "# system configuration finished"
exit 0