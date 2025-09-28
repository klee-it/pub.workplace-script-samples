#
## basic information:
## |__ Application detection and version check script
#
## documentation:
## |__ $AppName [MANDATORY]
## |__|__ supports wildcards like: 'python* *executables*' OR '*anyconnect*' but you should use as close name as possible
## |__ $AppNameExclusions [OPTIONAL]
## |__|__ for cases like Zoom, where you need to exclude Outlook Plugin for example, if exclusions are not required keep the variable empty
## |__|__ its also handy for applications like AnyConnect, where different modules might need to be excluded
## |__ $UninstallStringExclusion [OPTIONAL]
## |__|__ for cases like Express VPN, where you need to exclude MSI package to find the EXE package.
## |__ $AppLatestVersion [MANDATORY]
## |__|__ variable format is [Version]'VER.NO' like: [Version]'1.0.0.0' 
## |__|__ specify the version in this variable, note that if application has build number like 6150 and you specify 3.1.6.0 the build number will be 6 and not 6000
## |__ $AppMinVersion [OPTIONAL, Recommended 1+]
## |__|__ is to make filtering more fluid and sortable
## |__|__ specify major version number for query from registry, used to avoid *.msi's like 0.0.20.0 and for python where major version is very important.
## |__|__ although the script picks the highest installed version, it's still keeps it more tidy. also python... and whatever else is built with this stupid logic.
#
## Supported PowerShell versions:
## |__ v5.1
#
## location: Intune
#
## notes:
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
### FUNCTION: Get normalized version string which can be used for version comparison
###
function Get-NormalizedVersion
{
    [OutputType([System.String])]
    [CmdLetBinding(DefaultParameterSetName = 'Default')]

    param(
        [Parameter(Mandatory = $false)]
        [String] $Value = ''
    )
    
    try
    {
        Write-Verbose -Message "Original Version : '$($Value)'"

        $OutputString = ''
        $Value = "$( $Value.Trim() )" # remove leading and trailing whitespaces

        # check if the value is empty
        if ( [String]::IsNullOrEmpty($Value) )
        {
            Write-Warning -Message 'Given value was empty. Returning empty string.'
        }

        # check if the value contains letters
        elseif ( $Value -match '[a-zA-Z ]' )
        {
            Write-Warning -Message 'Given value contains letters. Returning empty string.'
        }

        # replace all non-numeric characters with a dot and trim ending zeros
        else
        {
            # $normalizedValue = "$($Value -replace '[\D]', '.')".TrimEnd('.0') # TrimEnd() replaces all specified characters, but not as "word"
            $normalizedValue = "$( "$($Value -replace '[\D]', '.')" -replace '\.0$', '' -replace '\.0$', '' )"
            Write-Verbose -Message "Normalized value: '$($normalizedValue)'"
    
            # check if normalized value is empty
            if ( [String]::IsNullOrEmpty($normalizedValue) )
            {
                Write-Warning -Message 'Normalized value was empty. Returning empty string.'
            }
            # check if normalized value is in format major.minor(.patch)(.build)
            elseif ( $normalizedValue -notmatch '^\d+\.\d+(?:\.\d+)?(?:\.\d+)?$' )
            {
                Write-Verbose -Message 'Normalized value is not in format major.minor. Add missing minor part.'
                $OutputString = "$($normalizedValue).0"
            }
            else
            {
                Write-Verbose -Message 'Normalized value is in format major.minor(.patch)(.build).'
                $OutputString = "$($normalizedValue)"
            }

            Get-Variable -Name 'normalizedValue' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
        }

        Write-Output -InputObject "$($OutputString)"
    }
    catch
    {
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
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
    Write-Logging -Value '### SCRIPT BEGIN #################################' -Mode 'set'
    Write-Logging -Value '[SR] Script: intunewin-app-update-detection'
    Write-Logging -Value "[SR] App name: $($AppName) - v$($AppLatestVersion)"

    # get installed applications from registry
    Write-Logging -Value '[SR] Collecting installed applications from registry...'
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
    Write-Logging -Value "[SR] Number of installed applications: $( ($LocalAppInfo | Measure-Object).Count )"

    # check if application is available
    if ( ($LocalAppInfo | Measure-Object).Count -le 0 )
    { 
        Write-Logging -Value "[SR] Specified application: $($AppName) is not installed"
        $exit_code = 1
    }
    elseif ( ($LocalAppInfo | Measure-Object).Count -eq 1 )
    {
        Write-Logging -Value "[SR] Local installed application name: '$($LocalAppInfo.DisplayName)' with version: '$($LocalAppInfo.DisplayVersion)'"

        [Version]$AppLatestVersion = Get-NormalizedVersion -Value "$($AppLatestVersion)"
        [Version]$ActualVersion = Get-NormalizedVersion -Value "$($LocalAppInfo.DisplayVersion)"

        if ($ActualVersion -ge $AppLatestVersion)
        {
            Write-Logging -Value "[SR] Update not required - client ($($ActualVersion)) has the same or newer version as remote ($($AppLatestVersion)) available"
            $exit_code = 0
        }
        else
        { 
            Write-Logging -Value "[SR] Update for $($LocalAppInfo.DisplayName) to v$($AppLatestVersion) required - client has older version $($ActualVersion)"
            $exit_code = 1
        }

        # clean-up
        Get-Variable -Name 'ActualVersion' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
    }
    else
    {
        Write-Logging -Value "[SR] Too many applications found: $($LocalAppInfo.DisplayName -join ' / ')"
        $exit_code = 0
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

    Write-Logging -Value '### SCRIPT END ###################################'
}
catch
{
    Write-Logging -Value "[SR] Error: [$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    $exit_code = $($_.Exception.HResult)
}

exit $exit_code
