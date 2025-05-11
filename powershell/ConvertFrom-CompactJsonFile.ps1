<#
.SYNOPSIS
    Converts a compact JSON file to a PSCustomObject.

.DESCRIPTION
    This PowerShell function reads a compact JSON file and converts it into a PSCustomObject. 
    It processes the schema and values from the input JSON to produce a structured output.

.PARAMETER InputObject
    The JSON object that contains the schema and values to be converted.

.OUTPUTS
    [PSCustomObject]
        The converted JSON object as a PSCustomObject.

.EXAMPLE
    PS> $json = Get-Content -Path "compact.json" -Raw | ConvertFrom-Json
    PS> ConvertFrom-CompactJsonFile -InputObject $json

.NOTES
    Author: klee-it
    PowerShell Version: 5.1, 7.x
#>

###
### FUNCTION: convert compact json to PSCustomObject
###
function ConvertFrom-CompactJsonFile
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding(DefaultParameterSetName="Default")]

    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject] $InputObject
    )
    
    try
    {
        # Check if the input object has a schema property
        if (-Not ($InputObject.PSObject.BaseObject.GetEnumerator() | Where-Object {$_.Name -eq 'Schema'}) )
        {
            throw "The input object does not contain a 'Schema' property."
        }

        # Check if the input object has a values property
        if (-Not ($InputObject.PSObject.BaseObject.GetEnumerator() | Where-Object {$_.Name -eq 'Values'}) )
        {
            throw "The input object does not contain a 'Values' property."
        }

        # Process the schema and values to create a PSCustomObject
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
