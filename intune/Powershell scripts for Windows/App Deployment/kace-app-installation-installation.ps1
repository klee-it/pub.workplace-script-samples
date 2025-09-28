# Basic information
# |__ Version: 2025-01-09
# |__ KACE Command: powershell.exe -NoLogo -WindowStyle Hidden -ExecutionPolicy ByPass -File ".\local-install-app-by-kace.ps1"

# set strict mode
$ErrorActionPreference = 'Stop'

# set system parameters
$exit_code = 0

# get script info
$script:MyScriptInfo = Get-Item -Path "$($MyInvocation.MyCommand.Path)"

# set logging parameters
$script:enable_write_logging = $true
$script:LogFilePath = "$($env:ProgramData)\klee-it\AppDeployment"
$script:LogFileName = "$($script:MyScriptInfo.BaseName).log"

# set configuration parameters
$script:ConfigFilePath = "$($PSScriptRoot)"
$script:ConfigFileName = "kace-app-installation-configuration.json"

# set download parameters
$script:DownloadPath = "$($PSScriptRoot)"

# set installation parameters
$script:AppName = ''
$script:RunStatus = [PSCustomObject]@{
    download   = $false
    pre_setup  = $false
    main_setup = $false
    post_setup = $false
}

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
### FUNCTION: write system details log
###
function Get-LocalSystemDetails
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding(DefaultParameterSetName = 'Default')]

    param()

    try
    {
        # set system details object
        $SystemDetails = [PSCustomObject]@{
            PowerShellVersion      = "$($PSVersionTable.PSVersion)"
            PowerShellEdition      = "$($PSVersionTable.PSEdition)"
            Is64BitProcess         = [Environment]::Is64BitProcess # if $false, then 32-bit process needs maybe instead of 'C:\WINDOWS\System32' the path: 'C:\WINDOWS\sysnative'
            Is64BitOperatingSystem = [Environment]::Is64BitOperatingSystem
            RuntimeUser            = "$([System.Security.Principal.WindowsIdentity]::GetCurrent() | Select-Object -ExpandProperty Name)"
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
            $SystemDetails.ComputerInfo = Get-ComputerInfo
            $SystemDetails.OsType = $PSVersionTable.OS
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

        # return system details
        Write-Output -InputObject $SystemDetails
    }
    catch
    {
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
}

###
### FUNCTION: read configuration file
###
function Import-Configuration
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding(DefaultParameterSetName = 'Default')]

    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path -Path "$($_)" -PathType 'Leaf' })]
        [String] $Path,

        [Parameter(Mandatory = $false)]
        [ValidateSet('json', 'raw')]
        [String] $Format = 'json'
    )

    try
    {
        # Read the configuration file
        Write-Verbose -Message "Reading configuration file: $($Path) with format $($Format)"
        switch ($Format)
        {
            'json' { $Config = Get-Content -Path "$($Path)" -Encoding 'UTF8' | ConvertFrom-Json }
            'raw' { $Config = Get-Content -Path "$($Path)" -Encoding 'UTF8' -Raw }
            default { throw "Invalid format: $($Format)" }
        }

        Write-Output -InputObject $Config
    }
    catch
    {
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
}

