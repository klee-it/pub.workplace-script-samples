<#
.SYNOPSIS
    Converts a PowerShell object or array of objects to a Markdown table.

.DESCRIPTION
    This function takes a PSCustomObject or an array of PSCustomObjects and generates a Markdown-formatted table string.
    The first row contains the property names as headers, the second row contains separator dashes, and subsequent rows contain the property values.

.PARAMETER InputObject
    The object or array of objects to convert to a Markdown table. This parameter is mandatory.

.OUTPUTS
    [System.String]
        The generated Markdown table as an array of strings.

.EXAMPLE
    $obj = [PSCustomObject]@{ Name = 'Alice'; Age = 30 }
    ConvertTo-MarkdownTable -InputObject $obj

.EXAMPLE
    $objs = @(
        [PSCustomObject]@{ Name = 'Alice'; Age = 30 },
        [PSCustomObject]@{ Name = 'Bob'; Age = 25 }
    )
    ConvertTo-MarkdownTable -InputObject $objs

.NOTES
    Author: klee-it
    PowerShell Version: 5.1, 7.x
#>

###
### FUNCTION: convert to Markdown table
###
function ConvertTo-MarkdownTable
{
    [OutputType([System.String])]
    [CmdLetBinding(DefaultParameterSetName = 'Default')]

    param(
        [Parameter(Mandatory = $True)]
        [PSCustomObject] $InputObject
    )

    try
    {
        $outputInfo = @()
        $Index = 0

        foreach ($Item in $InputObject)
        {
            if ( !$Index++ )
            {
                $outputInfo += "| $($Item.PSObject.Properties.Name -Join ' | ') |"
                $outputInfo += "| $($Item.PSObject.Properties.ForEach({ '---' }) -Join ' | ') |"
            }
            $outputInfo += "| $($Item.PSObject.Properties.Value -Join ' | ') |"
        }

        # Set the content of the return object
        Write-Output -InputObject $outputInfo
    }
    catch
    {
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
}
