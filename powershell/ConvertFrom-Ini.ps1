<#
.SYNOPSIS
    Converts an INI file to a HashTable.

.DESCRIPTION
    This function reads an INI file and converts its contents into a HashTable.
    It processes each line of the INI file, ignoring comments and empty lines,
    and organizes the data into a structured HashTable format.

.PARAMETER Path
    Specifies the path to the INI file that the function will process.
    The path must point to an existing file.

.OUTPUTS
    [System.Collections.Hashtable]
        The converted INI file as a HashTable.

.EXAMPLE
    PS> ConvertFrom-Ini -Path "C:\example.ini"

.NOTES
    Author: klee-it
    PowerShell Version: 5.1, 7.x
#>

###
### FUNCTION: convert an ini file to a HashTable
###
function ConvertFrom-Ini
{
    [OutputType([System.Collections.Hashtable])]
    [CmdLetBinding(DefaultParameterSetName = 'Default')]

    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path -Path $_ -PathType 'Leaf' })]
        [string]$Path
    )
    
    try
    {
        # read the file content
        $fileContent = Get-Content -Path "$($Path)"

        # set parameters
        $outputInfo = @{}
        $LastHeader = ''

        foreach ($Line in $fileContent)
        {
            if ( ($Line.StartsWith('#') -eq $True) -or ( [String]::IsNullOrEmpty($Line.Trim()) ) )
            {
                Write-Verbose 'Skip comment or empty line...'
                continue
            }
            
            if ($Line.StartsWith('[') -and $Line.EndsWith(']'))
            {
                Write-Verbose "Header line found: $($line)..."
                $LastHeader = "$($Line.Trim('[]'))"
                $outputInfo["$($LastHeader)"] = @{}
            }
            elseif ($Line -like '*=*')
            {
                Write-Verbose 'Key/Value line found...'
                $outputInfo["$($LastHeader)"] += ($Line | ConvertFrom-StringData -Delimiter '=')
            }
            else
            {
                throw "[$($_.InvocationInfo.ScriptLineNumber)] Invalid line format: $($Line)"
            }
        }

        Write-Output -InputObject $outputInfo

        # clean-up
        Get-Variable -Name 'fileContent' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
        Get-Variable -Name 'LastHeader' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
    }
    catch
    {
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
}
