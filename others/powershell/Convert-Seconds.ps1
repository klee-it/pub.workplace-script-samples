###
### FUNCTION: Convert seconds to other time units
### |_ usage: Convert-Seconds -From Seconds -To Minutes -Value 300
###
function Convert-Seconds
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding(DefaultParameterSetName="Default")]

    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("Nanoseconds", "Microseconds", "Milliseconds", "Seconds", "Minutes", "Hours")]
        [String] $From,
        
        [Parameter(Mandatory=$true)]
        [ValidateSet("Nanoseconds", "Microseconds", "Milliseconds", "Seconds","Minutes","Hours")]
        [String] $To,
        
        [Parameter(Mandatory=$true)]
        [Double] $Value,
        
        [Parameter(Mandatory=$false)]
        [Int] $Precision = 4
    )
    
    try
    {
        # base is seconds
        switch ($From)
        {
            "Nanoseconds"   { $value = $Value / 1000 / 1000 / 1000 }
            "Microseconds"  { $value = $Value / 1000 / 1000 }
            "Milliseconds"  { $value = $Value / 1000 }
            "Seconds"       { $value = $Value }
            "Minutes"       { $value = $Value * 60 }
            "Hours"         { $value = $Value * 60 * 60 }
        }
    
        switch ($To)
        {
            "Nanoseconds"   { $value = $Value * 1000 * 1000 * 1000 }
            "Microseconds"  { $value = $Value * 1000 * 1000 }
            "Milliseconds"  { $value = $Value * 1000 }
            "Seconds"       { return $value }
            "Minutes"       { $Value = $Value / 60 }
            "Hours"         { $Value = $Value / 60 / 60 }
        }
    
        Write-Output -InputObject ( [Math]::Round($value, $Precision, [MidPointRounding]::AwayFromZero) )
    }
    catch
    {
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
}
