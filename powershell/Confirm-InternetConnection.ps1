<#
.SYNOPSIS
    This script performs a check to confirm if there is an active internet connection.

.DESCRIPTION
    This script attempts to connect to a well-known website (e.g., google.com) to determine if there is an active internet connection. It returns a boolean value indicating the presence or absence of an internet connection.

.PARAMETER FQDN
    The FQDN to test the internet connection against. Default is "http://www.google.com".

.OUTPUTS
    [PSCustomObject]
        - IsConnected: A boolean value indicating if the internet connection is available.
        - VerifiedHost: The FQDN that was tested.

.EXAMPLE
    PS> Confirm-InternetConnection
    True

    PS> Confirm-InternetConnection -FQDN "http://www.bing.com"
    True

.NOTES
    Author: klee-it
    PowerShell Version: 5.1, 7.x
    Additional information: This function requires internet access to perform the check.
    Dependencies: Set-ClientTlsProtocols
#>

###
### FUNCTION: check if internet connection is available
###
Function Confirm-InternetConnection
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding(DefaultParameterSetName="Default")]

    param(
        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [String] $FQDN = 'www.google.com',

        [Parameter(Mandatory=$false)]
        [HashTable] $AdditionalParameters = @{}
    )

    try
    {
        # tell PowerShell to use TLS12 or higher 
        $SystemTlsVersion = [Net.ServicePointManager]::SecurityProtocol
        Set-ClientTlsProtocols
        
        # check if internet connection is available
        Write-Verbose -Message "Check if internet connection is available..."
        $DefaultParameters = @{
            ComputerName = $FQDN
            Quiet = $true
            Count = 3
        }
        $TestConnectionSplat = $DefaultParameters + $AdditionalParameters
        Write-Verbose -Message "Splat: $($TestConnectionSplat | ConvertTo-Json -Compress)"

        $IsConnected = Test-Connection @TestConnectionSplat
        Write-Verbose -Message "Is connected: $($IsConnected)"

        # return output object
        Write-Output -InputObject ( [PSCustomObject]@{ IsConnected = $IsConnected; VerifiedHost = $FQDN } )

        # clean-up
        Get-Variable -Name 'IsConnected' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
    }
    catch
    {
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
    finally
    {
        # Be nice and set session security protocols back to how we found them.
        [Net.ServicePointManager]::SecurityProtocol = $SystemTlsVersion
    }
}
