###
### FUNCTION: convert compact json to PSCustomObject
###
function ConvertFrom-CompactJsonFile
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding(DefaultParameterSetName="Default")]

    param(
        [Parameter(Mandatory=$true)] [PSCustomObject] $InputObject
    )
    
    try
    {
        $ColumnNames = [ordered] @{}
        $InputObject.Schema | ForEach-Object { $ColumnNames[$_.Column] = $null }
        $OutputObject = @()
        
        foreach ($item in $InputObject.Values)
        {
            $i = 0
            foreach ($itemValue in $item)
            {
                $ColumnNames[$i++] = $itemValue
            
            }
            
            $OutputObject += [PSCustomObject] $ColumnNames
        }

        Write-Output -InputObject ( $OutputObject )
    }
    catch
    {
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
}
