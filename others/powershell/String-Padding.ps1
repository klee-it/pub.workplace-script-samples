###
### FUNCTION: padding string left or right side
### |_ String-Padding -Value 'test' -FieldLength 6 -ToAppend ' ' -Justification 'Right'
###
function String-Padding
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding(DefaultParameterSetName="Default")]

    param(
        [Parameter(Mandatory=$true)]
        [String] $Value,
        
        [Parameter(Mandatory=$false)]
        [Int] $FieldLength = 20,
        
        [Parameter(Mandatory=$false)]
        [String] $ToAppend = ' ',
        
        [Parameter(Mandatory=$false)]
        [ValidateSet('Left', 'Right', 'Both')]
        [String] $Justification = 'Right'
    )

    try
    {
        Write-Verbose -Message "Value: $($Value)"
        Write-Verbose -Message "FieldLength: $($FieldLength)"
        Write-Verbose -Message "ToAppend: '$($ToAppend)"
        Write-Verbose -Message "Justification: $($Justification)"

        $iCount = $FieldLength - $Value.Length
        
        if ($iCount -gt 0)
        {
            $sAppended = $ToAppend * $iCount

            switch ($Justification)
            {
                'Left'  { $prefix = $sAppended; $suffix = ''; break }
                'Right' { $prefix = ''; $suffix = $sAppended; break }
                'Both'  { $prefix = $sAppended.Substring(0, $iCount / 2); $suffix = $sAppended.Substring($iCount / 2); break }
                default { Write-Warning -Message "Unknown justification: '$($Justification)'" }
            }
        }
        
        Write-Output -InputObject "$($prefix)$($Value)$($suffix)"
    }
    catch
    {
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
}
