#
## basic information:
## |__ WinGet app removal script
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
$Ids = $AppPackageData.'REPLACEMENT-APP-ID'
$AppName = "$($AppPackageData.'REPLACEMENT-APP-NAME')"
$Action = if ($AppPackageData.'REPLACEMENT-APP-ACTION') { "$($AppPackageData.'REPLACEMENT-APP-ACTION')" } else { 'removal' }
$AdditionalArguments = $AppPackageData.'REPLACEMENT-APP-ARGUMENT-LIST'

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

###
### FUNCTION: Manage WinGet apps for installation, removal or available updates and optionally upgrades them
###
function Deploy-WingetApps
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding(DefaultParameterSetName = 'Default')]

    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('user', 'machine')]
        [String] $Scope = 'user',

        [Parameter(Mandatory = $false)]
        [Switch] $Install = $false,

        [Parameter(Mandatory = $false)]
        [Switch] $Removal = $false,

        [Parameter(Mandatory = $false)]
        [Switch] $Update = $false,

        [Parameter(Mandatory = $false)]
        [Switch] $CheckAvailableUpdates = $false,

        [Parameter(Mandatory = $false)]
        [Switch] $ListInstalled = $false,

        [Parameter(Mandatory = $false)]
        [Switch] $ListPinned = $false,

        [Parameter(Mandatory = $false)]
        [Switch] $DisableProgress,

        [Parameter(Mandatory = $false)]
        [Object[]] $AdditionalArguments = @(),

        [Parameter(Mandatory = $false)]
        [bool] $IncludeScope = $true,

        [Parameter(Mandatory = $false)]
        [Object[]] $Exclude = @()
    )

    function Get-WinGetUserSettings
    {
        [OutputType([System.Management.Automation.PSObject])]
        [CmdLetBinding(DefaultParameterSetName = 'Default')]

        param(
            [Parameter(Mandatory = $false)]
            [String] $Path = "$($Env:LOCALAPPDATA)\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\settings.json"
        )

        try
        {
            Write-Verbose -Message "WinGet user settings path: $($Path)"

            if (-not (Test-Path -Path "$($Path)" -PathType 'Leaf') )
            {
                throw 'WinGet user settings file not found.'
            }

            # Get user-specific settings for WinGet
            Write-Verbose -Message 'Read WinGet user settings'
            $Settings = Get-Content -Path "$($Path)" -Raw | ConvertFrom-Json
            Write-Verbose -Message "Settings: $($Settings | ConvertTo-Json -Depth 5 -Compress)"
            Write-Output -InputObject $Settings
        }
        catch
        {
            Write-Warning -Message "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
            Write-Output -InputObject ( [PSCustomObject]@{ '$schema' = 'https://aka.ms/winget-settings.schema.json' } )
        }
    }

    function New-WinGetUserSettings
    {
        [OutputType([System.Management.Automation.PSObject])]
        [CmdLetBinding(DefaultParameterSetName = 'Default')]

        param(
            [Parameter(Mandatory = $false)]
            [String] $Path = "$($Env:LOCALAPPDATA)\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\settings.json",

            [Parameter(Mandatory = $false)]
            [System.Management.Automation.PSObject] $UserSettings = (Get-WinGetUserSettings -Path "$($Path)"),

            [Parameter(Mandatory = $false)]
            [System.Management.Automation.PSObject] $NewSettings
        )

        try
        {
            Write-Verbose -Message "WinGet user settings path: $($Path)"

            # Check if folder exists
            if (-not (Test-Path -Path "$($Path)" -PathType 'Leaf'))
            {
                $ParentPath = Split-Path -Path "$($Path)" -Parent

                if (-not (Test-Path -Path "$($ParentPath)" -PathType 'Container'))
                {
                    New-Item -Path "$($ParentPath)" -ItemType 'Directory' -Force | Out-Null
                }
            }

            # Add new settings to user settings
            Write-Verbose -Message 'Adding new settings to WinGet user settings'
            foreach ($setting in $NewSettings)
            {
                $nameParts = $setting.Name -split '\.'
                $current = $UserSettings

                for ($i = 0; $i -lt $nameParts.Length - 1; $i++)
                {
                    $part = $nameParts[$i]

                    if (-not ($current.PSObject.Properties.Name -contains $part))
                    {
                        $current | Add-Member -MemberType NoteProperty -Name $part -Value ([PSCustomObject]@{})
                    }

                    $current = $current.$part
                }

                $finalPart = $nameParts[-1]
                $current | Add-Member -Force -MemberType NoteProperty -Name $finalPart -Value $setting.Value
            }

            # Set user-specific settings for WinGet
            Write-Verbose -Message 'Write WinGet user settings'
            $UserSettings | ConvertTo-Json -Depth 20 | Out-File -FilePath "$($Path)" -Encoding 'UTF8' -Force

            # Return updated user settings
            Write-Output -InputObject (Get-WinGetUserSettings -Path "$($Path)")
        }
        catch
        {
            Write-Warning -Message "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
        }
    }

    function ConvertFrom-WinGetCliOutput
    {
        [OutputType([System.Management.Automation.PSObject])]
        [CmdLetBinding(DefaultParameterSetName = 'Default')]

        param(
            [Parameter(Mandatory = $false)]
            [String] $InputString = '',

            [Parameter(Mandatory = $false)]
            [Switch] $IsTable = $false
        )

        try
        {
            # validate input
            if ( [String]::IsNullOrEmpty($InputString) )
            {
                throw 'InputString is null or empty.'
            }
            
            # create output object
            $outputInfo = [PSCustomObject]@{
                Content        = @()
                AdditionalBody = @()
                RawContent     = "$($InputString.Clone().Trim())"
            }

            # Split the input string into an array of lines
            $InputObject = "$($InputString.Clone())".Split("`n")
            Write-Verbose -Message "Input Object Length: $($InputObject.Length)"

            # define how the input should be parsed
            if ($IsTable)
            {
                $lineIndex = 0
                foreach ($line in $InputObject)
                {
                    Write-Verbose -Message "Line Index: $($lineIndex)"

                    if ( ($lineIndex -eq 0) -and ($line -match '^(.+?)\s{2,}(.+?)\s{2,}(.+?)(?:\s{2,}(.+?))?\s{2,}(.+)$') )
                    {
                        # capture header line
                        Write-Verbose -Message "Capture header line: '$($line)'"
                        $TableHeaderComponents = $line | Select-String -Pattern '^(?<Name>Name\s+)(?<Id>Id\s+)(?<Version>Version\s+)(?<Available>Available\s+)?(?<Source>Source\s*)'

                        if (-not $TableHeaderComponents)
                        {
                            throw 'Header line not found.'
                        }

                        # Capture table components
                        $TableHeaderLength = $line.Length + 10
                        $TableHeaderComponentsName = $TableHeaderComponents.Matches.Captures.Groups['Name']
                        $TableHeaderComponentsId = $TableHeaderComponents.Matches.Captures.Groups['Id']
                        $TableHeaderComponentsVersion = $TableHeaderComponents.Matches.Captures.Groups['Version']
                        $TableHeaderComponentsAvailable = $TableHeaderComponents.Matches.Captures.Groups['Available']
                        $TableHeaderComponentsSource = $TableHeaderComponents.Matches.Captures.Groups['Source']

                        Write-Verbose -Message "Column 'Name' '$($TableHeaderComponentsName.Index)' '$($TableHeaderComponentsName.Length)': '$($TableHeaderComponentsName)'"
                        Write-Verbose -Message "Column 'Id' '$($TableHeaderComponentsId.Index)' '$($TableHeaderComponentsId.Length)': '$($TableHeaderComponentsId)'"
                        Write-Verbose -Message "Column 'Version' '$($TableHeaderComponentsVersion.Index)' '$($TableHeaderComponentsVersion.Length)': '$($TableHeaderComponentsVersion)'"
                        Write-Verbose -Message "Column 'Available' '$($TableHeaderComponentsAvailable.Index)' '$($TableHeaderComponentsAvailable.Length)': '$($TableHeaderComponentsAvailable)'"
                        Write-Verbose -Message "Column 'Source' '$($TableHeaderComponentsSource.Index)' '$($TableHeaderComponentsSource.Length)': '$($TableHeaderComponentsSource)'"
                    }
                    elseif ($lineIndex -eq 1 -and ($line -match '^[-]{5,}.*$'))
                    {
                        # skip separator line
                        Write-Verbose -Message 'Skip separator line'
                    }
                    elseif ( ($lineIndex -gt 0) -and ($line -match '^(.+?)\s{1,}([a-zA-Z]\S+?\.\S+?)\s{1,}(.+?)(?:\s{1,}(.+?))?\s{1,}(.+)$') )
                    {
                        if (-not ($TableHeaderLength) )
                        {
                            throw 'Header length not found.'
                        }
                        
                        # capture body lines
                        Write-Verbose -Message "Line: '$($line)'"
                        $linePadded = $line.PadRight($TableHeaderLength, ' ')
                        Write-Verbose -Message "Line Padded: '$($linePadded)'"

                        $outputInfo.Content += [PSCustomObject]@{
                            Name      = "$($linePadded.Substring($TableHeaderComponentsName.Index, $TableHeaderComponentsName.Length))".Trim()
                            Id        = "$($linePadded.Substring($TableHeaderComponentsId.Index, $TableHeaderComponentsId.Length))".Trim()
                            Version   = "$($linePadded.Substring($TableHeaderComponentsVersion.Index, $TableHeaderComponentsVersion.Length))".Trim()
                            Available = "$($linePadded.Substring($TableHeaderComponentsAvailable.Index, $TableHeaderComponentsAvailable.Length))".Trim()
                            Source    = "$($linePadded.Substring($TableHeaderComponentsSource.Index, $TableHeaderComponentsSource.Length))".Trim()
                        }
                    }
                    else
                    {
                        # capture additional body lines
                        Write-Verbose -Message "Additional Line: '$($line)'"
                        $TrimmedLine = "$($line.Trim())"
                        if ([String]::IsNullOrEmpty($TrimmedLine))
                        {
                            Write-Verbose -Message 'Skip empty line'
                        }
                        else
                        {
                            $outputInfo.AdditionalBody += "$($TrimmedLine)"
                        }
                    }

                    # increment line index
                    $lineIndex++
                }
            }
            else
            {
                Write-Verbose -Message 'Raw output will be returned'
            }
        }
        catch
        {
            Write-Warning -Message "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
        }
        finally
        {
            Write-Output -InputObject $outputInfo
        }
    }

    function Get-WinGetExecutable
    {
        [OutputType([System.String])]
        [CmdLetBinding(DefaultParameterSetName = 'Default')]

        param()

        try
        {
            # check if AppInstaller is installed
            Write-Verbose -Message 'Check if AppInstaller is installed'
            try
            {
                $AppInstaller = Get-AppxProvisionedPackage -Online -ErrorAction 'Stop' | Where-Object { $_.DisplayName -eq 'Microsoft.DesktopAppInstaller' }
                Write-Verbose -Message "AppInstaller Version: $([Version]$AppInstaller.Version)"
            }
            catch
            {
                Write-Warning -Message "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
            }
            finally
            {
                Get-Variable -Name 'AppInstaller' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
            }

            # search for winget executable
            Write-Verbose -Message 'Search for winget executable'
            $WinGetDirectories = @()
            $WinGetDirectories += "C:\Users\$($Env:USERNAME)\AppData\Local\Microsoft\WindowsApps\winget.exe"
            $WinGetDirectories += Resolve-Path 'C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_*__8wekyb3d8bbwe\winget.exe' -ErrorAction 'SilentlyContinue'
            # $WinGetDirectories += Get-ChildItem -Path "C:\Program Files\WindowsApps" -Recurse -File -ErrorAction 'SilentlyContinue' | Where-Object { $_.Name -eq "winget.exe" } | Select-Object -ExpandProperty FullName
            # $WinGetDirectories += Get-ChildItem -Path "C:\Program Files\WindowsApps" -Recurse -File -ErrorAction 'SilentlyContinue' | Where-Object { $_.Name -eq "AppInstallerCLI.exe" } | Select-Object -ExpandProperty FullName
            Write-Verbose -Message "WinGet directories: $($WinGetDirectories -join ', ')"

            # determine which winget executable to use
            Write-Verbose -Message 'Determine which winget executable to use'
            $WingetExecutable = $WinGetDirectories | Where-Object { Test-Path -Path "$($_)" -PathType 'Leaf' } | Select-Object -First 1
            Write-Verbose -Message "WinGet executable: $($WingetExecutable)"

            # clean-up
            Get-Variable -Name 'WinGetDirectories' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force

            # check if WinGet executable is available
            if (-not $WingetExecutable)
            {
                throw 'WinGet not found'
            }

            # output winget executable
            Write-Output -InputObject "$($WingetExecutable)"
        }
        catch
        {
            Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
        }
    }

    function Invoke-WingetCommand
    {
        [OutputType([System.String])]
        [CmdLetBinding(DefaultParameterSetName = 'Default')]

        param(
            [Parameter(Mandatory = $false)]
            [ValidateScript({ Test-Path -Path "$($_)" -PathType 'Leaf' })]
            [String] $FilePath,

            [Parameter(Mandatory = $false)]
            [Object[]] $AdditionalArguments = @()
        )

        try
        {
            Write-Verbose -Message "File Path: $($FilePath)"
            Write-Verbose -Message "Additional Arguments: $($AdditionalArguments -join ', ')"
            $AdditionalArguments = $AdditionalArguments | Select-Object -Unique
            Write-Verbose -Message "Unique Additional Arguments: $($AdditionalArguments -join ', ')"

            # create splat
            $ProcessStartInfo = New-Object Diagnostics.ProcessStartInfo
            $ProcessStartInfo.FileName = "$($FilePath)"
            $ProcessStartInfo.Arguments = "$($AdditionalArguments -join ' ')"
            $ProcessStartInfo.UseShellExecute = $false
            $ProcessStartInfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8
            $ProcessStartInfo.RedirectStandardOutput = $true

            $Process = [Diagnostics.Process]::Start($ProcessStartInfo)
            
            $ProcessResult = $Process.StandardOutput.ReadToEnd()
            
            $Process.WaitForExit()

            Write-Verbose -Message "Output:$([Environment]::NewLine)$($ProcessResult)"
            Write-Output -InputObject "$($ProcessResult)"

            # clean-up
            Get-Variable -Name 'ProcessStartInfo' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
            Get-Variable -Name 'Process' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
            Get-Variable -Name 'ProcessResult' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
        }
        catch
        {
            Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
        }
    }

    try
    {
        $outputInfo = [PSCustomObject]@{
            Scope            = "$($Scope)"
            Command          = ''
            UpdatesAvailable = $false
            ConsoleOutput    = ''
        }

        # get WinGet excutable
        $WingetExecutable = Get-WinGetExecutable
        
        # get WinGet user settings path
        if ($Scope -eq 'Machine')
        {
            $WingetUserSettingsPath = 'C:\Windows\System32\config\systemprofile\AppData\Local\Microsoft\WinGet\Settings\defaultState\settings.json'
        }
        else
        {
            $WingetUserSettingsPath = "$($Env:LOCALAPPDATA)\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\settings.json"
        }

        # set WinGet user settings to disable progress reporting
        if ($DisableProgress)
        {
            Write-Verbose -Message 'Set user settings to disable progress reporting'
            $WingetUserSettings = Get-WinGetUserSettings -Path "$($WingetUserSettingsPath)"
            $NewWingetUserSettings = New-WinGetUserSettings -Path "$($WingetUserSettingsPath)" -UserSettings $WingetUserSettings.PSObject.Copy() -NewSettings @( @{ Name = 'visual.progressBar'; Value = 'disabled' } )
            Write-Verbose -Message "WinGet user settings updated: $($NewWingetUserSettings | ConvertTo-Json -Depth 5 -Compress)"
            Get-Variable -Name 'NewWingetUserSettings' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
        }

        Write-Verbose -Message "Run upgrade by WinGet (User: $($env:USERNAME) / Scope: $($Scope))"

        # include scope if specified
        if ($IncludeScope)
        {
            $AdditionalArguments += "--scope $($Scope)"
        }

        # exclude apps if specified
        if ($Exclude -and $Exclude.Count -gt 0)
        {
            foreach ($AppId in $Exclude)
            {
                try
                {
                    Write-Verbose -Message "Add pinned app: $($AppId)"
                    $Splat = @{
                        FilePath            = "$($WingetExecutable)"
                        AdditionalArguments = @('pin', 'add', "--id $($AppId)", '--exact', '--accept-source-agreements', '--disable-interactivity')
                    }
                    Write-Verbose -Message "Splat: $($Splat | ConvertTo-Json -Compress -Depth 5)"
    
                    $CliOutput = Invoke-WingetCommand @Splat
                    Write-Verbose -Message "CLI Output:$([Environment]::NewLine)$($CliOutput)"
                    Get-Variable -Name 'Splat' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
                    Get-Variable -Name 'CliOutput' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
                }
                catch
                {
                    Write-Warning -Message "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
                }
            }
        }

        # check and detect available updates
        if ($CheckAvailableUpdates)
        {
            Write-Verbose -Message 'Check and detect available updates'
            $Splat = @{
                FilePath            = "$($WingetExecutable)"
                AdditionalArguments = @('upgrade', '--accept-source-agreements') + $AdditionalArguments
            }

            $outputInfo.Command = "$($Splat.FilePath) $($Splat.AdditionalArguments -join ' ')"
            $CliOutput = Invoke-WingetCommand @Splat
            $outputInfo.ConsoleOutput = ConvertFrom-WinGetCliOutput -InputString "$($CliOutput)" -IsTable
            $outputInfo.UpdatesAvailable = $outputInfo.ConsoleOutput.Content.Count -gt 0
            Get-Variable -Name 'Splat' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
            Get-Variable -Name 'CliOutput' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
        }
        # check and install updates
        elseif ($Update)
        {
            Write-Verbose -Message 'Check and install updates'
            $AdditionalArguments += if ( "$( $AdditionalArguments -join ' ' )" -notlike '*--id *' ) { '--all' }
            $Splat = @{
                FilePath            = "$($WingetExecutable)"
                AdditionalArguments = @('upgrade', '--silent', '--force', '--accept-source-agreements', '--disable-interactivity') + $AdditionalArguments
            }

            $outputInfo.Command = "$($Splat.FilePath) $($Splat.AdditionalArguments -join ' ')"
            $CliOutput = Invoke-WingetCommand @Splat
            $outputInfo.ConsoleOutput = ConvertFrom-WinGetCliOutput -InputString "$($CliOutput)" -IsTable
            $outputInfo.UpdatesAvailable = $outputInfo.ConsoleOutput.Content.Count -gt 0
            Get-Variable -Name 'Splat' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
            Get-Variable -Name 'CliOutput' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
        }
        # install Winget app
        elseif ($Install)
        {
            Write-Verbose -Message 'Install new app'
            if ( "$( $AdditionalArguments -join ' ' )" -notlike '*--id *' )
            {
                throw "No app Id specified. Use -AdditionalArguments @('--id <AppId>') to specify the app Id."
            }

            $Splat = @{
                FilePath            = "$($WingetExecutable)"
                AdditionalArguments = @('install', '--silent', '--force', '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity') + $AdditionalArguments
            }

            $outputInfo.Command = "$($Splat.FilePath) $($Splat.AdditionalArguments -join ' ')"
            $CliOutput = Invoke-WingetCommand @Splat
            $outputInfo.ConsoleOutput = ConvertFrom-WinGetCliOutput -InputString "$($CliOutput)"
            $outputInfo.UpdatesAvailable = $outputInfo.ConsoleOutput.Content.Count -gt 0
            Get-Variable -Name 'Splat' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
            Get-Variable -Name 'CliOutput' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
        }
        # remove Winget app
        elseif ($Removal)
        {
            Write-Verbose -Message 'Remove app'
            if ( "$( $AdditionalArguments -join ' ' )" -notlike '*--id *' )
            {
                throw "No app Id specified. Use -AdditionalArguments @('--id <AppId>') to specify the app Id."
            }

            $Splat = @{
                FilePath            = "$($WingetExecutable)"
                AdditionalArguments = @('remove', '--silent', '--force', '--accept-source-agreements', '--disable-interactivity') + $AdditionalArguments
            }

            $outputInfo.Command = "$($Splat.FilePath) $($Splat.AdditionalArguments -join ' ')"
            $CliOutput = Invoke-WingetCommand @Splat
            $outputInfo.ConsoleOutput = ConvertFrom-WinGetCliOutput -InputString "$($CliOutput)"
            $outputInfo.UpdatesAvailable = $outputInfo.ConsoleOutput.Content.Count -gt 0
            Get-Variable -Name 'Splat' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
            Get-Variable -Name 'CliOutput' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
        }
        # list installed Winget apps
        elseif ($ListInstalled)
        {
            Write-Verbose -Message 'List installed apps'
            $Splat = @{
                FilePath            = "$($WingetExecutable)"
                AdditionalArguments = @('list', '--accept-source-agreements', '--disable-interactivity') + $AdditionalArguments
            }

            $outputInfo.Command = "$($Splat.FilePath) $($Splat.AdditionalArguments -join ' ')"
            $CliOutput = Invoke-WingetCommand @Splat
            $outputInfo.ConsoleOutput = ConvertFrom-WinGetCliOutput -InputString "$($CliOutput)" -IsTable
            $outputInfo.UpdatesAvailable = if ( ($outputInfo.ConsoleOutput.Content.Available | Where-Object { [String]::IsNullOrEmpty($_) -eq $false } | Measure-Object).Count -gt 0) { $true } else { $false }
            Get-Variable -Name 'Splat' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
            Get-Variable -Name 'CliOutput' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
        }
        # list pinned Winget apps
        elseif ($ListPinned)
        {
            Write-Verbose -Message 'List pinned apps'
            $Splat = @{
                FilePath            = "$($WingetExecutable)"
                AdditionalArguments = @('pin', 'list', '--accept-source-agreements', '--disable-interactivity') + $AdditionalArguments
            }

            $outputInfo.Command = "$($Splat.FilePath) $($Splat.AdditionalArguments -join ' ')"
            $CliOutput = Invoke-WingetCommand @Splat
            $outputInfo.ConsoleOutput = ConvertFrom-WinGetCliOutput -InputString "$($CliOutput)" -IsTable
            $outputInfo.UpdatesAvailable = if ( ($outputInfo.ConsoleOutput.Content.Available | Where-Object { [String]::IsNullOrEmpty($_) -eq $false } | Measure-Object).Count -gt 0) { $true } else { $false }
            Get-Variable -Name 'Splat' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
            Get-Variable -Name 'CliOutput' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
        }
        else
        {
            throw 'No action specified. Use -Update or -CheckAvailableUpdates to check for available updates.'
        }

        Write-Output -InputObject $outputInfo
    }
    catch
    {
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
    finally
    {
        # remove pinned apps if specified
        if ($Exclude -and $Exclude.Count -gt 0)
        {
            foreach ($AppId in $Exclude)
            {
                try
                {
                    Write-Verbose -Message "Remove pinned app: $($AppId)"
                    $Splat = @{
                        FilePath            = "$($WingetExecutable)"
                        AdditionalArguments = @('pin', 'remove', "--id $($AppId)", '--exact', '--accept-source-agreements', '--disable-interactivity')
                    }
                    Write-Verbose -Message "Splat: $($Splat | ConvertTo-Json -Compress -Depth 5)"
    
                    $CliOutput = Invoke-WingetCommand @Splat
                    Write-Verbose -Message "CLI Output:$([Environment]::NewLine)$($CliOutput)"
                    Get-Variable -Name 'Splat' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
                    Get-Variable -Name 'CliOutput' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
                }
                catch
                {
                    Write-Warning -Message "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
                }
            }
        }

        # Reset WinGet user settings
        if ($WingetUserSettings)
        {
            Write-Verbose -Message 'Reset WinGet user settings to previous state'
            New-WinGetUserSettings -Path "$($WingetUserSettingsPath)" -UserSettings $WingetUserSettings -NewSettings $null | Out-Null
            Get-Variable -Name 'WingetUserSettings' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
        }
        
        # clean-up
        Get-Variable -Name 'WingetExecutable' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
        Get-Variable -Name 'WingetUserSettingsPath' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
    }
}

