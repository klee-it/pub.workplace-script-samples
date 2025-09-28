#
## basic information:
## |__ Deployment requirement script -> REQUIRED or NOT REQUIRED
#
## documentation:
## |__ $AppName [MANDATORY]
## |__|__ supports wildcards like: 'python* *executables*' OR '*anyconnect*' but you should use as close name as possible
## |__ $AppNameExclusions [OPTIONAL]
## |__|__ for cases like Zoom, where you need to exclude Outlook Plugin for example, if exclusions are not required keep the variable empty
## |__|__ its also handy for applications like AnyConnect, where different modules might need to be excluded
#
## Supported PowerShell versions:
## |__ v5.1
#
## location: Intune
#
## notes:
## |__ Exit code not supported, it must be handled by the StdOut
## |__ Do not use any console output (logs), because the Intune detection mechanic can handle only ONE LINE IN OUTPUT
## |__ the script runs on registry detection method, which gives the ability to detect the applications installed even on user level
#

# set strict mode
$ErrorActionPreference = 'Stop'

# set system parameters
$exit_code = 0

# load app package data
$AppPackageData = '{{JSON-APP-PACKAGE-DATA}}' | ConvertFrom-Json

# get script info
$script:MyScriptInfo = Get-Item -Path "$($MyInvocation.MyCommand.Path)"

# set logging parameters
$script:enable_write_logging = $true
$script:LogFilePath = "$($env:ProgramData)\klee-it\$( ($AppPackageData.'REPLACEMENT-APP-NAME') -replace '[\s\W]' )"
$script:LogFileName = "$($script:MyScriptInfo.BaseName).log"

# set app parameters
$AppName = "$($AppPackageData.'REPLACEMENT-APP-NAME')"
$AppLatestVersion = "$($AppPackageData.'REPLACEMENT-APP-VERSION')"
$AppMinVersion = "$($AppPackageData.'REPLACEMENT-APP-MAJOR-VERSION')"
$AppNameExclusion = "$($AppPackageData.'REPLACEMENT-APP-NAME-EXCLUSION')"
$UninstallStringExclusion = "$($AppPackageData.'REPLACEMENT-APP-UNINSTALL-STRING-EXCLUSION')"

###
### FUNCTION: write a log of the script
###
function Write-Logging
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding(DefaultParameterSetName = 'Default')]

    param(
        [Parameter(Mandatory = $false)]
        [String] $Value = '',

        [Parameter(Mandatory = $false)]
        [String] $Module = '',

        [Parameter(Mandatory = $false)]
        [ValidateScript({ $_ -eq -1 -or $_ -match '^\d+$' })]
        [int] $Level = -1,

        [Parameter(Mandatory = $false)]
        [String] $Mode = 'add',

        [Parameter(Mandatory = $false)]
        [ValidateSet('None', 'Host', 'Warning')]
        [String] $StdOut = 'Host',

        [Parameter(Mandatory = $false)]
        [HashTable] $OptionsSplat = @{}
    )
    
    try
    {
        # set log file path
        $FilePath = "$($script:LogFilePath)"
        if (-not (Test-Path -Path "$($FilePath)"))
        {
            New-Item -Path "$($FilePath)" -ItemType 'Directory' -Force | Out-Null
        }
        
        $File = Join-Path -Path "$($FilePath)" -ChildPath "$($script:LogFileName)"
        $prefix = ''
        
        # set prefix
        switch ($Level)
        {
            # default level
            -1 { $prefix = '' }
            # root level
            0 { $prefix = '# ' }
            # sub level
            default { $prefix = "$((1..$($Level) | ForEach-Object { '|__' }) -join '') " }
        }
        
        # set log message
        $logMessage = "$($prefix)$($Value)"
        $logDetails = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$($env:computername)] [$($env:UserName)] [$($env:UserDomain)] [$($Module)]"

        # write to stdout
        switch ($StdOut)
        {
            'Host' { $OptionsSplat['Object'] = "$($logMessage)"; Write-Host @OptionsSplat }
            'Warning' { $OptionsSplat['Message'] = "$($logMessage)"; Write-Warning @OptionsSplat }
            default { break }
        }

        # check size of log file
        if (Test-Path -Path "$($File)" -PathType 'Leaf')
        {
            # if max size reached, create new log file
            if ((Get-Item -Path "$($File)").length -gt 10Mb)
            {
                $Mode = 'set'
            }
        }

        # check if logging is enabled
        if ($script:enable_write_logging)
        {
            $LogSplat = @{
                Path     = "$($File)"
                Value    = "$($logDetails) $($logMessage)"
                Encoding = 'UTF8'
            }

            switch ($Mode)
            {
                # create new logfile with the value
                'set' { Set-Content @LogSplat; break }
                # add existing value
                'add' { Add-Content @LogSplat; break }
            }

            Get-Variable -Name 'LogSplat' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
        }

        # clean-up
        Get-Variable -Name 'FilePath' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
        Get-Variable -Name 'File' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
        Get-Variable -Name 'prefix' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
        Get-Variable -Name 'logMessage' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
        Get-Variable -Name 'logDetails' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
    }
    catch
    {
        Write-Warning -Message "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
}

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

