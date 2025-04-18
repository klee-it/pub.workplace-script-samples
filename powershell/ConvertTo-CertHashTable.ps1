<#
.SYNOPSIS
    Converts a certificate subject or issuer string into a hash table.

.DESCRIPTION
    This function processes a certificate subject or issuer string, splitting it into key-value pairs
    and storing them in a hash table. Each key-value pair is extracted based on the '=' delimiter.

.PARAMETER Value
    The certificate subject or issuer string to be converted. This parameter is optional and defaults to an empty string.
    It can also accept input from the pipeline or by property name.

.OUTPUTS
    [System.Management.Automation.PSObject]
        An ordered hash table containing the parsed key-value pairs from the input string.

.EXAMPLE
    PS> ConvertTo-CertHashTable -Value "CN=example.com, O=Example Org, C=US"
    Name                           Value
    ----                           -----
    CN                             {example.com}
    O                              {Example Org}
    C                              {US}

.NOTES
    Author: klee-it
    PowerShell Version: 5.1, 7.x
#>

###
### FUNCTION: convert certificate subject/issuer into hash table
###
function ConvertTo-CertHashTable
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding(DefaultParameterSetName="Default")]

    param(
        [Parameter(
            Mandatory = $false,
            ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True
        )]
        [Alias("Subject", "Issuer")]
        [String] $Value = '',
        
        [Parameter(
            Mandatory = $false,
            ValueFromPipeline = $True,
            ValueFromPipelineByPropertyName = $True
        )]
        [ValidateSet(1, 2)]
        [Int32] $Option = 1
    )

    try
    {
        switch ($Option)
        {
            1 {
                $outputInfo = [ordered]@{}
                $regex = '(?<key>[^=,]+)=(?:"(?<value>[^"]+)"|(?<value>[^,]+))'
        
                # Match all key-value pairs in the string
                foreach ($match in [regex]::Matches($Value, $regex)) {
                    $key = $match.Groups['key'].Value.Trim()
                    $value = $match.Groups['value'].Value.Trim()
                    $outputInfo[$key] = $value
                }
            }
            2 { 
                $processedString = $Value -replace ',(?=(?:[^"]*"[^"]*")*[^"]*$)', "`n"
                $outputInfo = $processedString | ConvertFrom-StringData
            }
        }

        Write-Output -InputObject $outputInfo
    }
    catch
    {
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
}
