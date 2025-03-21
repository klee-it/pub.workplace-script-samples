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
Function ConvertFrom-Ini
{
    [OutputType([System.Collections.Hashtable])]
    [CmdLetBinding(DefaultParameterSetName="Default")]

    param(
        [Parameter(Mandatory=$true)]
        [ValidateScript({Test-Path -Path $_ -PathType 'Leaf'})]
        [string]$Path
    )
    
    try
    {
        # read the ini file
        $INI = Get-Content -Path "$($Path)"

        $IniHash = @{}
        $IniTemp = $null
        $LastHeader = ''

        ForEach ($Line in $INI)
        {
            If ($Line.StartsWith('#') -eq $True)
            {
                continue
            }
            
            If ($Line -eq "")
            {
                continue
            }
            
            If ($Line.StartsWith('[') -eq $True)
            {
                if ( ($IniTemp | Measure-Object).Count -gt 0 )
                {
                    $IniHash += $IniTemp
                }
                
                $LastHeader = "$($Line.replace('[','').replace(']',''))".trim()
                $IniTemp = @{}
                $IniTemp = @{ "$($LastHeader)" = @{} }
            }
            
            If ($Line.StartsWith("[") -ne $True)
            {
                $SplitArray = $Line.Split("=")
                $IniTemp."$($LastHeader)" += @{$SplitArray[0].trim() = $SplitArray[1].trim()}
            }
        }

        Write-Output -InputObject $IniHash
    }
    catch
    {
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
}
