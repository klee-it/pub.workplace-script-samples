<#
.SYNOPSIS
    Returns installed applications discovered in the Windows registry with optional filters or all entries.

.DESCRIPTION
    Enumerates common HKLM and/or HKCU Uninstall registry locations (both native and 32-bit views) and outputs registry entry data
    for installed applications. Supports wildcard matching on DisplayName, optional exclusion by DisplayName, minimum VersionMajor 
    numeric filter, and UninstallString pattern exclusion. Use -All to return all entries, -Filter for custom filtering, 
    -IncludeCurrentUser to add HKCU entries, or -OnlyCurrentUser to query only HKCU.
    Emits verbose messages when -Verbose is specified.

.PARAMETER IncludeCurrentUser
    Switch to include HKCU registry path in addition to HKLM paths. Optional.

.PARAMETER OnlyCurrentUser
    Switch to query only HKCU registry path, excluding HKLM paths. Optional.

.PARAMETER DisplayName
    Display name pattern to include (wildcards supported). Mandatory in the 'SingleApp' parameter set.

.PARAMETER DisplayNameExclusion
    Display name pattern to exclude (wildcards supported). Optional in the 'SingleApp' parameter set.

.PARAMETER VersionMajor
    Minimum major version (numeric) to include. Compared against the 'VersionMajor' registry value using -ge. Optional in the 'SingleApp' parameter set.

.PARAMETER UninstallString
    Uninstall string pattern to exclude (wildcards supported). Optional in the 'SingleApp' parameter set.

.PARAMETER All
    Switch to return all installed applications (parameter set 'All'). When used, other parameters are ignored.

.PARAMETER Filter
    Custom hashtable filter to apply using Where-Object. Mandatory in the 'ByFilter' parameter set.

.INPUTS
    None. You cannot pipe input to this function.

.OUTPUTS
    System.Management.Automation.PSObject
        Properties include: DisplayName, DisplayVersion, Publisher, InstallDate, VersionMajor, VersionMinor,
        PSChildName, UninstallString, InstallLocation, RegistryPath.

.EXAMPLE
    Get-InstalledAppsFromRegistry -DisplayName 'Microsoft*'

.EXAMPLE
    Get-InstalledAppsFromRegistry -DisplayName 'Google*' -DisplayNameExclusion '*Update*'

.EXAMPLE
    Get-InstalledAppsFromRegistry -DisplayName '*Office*' -VersionMajor 16

.EXAMPLE
    Get-InstalledAppsFromRegistry -DisplayName '*Chrome*' -UninstallString '*msiexec*'

.EXAMPLE
    Get-InstalledAppsFromRegistry -All -Verbose

.EXAMPLE
    Get-InstalledAppsFromRegistry -OnlyCurrentUser -DisplayName '*Adobe*'

.EXAMPLE
    Get-InstalledAppsFromRegistry -IncludeCurrentUser -All

.EXAMPLE
    Get-InstalledAppsFromRegistry -Filter @{DisplayName = 'Visual Studio Code'}

.NOTES
    Requires read access to HKLM and/or HKCU. Works with Windows PowerShell 5.1 and PowerShell 7+.
    Scans uninstall entries for both 64-bit and 32-bit applications.
#>