###
### FUNCTION: replace environment variables from config
###
function Update-EnvVariables
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding(DefaultParameterSetName = 'Default')]

    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSObject] $InputObject
    )

    try
    {
        # Replace environment variable
        if ($InputObject)
        {
            foreach ($element in $InputObject.psobject.properties.name)
            {
                foreach ($field in $InputObject.$($element).psobject.properties.name)
                {
                    Write-Verbose -Message "Element: $($element) - Field: $($field)"
                    
                    if ($InputObject.$($element).$($field) -like '*$($Env:*)*')
                    {
                        $SearchResult = Select-String -InputObject "$($InputObject.$($element).$($field))" -Pattern '\$\((.*?)\)' -AllMatches
                        
                        foreach ($match in $SearchResult.Matches)
                        {
                            $MatchValue = "$($match.value)"
                            $MatchString = "$($match.groups[1])"
                            Write-Verbose -Message "MatchValue: $($MatchValue)"
                            Write-Verbose -Message "MatchString: $($MatchString)"
                            
                            $EnvVariable = $MatchString.split(':')[1]
                            $EnvPath = (Get-Item -Path Env:\$EnvVariable).Value
                            $InputObject.$($element).$($field) = ($InputObject.$($element).$($field)).replace($MatchValue, $EnvPath)
                        }
                        Write-Verbose -Message "Element: $($element) - Field: $($field) - Environment variable updated"
                    }
                }
            }

            Write-Verbose -Message 'Update environment variables in configuration file successfully completed'
        }
        else
        {
            Write-Verbose -Message 'Config import missing'
        }

        Write-Output -InputObject $InputObject
    }
    catch
    {
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
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
### FUNCTION: Get status of application installation
###
function Get-ApplicationStatus
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding(DefaultParameterSetName = 'Default')]

    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSObject] $InputObject
    )

    try
    {
        # set parameter
        $OtherInstallationExists = $false

        # check if other installation exists
        if ($InputObject.setup_parameter.check_other_installation -eq 'yes')
        {
            Write-Logging -Module "$($MyInvocation.MyCommand)" -Value "[$($InputObject.application.display_name)] Check if other installation exists"
            
            # check other installation by ...
            switch -Wildcard ($InputObject.setup_parameter.check_other_installation_by)
            {
                'file*'
                {
                    Write-Logging -Module "$($MyInvocation.MyCommand)" -Value "[$($InputObject.application.display_name)] check other installation by: file*"
                    
                    # check if application is already installed
                    foreach ($install_path in $InputObject.application.install_path)
                    {
                        Write-Logging -Module "$($MyInvocation.MyCommand)" -Value "[$($InputObject.application.display_name)] check other installation by path: $($install_path)\$($InputObject.application.exec_name)"

                        if (Test-Path -Path "$($install_path)\$($InputObject.application.exec_name)" -PathType Leaf)
                        {
                            Write-Logging -Module "$($MyInvocation.MyCommand)" -Value "[$($InputObject.application.display_name)] Application file already exist"

                            if ($InputObject.setup_parameter.check_other_installation_by -eq 'file+version')
                            {
                                $CurrentItem = Get-Item -Path "$($install_path)\$($InputObject.application.exec_name)"
                                [Version]$CurrentItem_version = Get-NormalizedVersion -Value "$($CurrentItem.VersionInfo.FileVersion)"
                                [Version]$NewItem_version = Get-NormalizedVersion -Value "$($InputObject.application.version)"
                                
                                Write-Logging -Module "$($MyInvocation.MyCommand)" -Value "[$($InputObject.application.display_name)] Current application version: '$($CurrentItem_version)' ($($CurrentItem.VersionInfo.FileVersion))"
                                Write-Logging -Module "$($MyInvocation.MyCommand)" -Value "[$($InputObject.application.display_name)] New application version: '$($NewItem_version)' ($($InputObject.application.version))"

                                if ( $CurrentItem_version -ge $NewItem_version )
                                {
                                    Write-Logging -Module "$($MyInvocation.MyCommand)" -Value "[$($InputObject.application.display_name)] Current application version '$($CurrentItem_version)' is newer or equal to setup file '$($NewItem_version)'"
                                    $OtherInstallationExists = $true
                                    break
                                }

                                Get-Variable -Name 'CurrentItem' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
                                Get-Variable -Name 'CurrentItem_version' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
                                Get-Variable -Name 'NewItem_version' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
                            }
                            else
                            {
                                $OtherInstallationExists = $true
                            }
                            break
                        }
                    }
                    break
                }
                'folder'
                {
                    Write-Logging -Module "$($MyInvocation.MyCommand)" -Value "[$($InputObject.application.display_name)] check other installation by: folder"
                    
                    # check if application is already installed
                    foreach ($install_path in $InputObject.application.install_path)
                    {
                        if (Test-Path -Path "$($install_path)" -PathType Container)
                        {
                            Write-Logging -Module "$($MyInvocation.MyCommand)" -Value "[$($InputObject.application.display_name)] Application directory already exist"
                            $OtherInstallationExists = $true
                            break
                        }
                    }
                    break
                }
                'registry'
                {
                    Write-Logging -Module "$($MyInvocation.MyCommand)" -Value "[$($InputObject.application.display_name)] check other installation by: registry"
                    
                    # check if application is already installed
                    [Version]$LatestVersion = Get-NormalizedVersion -Value "$($InputObject.application.version)"
                    $MinVersion = $LatestVersion.Major

                    # check if application is already installed
                    $Splat = @{
                        DisplayName  = "$($InputObject.application.registry_name)"
                        VersionMajor = "$($MinVersion)"
                    }
                    
                    if ($InputObject.application.registry_exclusion_name)
                    {
                        $Splat.DisplayNameExclusion = "$($InputObject.application.registry_exclusion_name)"
                    }

                    if ($InputObject.application.registry_exclusion_uninstall_string)
                    {
                        $Splat.UninstallString = "$($InputObject.application.registry_exclusion_uninstall_string)"
                    }

                    $LocalAppInfo = Get-InstalledAppsFromRegistry @Splat
                    Get-Variable -Name 'Splat' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
                    Write-Logging -Module "$($MyInvocation.MyCommand)" -Value "[$($InputObject.application.display_name)] Number of installed applications: $( ($LocalAppInfo | Measure-Object).Count )"

                    # if application is installed check version
                    if ( ($LocalAppInfo | Measure-Object).Count -le 0 )
                    { 
                        Write-Logging -Module "$($MyInvocation.MyCommand)" -Value "[$($InputObject.application.display_name)] Specified application: $($InputObject.application.registry_name) is either invalid or application is not installed"
                        $OtherInstallationExists = $false
                    }
                    elseif ( ($LocalAppInfo | Measure-Object).Count -eq 1 )
                    {
                        # if DisplayVersion is empty, set default value
                        if ( [string]::IsNullOrEmpty($LocalAppInfo.DisplayVersion) )
                        {
                            $LocalAppInfo.DisplayVersion = '0.0'
                        }

                        # we assign comparable value through [System.Version] parameter to all object in array and sort them by latest version being on top
                        [Version]$ActualVersion = Get-NormalizedVersion -Value "$($LocalAppInfo.DisplayVersion)"

                        # more blabla to log, trust me, you'll need it for tests
                        Write-Logging -Module "$($MyInvocation.MyCommand)" -Value "[$($InputObject.application.display_name)] Local installed application name: '$($LocalAppInfo.DisplayName)' with version: '$($LocalAppInfo.DisplayVersion)'"

                        if ($ActualVersion -ge $LatestVersion)
                        {
                            Write-Logging -Module "$($MyInvocation.MyCommand)" -Value "[$($InputObject.application.display_name)] Client version: $($ActualVersion), Pushed version: $($LatestVersion)"
                            Write-Logging -Module "$($MyInvocation.MyCommand)" -Value "[$($InputObject.application.display_name)] Update not required due to client having newer version OR its the same"
                            $OtherInstallationExists = $true
                        }
                        else
                        { 
                            Write-Logging -Module "$($MyInvocation.MyCommand)" -Value "[$($InputObject.application.display_name)] Actual version: $($ActualVersion), Compared version: $($LatestVersion)"
                            Write-Logging -Module "$($MyInvocation.MyCommand)" -Value "[$($InputObject.application.display_name)] Update for $($LocalAppInfo.DisplayName) required, updating to version $($LatestVersion)"
                            $OtherInstallationExists = $false
                        }

                        Remove-Variable -Name 'ActualVersion'
                    }
                    else
                    { 
                        Write-Logging -Module "$($MyInvocation.MyCommand)" -Value "[$($InputObject.application.display_name)] Too many applications found: $($LocalAppInfo.DisplayName -join ' / ')"
                        $OtherInstallationExists = $true
                    }
                    
                    # clean-up
                    Get-Variable -Name 'LocalAppInfo' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
                    Get-Variable -Name 'FilterScript' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
                    Get-Variable -Name 'ReadRegistry' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
                    Get-Variable -Name 'RegistryUninstallPaths' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
                    Get-Variable -Name 'MinVersion' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
                    Get-Variable -Name 'LatestVersion' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
                    break
                }
                default
                {
                    Write-Logging -Module "$($MyInvocation.MyCommand)" -Value "[$($InputObject.application.display_name)] Value to check other installation not supported: $($InputObject.setup_parameter.check_other_installation_by)"
                    break
                }
            }
        }

        # check if existing installation should be replaced
        if ( ($InputObject.setup_parameter.replace_other_installation -eq 'no') -and ($OtherInstallationExists -eq $true) )
        {
            Write-Logging -Module "$($MyInvocation.MyCommand)" -Value "[$($InputObject.application.display_name)] Application replacement not allowed"
            $script:RunStatus.pre_setup = $false
        }
        else
        {
            Write-Logging -Module "$($MyInvocation.MyCommand)" -Value "[$($InputObject.application.display_name)] Application replacement allowed, continue with setup"
            
            # check if file download is enabled
            if ($InputObject.file_download.enabled -eq 'yes')
            {
                $script:RunStatus.download = $true
            }

            $script:RunStatus.pre_setup = $true
        }

        # clean-up
        Get-Variable -Name 'OtherInstallationExists' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force

        # return status
        Write-Output -InputObject $script:RunStatus
    }
    catch
    {
        Write-Logging -Module "$($MyInvocation.MyCommand)" -Value "[$($script:AppName)] Error: [$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)" -StdOut 'None'
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
}

