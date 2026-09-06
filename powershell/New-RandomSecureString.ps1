<#
.SYNOPSIS
    Generates a random string with customizable character composition.

.DESCRIPTION
    Generates a random string of a specified length, ensuring a minimum number of uppercase, lowercase, numeric, and special characters as specified by parameters.
    The function enforces that the total of each requested character type does not exceed the total length and the output will be randomized accordingly.
    Optionally outputs as a secure string with the -AsSecureString switch.

.PARAMETER Length
    The total length of the generated string. Must be at least 8.

.PARAMETER Upper
    Minimum number of uppercase letters to include (default: 2).

.PARAMETER Lower
    Minimum number of lowercase letters to include (default: 2).

.PARAMETER Numeric
    Minimum number of numeric digits to include (default: 2).

.PARAMETER Special
    Minimum number of special characters to include (default: 2).

.PARAMETER AsSecureString
    If specified, returns as a [SecureString] object instead of plain text.

.OUTPUTS
    [System.String] or [System.Security.SecureString]
        The generated string, in plain text or SecureString according to parameters.

.EXAMPLE
    PS> New-RandomSecureString -Length 24

.EXAMPLE
    PS> New-RandomSecureString -Length 24
    PS> Set-ADAccountPassword -Identity "<ad-user>" -Reset -NewPassword (ConvertTo-SecureString -AsPlainText "$(New-RandomSecureString -Length 24)" -Force)

.NOTES
    Author: klee-it
    PowerShell Version: 5.1, 7.x
#>

###
### FUNCTION: generate new random secure string
###
function New-RandomSecureString
{
    [OutputType([System.String])]
    [CmdLetBinding(DefaultParameterSetName = 'Default')]

    param(
        [Parameter( Mandatory = $True )]
        [ValidateRange(8, [Int]::MaxValue)]
        [Int] $Length,

        [Parameter( Mandatory = $False )] [Int] $Upper = 2,
        [Parameter( Mandatory = $False )] [Int] $Lower = 2,
        [Parameter( Mandatory = $False )] [Int] $Numeric = 2,
        [Parameter( Mandatory = $False )] [Int] $Special = 2,

        [Parameter( Mandatory = $False )]
        [Switch] $AsSecureString = $false
    )

    try
    {
        ###
        ### generate new secure string - Enforce the number of special characters
        ###
        
        # check if the number of upper/lower/numeric/special char is lower or equal to length
        if ($Upper + $Lower + $Numeric + $Special -gt $Length)
        {
            throw 'Number of upper/lower/numeric/special char must be lower or equal to length'
        }

        # define character sets
        $uCharSet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
        $lCharSet = 'abcdefghijklmnopqrstuvwxyz'
        $nCharSet = '0123456789'
        $sCharSet = '!@#$*._-+'
        $charSet = ''

        # add character sets to the secure string
        if ($Upper -gt 0) { $charSet += $uCharSet }
        if ($Lower -gt 0) { $charSet += $lCharSet }
        if ($Numeric -gt 0) { $charSet += $nCharSet }
        if ($Special -gt 0) { $charSet += $sCharSet }

        # convert to char array
        $charSet = $charSet.ToCharArray()

        # generate secure string using rejection sampling to eliminate modulo bias.
        # bytes in the range [maxUsable, 255] are discarded and redrawn so that
        # every remaining value maps to exactly one charset index with equal probability.
        $rng = New-Object -TypeName 'System.Security.Cryptography.RNGCryptoServiceProvider'
        $singleByte = New-Object -TypeName 'System.Byte[]' -ArgumentList 1

        function Get-RandomIndexFromRange
        {
            param([Int] $Range)

            $maxUsable = [Math]::Floor(256 / $Range) * $Range

            do
            {
                $rng.GetBytes($singleByte)
            } while ($singleByte[0] -ge $maxUsable)

            return $singleByte[0] % $Range
        }

        function Get-RandomCharFromSet
        {
            param([Char[]] $Set)

            return $Set[(Get-RandomIndexFromRange -Range $Set.Length)]
        }

        # guarantee minimum counts per character class, then fill remaining positions
        $result = [System.Collections.Generic.List[Char]]::new($Length)

        for ($i = 0 ; $i -lt $Upper ; $i++) { $result.Add( (Get-RandomCharFromSet -Set $uCharSet.ToCharArray()) ) }
        for ($i = 0 ; $i -lt $Lower ; $i++) { $result.Add( (Get-RandomCharFromSet -Set $lCharSet.ToCharArray()) ) }
        for ($i = 0 ; $i -lt $Numeric ; $i++) { $result.Add( (Get-RandomCharFromSet -Set $nCharSet.ToCharArray()) ) }
        for ($i = 0 ; $i -lt $Special ; $i++) { $result.Add( (Get-RandomCharFromSet -Set $sCharSet.ToCharArray()) ) }

        $remaining = $Length - $Upper - $Lower - $Numeric - $Special
        for ($i = 0 ; $i -lt $remaining ; $i++)
        {
            $result.Add( (Get-RandomCharFromSet -Set $charSet) )
        }

        # shuffle with Fisher-Yates so required characters are not predictable by position
        for ($i = ($result.Count - 1) ; $i -gt 0 ; $i--)
        {
            $j = Get-RandomIndexFromRange -Range ($i + 1)
            $temp = $result[$i]
            $result[$i] = $result[$j]
            $result[$j] = $temp
        }

        $secureString = -join $result

        # convert to secure string if requested
        if ($AsSecureString)
        {
            Write-Verbose -Message 'Converting to secure string...'
            $secureString = ConvertTo-SecureString -String "$($secureString)" -AsPlainText -Force
        }
        else
        {
            Write-Verbose -Message 'Returning as plain text...'
        }

        # clean-up
        $rng.Dispose()

        Write-Output -InputObject $secureString
    }
    catch
    {
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
}
