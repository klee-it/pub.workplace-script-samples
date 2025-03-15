<#
.SYNOPSIS
    Gets details of the current Windows principal.

.DESCRIPTION
    This function retrieves details of the current Windows principal, including the name, SID, authentication type, 
    whether the principal is authenticated, whether it is a system account, whether it has administrative privileges, 
    and the groups the principal belongs to.

.PARAMETER None
    This function does not take any parameters.

.OUTPUTS
    [PSCustomObject]
        - Name: The name of the Windows principal.
        - Sid: The SID of the Windows principal.
        - AuthenticationType: The authentication type of the Windows principal.
        - IsAuthenticated: Indicates whether the Windows principal is authenticated.
        - IsSystem: Indicates whether the Windows principal is a system account.
        - IsAdmin: Indicates whether the Windows principal has administrative privileges.
        - Groups: The groups the Windows principal belongs to.

.EXAMPLE
    PS> Get-WindowsPrincipalDetails

.NOTES
    Author: klee-it
    PowerShell Version: 5.1, 7.x
#>

###
### FUNCTION: Get Windows principal details
###
function Get-WindowsPrincipalDetails
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding(DefaultParameterSetName="Default")]

    param()
    
    try
    {
        # get Windows principal object
        $WindowsPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())

        # set output object
        $outputInfo = [PSCustomObject]@{
            Name = $WindowsPrincipal.Identity.Name
            Sid = $WindowsPrincipal.Identity.User.Value
            AuthenticationType = $WindowsPrincipal.Identity.AuthenticationType
            IsAuthenticated = $WindowsPrincipal.Identity.IsAuthenticated
            IsSystem = $WindowsPrincipal.Identity.IsSystem
            IsAdmin = $WindowsPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
            Groups = $WindowsPrincipal.Identity.Groups
        }

        # get true/false if user has admin permissions or not
        Write-Output -InputObject $outputInfo
    }
    catch
    {
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
}
