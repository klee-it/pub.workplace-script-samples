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
### run app deployment
###
# set list of apps
echo "# install defined apps"
app_list="curl
wget
zip
unzip
tar
nano
vim
cifs-utils
libplist-utils
libnss3-tools
coreutils
grep
sed
software-properties-common
gpg
apt-transport-https
ubuntu-release-upgrader-core
ubuntu-drivers-common
dkms
jq
yq
htop
7zip
ca-certificates
rsync
openssh-client
openssh-server
openssl
ubuntu-restricted-addons
libpam-pwquality
rsyslog
cron
fail2ban
git-all
"
apt-get -y install $(echo $app_list)

###
### run app configuration
###
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
if [ -f "fail2ban-server" ]; then
    echo 
    echo "# fail2ban successfully installed"
    echo -e "[DEFAULT]\nbantime  = 60m\nfindtime = 10m\nmaxretry = 3\n\n[sshd]\nenabled = true\nfilter  = sshd" > /etc/fail2ban/jail.d/jail.local
    systemctl enable fail2ban
    systemctl start fail2ban
fi

echo "# system configuration finished"
exit 0