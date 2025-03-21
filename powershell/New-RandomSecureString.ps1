<#
.SYNOPSIS
    Generates a new random secure string.

.DESCRIPTION
    This function generates a new random secure string with the specified length and character composition.
    It allows specifying the number of uppercase, lowercase, numeric, and special characters in the secure string.

.PARAMETER Length
    The length of the secure string. This parameter is mandatory.

.PARAMETER Upper
    The number of uppercase characters in the secure string. This parameter is optional and defaults to 2.

.PARAMETER Lower
    The number of lowercase characters in the secure string. This parameter is optional and defaults to 2.

.PARAMETER Numeric
    The number of numeric characters in the secure string. This parameter is optional and defaults to 2.

.PARAMETER Special
    The number of special characters in the secure string. This parameter is optional and defaults to 2.

.OUTPUTS
    [System.String]
        The generated secure string.

.EXAMPLE
    PS> New-RandomSecureString -Length 24

.EXAMPLE
    PS> New-RandomSecureString -Length 24
    PS> Set-ADAccountPassword -Identity "<ad-user>" -Reset -NewPassword (ConvertTo-SecureString -AsPlainText "$( New-RandomSecureString -Length 24 )" -Force)

.NOTES
    Author: klee-it
    PowerShell Version: 5.1, 7.x
#>

###
### FUNCTION: generate new random secure string
###
Function New-RandomSecureString
{
    [OutputType([System.String])]
    [CmdLetBinding(DefaultParameterSetName="Default")]

    param(
        [Parameter( Mandatory = $True )]
        [ValidateRange(8, [Int]::MaxValue)]
        [Int] $Length,

        [Parameter( Mandatory = $False )] [Int] $Upper = 2,
        [Parameter( Mandatory = $False )] [Int] $Lower = 2,
        [Parameter( Mandatory = $False )] [Int] $Numeric = 2,
        [Parameter( Mandatory = $False )] [Int] $Special = 2
    )
    
    try
    {
        ###
        ### [Option 1] generate new secure string
        ###
        # Add-Type -AssemblyName 'System.Web'
        # $amountOfNonAlphanumeric = 3
        # $newPassphrase = [System.Web.Security.Membership]::GeneratePassword($Length, $amountOfNonAlphanumeric)

        ###
        ### [Option 2] generate new secure string
        ###
        # using a fixed set of characters => theoretically it is possible that the secure string does not contain the required number of special characters
        # $stringChars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()_+'
        # $stringArray = $stringChars.ToCharArray()
        # Write-Output -InputObject ( -join ($stringArray | Get-Random -Count 24) )

        ###
        ### [Option 3] generate new secure string - Enforce the number of special characters
        ###
        # check if the number of upper/lower/numeric/special char is lower or equal to length
        if ($Upper + $Lower + $Numeric + $Special -gt $Length)
        {
            throw "Number of upper/lower/numeric/special char must be lower or equal to length"
        }

        # define character sets
        $uCharSet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
        $lCharSet = 'abcdefghijklmnopqrstuvwxyz'
        $nCharSet = '0123456789'
        $sCharSet = '!@#$*._-+'
        $charSet = ""

        # add character sets to the secure string
        if ($Upper -gt 0) { $charSet += $uCharSet }
        if ($Lower -gt 0) { $charSet += $lCharSet }
        if ($Numeric -gt 0) { $charSet += $nCharSet }
        if ($Special -gt 0) { $charSet += $sCharSet }
        
        # convert to char array
        $charSet = $charSet.ToCharArray()

        # generate secure string
        $rng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
        $bytes = New-Object byte[]($Length)
        $rng.GetBytes($bytes)
    
        # create secure string
        $result = New-Object char[]($Length)

        for ($i = 0 ; $i -lt $Length ; $i++)
        {
            $result[$i] = $charSet[$bytes[$i] % $charSet.Length]
        }

        $secureString = (-join $result)
        $valid = $true

        # check if the secure string contains the required number of upper/lower/numeric/special characters
        if ($Upper   -gt ($secureString.ToCharArray() | Where-Object {$_ -cin $uCharSet.ToCharArray() }).Count) { $valid = $false }
        if ($Lower   -gt ($secureString.ToCharArray() | Where-Object {$_ -cin $lCharSet.ToCharArray() }).Count) { $valid = $false }
        if ($Numeric -gt ($secureString.ToCharArray() | Where-Object {$_ -cin $nCharSet.ToCharArray() }).Count) { $valid = $false }
        if ($Special -gt ($secureString.ToCharArray() | Where-Object {$_ -cin $sCharSet.ToCharArray() }).Count) { $valid = $false }
    
        if (-Not $valid)
        {
            $secureString = New-RandomSecureString -Length $Length -Upper $Upper -Lower $Lower -Numeric $Numeric -Special $Special
        }
        
        Write-Output -InputObject "$($secureString)"
    }
    catch
    {
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
}
