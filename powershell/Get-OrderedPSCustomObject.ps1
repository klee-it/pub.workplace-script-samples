<#
.SYNOPSIS
    Returns an ordered PSCustomObject with properties sorted alphabetically.

.DESCRIPTION
    Accepts a PSCustomObject and outputs a new ordered PSCustomObject with its NoteProperty members sorted by property name. Useful for consistent formatting and comparison.

.PARAMETER InputObject
    The PSCustomObject to sort. This parameter is mandatory.

.OUTPUTS
    [System.Management.Automation.PSObject]
        An ordered PSCustomObject with sorted properties.

.EXAMPLE
    PS> $obj = [PSCustomObject]@{b=2;a=1}
    PS> Get-OrderedPSCustomObject -InputObject $obj
    a : 1
    b : 2

.NOTES
    Author: klee-it
    Only NoteProperty members are included in the output.
    Compatible with PowerShell 5.1 and 7.x
#>

###
### FUNCTION: Get ordered PSCustomObject
###
function Get-OrderedPSCustomObject
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding(DefaultParameterSetName = 'Default')]

    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [ValidateNotNullOrEmpty()]
        [Object] $InputObject
    )

    begin
    {
        if ($null -eq $InputObject)
        {
            return
        }
    }

    process
    {
        foreach ($obj in @($InputObject))
        {
            try
            {
                if ($obj -is [PSCustomObject])
                {
                    $NewOrderedObject = [PSCustomObject][Ordered]@{}

                    foreach ($prop in ($obj.PSObject.Properties | Where-Object { $_.MemberType -eq 'NoteProperty' } | Sort-Object Name))
                    {
                        $NewOrderedObject | Add-Member -MemberType 'NoteProperty' -Name $prop.Name -Value $prop.Value
                    }
                }
                else
                {
                    $NewOrderedObject = $obj
                }

                Write-Output $NewOrderedObject
            }
            catch
            {
                Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
            }
        }
    }
}
