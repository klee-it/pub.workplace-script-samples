<#
.SYNOPSIS
    Converts a size value from one unit to another (Bytes, KB, MB, GB, TB).

.DESCRIPTION
    This PowerShell function is designed to convert a size value from one unit to another. It supports conversions between Bytes, KB, MB, GB, and TB. The function allows specifying the precision of the output value.

.PARAMETER From
    The unit of the input value. Valid values are: Bytes, KB, MB, GB, TB.

.PARAMETER To
    The unit to convert the input value to. Valid values are: Bytes, KB, MB, GB, TB.

.PARAMETER Value
    The size value to be converted.

.PARAMETER Precision
    The number of decimal places for the output value. Default is 4.

.OUTPUTS
    [System.Double]
        The converted value rounded to the specified precision.

.EXAMPLE
    PS> Convert-Size -From KB -To GB -Value 1024

.EXAMPLE
    PS> Convert-Size -From Bytes -To MB -Value 15345234524 -Precision 2

.NOTES
    Author: klee-it
    PowerShell Version: 5.1, 7.x
#>

###
### FUNCTION: Convert seconds to other time units
###
function Convert-Size
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding(DefaultParameterSetName = 'Default')]

    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Bytes', 'KB', 'MB', 'GB', 'TB')]
        [String] $From,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet('Bytes', 'KB', 'MB', 'GB', 'TB')]
        [String] $To,
        
        [Parameter(Mandatory = $true)]
        [Double] $Value,
        
        [Parameter(Mandatory = $false)]
        [Int] $Precision = 4
    )
    
    try
    {
        switch ($From)
        {
            'Bytes' { $value = $Value }
            'KB' { $value = $Value * 1024 }
            'MB' { $value = $Value * 1024 * 1024 }
            'GB' { $value = $Value * 1024 * 1024 * 1024 }
            'TB' { $value = $Value * 1024 * 1024 * 1024 * 1024 }
        }

        switch ($To)
        {
            'Bytes' { return $value }
            'KB' { $Value = $Value / 1KB }
            'MB' { $Value = $Value / 1MB }
            'GB' { $Value = $Value / 1GB }
            'TB' { $Value = $Value / 1TB }
        }

        Write-Output -InputObject ( [Math]::Round($value, $Precision, [MidPointRounding]::AwayFromZero) )
    }
    catch
    {
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
}
