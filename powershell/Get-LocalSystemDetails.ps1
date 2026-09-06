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
        $OperatingSystem = Get-CimInstance -ClassName 'Win32_OperatingSystem' | Select-Object Caption, OSArchitecture, InstallDate, LastBootUpTime

        # set system details object
        $SystemDetails = [PSCustomObject][Ordered]@{
            AppInstallerVersion    = "$( try { Get-AppxProvisionedPackage -Online -ErrorAction 'Stop' | Where-Object {$_.PackageName -like 'Microsoft.DesktopAppInstaller*'} | Select-Object -ExpandProperty 'Version' } catch { 'N/A' } )"
            BitLockerAvailable     = if (Get-Command 'Get-BitLockerVolume' -ErrorAction 'SilentlyContinue') { $true } else { $false }
            ComputerInfo           = $null
            ComputerName           = "$($env:COMPUTERNAME)"
            FirmwareType           = "$($env:Firmware_Type)"
            InstallDate            = "$($OperatingSystem.InstallDate)"
            Is64BitOperatingSystem = [Environment]::Is64BitOperatingSystem
            Is64BitProcess         = [Environment]::Is64BitProcess # if $false, then 32-bit process needs maybe instead of 'C:\WINDOWS\System32' the path: 'C:\WINDOWS\sysnative'
            LastBootDateTime       = "$($OperatingSystem.LastBootUpTime)"
            LastBootUpTime         = $null
            OSArchitecture         = "$($OperatingSystem.OSArchitecture)"
            OSName                 = "$($OperatingSystem.Caption)"
            OsType                 = $null
            PendingReboot          = $false
            PowerShellEdition      = "$($PSVersionTable.PSEdition)"
            PowerShellVersion      = "$($PSVersionTable.PSVersion)"
            ProcessorArchitecture  = "$($env:PROCESSOR_ARCHITECTURE)"
            RuntimeUser            = [PSCustomObject]@{
                AuthenticationType = $WindowsPrincipal.Identity.AuthenticationType
                Groups             = $WindowsPrincipal.Identity.Groups
                IsAdmin            = $WindowsPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')
                IsAuthenticated    = $WindowsPrincipal.Identity.IsAuthenticated
                IsSystem           = $WindowsPrincipal.Identity.IsSystem
                Name               = $WindowsPrincipal.Identity.Name
                Sid                = $WindowsPrincipal.Identity.User.Value
            }
            RuntimeUserScope       = if ($env:USERNAME -eq "$($env:COMPUTERNAME)$") { 'System' } else { 'User' }
            TimeZone               = Get-TimeZone | Select-Object -ExpandProperty Id
            WinGetVersion          = "$( try { Deploy-WingetApps -Version -IncludeScope $false -ErrorAction 'Stop' | Select-Object -ExpandProperty ConsoleOutput } catch { 'N/A' } )"
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
        $pendingReboot = $false

        # Windows Update COM API
        try
        {
            if ((New-Object -ComObject 'Microsoft.Update.SystemInfo').RebootRequired)
            {
                $pendingReboot = $true
            }
        }
        catch
        {
            # WU COM unavailable — continue with registry checks
        }

        # Registry keys — key existence indicates a pending reboot
        if (-not $pendingReboot)
        {
            $registryChecks = @(
                'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
                'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
                'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\PostRebootReporting'
            )

            foreach ($registryPath in $registryChecks)
            {
                if (Test-Path -LiteralPath $registryPath)
                {
                    $pendingReboot = $true
                    break
                }
            }
        }

        # Pending file rename operations (Session Manager)
        if (-not $pendingReboot)
        {
            try
            {
                $pendingFileRenameOperations = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name 'PendingFileRenameOperations' -ErrorAction 'Stop').PendingFileRenameOperations
                if ($pendingFileRenameOperations)
                {
                    $pendingReboot = $true
                }
            }
            catch
            {
                # Property absent — no pending file renames
            }
        }

        $SystemDetails.PendingReboot = $pendingReboot
        Get-Variable -Name 'pendingReboot' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force

        Write-Output -InputObject $SystemDetails
    }
    catch
    {
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
}