###
### FUNCTION: invoke file download
###
function Invoke-FileDownload
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding(DefaultParameterSetName = 'Default')]

    param(
        [Parameter(Mandatory = $true)]
        [String] $Path,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String] $FileName,

        [Parameter(Mandatory = $true)]
        [ValidateScript({ $_ -like 'https://*' })]
        [String] $Url
    )

    try
    {
        Write-Logging -Module "$($MyInvocation.MyCommand)" -Value "[$($script:AppName)] Invoke file download"

        # create local repository
        if (-not (Test-Path -Path "$($Path)"))
        {
            New-Item -Path "$($Path)" -ItemType 'Directory' -Force | Out-Null
            Write-Logging -Module "$($MyInvocation.MyCommand)" -Value "[$($script:AppName)] Local repository created: $($Path)"
        }

        # abort if local repository does not exist
        if (-not ( Test-Path -Path "$($Path)" ) )
        {
            throw 'Local repository does not exist'
        }

        # remove previous file
        Write-Logging -Module "$($MyInvocation.MyCommand)" -Value "[$($script:AppName)] Remove previous files"
        $localFiles = Get-ChildItem -Path "$($Path)\*" -Filter "$($FileName)"
        if ( ($localFiles | Measure-Object).Count -gt 0 )
        {
            foreach ($file in $localFiles)
            {
                try
                {
                    Remove-Item -Path "$($file.FullName)" -Force -Confirm:$false
                    Write-Logging -Module "$($MyInvocation.MyCommand)" -Value "[$($script:AppName)] |__ File removed: $($file.FullName)"
                }
                catch
                {
                    Write-Logging -Module "$($MyInvocation.MyCommand)" -Value "[$($script:AppName)] |__ Error: $($_.Exception.Message)"
                }
            }
        }
        else
        {
            Write-Logging -Module "$($MyInvocation.MyCommand)" -Value "[$($script:AppName)] |__ No previous file found"
        }
        Get-Variable -Name 'localFiles' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force

        # create web request splat
        $WebRequestSplat = @{
            Uri             = "$($Url)"
            OutFile         = "$($Path)\$($FileName)"
            UseBasicParsing = $true
        }
        Write-Logging -Module "$($MyInvocation.MyCommand)" -Value "[$($script:AppName)] Splat: $( $WebRequestSplat | ConvertTo-Json -Compress )"

        # download a file through HTTP(S)
        $WebResult = Invoke-WebRequest @WebRequestSplat
        Write-Logging -Module "$($MyInvocation.MyCommand)" -Value "[$($script:AppName)] Web result: $( $WebResult | ConvertTo-Json -Compress -Depth 2 )"
        
        Get-Variable -Name 'WebResult' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
        Get-Variable -Name 'WebRequestSplat' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force

        # return content
        Write-Output -InputObject ( Get-Item -Path "$($Path)\$($FileName)" )
    }
    catch
    {
        Write-Logging -Module "$($MyInvocation.MyCommand)" -Value "[$($script:AppName)] Error: [$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)" -StdOut 'None'
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
}

