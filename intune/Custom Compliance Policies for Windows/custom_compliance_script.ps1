#
## location: all client devices
#
## notes:
## |__ Rollout by Intune Custom Compliance Policy
## |__ This script checks the host name of a device
#
## Error Codes:
## |__ 65007: Script returned failure
## |__ 65008: Setting missing in the script result
## |__ 65009: Invalid json for the discovered setting
## |__ 65010: Invalid datatype for the discovered setting
#

# set script parameters
$OutputHash = [ordered]@{
    windows_host_name          = 'NOK'
}

###
### Hostname check
###
# This variable represents the current host name of the device
$COMPUTERNAME = "$( $env:computername.ToUpper() )"

# check if the host name matches the device naming convention
if ($COMPUTERNAME -match '^[a-zA-Z]{3,4}-[a-zA-Z0-9]{7,}$')
{
    $OutputHash.windows_host_name = 'OK'
}

return $OutputHash | ConvertTo-Json -Compress
