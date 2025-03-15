<#
.SYNOPSIS
    Pads a string on the left, right, or both sides.

.DESCRIPTION
    This function pads a string on the left, right, or both sides with a specified character to a specified length.

.PARAMETER Value
    The string to be padded. This parameter is mandatory.

.PARAMETER FieldLength
    The total length of the output string, including the padding. Default is 20.

.PARAMETER ToAppend
    The character to use for padding. Default is a space (' ').

.PARAMETER Justification
    Specifies whether to pad the string on the left, right, or both sides. Valid values are 'Left', 'Right', and 'Both'. Default is 'Right'.

.OUTPUTS
    [System.String]
        The padded string.

.EXAMPLE
    PS> String-Padding -Value "test" -FieldLength 6 -ToAppend " " -Justification 'Right'
    Output: "test  "

.NOTES
    Author: klee-it
    PowerShell Version: 5.1, 7.x
#>

###
### FUNCTION: padding string left or right side
###
function String-Padding
{
    [OutputType([System.String])]
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
