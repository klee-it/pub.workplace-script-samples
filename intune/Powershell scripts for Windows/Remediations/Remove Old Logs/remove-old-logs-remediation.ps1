#
## basic information:
## |__ This script will remove old log files
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
$script:LogFilePath          = "$($Env:ProgramData)\Microsoft\IntuneManagementExtension\Logs\Custom\Remediations\RemoveOldLogs"
$script:LogFileName          = "$($script:MyScriptInfo.BaseName).log"
$script:LogStream            = $null
$script:LogOptionAppend      = $false

# set device parameters
$script:LocalLogDirectories = @(
    [PSCustomObject]@{
        Path = "$($Env:ProgramData)\Microsoft\IntuneManagementExtension\Logs\Custom"
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
                Write-Logging -Level 2 -Value "Path does not exist"
                continue
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
            $RetentionMode  = "$($LocalDir.RetentionPolicy[-1])"
            $RetentionValue = ($LocalDir.RetentionPolicy).Substring(0, ($LocalDir.RetentionPolicy).Length - 1)
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

            # remove files
            if ( ($FilesToRemove | Measure-Object).Count -gt 0 )
            {
                Write-Logging -Level 1 -Value 'Remove old files...'

                foreach ($item in $FilesToRemove)
                {
                    try
                    {
                        Write-Logging -Level 2 -Value "Remove File: $( $item.FullName )"
    
                        if (Test-Path -Path "$($item.FullName)" -PathType 'Leaf')
                        {
                            Remove-Item -Path "$($item.FullName)" -Force
                            Write-Logging -Level 3 -Value 'File removed'
                        }
                        else
                        {
                            throw 'File not found'
                        }
                    }
                    catch
                    {
                        Write-Logging -Level 2 -Value "Error: [$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
                        $exit_code = $($_.Exception.HResult)
                    }
                }
            }

            # check if empty folders (no files, no subfolders) exists and remove them
            Write-Logging -Level 1 -Value 'Check for empty folders...'
            $EmptyFolders = Get-ChildItem -Path "$($LocalDir.Path)" -Recurse | Where-Object { ($_.PSIsContainer) -and ($_.GetFileSystemInfos().Count -eq 0) }
            Write-Logging -Level 2 -Value "Number of empty folders: $( ($EmptyFolders | Measure-Object).Count )"

            if ( ($EmptyFolders | Measure-Object).Count -gt 0 )
            {
                Write-Logging -Level 1 -Value 'Remove empty folders...'

                foreach ($item in $EmptyFolders)
                {
                    try
                    {
                        Write-Logging -Level 2 -Value "Remove Folder: $( $item.FullName )"
    
                        if (Test-Path -Path "$($item.FullName)" -PathType 'Container')
                        {
                            Remove-Item -Path "$($item.FullName)" -Force -Confirm:$false
                            Write-Logging -Level 3 -Value 'Folder removed'
                        }
                        else
                        {
                            throw 'Folder not found'
                        }
                    }
                    catch
                    {
                        Write-Logging -Level 2 -Value "Error: [$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
                        $exit_code = $($_.Exception.HResult)
                    }
                }
            }
        }
        catch
        {
            Write-Logging -Level 2 -Value "Error: [$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
            $exit_code = $($_.Exception.HResult)
        }
        finally
        {
            # cleanup
            Get-Variable -Name 'SearchSplat' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
            Get-Variable -Name 'AllLogFiles' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
            Get-Variable -Name 'RetentionMode' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
            Get-Variable -Name 'RetentionValue' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
            Get-Variable -Name 'FilesToRemove' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
            Get-Variable -Name 'EmptyFolders' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
        }
    }

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
