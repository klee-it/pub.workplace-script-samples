<#
.SYNOPSIS
    Retrieves detailed information about the local system.

.DESCRIPTION
    Gathers and returns various details about the local system, including PowerShell version, edition, process and OS architecture, runtime user, last boot time, pending reboot status, and additional computer information (on PowerShell 7+).

.OUTPUTS
    [PSCustomObject]
        An object containing local system details.

.EXAMPLE
    PS> Get-LocalSystemDetails

.NOTES
    Author: klee-it
    Compatible with: PowerShell 5.1, 7.x
#>

###
### FUNCTION: get local system details
###
function Get-LocalSystemDetails
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding(DefaultParameterSetName = 'Default')]

    param(
        [Parameter(Mandatory = $false)]
        [Switch] $Detailed = $false
    )

    try
    {
        # get Windows principal object
        $WindowsPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())

        # set system details object
        $SystemDetails = [PSCustomObject]@{
            PowerShellVersion      = "$($PSVersionTable.PSVersion)"
            PowerShellEdition      = "$($PSVersionTable.PSEdition)"
            Is64BitProcess         = [Environment]::Is64BitProcess # if $false, then 32-bit process needs maybe instead of 'C:\WINDOWS\System32' the path: 'C:\WINDOWS\sysnative'
            Is64BitOperatingSystem = [Environment]::Is64BitOperatingSystem
            RuntimeUser            = [PSCustomObject]@{
                Name               = $WindowsPrincipal.Identity.Name
                Sid                = $WindowsPrincipal.Identity.User.Value
                AuthenticationType = $WindowsPrincipal.Identity.AuthenticationType
                IsAuthenticated    = $WindowsPrincipal.Identity.IsAuthenticated
                IsSystem           = $WindowsPrincipal.Identity.IsSystem
                IsAdmin            = $WindowsPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')
                Groups             = $WindowsPrincipal.Identity.Groups
            }
            RuntimeUserScope       = if ($env:USERNAME -eq "$($env:COMPUTERNAME)$") { 'System' } else { 'User' }
            LastBootDateTime       = Get-CimInstance -ClassName 'Win32_OperatingSystem' | Select-Object -ExpandProperty LastBootUpTime
            LastBootUpTime         = $null
            PendingReboot          = $false
            ComputerInfo           = $null
            OsType                 = $null
        }

        # PowerShell v7
        if ($PSVersionTable.PSEdition -eq 'Core' -and $PSVersionTable.PSVersion.major -ge 7)
        {
            $SystemDetails.LastBootUpTime = Get-Uptime
            $SystemDetails.OsType = $PSVersionTable.OS

            if ($Detailed)
            {
                $SystemDetails.ComputerInfo = Get-ComputerInfo
            }
        }

        # check if a reboot is pending
        try
        {
            $SystemDetails.PendingReboot = (New-Object -ComObject 'Microsoft.Update.SystemInfo').RebootRequired
        }
        catch
        {
            try
            {
                Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired' -ErrorAction 'Stop' | Out-Null
                $SystemDetails.PendingReboot = $true
            }
            catch
            {
                $SystemDetails.PendingReboot = $false
            }
        }

        Write-Output -InputObject $SystemDetails
    }
    catch
    {
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
}
