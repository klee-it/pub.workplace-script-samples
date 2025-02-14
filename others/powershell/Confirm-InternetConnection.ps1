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
        Write-Verbose -Message "Splat: $($TestConnectionSplat | ConvertTo-Json -Compress)" -StdOut 'None'

        $IsConnected = Test-Connection @TestConnectionSplat
        Write-Verbose -Message "Is connected: $($IsConnected)"

        Write-Output -InputObject ( [PSCustomObject]@{ IsConnected = $IsConnected; VerifiedHost = $FQDN } )

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
