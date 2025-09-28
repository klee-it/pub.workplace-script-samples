#
## basic information:
## |__ App deployment script
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
$StartProcess_FilePath = "$($AppPackageData.'REPLACEMENT-APP-FILE-PATH')"
$StartProcess_Parameters = $AppPackageData.'REPLACEMENT-APP-PARAMETERS'
$StartProcess_ArgumentList = $AppPackageData.'REPLACEMENT-APP-ARGUMENT-LIST'
$StartProcess_PreInstallScript = if ($AppPackageData.'REPLACEMENT-APP-PRE-INSTALL-SCRIPT') { $AppPackageData.'REPLACEMENT-APP-PRE-INSTALL-SCRIPT' } else { $false }
$StartProcess_PostInstallScript = if ($AppPackageData.'REPLACEMENT-APP-POST-INSTALL-SCRIPT') { $AppPackageData.'REPLACEMENT-APP-POST-INSTALL-SCRIPT' } else { $false }

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
            Wait         = $true
            NoNewWindow  = $true
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

        Write-Logging -Value "[SR] [$($SetupFile_Ext)] [$Scope] Installation will be started: $($SetupFile)"

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
            'msixbundle'
            {
                $StartProcessSplat['FilePath'] = "$($SetupFile)"
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
                Write-Logging -Value '[SR] Use default installation method'
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

        # replace '.\' with current script path
        if ( $StartProcessSplat['ArgumentList'] -match '"\.\\.+\.[a-zA-Z0-9]{3,}"' )
        {
            $StartProcessSplat['ArgumentList'] = ($StartProcessSplat['ArgumentList']).replace('".\', "`"$($script:MyScriptInfo.Directory)\")
            Write-Logging -Value "[SR] ArgumentList modified ('.\' replaced with script path)"
        }
        
        # replace placeholders in arguments
        foreach ($items in $StartProcessSplat['ArgumentList'])
        {
            $EnvVarName = $items | Select-String -Pattern '".*\$\((\$.+)\)\\.+\.[a-zA-Z0-9]{3,}"' | Select-Object -ExpandProperty Matches | Select-Object -ExpandProperty Groups | Where-Object { $_.Name -eq '1' } | Select-Object -ExpandProperty Value
            if ( $EnvVarName )
            {
                if ( $EnvVarName.ToUpper() -like '$ENV:*' )
                {
                    $NewValue = Get-Item -Path "Env:\$( $EnvVarName.ToUpper().replace('$ENV:', '') )" -ErrorAction 'SilentlyContinue' | Select-Object -ExpandProperty Value
                }
                else
                {
                    $NewValue = Get-Variable -Name "$( $EnvVarName.replace('$', '') )" -ErrorAction 'SilentlyContinue' | Select-Object -ExpandProperty Value
                }
                
                if ($NewValue)
                {
                    $StartProcessSplat['ArgumentList'] = ($StartProcessSplat['ArgumentList']).replace("`$($($EnvVarName))", "$($NewValue)")
                    Write-Logging -Value '[SR] ArgumentList modified (placeholder replaced)'
                }
            }
        }

        # start installation of setup file
        Write-Logging -Value "[SR] Splat: $($StartProcessSplat | ConvertTo-Json -Depth 3 -Compress)"
        if ($SetupFile_Ext -eq 'msixbundle')
        {
            Write-Logging -Value '[SR] Install MSIX bundle'
            Add-AppxPackage -Path "$($StartProcessSplat['FilePath'])"
        }
        else
        {
            Write-Logging -Value '[SR] Install EXE/MSI'
            Start-Process @StartProcessSplat
        }

        # check if script should sleep after installation
        if ($SetupSleep -eq 'yes')
        {
            Write-Logging -Module "$($MyInvocation.MyCommand)" -Value "[$($script:AppName)] Sleep for $($StartSleep) seconds"
            Start-Sleep -Seconds $StartSleep
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
    Write-Logging -Value '### SCRIPT BEGIN #################################' -Mode 'set'
    Write-Logging -Value '[SR] Script: intunewin-app-installation-intallation'
    Write-Logging -Value "[SR] App name: $($AppName)"

    # get system details log
    $SystemDetails = Get-LocalSystemDetails
    Write-Logging -Value "[SR] System Details: $($SystemDetails | ConvertTo-Json -Depth 3 -Compress)" -StdOut 'None'

    # run pre-install
    if ($StartProcess_PreInstallScript)
    {
        Write-Logging -Value "[SR] [$($AppName)] Start with Pre-Install"
        $Splat = @{
            InputObject = [PSCustomObject]@{ file = 'pre-install.ps1' }
            Scope       = 'pre_setup'
        }
        Install-Application @Splat
    }

    # run main-setup
    Write-Logging -Value "[SR] [$($AppName)] Start with Main-Setup"
    $Splat = @{
        InputObject = [PSCustomObject]@{
            file       = "$($StartProcess_FilePath)"
            parameters = $StartProcess_Parameters
            arguments  = $StartProcess_ArgumentList
        }
        Scope       = 'main_setup'
    }
    Install-Application @Splat

    # run post-install
    if ($StartProcess_PostInstallScript)
    {
        Write-Logging -Value "[SR] [$($AppName)] Start with Post-Install"
        $Splat = @{
            InputObject = [PSCustomObject]@{ file = 'post-install.ps1' }
            Scope       = 'post_setup'
        }
        Install-Application @Splat
    }

    Write-Logging -Value "[SR] [$($AppName)] App installation executed"

    Write-Logging -Value '### SCRIPT END ###################################'
}
catch
{
    Write-Logging -Value "[SR] Error: [$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    $exit_code = $($_.Exception.HResult)
}

exit $exit_code
