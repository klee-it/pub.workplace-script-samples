###
### FUNCTION: get a chunk of rows based on a list of items
###
function Get-ChunkByRows
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding(DefaultParameterSetName="Default")]

    param(
        [Parameter(Mandatory=$false)] [Object[]] $InputObject = @(),
        [Parameter(Mandatory=$false)] [int] $ChunkSize = 10
    )
    
    try
    {
        $OutputList = New-Object System.Collections.ArrayList
        $TempList = New-Object System.Collections.ArrayList

        foreach($item in $InputObject)
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
