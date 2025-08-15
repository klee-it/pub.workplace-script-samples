#
## basic information:
## |__ This script will check and detect old log files
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

# get script info
$script:MyScriptInfo = Get-Item -Path "$($MyInvocation.MyCommand.Path)"

# set logging parameters
$script:enable_write_logging = $true
$script:LogFilePath          = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\Custom\Remediations\RemoveOldLogs"
$script:LogFileName          = "$($script:MyScriptInfo.BaseName).log"
$script:LogStream            = $null
$script:LogOptionAppend      = $false

# set device parameters
$script:LocalLogDirectories = @(
    [PSCustomObject]@{
        Path = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\Custom"
        FileExtension = @('*.log')
        RetentionPolicy = "1M"
    }
)

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
### MAIN SCRIPT
###
try
{
    Write-Logging -Value '### SCRIPT BEGIN #################################'

    # go through all local log paths
    foreach ($LocalDir in $script:LocalLogDirectories)
    {
        try
        {
            Write-Logging -Level 0 -Value "Local log directory: '$($LocalDir.Path)'"

            # check if path exists
            Write-Logging -Level 1 -Value 'Check if path exists...'
            if (-not (Test-Path -Path "$($LocalDir.Path)" -PathType 'Container'))
            {
                throw "Path does not exist"
            }

            # get all log files
            Write-Logging -Level 1 -Value 'Get all log files...'
            $SearchSplat = @{
                Path = "$($LocalDir.Path)"
                Include = $LocalDir.FileExtension
                File = $true
                Recurse = $true
            }
            $AllLogFiles = Get-ChildItem @SearchSplat | Sort-Object -Property 'LastWriteTime' -Descending
            Write-Logging -Level 2 -Value "Number of files: $( ($AllLogFiles | Measure-Object).Count )"

            # get files older than retention policy
            $RetentionMode  = "$($script:LocalLogDirectories.RetentionPolicy[-1])"
            $RetentionValue = ($script:LocalLogDirectories.RetentionPolicy).Substring(0, ($script:LocalLogDirectories.RetentionPolicy).Length - 1)
            $FilesToRemove  = @()

            Write-Logging -Level 1 -Value "Get files older then $($RetentionValue)$($RetentionMode)..."
            switch -CaseSensitive ($RetentionMode)
            {
                "y" { $FilesToRemove = $AllLogFiles | Where-Object { ($_.LastWriteTimeUtc).AddYears($RetentionValue) -lt (Get-Date) }; break }
                "M" { $FilesToRemove = $AllLogFiles | Where-Object { ($_.LastWriteTimeUtc).AddMonths($RetentionValue) -lt (Get-Date) }; break }
                "d" { $FilesToRemove = $AllLogFiles | Where-Object { ($_.LastWriteTimeUtc).AddDays($RetentionValue) -lt (Get-Date) }; break }
                "h" { $FilesToRemove = $AllLogFiles | Where-Object { ($_.LastWriteTimeUtc).AddHours($RetentionValue) -lt (Get-Date) }; break }
                "m" { $FilesToRemove = $AllLogFiles | Where-Object { ($_.LastWriteTimeUtc).AddMinutes($RetentionValue) -lt (Get-Date) }; break }
                "s" { $FilesToRemove = $AllLogFiles | Where-Object { ($_.LastWriteTimeUtc).AddSeconds($RetentionValue) -lt (Get-Date) }; break }
                default { throw "Defined mode are not supported: $($RetentionMode)"; break }
            }
            Write-Logging -Level 2 -Value "Number of old files: $( ($FilesToRemove | Measure-Object).Count )"

            # check if files should be removed
            Write-Logging -Level 1 -Value 'Check if files should be removed...'
            if ( ($FilesToRemove | Measure-Object).Count -gt 0 )
            {
                Write-Logging -Level 2 -Value 'Old log files found and should be removed'
                $exit_code = 1
            }
        }
        catch
        {
            Write-Logging -Level 2 -Value "Error: [$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
            $exit_code = $($_.Exception.HResult)
        }
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
