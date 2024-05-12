#!/bin/bash

#
## location: all client devices
#
## dependencies:
## |__ authorise to send Apple events to System Events
## |__ create "Configuration Profile"
## |__|__ Type: Privacy Preferences Policy Control
## |__|__ App Access:
## |__|__|__ Identifier: com.jamf.management.Jamf
## |__|__|__ Code Requirement: anchor apple generic and identifier "com.jamf.management.Jamf" and (certificate leaf[field.1.2.840.113635.100.6.1.9] /* exists */ or certificate 1[field.1.2.840.113635.100.6.2.6] /* exists */ and certificate leaf[field.1.2.840.113635.100.6.1.13] /* exists */ and certificate leaf[subject.OU] = "483DWKW443")
## |__|__|__ App or Service:
## |__|__|__|__ Service: AppleEvents
## |__|__|__|__ Access: Allow
## |__|__|__|__ Receiver Identifier: com.apple.systemevents
## |__|__|__|__ Receiver Code Requirement: identifier "com.apple.systemevents" and anchor apple
#
## notes:
## |__ rollout by Jamf Pro
#

echo "### script starts ###"

ExitCode=0

### Define prefix by location
LOCATIONS=$(cat << EOF
"Location1":LOC1
"Location2":LOC2
EOF
)

### Get current computer details
COMPUTERNAME=$(scutil --get ComputerName | tr "[:lower:]" "[:upper:]")
#SERIALNUMBER=$(ioreg -l | grep IOPlatformSerialNumber | /usr/bin/awk '/IOPlatformSerialNumber/ {print $4}' | tr -d '"')
# SERIALNUMBER=$(/usr/sbin/system_profiler SPHardwareDataType | /usr/bin/awk '/Serial Number/ {print $NF}')

### Check if current computer name matches naming convention
if [[ ! $COMPUTERNAME =~ ^[a-zA-Z]{3,4}-[a-zA-Z0-9]{10,}$ ]]; then
    ### Get device location from computername
    DEVICELOCATION=$(echo "$COMPUTERNAME" | cut -c 1-3)
    NEWDEVICELOCATION=""
    
    if [[ $LOCATIONS == *:$DEVICELOCATION* ]]; then
        echo "Auto selection: $DEVICELOCATION"
        NEWDEVICELOCATION=$DEVICELOCATION
    else
        ### Set location by user selection
        LIST_OF_OFFICES=($(echo "$LOCATIONS" | cut -d ":" -f1))
        LIST_OF_OFFICES=$(IFS=',';echo "${LIST_OF_OFFICES[*]}";IFS=$' \t\n')

        { # try
        ## Current User
        CURRENT_USER=$(ls -l /dev/console | awk '{print $3}')
        CURRENT_USER_UID=$(id -u $CURRENT_USER)
        
        OFFICE=$(launchctl asuser $CURRENT_USER_UID /usr/bin/osascript << EOF
tell application "System Events"
activate
set office to (choose from list {$LIST_OF_OFFICES} with title "Select your office" with prompt "Dear,\nYour computer name doesn't meet the naming convention and needs to be changed.\nPlease refer to the link https://knowledgebase\n\nTo continue it's important that you select your associated office from the list below.")
end tell
EOF
)
        } && { # continue
            echo "User selection: $OFFICE"
            NEWDEVICELOCATION="$(echo "$LOCATIONS" | grep "^\"$OFFICE\":" | cut -d ":" -f2)"
        } || { # catch
            exit $?
            ExitCode=$?
        }

    fi
    echo "Device location: $NEWDEVICELOCATION"

    if [ "$NEWDEVICELOCATION" = "" ]; then
        echo "Device location not selected/found"
        ExitCode=1
    else
        ### Define new computer name
        NEWPREFIX="$NEWDEVICELOCATION-"
        # NEWCOMPUTERNAME="$NEWPREFIX$SERIALNUMBER"
        echo "New prefix: $NEWPREFIX"
        # echo "New computer name: $NEWCOMPUTERNAME"
        
        ### Set new computer name
        # /usr/sbin/scutil --set ComputerName $NEWCOMPUTERNAME
        # /usr/sbin/scutil --set LocalHostName $NEWCOMPUTERNAME
        # /usr/sbin/scutil --set HostName $NEWCOMPUTERNAME
        # dscacheutil -flushcache

        # jamf setComputerName -name $NEWCOMPUTERNAME
        jamf setComputerName -useSerialNumber -prefix "$NEWPREFIX"
    fi
else
    echo "Computer name already fits naming convention: $COMPUTERNAME"
fi

echo "### Script ends ###"

exit $ExitCode