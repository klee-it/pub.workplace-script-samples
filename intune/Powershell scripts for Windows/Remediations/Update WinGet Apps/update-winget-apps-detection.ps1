#
## basic information:
## |__ This script will check and detect all available WinGet app updates
# 
## Supported PowerShell versions:
## |__ v5.1
#
## location: Intune
#

# set strict mode
$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

# do not display UI, progress bar, etc.
$ProgressPreference = 'SilentlyContinue'

# set system parameters
$exit_code = 0

# get script info
$script:MyScriptInfo = Get-Item -Path "$($MyInvocation.MyCommand.Path)"

# set WinGet parameters
$script:Scope = if ($env:USERNAME -eq "$($env:COMPUTERNAME)$") { 'Machine' } else { 'User' }

# set logging parameters
$script:enable_write_logging = $false
$script:LogFilePath          = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\Custom\Remediations\UpdateWingetApps"
$script:LogFileName          = "$($script:MyScriptInfo.BaseName)-$($script:Scope).log"
$script:LogStream            = $null
$script:LogOptionAppend      = $false

###
### FUNCTION: write a log of the script
###
function Write-Logging
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding(DefaultParameterSetName="Default")]

    param(
        [Parameter(Mandatory=$false)]
        [String] $Value = '',

        [Parameter(Mandatory=$false)]
        [String] $Module = '',

        [Parameter(Mandatory=$false)]
        [ValidateScript({$_ -eq -1 -or $_ -match "^\d+$"})]
        [int] $Level = -1,

        [Parameter(Mandatory=$false)]
        [ValidateSet('None', 'Host', 'Warning')]
        [String] $StdOut = 'Host',

        [Parameter(Mandatory=$false)]
        [HashTable] $OptionsSplat = @{}
    )
    
    try
    {
        # set log file path
        $FilePath = "$($script:LogFilePath)"
        If (-Not (Test-Path -Path "$($FilePath)"))
        {
            New-Item -Path "$($FilePath)" -ItemType "Directory" -Force | Out-Null
        }
        
        $File   = Join-Path -Path "$($FilePath)" -ChildPath "$($script:LogFileName)"
        $prefix = ''
        
        # set prefix
        switch ($Level)
        {
            # default level
            -1 { $prefix = '' }
            # root level
            0  { $prefix = '# ' }
            # sub level
            default { $prefix = "$((1..$($Level) | ForEach-Object { "|__" }) -join '') " }
        }
        
        # set log message
        $logMessage = "$($prefix)$($Value)"
        $logDetails = "[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")] [$($env:computername)] [$($env:UserName)] [$($env:UserDomain)] [$($Module)]"

        # write to stdout
        switch ($StdOut)
        {
            'Host'        { $OptionsSplat['Object'] = "$($logMessage)"; Write-Host @OptionsSplat }
            'Warning'     { $OptionsSplat['Message'] = "$($logMessage)"; Write-Warning @OptionsSplat }
            default       { break }
        }

        # check size of log file
        if (Test-Path -Path "$($File)" -PathType 'Leaf')
        {
            # if max size reached, create new log file
            if ((Get-Item -Path "$($File)").length -gt 10Mb)
            {
                if (-Not ( [string]::IsNullOrEmpty($script:LogStream) ) )
                {
                    $script:LogStream.close()
                    $script:LogStream = $null
                }
            }
        }

        # check if logging is enabled
        if ($script:enable_write_logging)
        {
            # check if file stream exists already
            if ( [string]::IsNullOrEmpty($script:LogStream) )
            {
                $script:LogStream = [System.IO.StreamWriter]::new("$($File)", $script:LogOptionAppend, [Text.Encoding]::UTF8) # path, append, encoding
            }
            
            # write log line
            if (-Not ( [string]::IsNullOrEmpty($script:LogStream) ) )
            {
                $script:LogStream.WriteLine("$($logDetails) $($logMessage)")
            }
            else
            {
                throw "Log stream failed to load"
            }
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
### FUNCTION: Checks WinGet apps for available updates and optionally upgrades them
###
function Update-WingetApps
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding(DefaultParameterSetName="Default")]

    param(
        [Parameter(Mandatory=$false)]
        [ValidateSet('user', 'machine')]
        [String]$Scope = 'user',

        [Parameter(Mandatory=$false)]
        [Switch] $IsCheckOnly = $false
    )

    try
    {
        $outputInfo = [PSCustomObject]@{
            UpdatesAvailable = $false
            Message          = ''
        }

        # check if AppInstaller is installed
        Write-Verbose -Message "Check if AppInstaller is installed..."
        try
        {
            $AppInstaller = Get-AppxProvisionedPackage -Online -ErrorAction 'Stop' | Where-Object {$_.DisplayName -eq 'Microsoft.DesktopAppInstaller'}
            Write-Verbose -Message "AppInstaller Version: $([Version]$AppInstaller.Version)"

            if (-not $AppInstaller)
            {
                throw "AppInstaller not installed"
            }
        }
        catch
        {
            Write-Warning -Message "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
        }

        # determine which winget executable to use
        Write-Verbose -Message "Determine WinGet executable..."
        $WinGetDirectories = @()
        $WinGetDirectories += "C:\Users\$($Env:USERNAME)\AppData\Local\Microsoft\WindowsApps\winget.exe"
        $WinGetDirectories += Get-ChildItem -Path "C:\Program Files\WindowsApps" -Recurse -File -ErrorAction 'SilentlyContinue' | Where-Object { $_.Name -eq "winget.exe" } | Select-Object -ExpandProperty FullName
        $WinGetDirectories += Get-ChildItem -Path "C:\Program Files\WindowsApps" -Recurse -File -ErrorAction 'SilentlyContinue' | Where-Object { $_.Name -eq "AppInstallerCLI.exe" } | Select-Object -ExpandProperty FullName
        Write-Verbose -Message "WinGet directories: $($WinGetDirectories -join ', ')"

        # determine which winget executable to use
        $Winget = $WinGetDirectories | Where-Object { Test-Path -Path "$($_)" -PathType 'Leaf' } | Select-Object -First 1
        Write-Verbose -Message "WinGet executable: $($Winget)"

        # clean-up
        Get-Variable -Name "WinGetDirectories" -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
        Get-Variable -Name "AppInstaller" -ErrorAction 'SilentlyContinue' | Remove-Variable -Force

        # run update by WinGet
        Write-Verbose -Message "WinGet source: $($Winget)"
        if (-Not $Winget)
        {
            throw "WinGet not found"
        }

        Write-Verbose -Message "Run upgrade by WinGet (User: $($env:USERNAME) / Scope: $($Scope))..."

        # list available updates
        Write-Verbose -Message "Check and detect available updates..."
        $ProcessStartInfo = New-Object Diagnostics.ProcessStartInfo
        $ProcessStartInfo.FileName = "$($Winget)"
        $ProcessStartInfo.Arguments = "upgrade --accept-source-agreements --scope $($Scope)"
        $ProcessStartInfo.UseShellExecute = $false
        $ProcessStartInfo.StandardOutputEncoding = [Text.Encoding]::UTF8
        $ProcessStartInfo.RedirectStandardOutput = $true
        $Process = [Diagnostics.Process]::Start($ProcessStartInfo)
        $updates = $Process.StandardOutput.ReadToEnd()
        $Process.WaitForExit()
        Write-Verbose -Message "Updates:$([Environment]::NewLine)$($updates)"

        # check result if updates are available
        $updatesAvailable = $updates | Select-String -Pattern '[0-9]+[ \t]*(?:upgrades available|Aktualisierungen verfügbar)' -Quiet
        
        # clean-up
        Get-Variable -Name "ProcessStartInfo" -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
        Get-Variable -Name "Process" -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
        Get-Variable -Name "updates" -ErrorAction 'SilentlyContinue' | Remove-Variable -Force

        if ($updatesAvailable)
        {
            if ($IsCheckOnly -eq $false)
            {
                # updates available
                Write-Verbose -Message "Updates available, run upgrade process"
                $ProcessStartInfo = New-Object Diagnostics.ProcessStartInfo
                $ProcessStartInfo.FileName = "$($Winget)"
                $ProcessStartInfo.Arguments = "upgrade --all --silent --force --accept-source-agreements --disable-interactivity --scope $($Scope)"
                $ProcessStartInfo.UseShellExecute = $false
                $ProcessStartInfo.StandardOutputEncoding = [Text.Encoding]::UTF8
                $ProcessStartInfo.RedirectStandardOutput = $true
                $Process = [Diagnostics.Process]::Start($ProcessStartInfo)
                $updates = $Process.StandardOutput.ReadToEnd()
                $Process.WaitForExit()
                Write-Verbose -Message "$([Environment]::NewLine)$($updates)"
    
                # clean-up
                Get-Variable -Name "ProcessStartInfo" -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
                Get-Variable -Name "Process" -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
                Get-Variable -Name "updates" -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
    
                Write-Verbose -Message "WinGet upgrade done"
                $outputInfo.UpdatesAvailable = $true
                $outputInfo.Message          = "WinGet upgrade done"
            }
            else
            {
                Write-Verbose -Message "Updates available, but check-only mode is enabled"
                $outputInfo.UpdatesAvailable = $true
                $outputInfo.Message          = "Updates available, but check-only mode is enabled"
            }
        }
        else
        {
            Write-Verbose -Message "No updates available"
            $outputInfo.UpdatesAvailable = $false
            $outputInfo.Message          = "No updates available"
        }
        
        # clean-up
        Get-Variable -Name "updatesAvailable" -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
        Get-Variable -Name "Winget" -ErrorAction 'SilentlyContinue' | Remove-Variable -Force

        Write-Output -InputObject $outputInfo
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
    Write-Logging -Value '### SCRIPT BEGIN #################################'

    # Check for updates
    Write-Logging -Level 0 -Value "Check for updates by WinGet (User: $($env:USERNAME) / Scope: $($script:Scope))..."
    $result = Update-WingetApps -Scope "$($script:Scope)" -IsCheckOnly
    Write-Logging -Level 1 -Value "Result: $($result | ConvertTo-Json -Depth 5 -Compress)"

    if ($result.UpdatesAvailable)
    {
        $exit_code = 1
    }

    # set output for intune
    Write-Logging -Value "Exit code for Intune: $($exit_code)"

    Write-Logging -Value '### SCRIPT END ###################################'
}
catch
{
    $exit_code = $($_.Exception.HResult)
    Write-Logging -Value "Error: [$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
}
finally
{
    # close log stream
    if (-Not ( [string]::IsNullOrEmpty($script:LogStream) ) )
    {
        Write-Logging -Value "Log stream closed"
        $script:LogStream.close()
        $script:LogStream = $null
    }
}

exit $exit_code
