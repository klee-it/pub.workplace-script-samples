<#
.SYNOPSIS
    Gets installed Microsoft Store apps. Supports filters or -All.

.DESCRIPTION
    Uses Get-AppxPackage -AllUsers to collect installed Microsoft Store apps and optionally filters
    by Name and PackageFamilyName (wildcards supported). When -All is specified, returns all apps
    and ignores other filters. Emits verbose output when -Verbose is supplied.

.PARAMETER Name
    Appx package Name to match (wildcards supported). Mandatory in the 'Default' parameter set.

.PARAMETER PackageFamilyName
    PackageFamilyName to match (wildcards supported). Optional; applies only in the 'Default' set.

.PARAMETER All
    Return all installed apps using the 'All' parameter set. When used, other filter parameters are ignored.

.INPUTS
    None

.OUTPUTS
    Microsoft.Windows.Appx.PackageManager.Commands.AppxPackage
        Objects returned by Get-AppxPackage.

.EXAMPLE
    PS> Get-InstalledAppsFromMsStore -Name 'Microsoft.*'

.EXAMPLE
    PS> Get-InstalledAppsFromMsStore -Name 'Microsoft.*' -PackageFamilyName '*WindowsCalculator*'

.EXAMPLE
    PS> Get-InstalledAppsFromMsStore -All

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
        [Parameter(ParameterSetName = 'Default', Mandatory = $true)]
        [String] $Name,

        [Parameter(ParameterSetName = 'Default', Mandatory = $false)]
        [String] $PackageFamilyName,

        [Parameter(ParameterSetName = 'All', Mandatory = $true)]
        [Switch] $All = $false
    )
    
    try
    {
        # query all installed applications from MS Store
        Write-Verbose -Message 'Collecting installed applications from MS Store...'
        $MsStoreApps = Get-AppxPackage -AllUsers
        
        if ($All)
        {
            Write-Verbose -Message 'All switch specified, returning all installed applications...'
            $LocalAppInfo = $MsStoreApps
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
