#
## basic information:
## |__ App removal script
#
## Supported PowerShell versions:
## |__ v5.1
#
## location: Intune
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
$AppMinVersion = "$($AppPackageData.'REPLACEMENT-APP-MAJOR-VERSION')"
$AppNameExclusion = "$($AppPackageData.'REPLACEMENT-APP-NAME-EXCLUSION')"
$UninstallStringExclusion = "$($AppPackageData.'REPLACEMENT-APP-UNINSTALL-STRING-EXCLUSION')"
$StartProcess_Parameters = $AppPackageData.'REPLACEMENT-APP-PARAMETERS'
$StartProcess_ArgumentList = $AppPackageData.'REPLACEMENT-APP-ARGUMENT-LIST'
$StartProcess_PreRemovalScript = if ($AppPackageData.'REPLACEMENT-APP-PRE-REMOVAL-SCRIPT') { $AppPackageData.'REPLACEMENT-APP-PRE-REMOVAL-SCRIPT' } else { $false }
$StartProcess_PostRemovalScript = if ($AppPackageData.'REPLACEMENT-APP-POST-REMOVAL-SCRIPT') { $AppPackageData.'REPLACEMENT-APP-POST-REMOVAL-SCRIPT' } else { $false }

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

        Write-Output -InputObject $SystemDetails
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
    Write-Logging -Value '[SR] Script: intunewin-app-installation-removal'
    Write-Logging -Value "[SR] App name: $($AppName)"

    # get system details log
    $SystemDetails = Get-LocalSystemDetails
    Write-Logging -Value "[SR] System Details: $($SystemDetails | ConvertTo-Json -Depth 3 -Compress)" -StdOut 'None'

    # run pre-removal
    if ($StartProcess_PreRemovalScript)
    {
        Write-Logging -Value "[SR] [$($AppName)] Start with Pre-Removal"
        $Splat = @{
            FilePath     = "$($Env:SystemRoot)\system32\WindowsPowerShell\v1.0\powershell.exe"
            ArgumentList = @(
                '-ExecutionPolicy ByPass'
                '-File pre-removal.ps1'
            )
            Wait         = $true
            NoNewWindow  = $true
        }
        Write-Logging -Value "[SR] Splat: $($Splat | ConvertTo-Json -Depth 3 -Compress)"
        Start-Process @Splat
        Get-Variable -Name 'Splat' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
        Write-Logging -Value '[SR] Pre-removal script executed'
    }

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

    # if application is installed check version
    if ( ($LocalAppInfo | Measure-Object).Count -le 0 )
    { 
        Write-Logging -Value "[SR] Specified application: $($AppName) not found"
    }
    else
    {
        ###
        ### Remove application
        ###
        foreach ($localApp in $LocalAppInfo)
        {
            Write-Logging -Value '---'
            Write-Logging -Value "[SR] Removal required for local installed application: name: $($localApp.DisplayName) / version: $($localApp.DisplayVersion)"
            Write-Logging -Value "[SR] Local application details: $($localApp | ConvertTo-Json -Depth 3 -Compress)" -StdOut 'None'
            
            try
            {
                # set process parameters
                $StartProcessSplat = @{
                    FilePath     = ''
                    ArgumentList = ''
                    Wait         = $true
                    NoNewWindow  = $true
                }
                
                if ($StartProcess_Parameters)
                {
                    $StartProcess_Parameters.PsObject.Properties | ForEach-Object { $StartProcessSplat[$_.Name] = $_.Value }
                }

                if ($localApp.UninstallString -like 'msiexec.exe*')
                {
                    Write-Logging -Value '[SR] Uninstallation by MSI'

                    $StartProcessSplat['FilePath'] = 'msiexec.exe'
                    $StartProcessSplat['ArgumentList'] = @(if ( [string]::IsNullOrEmpty($StartProcess_ArgumentList) ) { '/qn' } else { $StartProcess_ArgumentList }, "/x `"$($localApp.PSChildName)`"")
                }
                elseif ($localApp.UninstallString -like '*.exe*')
                {
                    Write-Logging -Value '[SR] Uninstallation by EXE'

                    $StartProcessSplat['FilePath'] = "$(($localApp.UninstallString.Replace('"','') | Select-String -Pattern '^(.*\.exe)').Matches[0].Value)"
                    $StartProcessSplat['ArgumentList'] = @(if ( [string]::IsNullOrEmpty($StartProcess_ArgumentList) ) { '/S' } else { $StartProcess_ArgumentList })
                }
                else
                {
                    Write-Logging -Value '[SR] Uninstallation not supported'
                }

                if (-not ( [string]::IsNullOrEmpty($StartProcessSplat['FilePath']) ) )
                {
                    Write-Logging -Value "[SR] Splat: $($StartProcessSplat | ConvertTo-Json -Compress)" -StdOut 'None'
                    Start-Process @StartProcessSplat
                    Write-Logging -Value '[SR] Application successfully removed'
                }
            }
            catch
            {
                Write-Logging -Value "Error: [$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
            }
        }
    }

    # run post-removal
    if ($StartProcess_PostRemovalScript)
    {
        Write-Logging -Value "[SR] [$($AppName)] Start with Post-Removal"
        $Splat = @{
            FilePath     = "$($Env:SystemRoot)\system32\WindowsPowerShell\v1.0\powershell.exe"
            ArgumentList = @(
                '-ExecutionPolicy ByPass'
                '-File post-removal.ps1'
            )
            Wait         = $true
            NoNewWindow  = $true
        }
        Write-Logging -Value "[SR] Splat: $($Splat | ConvertTo-Json -Depth 3 -Compress)"
        Start-Process @Splat
        Get-Variable -Name 'Splat' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
        Write-Logging -Value '[SR] Pre-removal script executed'
    }

    Write-Logging -Value '### SCRIPT END ###################################'
}
catch
{
    Write-Logging -Value "[SR] Error: [$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    $exit_code = $($_.Exception.HResult)
}

exit $exit_code
