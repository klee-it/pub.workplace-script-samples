###
### FUNCTION: confirm if the script is running as admin
###
function Confirm-RunAsAdmin
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding(DefaultParameterSetName="Default")]

    param()
    
    try
    {
        # get true/false if user has admin permissions or not
        $WindowsPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        Write-Output -InputObject ( $WindowsPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator") )
        
        # alternative
        # ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    }
    catch
    {
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
}
