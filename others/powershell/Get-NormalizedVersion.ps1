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
                Write-Warning -Message "Normalized value is not in format major.minor. Add missing minor part."
                $OutputString = "$($normalizedValue).0"
            }
            else
            {
                Write-Warning -Message "$($MyInvocation.MyCommand)" -Value "Normalized value is in format major.minor(.patch)(.build)."
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