###
### MAIN SCRIPT
###
try
{
    Write-Logging -Value '### SCRIPT BEGIN #################################' -Mode 'set'
    Write-Logging -Value '[SR] Script: intunewinget-app-installation-removal'
    Write-Logging -Value "[SR] App Name: $($AppName)"

    foreach ($Id in $Ids)
    {
        Write-Logging -Value "[SR] ID: $($Id)"
        Write-Logging -Value "[SR] Action: $($Action)"
        Write-Logging -Value "[SR] Additional arguments: $($AdditionalArguments -join ', ')"

        # get Windows principal details
        $RuntimeUser = Get-LocalSystemDetails | Select-Object -ExpandProperty RuntimeUser

        # Manage WinGet apps
        $Splat = @{
            Scope                 = if ( ($RuntimeUser.IsSystem -eq $true) -or ($RuntimeUser.IsAdmin -eq $true) ) { 'machine' } else { 'user' }
            Install               = ($Action -eq 'install')
            Removal               = ($Action -eq 'removal')
            Update                = ($Action -eq 'update' -or $Action -eq 'upgrade')
            CheckAvailableUpdates = ($Action -eq 'check-updates' -or $Action -eq 'check-available-updates')
            ListInstalled         = ($Action -eq 'list-installed')
            DisableProgress       = $true
            AdditionalArguments   = @("--id $($Id)") + $AdditionalArguments
            IncludeScope          = $false
        }
        Write-Logging -Value "[SR] Splat: $($Splat | ConvertTo-Json -Compress)" -StdOut 'None'

        $outputInfo = Deploy-WingetApps @Splat

        Write-Logging -Value "[SR] App removal executed: $($outputInfo | ConvertTo-Json -Depth 10 -Compress)"
    }

    Write-Logging -Value '### SCRIPT END ###################################'
}
catch
{
    Write-Logging -Value "[SR] Error: [$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    $exit_code = $($_.Exception.HResult)
}

exit $exit_code
