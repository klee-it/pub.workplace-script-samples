<#
.SYNOPSIS
    Converts a given value from one time unit to another.

.DESCRIPTION
    The Convert-Seconds function allows you to convert a specified value from one time unit (e.g., seconds) to another (e.g., minutes).

.PARAMETER From
    The unit of the input value. For example, 'Seconds'.

.PARAMETER To
    The unit to convert the input value to. For example, 'Minutes'.

.PARAMETER Value
    The numerical value to be converted.

.PARAMETER Precision
    The number of decimal places to round the result to. Default is 4.

.OUTPUTS
    [System.Double]
        The converted value rounded to the specified precision.

.EXAMPLE
    PS> Convert-Seconds -From Seconds -To Minutes -Value 300

.NOTES
    Author: klee-it
    PowerShell Version: 5.1, 7.x
#>

###
### FUNCTION: Convert seconds to other time units
###
function Convert-Seconds
{
    [OutputType([System.Double])]
    [CmdLetBinding(DefaultParameterSetName = 'Default')]

    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Nanoseconds', 'Microseconds', 'Milliseconds', 'Seconds', 'Minutes', 'Hours')]
        [String] $From,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet('Nanoseconds', 'Microseconds', 'Milliseconds', 'Seconds', 'Minutes', 'Hours')]
        [String] $To,
        
        [Parameter(Mandatory = $true)]
        [Double] $Value,
        
        [Parameter(Mandatory = $false)]
        [Int] $Precision = 4
    )
    
    try
    {
        # base is seconds
        switch ($From)
        {
            'Nanoseconds' { $value = $Value / 1000 / 1000 / 1000 }
            'Microseconds' { $value = $Value / 1000 / 1000 }
            'Milliseconds' { $value = $Value / 1000 }
            'Seconds' { $value = $Value }
            'Minutes' { $value = $Value * 60 }
            'Hours' { $value = $Value * 60 * 60 }
        }
    
        switch ($To)
        {
            'Nanoseconds' { $value = $Value * 1000 * 1000 * 1000 }
            'Microseconds' { $value = $Value * 1000 * 1000 }
            'Milliseconds' { $value = $Value * 1000 }
            'Seconds' { return $value }
            'Minutes' { $Value = $Value / 60 }
            'Hours' { $Value = $Value / 60 / 60 }
        }
    
        Write-Output -InputObject ( [Math]::Round($value, $Precision, [MidPointRounding]::AwayFromZero) )
    }
    catch
    {
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
}
