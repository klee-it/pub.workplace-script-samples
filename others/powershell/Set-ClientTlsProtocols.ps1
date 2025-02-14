###
### FUNCTION: set client tls protocols
###
Function Set-ClientTlsProtocols
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding(DefaultParameterSetName="Default")]

    param()
    
    # set function parameters
    try
    {
        # find and include all available protocols 'Tls12' or higher
        $AvailableTls = [enum]::GetValues('Net.SecurityProtocolType') | Where-Object { $_ -ge 'Tls12' }
    
        $AvailableTls.ForEach({
            [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor $_
        })
    }
    catch
    {
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
}
