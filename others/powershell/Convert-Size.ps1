###
### FUNCTION: Convert seconds to other time units
### |_ usage: Convert-Size -From KB -To GB -Value 1024
### |_ usage: Convert-Size -From KB -To GB -Value 1024000
### |_ usage: Convert-Size -From KB -To GB -Value 1024000 -Precision 2
### |_ usage: Convert-Size -From Bytes -To MB 15345234524
### |_ usage: Convert-Size -From Bytes -To MB 15345234524 -Precision 2
###
function Convert-Size
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding(DefaultParameterSetName="Default")]

    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("Bytes", "KB", "MB", "GB", "TB")]
        [String] $From,
        
        [Parameter(Mandatory=$true)]
        [ValidateSet("Bytes", "KB", "MB", "GB", "TB")]
        [String] $To,
        
        [Parameter(Mandatory=$true)]
        [Double] $Value,
        
        [Parameter(Mandatory=$false)]
        [Int] $Precision = 4
    )
    
    try
    {
        switch ($From)
        {
            "Bytes" {$value = $Value }
            "KB"    {$value = $Value * 1024 }
            "MB"    {$value = $Value * 1024 * 1024}
            "GB"    {$value = $Value * 1024 * 1024 * 1024}
            "TB"    {$value = $Value * 1024 * 1024 * 1024 * 1024}
        }

        switch ($To)
        {
            "Bytes" {return $value}
            "KB"    {$Value = $Value/1KB}
            "MB"    {$Value = $Value/1MB}
            "GB"    {$Value = $Value/1GB}
            "TB"    {$Value = $Value/1TB}
        }

        Write-Output -InputObject ( [Math]::Round($value, $Precision, [MidPointRounding]::AwayFromZero) )
    }
    catch
    {
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
}
