<#
.SYNOPSIS
    Merges a default object with a custom object and returns a new full object with all fields.

.DESCRIPTION
    This function merges a default object with a custom object and returns a new full object with all fields.
    It allows specifying whether to overwrite arrays and whether to only merge empty objects.

.PARAMETER DefaultObject
    The default object to merge. This parameter is mandatory.

.PARAMETER CustomObject
    The custom object to merge. This parameter is mandatory.

.PARAMETER OverwriteArrays
    A switch to indicate whether to overwrite arrays. Default is false. This parameter is optional.

.PARAMETER OnlyEmptyObjects
    A switch to indicate whether to only merge empty objects. Default is false. This parameter is optional.

.OUTPUTS
    [PSCustomObject]
        The merged object with all fields.

.EXAMPLE
    PS> $default = [PSCustomObject]@{ Name = 'John'; Age = 30 }
    PS> $custom = [PSCustomObject]@{ Age = 25; City = 'New York' }
    PS> Merge-CustomObjectData -DefaultObject $default -CustomObject $custom

.NOTES
    Author: klee-it
    PowerShell Version: 5.1, 7.x
#>

###
### FUNCTION: merge default object with custom object and return new full object with all fields
###
function Merge-CustomObjectData
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding(DefaultParameterSetName="Default")]

    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject] $DefaultObject,

        [Parameter(Mandatory=$true)]
        [PSCustomObject] $CustomObject,

        [Parameter(Mandatory=$false)]
        [Switch] $OverwriteArrays = $false,

        [Parameter(Mandatory=$false)]
        [Switch] $OnlyEmptyObjects = $false
    )
    
    try 
    {
        # set default and custom object to full object
        $DefaultObject = $DefaultObject.PSObject.Copy()
        $CustomObject  = $CustomObject.PSObject.Copy()

        # get field names
        $DefaultObject_Fields = $DefaultObject | Get-Member -MemberType 'NoteProperty' | Sort-Object -Property Name | Select-Object -ExpandProperty Name
        $CustomObject_Fields  = $CustomObject | Get-Member -MemberType 'NoteProperty' | Sort-Object -Property Name | Select-Object -ExpandProperty Name

        # go through all default fields
        foreach ($fieldName in $DefaultObject_Fields)
        {
            # check if default field exists in custom object
            if ($fieldName -notin $CustomObject_Fields)
            {
                # field not provided, add default data
                $CustomObject | Add-Member -MemberType 'NoteProperty' -Name "$($fieldName)" -Value $DefaultObject."$($fieldName)"
            }
            else
            {
                # get field type
                $fieldType = "$($DefaultObject."$($fieldName)".GetType().Name)"

                # if field exists and is a object, check subfields
                switch ($fieldType)
                {
                    'PSCustomObject' { 
                        $DataSplat = @{
                            DefaultObject = $DefaultObject."$($fieldName)"
                            CustomObject  = $CustomObject."$($fieldName)"
                            OverwriteArrays = $OverwriteArrays
                            OnlyEmptyObjects = $OnlyEmptyObjects
                        }
                        $CustomObject."$($fieldName)" = Merge-CustomObjectData @DataSplat
                        break
                    }
                    'Object[]' {
                        if ($OnlyEmptyObjects)
                        {
                            if ( [String]::IsNullOrEmpty($DefaultObject."$($fieldName)") )
                            {
                                $CustomObject."$($fieldName)" = $CustomObject."$($fieldName)"
                            }
                            else
                            {
                                $CustomObject."$($fieldName)" = $DefaultObject."$($fieldName)"
                            }
                        }
                        else
                        {
                            if ($OverwriteArrays)
                            {
                                $CustomObject."$($fieldName)" = $CustomObject."$($fieldName)"
                            }
                            else
                            {
                                $CustomObject."$($fieldName)" = $DefaultObject."$($fieldName)" + $CustomObject."$($fieldName)"
                            }
                        }
                        break
                    }
                    default {
                        if ($OnlyEmptyObjects)
                        {
                            if ( [String]::IsNullOrEmpty($DefaultObject."$($fieldName)") )
                            {
                                $CustomObject."$($fieldName)" = $CustomObject."$($fieldName)"
                            }
                            else
                            {
                                $CustomObject."$($fieldName)" = $DefaultObject."$($fieldName)"
                            }
                        }
                        else
                        {
                            $CustomObject."$($fieldName)" = $CustomObject."$($fieldName)"
                        }
                        break
                    }
                }
            }
        }

        Write-Output -InputObject $CustomObject.PSObject.Copy()
    }
    catch 
    {
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
}