###
### MAIN SCRIPT
###
try
{
    Write-Logging -Value '### SCRIPT BEGIN #################################' -StdOut 'None' -Mode 'set'
    Write-Logging -Value '[SR] Script: intunewin-app-installation-requirement' -StdOut 'None'
    Write-Logging -Value "[SR] App name: $($AppName) - v$($AppLatestVersion)" -StdOut 'None'

    # get installed applications from registry
    Write-Logging -Value '[SR] Collecting installed applications from registry...' -StdOut 'None'
    $Splat = @{
        DisplayName = "$($AppName)"
    }

    if ($AppMinVersion)
    {
        $Splat.VersionMajor = "$($AppMinVersion)"
    }
    
    if ($AppNameExclusion)
    {
        $Splat.DisplayNameExclusion = "$($AppNameExclusion)"
    }

    if ($UninstallStringExclusion)
    {
        $Splat.UninstallString = "$($UninstallStringExclusion)"
    }

    $LocalAppInfo = Get-InstalledAppsFromRegistry @Splat
    Get-Variable -Name 'Splat' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
    Write-Logging -Value "[SR] Number of installed applications: $( ($LocalAppInfo | Measure-Object).Count )" -StdOut 'None'

    # check if application is available
    if ( ($LocalAppInfo | Measure-Object).Count -le 0 )
    {
        Write-Logging -Value "[SR] Specified application: $($AppName) is not installed" -StdOut 'None'
        Write-Logging -Value '[SR] Deployment applicable' -StdOut 'None'
        Write-Output -InputObject 'applicable'
    }
    elseif ( ($LocalAppInfo | Measure-Object).Count -eq 1 )
    {
        Write-Logging -Value "[SR] Specified application: '$($LocalAppInfo.DisplayName)' with version: '$($LocalAppInfo.DisplayVersion)' is already installed" -StdOut 'None'
        Write-Logging -Value '[SR] Skip deployment' -StdOut 'None'
    }
    else
    { 
        Write-Logging -Value "[SR] Too many applications found: $($LocalAppInfo.DisplayName -join ' / ')" -StdOut 'None'
        Write-Logging -Value '[SR] Skip deployment' -StdOut 'None'
    }

    # clean-up
    Get-Variable -Name 'AppName' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
    Get-Variable -Name 'AppLatestVersion' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
    Get-Variable -Name 'AppMinVersion' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
    Get-Variable -Name 'AppNameExclusion' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
    Get-Variable -Name 'UninstallStringExclusion' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
    Get-Variable -Name 'ReadRegistry' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
    Get-Variable -Name 'FilterScript' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
    Get-Variable -Name 'LocalAppInfo' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force

    Write-Logging -Value '### SCRIPT END ###################################' -StdOut 'None'
}
catch
{
    Write-Logging -Value "[SR] Error: [$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    $exit_code = $($_.Exception.HResult)
}

exit $exit_code
