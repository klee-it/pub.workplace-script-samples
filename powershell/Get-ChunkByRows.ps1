<#
.SYNOPSIS
    Gets a chunk of rows based on a list of items.

.DESCRIPTION
    This function takes an array of input objects and splits them into chunks of a specified size.
    It returns an array of arrays, where each inner array contains a chunk of the input objects.

.PARAMETER InputObject
    The array of input objects to be chunked. This parameter is optional and defaults to an empty array.

.PARAMETER ChunkSize
    The size of each chunk. This parameter is optional and defaults to 10.

.OUTPUTS
    [System.Object[]]
        An array of arrays, where each inner array contains a chunk of the input objects.

.EXAMPLE
    PS> $items = 1..25
    PS> Get-ChunkByRows -InputObject $items -ChunkSize 5

.NOTES
    Author: klee-it
    PowerShell Version: 5.1, 7.x
#>

###
### FUNCTION: get a chunk of rows based on a list of items
###
function Get-ChunkByRows
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding(DefaultParameterSetName = 'Default')]

    param(
        [Parameter(Mandatory = $false)]
        [Object[]] $InputObject = @(),

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $ChunkSize = 10
    )
    
    try
    {
        $OutputList = New-Object System.Collections.ArrayList
        $TempList = New-Object System.Collections.ArrayList

        foreach ($item in $InputObject)
        {
            $TempList.Add($item) | Out-Null

            if ($TempList.Count -ge $ChunkSize)
            {
                $OutputList.Add($TempList.ToArray()) | Out-Null
                $TempList.Clear()
            }
        }
    
        if ($TempList.Count -gt 0)
        {
            $OutputList.Add($TempList.ToArray()) | Out-Null
        }
    
        Write-Output -InputObject $OutputList.ToArray()
    }
    catch
    {
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
}
