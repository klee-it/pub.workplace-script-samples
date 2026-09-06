<#
.SYNOPSIS
    Merges a default hashtable with a custom hashtable and returns a merged hashtable with all fields.

.DESCRIPTION
    This function merges a default hashtable with a custom hashtable and returns a merged hashtable including all fields from both tables.
    It allows specifying whether to order by keys, overwrite arrays, and only merge empty objects.

.PARAMETER DefaultHashTable
    The default hashtable to merge. This parameter is mandatory.

.PARAMETER CustomHashTable
    The custom hashtable to merge. This parameter is mandatory.

.PARAMETER OrderByKeys
    Switch to indicate whether to order the keys alphabetically in the result. This parameter is optional.

.PARAMETER OverwriteArrays
    Switch to indicate whether arrays in the hashtable should be overwritten or merged. Default is false. This parameter is optional.

.PARAMETER OnlyEmptyObjects
    Switch to indicate whether to only merge empty objects. Default is false. This parameter is optional.

.OUTPUTS
    [HashTable]
        The merged hashtable with all fields.

.EXAMPLE
    PS> $default = @{ Name = 'John'; Age = 30 }
    PS> $custom = @{ Age = 25; City = 'New York' }
    PS> Merge-CustomHashTable -DefaultHashTable $default -CustomHashTable $custom

.NOTES
    Author: klee-it
    PowerShell Version: 5.1, 7.x
#>

###
### FUNCTION: merge default object with custom object and return new full object with all fields
###
function Merge-CustomHashTable
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding(DefaultParameterSetName = 'Default')]

    param(
        [Parameter(Mandatory = $true)]
        [HashTable] $DefaultHashTable,

        [Parameter(Mandatory = $true)]
        [HashTable] $CustomHashTable,

        [Parameter(Mandatory = $false)]
        [Switch] $OrderByKeys = $false,

        [Parameter(Mandatory = $false)]
        [Switch] $OverwriteArrays = $false,

        [Parameter(Mandatory = $false)]
        [Switch] $OnlyEmptyObjects = $false
    )

    try
    {
        # set default and custom object to full object
        $DefaultHashTable = $DefaultHashTable.Clone()
        $CustomHashTable = $CustomHashTable.Clone()

        # go through all default keys
        foreach ($defaultIem in $DefaultHashTable.GetEnumerator())
        {
            if ($defaultIem.Key -notin $CustomHashTable.Keys)
            {
                $CustomHashTable.Add($defaultIem.Key, $defaultIem.Value)
            }
            else
            {
                # get item type
                $defaultIemType = "$($defaultIem.Value.GetType().Name)"
                Write-Verbose "Item '$($defaultIem.Key)' has type: $defaultIemType"

                # if item exists and is a object, check subfields
                switch ($defaultIemType)
                {
                    'PSCustomObject'
                    {
                        $DataSplat = @{
                            DefaultObject    = $defaultIem.Value
                            CustomObject     = $CustomHashTable[$defaultIem.Key]
                            OverwriteArrays  = $OverwriteArrays
                            OnlyEmptyObjects = $OnlyEmptyObjects
                        }

                        # if custom object is empty, set it to empty string to avoid errors in recursive function call
                        if ([String]::IsNullOrEmpty($DataSplat.CustomObject))
                        {
                            $DataSplat.CustomObject = ''
                        }

                        # merge subfields with recursive function call
                        $CustomHashTable[$defaultIem.Key] = Merge-CustomObjectData @DataSplat
                        break
                    }
                    'Hashtable'
                    {
                        $CustomHashTable[$defaultIem.Key] = Merge-CustomHashTable -DefaultHashTable $defaultIem.Value -CustomHashTable $CustomHashTable[$defaultIem.Key]
                        break
                    }
                    'Object[]'
                    {
                        if ($OnlyEmptyObjects)
                        {
                            if ( [String]::IsNullOrEmpty($defaultIem.Value) )
                            {
                                $CustomHashTable[$defaultIem.Key] = $CustomHashTable[$defaultIem.Key]
                            }
                            else
                            {
                                $CustomHashTable[$defaultIem.Key] = $defaultIem.Value
                            }
                        }
                        else
                        {
                            if ($OverwriteArrays)
                            {
                                $CustomHashTable[$defaultIem.Key] = $CustomHashTable[$defaultIem.Key]
                            }
                            else
                            {
                                $CustomHashTable[$defaultIem.Key] = $defaultIem.Value + $CustomHashTable[$defaultIem.Key]
                            }
                        }
                        break
                    }
                    default
                    {
                        if ($OnlyEmptyObjects)
                        {
                            if ( [String]::IsNullOrEmpty($defaultIem.Value) )
                            {
                                $CustomHashTable[$defaultIem.Key] = $CustomHashTable[$defaultIem.Key]
                            }
                            else
                            {
                                $CustomHashTable[$defaultIem.Key] = $defaultIem.Value
                            }
                        }
                        else
                        {
                            $CustomHashTable[$defaultIem.Key] = $CustomHashTable[$defaultIem.Key]
                        }
                        break
                    }
                }
            }
        }

        # order keys alphabetically if requested
        if ($OrderByKeys)
        {
            $orderedCustomHashTable = [ordered]@{}
            $CustomHashTable.Keys | Sort-Object | ForEach-Object { $orderedCustomHashTable.Add($_, $CustomHashTable[$_]) }
            Write-Output -InputObject $orderedCustomHashTable.PSObject.Copy()
        }
        else
        {
            Write-Output -InputObject $CustomHashTable.Clone()
        }
    }
    catch
    {
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
}
