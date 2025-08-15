<#
.SYNOPSIS
    This script performs clean-up of available archived files based on a retention policy.

.DESCRIPTION
    The Clear-ArchivePath function removes files from a specified archive path that are older than the defined retention policy. 
    It supports filtering by file extensions and provides an option to skip file removal for testing purposes.

.PARAMETER Path
    The path to the archive directory where files will be checked and removed.

.PARAMETER FileExtensions
    An array of file extensions to filter the files to be removed. Default is '*.log'.

.PARAMETER RetentionPolicy
    The retention policy defining the age of files to be removed. 
    The format is a number followed by a unit (y, M, d, h, m, s) representing years, months, days, hours, minutes, or seconds.

.PARAMETER SkipRemoval
    A switch to skip the actual removal of files. Useful for testing and verification.

.OUTPUTS
    [PSCustomObject]
        - FullName: The full path of the file.
        - Status: The status of the file (e.g., retired, removed, failed, not found).

.EXAMPLE
    PS> Clear-ArchivePath -Path "C:\Logs" -RetentionPolicy "30d"
    Removes files older than 30 days from the specified path.

    PS> Clear-ArchivePath -Path "C:\Logs" -FileExtensions @('*.txt', '*.log') -RetentionPolicy "7d" -SkipRemoval
    Lists files older than 7 days with the specified extensions without removing them.

.NOTES
    Author: klee-it
    PowerShell Version: 5.1, 7.x
#>

###
### FUNCTION: clean-up of available archived files
###
Function Clear-ArchivePath
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding(DefaultParameterSetName="Default")]

    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [String] $Path,

        [Parameter(Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [Object[]] $FileExtensions = @('*.log'),

        [Parameter(Mandatory=$true)]
        [ValidateScript({$_ -match '^[0-9]+[yMdhms]$' })]
        [String] $RetentionPolicy,

        [Parameter(Mandatory=$false)]
        [Switch] $SkipRemoval = $false
    )

    try
    {
        # check if archive path exists
        if (-not (Test-Path -Path "$($Path)" -PathType 'Container'))
        {
            throw "Archive path does not exist: $($Path)"
        }

        # set parameters
        $RetentionMode  = "$($RetentionPolicy[-1])"
        $RetentionValue = ($RetentionPolicy).Substring(0, ($RetentionPolicy).Length - 1)
        $FilesToRemove  = @()

        # Get all files in archive path
        Write-Verbose -Message "Get all files in archive path..."
        $ArchiveFiles = Get-ChildItem -Path "$($Path)" -Include $FileExtensions -File -Recurse | Sort-Object -Descending
        Write-Verbose -Message "Number of total files: $( ($ArchiveFiles | Measure-Object).Count )"

        # Get files older then RetentionPolicy
        Write-Verbose -Message "Get files older then $($RetentionValue)$($RetentionMode)..."
        switch -CaseSensitive ($RetentionMode)
        {
            "y" { $FilesToRemove = $ArchiveFiles | Where-Object { ($_.LastWriteTimeUtc).AddYears($RetentionValue) -lt (Get-Date) }; break }
            "M" { $FilesToRemove = $ArchiveFiles | Where-Object { ($_.LastWriteTimeUtc).AddMonths($RetentionValue) -lt (Get-Date) }; break }
            "d" { $FilesToRemove = $ArchiveFiles | Where-Object { ($_.LastWriteTimeUtc).AddDays($RetentionValue) -lt (Get-Date) }; break }
            "h" { $FilesToRemove = $ArchiveFiles | Where-Object { ($_.LastWriteTimeUtc).AddHours($RetentionValue) -lt (Get-Date) }; break }
            "m" { $FilesToRemove = $ArchiveFiles | Where-Object { ($_.LastWriteTimeUtc).AddMinutes($RetentionValue) -lt (Get-Date) }; break }
            "s" { $FilesToRemove = $ArchiveFiles | Where-Object { ($_.LastWriteTimeUtc).AddSeconds($RetentionValue) -lt (Get-Date) }; break }
            default { throw "Defined mode are not supported: $($RetentionMode)"; break }
        }
        Write-Verbose -Message "Number of old files: $( ($FilesToRemove | Measure-Object).Count )"

        # generate output object
        $outputInfo = $FilesToRemove | Select-Object FullName, @{ Name = 'Status'; Expression = {'retired'} }

        # check if clean-up is enabled
        if ($SkipRemoval -eq $false)
        {
            # remove files
            if ( ($FilesToRemove | Measure-Object).Count -gt 0 )
            {
                Write-Verbose -Message "Remove old files..."

                foreach ($item in $FilesToRemove)
                {
                    Write-Verbose -Message "Remove file: $($item.FullName)"
                    $itemStatus = ''

                    if (Test-Path -Path "$($item.FullName)" -PathType 'Leaf')
                    {
                        try
                        {
                            Remove-Item -Path "$($item.FullName)" -Force
                            Write-Verbose -Message "File removed"
                            $itemStatus = 'removed'
                        }
                        catch
                        {
                            Write-Warning -Message "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
                            $itemStatus = 'failed'
                        }
                    }
                    else
                    {
                        Write-Verbose -Message "File not found"
                        $itemStatus = 'not found'
                    }

                    $outputInfo | Where-Object { $_.FullName -eq $item.FullName } | ForEach-Object { $_.Status = $itemStatus }
                }
            }

            # clean-up
            Get-Variable -Name 'FilesToRemove' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
            Get-Variable -Name 'ArchiveFiles' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
            Get-Variable -Name 'RetentionValue' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
            Get-Variable -Name 'RetentionMode' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
        }
        else
        {
            Write-Verbose -Message "Skip removal of old files..."
        }

        # return output object
        Write-Output -InputObject $outputInfo
    }
    catch
    {
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
}
