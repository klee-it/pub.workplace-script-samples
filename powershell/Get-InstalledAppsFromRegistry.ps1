<#
.SYNOPSIS
    Returns installed applications discovered in the Windows registry with optional filters or all entries.

.DESCRIPTION
    Enumerates common HKLM Uninstall registry locations (both native and 32-bit views) and outputs registry entry data
    for installed applications. Supports wildcard matching on DisplayName and UninstallString, optional exclusion by
    DisplayName, and a minimum VersionMajor numeric filter. Use -All to ignore filters and return all entries.
    Emits verbose messages when -Verbose is specified.

.PARAMETER DisplayName
    Display name pattern to include (wildcards supported). Mandatory in the 'Default' parameter set.

.PARAMETER DisplayNameExclusion
    Display name pattern to exclude (wildcards supported). Optional.

.PARAMETER VersionMajor
    Minimum major version (numeric) to include. Compared against the 'VersionMajor' registry value using -ge. Optional.

.PARAMETER UninstallString
    Uninstall string pattern to exclude (wildcards supported). Optional.

.PARAMETER All
    Switch to return all installed applications (parameter set 'All'). When used, other parameters are ignored.

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

.NOTES
    Requires read access to HKLM. Works with Windows PowerShell 5.1 and PowerShell 7+.
    Scans uninstall entries for both 64-bit and 32-bit applications.

.LINK
    about_Comment_Based_Help
#>

###
### FUNCTION: Get installed applications from registry with filtering options
###
function Get-InstalledAppsFromRegistry
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding(DefaultParameterSetName = 'Default')]

    param(
        [Parameter(ParameterSetName = 'Default', Mandatory = $true)]
        [String] $DisplayName,

        [Parameter(ParameterSetName = 'Default', Mandatory = $false)]
        [String] $DisplayNameExclusion = '',

        [Parameter(ParameterSetName = 'Default', Mandatory = $false)]
        [String] $VersionMajor = '',

        [Parameter(ParameterSetName = 'Default', Mandatory = $false)]
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
        $RegistryUninstallPaths = @(
            'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
            'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
            'HKLM:\Software\WowAA32Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )

        $ReadRegistry = @()
        foreach ($RegistryUninstallPath in $RegistryUninstallPaths)
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
