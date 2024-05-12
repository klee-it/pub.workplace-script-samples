#!/bin/sh

#
## location: all client devices
#
## configuration
## |__ Execution context: User
## |__ Execution frequency: Every 1 week
## |__ Execution retries: No retries
#
## notes:
## |__ rollout by Intune
#

IntunePortal="/opt/microsoft/intune/bin/intune-portal"

# check if intune-portal is installed
if which "$IntunePortal" >/dev/null; then
    echo "# start intune-portal to re-authenticate user"
    (exec env INTUNE_NO_LOG_STDOUT=1 $IntunePortal &> /dev/null & )
else
    echo "# intune-portal is not installed"
fi