###
### FUNCTION: Get installed applications from registry with filtering options
###
function Get-InstalledAppsFromRegistry
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding(DefaultParameterSetName = 'Default')]

    param(
        [Parameter(Mandatory = $false)]
        [Switch] $IncludeCurrentUser = $false,

        [Parameter(Mandatory = $false)]
        [Switch] $OnlyCurrentUser = $false,

        [Parameter(ParameterSetName = 'SingleApp', Mandatory = $true)]
        [String] $DisplayName,

        [Parameter(ParameterSetName = 'SingleApp', Mandatory = $false)]
        [String] $DisplayNameExclusion = '',

        [Parameter(ParameterSetName = 'SingleApp', Mandatory = $false)]
        [String] $VersionMajor = '',

        [Parameter(ParameterSetName = 'SingleApp', Mandatory = $false)]
        [String] $UninstallString = '',

        [Parameter(ParameterSetName = 'All', Mandatory = $true)]
        [Switch] $All = $false,

        [Parameter(ParameterSetName = 'ByFilter', Mandatory = $true)]
        [System.Collections.Hashtable] $Filter = @{}
    )
    
    try
    {
        # query all the registry keys where applications usually leave a mark for installed applications
        Write-Verbose -Message 'Collecting installed applications from registry...'
        if ($OnlyCurrentUser)
        {
            Write-Verbose -Message 'Set current user uninstall registry path...'
            $RegistryUninstallPaths = @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*')
        }
        else
        {
            Write-Verbose -Message 'Set local machine uninstall registry paths...'
            $RegistryUninstallPaths = @(
                'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
                'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
                'HKLM:\Software\WowAA32Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
            )
        }

        if ($IncludeCurrentUser)
        {
            Write-Verbose -Message 'Including current user uninstall registry path...'
            $RegistryUninstallPaths += 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
        }


        $ReadRegistry = @()
        foreach ($RegistryUninstallPath in ($RegistryUninstallPaths | Sort-Object -Unique))
        {
            $ReadRegistry += Get-ItemProperty -Path "$($RegistryUninstallPath)" -ErrorAction 'SilentlyContinue' | Select-Object DisplayName, DisplayVersion, Publisher, InstallDate, VersionMajor, VersionMinor, PSChildName, UninstallString, InstallLocation, @{ Name = 'RegistryPath'; Expression = { $RegistryUninstallPath } }
        }

        if ($All)
        {
            Write-Verbose -Message 'All switch specified, returning all installed applications...'
            $LocalAppInfo = $ReadRegistry
        }
        elseif ($PSBoundParameters.ContainsKey('Filter') -and $Filter.Count -gt 0)
        {
            Write-Verbose -Message 'Custom filter hashtable specified, applying filter...'
            $LocalAppInfo = $ReadRegistry | Where-Object @Filter
        }
        else
        {
            # set basic filter script
            Write-Verbose -Message 'Setting basic filter script...'
            $FilterScript = { $_.DisplayName -like "$($DisplayName)" }

            # filter by minimum major version
            if (-not ( [string]::IsNullOrWhiteSpace($VersionMajor) ) )
            {
                Write-Verbose -Message "Minimum major version variable specified: $($VersionMajor)"
    
                $FilterScript = [ScriptBlock]::Create($FilterScript.ToString() + ' -and $_.VersionMajor -ge $VersionMajor')
            }

            # filter by display name exclusion
            if (-not ( [string]::IsNullOrWhiteSpace($DisplayNameExclusion) ) )
            {
                Write-Verbose -Message "DisplayName exclusion variable specified: $($DisplayNameExclusion)"

                $FilterScript = [ScriptBlock]::Create($FilterScript.ToString() + ' -and $_.DisplayName -notlike "$($DisplayNameExclusion)"')
            }

            # filter by uninstall string exclusion
            if (-not ( [string]::IsNullOrWhiteSpace($UninstallString) ) )
            {
                Write-Verbose -Message "UninstallString exclusion variable specified: $($UninstallString)"
    
                $FilterScript = [ScriptBlock]::Create($FilterScript.ToString() + ' -and $_.UninstallString -notlike "$($UninstallString)"')
            }

            # get application based on filter script
            $LocalAppInfo = $ReadRegistry | Where-Object -FilterScript $FilterScript
        }
        Write-Verbose -Message "Number of installed applications: $( ($LocalAppInfo | Measure-Object).Count )"

        # output the local app info
        Write-Output -InputObject $LocalAppInfo

        # clean-up
        Get-Variable -Name 'FilterScript' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
        Get-Variable -Name 'ReadRegistry' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
        Get-Variable -Name 'RegistryUninstallPaths' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
    }
    catch
    {
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
}
