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

# set list of apps
app_list="curl
wget
zip
unzip
nano
cifs-utils
libplist-utils
libnss3-tools
gpg
apt-transport-https
libpam-pwquality
ubuntu-restricted-addons
rsyslog
cron
tar
software-properties-common
openssl
git-all
fail2ban
"

###
### check if network connection exists
###
{ #try
   /usr/bin/curl -I https://www.google.at > /dev/null
} || { #catch
   echo "no internet connection"
   exit 0
}

###
### run system update
###
# check if apt-get is installed
if which apt-get > /dev/null; then
    echo "# update the apt-get lists"
    /usr/bin/apt-get update 
    
    echo "# fix broken dependencies"
    /usr/bin/apt --fix-broken install
    
    echo "# run system upgrade with apt-get"
    /usr/bin/apt-get -y upgrade && /usr/bin/apt-get -y dist-upgrade && /usr/bin/apt-get -y autoremove && /usr/bin/apt-get -y autoclean
else
    echo "# apt-get is not installed"
fi

# check if snap is installed
if which snap > /dev/null; then
    echo "# start system upgrade with snap"
    /usr/bin/snap refresh
else
    echo "# snap is not installed"
fi

###
### run app deployment
###
if which apt-get > /dev/null; then
    echo "# update the apt-get lists"
    /usr/bin/apt-get update

    echo "# install defined apps"
    /usr/bin/apt-get -y install $(echo $app_list)
else
    echo "# apt-get is not installed"
fi

# start rsyslog service with my config
if [ -f "/usr/sbin/rsyslogd" ]; then
    echo 
    echo "# rsyslogd successfully installed"
    echo -e "#  Default rules for rsyslog.\ncron.*                         /var/log/cron.log\n\n*.=info;*.=notice;*.=warn;\\\\ \n       auth,authpriv.none;\\\\\n       cron,daemon.none;\\\\\n       mail,news.none          -/var/log/messages" > /etc/rsyslog.d/40-custom.conf
    systemctl restart rsyslog
fi

# start cron service
if which cron > /dev/null; then
    echo 
    echo "# cron successfully installed"
    #systemctl status cron
    systemctl enable cron
    systemctl start cron
    #systemctl status cron
fi

# start fail2ban service with my config
if [ -f "/usr/bin/fail2ban-server" ]; then
    echo 
    echo "# fail2ban successfully installed"
    echo -e "[DEFAULT]\nbantime  = 60m\nfindtime = 10m\nmaxretry = 3\n\n[sshd]\nenabled = true\nfilter  = sshd" > /etc/fail2ban/jail.d/jail.local
    systemctl enable fail2ban
    systemctl start fail2ban
fi

if which gpg > /dev/null; then
    ###
    ### add Microsoft GPG public key
    ###
    echo "# add Microsoft GPG public key"
    MSgpgFileName='microsoft-prod.gpg'
    MSgpgFilePath="/usr/share/keyrings"
    MSgpgFullFileName="$MSgpgFilePath/$MSgpgFileName"

    # download Microsoft GPG public key
    /usr/bin/curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > "./$MSgpgFileName"

    # install Microsoft GPG public key
    /usr/bin/install -o root -g root -m 644 "./$MSgpgFileName" "$MSgpgFilePath/"
    /usr/bin/rm "./$MSgpgFileName"

    ###
    ### add Microsoft repositories
    ###

    ### Microsoft Prod
    echo "# add Microsoft Prod repository"
    MSrepositoryFileName='microsoft-prod.list'
    MSrepositoryFullFileName="/etc/apt/sources.list.d/$MSrepositoryFileName"
    MSrepositoryGpgFile=$(echo "$MSgpgFullFileName" | sed 's,\/,\\\/,g')

    # download source list
    /usr/bin/curl -o "$MSrepositoryFileName" https://packages.microsoft.com/config/$distroName/$distroVersion/prod.list

    # if missed, add signed-by
    /usr/bin/sed -i -E '/^deb \[.*signed-by=/!s/(^deb \[.*arch=.*)\]/\1 signed-by='"$MSrepositoryGpgFile"'\]/g' "./$MSrepositoryFileName"

    # move to source.list.d
    /usr/bin/mv "./$MSrepositoryFileName" "$MSrepositoryFullFileName"

    ### Microsoft Edge
    echo "# add Microsoft Edge repository"
    MSEdgeRepositoryFile='/etc/apt/sources.list.d/microsoft-edge.list'

    # download source list
    /usr/bin/sh -c "echo 'deb [arch=amd64 signed-by=$MSgpgFullFileName] https://packages.microsoft.com/repos/edge stable main' > $MSEdgeRepositoryFile"
fi

echo "# system configuration finished"
exit 0