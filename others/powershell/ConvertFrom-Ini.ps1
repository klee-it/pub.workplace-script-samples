###
### FUNCTION: convert an ini file to a HashTable
###
Function ConvertFrom-Ini
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding(DefaultParameterSetName="Default")]

    param(
        [Parameter(Mandatory=$true)]
        [ValidateScript({Test-Path -Path $_ -PathType Leaf})]
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
