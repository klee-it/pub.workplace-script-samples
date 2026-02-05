#!/bin/bash

#
## basic information:
## |__ This script performs system upgrades on client devices.
#
## location: all client devices
#

# show current script path
echo "# Current script location: $(pwd)"

# show disk space information
echo "# Current disk space information:"
echo "$(df -h)"

# set parameters
LogFile="/var/log/apt/system_update.log"

# check if curl is installed
if ! which curl > /dev/null; then
    echo "# curl not found, start installation"
    apt-get update
    apt-get install -y curl
fi

# check if network connection exists
echo
echo "# check if network connection exists"
{ #try
   curl -I https://www.google.at > /dev/null
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
    apt-key adv --refresh-keys
else
    echo "|__ apt-key is not installed"
fi

# check if apt-get is installed
echo
echo "# check if apt-get is installed"
if which apt-get > /dev/null; then

    echo "# update apt-get lists"
    apt-get update > "$LogFile" 2>&1

    echo "# install pre-requisite packages"
    listOf_prereqs="gpg apt-transport-https ubuntu-restricted-addons coreutils grep sed software-properties-common"
    apt-get install -y $listOf_prereqs

    # clean-up problematic repositories and source list files
    echo "# get list of problematic repositories and source list files"
    sourceListIssues=$(grep -P '^(?:Err|E|Warn|W):.+(?:http|https|sources.list.d)' "$LogFile" | sort -u)

    echo "# disable repositories"
    sourceListRepos=$(echo "$sourceListIssues" | grep -Po 'http[s]?://[^ ]+' | sort -u)
    for repo in $sourceListRepos; do
        echo "|__ repository (orig): $repo"
        repo=${repo%/}
        echo "|__ repository (trimmed): $repo"

        # disable repository by commenting out source from .list files
        listFiles=$(grep -rl "$repo" /etc/apt/sources.list /etc/apt/sources.list.d/*.list)
        for listFile in $listFiles; do
            echo "|__|__ list file: $listFile"
            sed -i -e "s|^deb.* $repo|# &|" "$listFile"
            echo "|__|__|__ repository in list file commented out"
        done

        # disable repository by commenting out source from .sources files
        # find repo in .sources file and add a additional line "Enabled: 0" below it, also check if there is a line "Enabled: 1" and change it to "Enabled: 0"
        sourceFiles=$(grep -rl "$repo" /etc/apt/sources.list.d/*.sources)
        for sourceFile in $sourceFiles; do
            echo "|__|__ source file: $sourceFile"
            # check if there is a line "Enabled: 1" and change it to "Enabled: 0"

            # set helper variables
            TEMP_FILE="$(mktemp)"
            block=""

            # Read the file line by line
            while IFS= read -r line || [ -n "$line" ]; do
                if [[ "$line" =~ ^Types: ]]; then
                    # Process previous block
                    if [[ -n "$block" ]]; then
                        if echo "$block" | grep -q "$repo"; then
                            if echo "$block" | grep -q "^Enabled:"; then
                                block=$(echo "$block" | sed 's/^Enabled:.*/Enabled: no/')
                            else
                                block="$block""Enabled: no"
                            fi
                            echo "$block" >> "$TEMP_FILE"
                            block=""
                        else
                            echo "$block" >> "$TEMP_FILE"
                            block=""
                        fi
                    fi
                fi
                block="$block"$'\n'"$line"
            done < "$sourceFile"

            # Process last block
            if [[ -n "$block" ]]; then
                if echo "$block" | grep -q "$repo"; then
                    if echo "$block" | grep -q "^Enabled:"; then
                        block=$(echo "$block" | sed 's/^Enabled:.*/Enabled: no/')
                    else
                        block="$block"$'\n'"Enabled: no"
                    fi
                    echo "$block" >> "$TEMP_FILE"
                else
                    echo "$block" >> "$TEMP_FILE"
                fi
            fi

            # Replace original file
            mv "$TEMP_FILE" "$sourceFile"
            echo "|__|__|__ temp file: $TEMP_FILE"
            echo "|__|__|__ repository in sources file disabled"
        done

        # remove repository from apt cache (if exists)
        if apt-cache policy | grep -q "$repo"; then
            #apt-add-repository --remove "$repo"
            # echo "|__|__ repository disabled"
            echo "|__|__ (cache) repository should be disabled"
        else
            echo "|__|__ (cache) repository not found"
        fi
    done

    echo "# disable source list files"
    sourceListFiles=$(echo "$sourceListIssues" | while IFS= read -r repoLine; do echo "$repoLine" | grep -Po '/etc/apt/sources\.list\.d/[^ ]+\.list' | head -n 1; done | sort -u)
    for file in $sourceListFiles; do
        echo "|__ source list file: $file"
        if [ "$file" == "/etc/apt/sources.list" ]; then
            echo "|__|__ skip main source list"
            continue
        fi
        if [ -f "$file" ]; then
            mv "$file" "$file.disabled"
            echo "|__|__ source list disabled"
        else
            echo "|__|__ file does not exist: $file"
        fi
    done

    echo "# remove disabled microsoft source list files"
    disabledMSFiles=$(ls /etc/apt/sources.list.d/microsoft-*.list.disabled 2>/dev/null)
    for disabledFile in $disabledMSFiles; do
        echo "|__ remove disabled file: $disabledFile"
        rm "$disabledFile"
        echo "|__|__ file removed"
    done

    # re-run apt update if any repositories or source list files were disabled
    if [ -n "$sourceListRepos" ] || [ -n "$sourceListFiles" ]; then
        echo "# re-run apt-get update after disabling problematic repositories and source list files"
        apt-get update > "$LogFile" 2>&1
    fi

    # check if source lists can be modernized
    echo "# check if source lists can be modernized"
    if grep -Pc '^N:.+apt modernize-sources' "$LogFile" > /dev/null; then
        echo "|__ modernize source lists"
        apt -y modernize-sources

        echo "|__ re-run apt-get update after modernizing source lists"
        apt-get update > "$LogFile" 2>&1
    fi 

    # check if source lists are broken
    echo "# check if source lists are broken"
    APT_check=$(grep -Pc '^(?:Err|E):' "$LogFile")

    if [ "$APT_check" == "0" ]; then
        echo "# fix dpkg configuration"
        dpkg --configure -a
        
        echo "# fix broken dependencies"
        apt --fix-broken install

        echo "# remove unused kernels"
        apt-get -y purge $(dpkg --list | grep 'linux-image-.*-generic' | grep '^rc' | awk '{print $2}' | sort -u)

        echo "# update drivers and kernel modules"
        if which ubuntu-drivers > /dev/null; then
            echo "|__ update ubuntu drivers"
            ubuntu-drivers autoinstall
        else
            echo "|__ ubuntu-drivers is not installed"
        fi

        echo "# rebuild dkms modules"
        if which dkms > /dev/null; then
            echo "|__ rebuild dkms modules"
            dkms autoinstall
        else
            echo "|__ dkms is not installed"
        fi

        echo "# run system upgrade by apt-get"
        apt-get -y upgrade && apt-get -y autoremove && apt-get -y autoclean
    else
        echo "|__ source lists are broken, skip update process"
        cat "$LogFile"

        echo "|__ show list of source files"
        ls -la /etc/apt/sources.list.d/

        echo "|__ show content of .list and .sources files"
        for file in /etc/apt/sources.list /etc/apt/sources.list.d/*; do
            echo "|__|__ file: $file"
            cat "$file"
        done
    fi
else
    echo "|__ apt-get is not installed"
fi

# check if snap is installed
echo
echo "# invoke update process by snap"
if which snap > /dev/null; then
    echo "|__ start system upgrade with snap"
    snap refresh
else
    echo "|__ snap is not installed"
fi

# check if flatpak is installed
echo
echo "# invoke update process by flatpak"
if which flatpak > /dev/null; then
    echo "|__ start system upgrade with flatpak"
    flatpak update -y
else
    echo "|__ flatpak is not installed"
fi

exit 0
