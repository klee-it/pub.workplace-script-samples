<#
.SYNOPSIS
    Gets installed Microsoft Store apps with filtering options.

.DESCRIPTION
    Queries installed Microsoft Store applications using Get-AppxPackage with optional scope and filtering.
    Can filter by Name and PackageFamilyName (wildcards supported), use a custom filter hashtable, or return all apps with -All switch.
    Supports CurrentUser or AllUsers scope.

.PARAMETER Scope
    Specifies the scope for querying apps. Valid values: 'CurrentUser', 'AllUsers'. Default is 'AllUsers'.

.PARAMETER Name
    Appx package Name to match (wildcards supported). Mandatory in the 'Default' parameter set.

.PARAMETER PackageFamilyName
    PackageFamilyName to match (wildcards supported). Optional; applies only in the 'Default' parameter set.

.PARAMETER All
    Return all installed apps using the 'All' parameter set. When used, other filter parameters are ignored.

.PARAMETER Filter
    Custom hashtable filter to apply using Where-Object. Mandatory in the 'ByFilter' parameter set.

.INPUTS
    None

.OUTPUTS
    Microsoft.Windows.Appx.PackageManager.Commands.AppxPackage
        Objects returned by Get-AppxPackage.

.EXAMPLE
    PS> Get-InstalledAppsFromMsStore -Name 'Microsoft.*'
    Retrieves all Microsoft Store apps matching 'Microsoft.*' for all users.

.EXAMPLE
    PS> Get-InstalledAppsFromMsStore -Name 'Microsoft.*' -PackageFamilyName '*WindowsCalculator*'
    Retrieves apps matching both Name and PackageFamilyName filters.

.EXAMPLE
    PS> Get-InstalledAppsFromMsStore -All
    Retrieves all installed Microsoft Store apps for all users.

.EXAMPLE
    PS> Get-InstalledAppsFromMsStore -Name 'Microsoft.*' -Scope CurrentUser
    Retrieves matching apps for the current user only.

.EXAMPLE
    PS> Get-InstalledAppsFromMsStore -Filter @{Architecture = 'X64'; SignatureKind = 'Store'}
    Retrieves apps using a custom filter hashtable.

.NOTES
    Author: klee-it
    Works with: Windows PowerShell 5.1, PowerShell 7+
#>

###
### FUNCTION: Get installed applications from msstore with filtering options
###
function Get-InstalledAppsFromMsStore
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding(DefaultParameterSetName = 'Default')]

    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('CurrentUser', 'AllUsers')]
        [String] $Scope = 'AllUsers',

        [Parameter(ParameterSetName = 'Default', Mandatory = $true)]
        [String] $Name,

        [Parameter(ParameterSetName = 'Default', Mandatory = $false)]
        [String] $PackageFamilyName,

        [Parameter(ParameterSetName = 'All', Mandatory = $true)]
        [Switch] $All = $false,

        [Parameter(ParameterSetName = 'ByFilter', Mandatory = $true)]
        [System.Collections.Hashtable] $Filter = @{}
    )
    
    try
    {
        # query all installed applications from MS Store
        Write-Verbose -Message 'Collecting installed applications from MS Store...'
        if ($Scope -eq 'CurrentUser')
        {
            Write-Verbose -Message 'Set scope to current user...'
            $MsStoreApps = Get-AppxPackage
        }
        elseif ($Scope -eq 'AllUsers')
        {
            Write-Verbose -Message 'Set scope to all users...'
            $MsStoreApps = Get-AppxPackage -AllUsers
        }
        else
        {
            throw 'Invalid scope specified'
        }
        Write-Verbose -Message "Number of applications retrieved: $( ($MsStoreApps | Measure-Object).Count )"
        
        # filter applications based on parameters
        if ($All)
        {
            Write-Verbose -Message 'All switch specified, returning all installed applications...'
            $LocalAppInfo = $MsStoreApps
        }
        elseif ($PSBoundParameters.ContainsKey('Filter') -and $Filter.Count -gt 0)
        {
            Write-Verbose -Message 'Custom filter hashtable specified, applying filter...'
            $LocalAppInfo = $MsStoreApps | Where-Object @Filter
        }
        else
        {
            # set basic filter script
            Write-Verbose -Message 'Setting basic filter script...'
            $FilterScript = { $_.Name -like "$($Name)" }

            # filter by PackageFamilyName
            if (-not ( [string]::IsNullOrWhiteSpace($PackageFamilyName) ) )
            {
                Write-Verbose -Message "PackageFamilyName variable specified: $($PackageFamilyName)"

                $FilterScript = [ScriptBlock]::Create($FilterScript.ToString() + ' -and $_.PackageFamilyName -like "$($PackageFamilyName)"')
            }

            # get application based on filter script
            $LocalAppInfo = $MsStoreApps | Where-Object -FilterScript $FilterScript
        }
        Write-Verbose -Message "Number of installed applications: $( ($LocalAppInfo | Measure-Object).Count )"

        # output the local app info
        Write-Output -InputObject $LocalAppInfo

        # clean-up
        Get-Variable -Name 'FilterScript' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
        Get-Variable -Name 'MsStoreApps' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
    }
    catch
    {
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
}
