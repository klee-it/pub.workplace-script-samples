<#
.SYNOPSIS
    Gets a normalized version string which can be used for version comparison.

.DESCRIPTION
    This function takes a version string as input and normalizes it by removing non-numeric characters and trimming ending zeros.
    It returns a normalized version string that can be used for version comparison.

.PARAMETER Value
    The version string to be normalized. This parameter is optional and defaults to an empty string.

.OUTPUTS
    [System.String]
        The normalized version string.

.EXAMPLE
    PS> Get-NormalizedVersion -Value '1.0.0-beta'
    1.0

.EXAMPLE
    PS> Get-NormalizedVersion -Value '2.3.4.0'
    2.3.4

.EXAMPLE
    PS> Get-NormalizedVersion -Value '2.0'
    2.0

.NOTES
    Author: klee-it
    PowerShell Version: 5.1, 7.x
#>

###
### FUNCTION: Get normalized version string which can be used for version comparison
###
Function Get-NormalizedVersion
{
    [OutputType([System.String])]
    [CmdLetBinding(DefaultParameterSetName="Default")]

    param(
        [Parameter(Mandatory=$false)]
        [String] $Value = ''
    )
    
    try
    {
        Write-Verbose -Message "Original Version : '$($Value)'"

        $OutputString = ''
        $Value = "$( $Value.Trim() )" # remove leading and trailing whitespaces

        # check if the value is empty
        if ( [String]::IsNullOrEmpty($Value) )
        {
            Write-Warning -Message "Given value was empty. Returning empty string."
        }

        # check if the value contains letters
        elseif ( $Value -match '[a-zA-Z ]' )
        {
            Write-Warning -Message "Given value contains letters. Returning empty string."
        }

        # replace all non-numeric characters with a dot and trim ending zeros
        else
        {
            # $normalizedValue = "$($Value -replace '[\D]', '.')".TrimEnd('.0') # TrimEnd() replaces all specified characters, but not as "word"
            $normalizedValue = "$( "$($Value -replace '[\D]', '.')" -replace '\.0$', '' )"
            Write-Verbose -Message "Normalized value: '$($normalizedValue)'"

            # check if normalized value is empty
            if ( [String]::IsNullOrEmpty($normalizedValue) )
            {
                Write-Warning -Message "Normalized value was empty. Returning empty string."
            }
            # check if normalized value is in format major.minor(.patch)(.build)
            elseif ( $normalizedValue -notmatch '^\d+\.\d+(?:\.\d+)?(?:\.\d+)?$' )
            {
                Write-Verbose -Message "Normalized value is not in format major.minor. Add missing minor part."
                $OutputString = "$($normalizedValue).0"
            }
            else
            {
                Write-Verbose -Message "Normalized value is in format major.minor(.patch)(.build)."
                $OutputString = "$($normalizedValue)"
            }

            Get-Variable -Name 'normalizedValue' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
        }

        Write-Output -InputObject "$($OutputString)"
    }
    catch
    {
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
}