###
### FUNCTION: Install Application
###
function Install-Application
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding(DefaultParameterSetName = 'Default')]

    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSObject] $InputObject,

        [Parameter(Mandatory = $true)]
        [ValidateSet('pre_setup', 'main_setup', 'post_setup')]
        [String] $Scope
    )
        
    try
    {
        # set parameters
        $SetupFile = "$($InputObject.file)"
        $SetupFile_Ext = "$( [System.IO.Path]::GetExtension($SetupFile) )".TrimStart('.')
        $SetupArguments = if ($InputObject.arguments) { $InputObject.arguments } else { @() }
        $SetupParameters = if ($InputObject.parameters) { $InputObject.parameters } else { $null }
        $SetupSleep = if ($InputObject.sleep) { $InputObject.sleep } else { $false }

        # set start process parameters
        $StartProcessSplat = @{
            FilePath     = ''
            ArgumentList = @()
        }
        
        if ($SetupParameters)
        {
            $SetupParameters.PsObject.Properties | ForEach-Object { $StartProcessSplat[$_.Name] = $_.Value }
        }

        # set sleep parameter
        $StartSleep = 30 #seconds

        # check if setup file path corresponds to Powershell execution path
        if ($SetupFile.substring(0, 3) -notlike '*:\' -and $SetupFile.substring(0, 2) -ne '.\')
        {
            switch ( $SetupFile_Ext )
            {
                'msi' { break }
                default
                {
                    $SetupFile = "$($PSScriptRoot)\$($SetupFile)"
                    break
                }
            }
        }

        Write-Logging -Module "$($MyInvocation.MyCommand)" -Value "[$($script:AppName)] [$($SetupFile_Ext)] [$Scope] Installation will be started: $($SetupFile)"

        # check setup file extension and set file path and arguments
        switch ( $SetupFile_Ext )
        {
            'msi'
            {
                $StartProcessSplat['FilePath'] = 'msiexec.exe'
                $StartProcessSplat['ArgumentList'] += "/i `"$($SetupFile)`""
                $StartProcessSplat['ArgumentList'] += $SetupArguments
                break
            }
            'ps1'
            {
                $StartProcessSplat['FilePath'] = "$($Env:SystemRoot)\system32\WindowsPowerShell\v1.0\powershell.exe"
                $StartProcessSplat['ArgumentList'] += '-ExecutionPolicy ByPass'
                $StartProcessSplat['ArgumentList'] += "-File `"$($SetupFile)`""
                break
            }
            default
            {
                Write-Logging -Module "$($MyInvocation.MyCommand)" -Value "[$($script:AppName)] Use default installation method"
                $StartProcessSplat['FilePath'] = "$($SetupFile)"
                $StartProcessSplat['ArgumentList'] += $SetupArguments
                break
            }
        }

        # remove argument list if empty
        if ( [string]::IsNullOrEmpty($StartProcessSplat['ArgumentList']) )
        {
            $StartProcessSplat.Remove('ArgumentList')
        }

        # start installation of setup file
        Write-Logging -Module "$($MyInvocation.MyCommand)" -Value "[$($script:AppName)] Splat: $($StartProcessSplat | ConvertTo-Json -Depth 3 -Compress)"
        Start-Process @StartProcessSplat

        # check if script should sleep after installation
        if ($SetupSleep -eq 'yes')
        {
            Write-Logging -Module "$($MyInvocation.MyCommand)" -Value "[$($script:AppName)] Sleep for $($StartSleep) seconds"
            Start-Sleep -Seconds $StartSleep
        }

        switch ($Scope)
        {
            'pre_setup'
            {
                $script:RunStatus.main_setup = $true
                break
            }
            'main_setup'
            {
                $script:RunStatus.post_setup = $true
                break
            }
            'post_setup'
            {
                break
            }
            default
            {
                break
            }
        }

        # clean-up
        Get-Variable -Name 'StartProcessSplat' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
        Get-Variable -Name 'SetupSleep' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
        Get-Variable -Name 'SetupParameters' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
        Get-Variable -Name 'SetupArguments' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
        Get-Variable -Name 'SetupFile_Ext' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
        Get-Variable -Name 'SetupFile' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
    }
    catch
    {
        Write-Logging -Module "$($MyInvocation.MyCommand)" -Value "[$($script:AppName)] Error: [$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)" -StdOut 'None'
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
}

###
### MAIN SCRIPT
###
try
{
    # import configuration
    $AppConfigObject = Update-EnvVariables -InputObject ( Import-Configuration -Path "$($script:ConfigFilePath)\$($script:ConfigFileName)" )
    $script:AppName = "$($AppConfigObject.application.display_name)"

    Write-Logging -Value "[$($script:AppName)] ### SCRIPT BEGIN #################################"
    Write-Logging -Value "[$($script:AppName)] Json version: $($AppConfigObject._version)"

    # get system details log
    $SystemDetails = Get-LocalSystemDetails
    Write-Logging -Value "[$($script:AppName)] Local system details: $($SystemDetails | ConvertTo-Json -Depth 3 -Compress)" -StdOut 'None'

    # check if other installation exists
    Get-ApplicationStatus -InputObject $AppConfigObject | Out-Null

    # download file
    if ($script:RunStatus.download)
    {
        # check file download is enabled ...
        if ($AppConfigObject.file_download.enabled -eq 'yes')
        {
            Write-Logging -Value "[$($script:AppName)] Start with File-Download"
            $DownloadResult = Invoke-FileDownload -Path "$($script:DownloadPath)" -FileName "$($AppConfigObject.file_download.filename)" -Url "$($AppConfigObject.file_download.url)"
            
            if ($DownloadResult)
            {
                Write-Logging -Value "[$($script:AppName)] Downloaded file: $($DownloadResult.FullName)"
            }
            else
            {
                throw 'Download failed'
            }

            Get-Variable -Name 'DownloadResult' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
        }
    }
    
    # run pre-setup
    if ($script:RunStatus.pre_setup)
    {
        # check pre-setup is enabled ...
        if ($AppConfigObject.pre_setup.enabled -eq 'yes')
        {
            Write-Logging -Value "[$($script:AppName)] Start with Pre-Setup"
            Install-Application -InputObject $AppConfigObject.pre_setup -Scope 'pre_setup'
        }
        else
        {
            $script:RunStatus.main_setup = $true
        }
    }

    # run main-setup
    if ($script:RunStatus.main_setup)
    {
        Write-Logging -Value "[$($script:AppName)] Start with Main-Setup"
        Install-Application -InputObject $AppConfigObject.main_setup -Scope 'main_setup'
    }
    
    # run post-setup
    if ($script:RunStatus.post_setup)
    {
        # check post-setup is enabled ...
        if ($AppConfigObject.post_setup.enabled -eq 'yes')
        {
            Write-Logging -Value "[$($script:AppName)] Start with Post-Setup"
            Install-Application -InputObject $AppConfigObject.post_setup -Scope 'post_setup'
        }
    }

    # clean-up
    Get-Variable -Name 'AppConfigObject' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force

    Write-Logging -Value "[$($script:AppName)] ### SCRIPT END ###################################"
}
catch
{
    Write-Logging -Value "Error: [$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    $exit_code = $($_.Exception.HResult)
}

exit $exit_code