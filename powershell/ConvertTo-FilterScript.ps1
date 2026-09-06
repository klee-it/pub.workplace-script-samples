<#
.SYNOPSIS
    Converts a PSObject or custom expression to a filter script.

.DESCRIPTION
    This function takes a PSObject as input and generates a filter script based on the properties and values of the object.
    Alternatively, accepts a custom filter expression string for direct filter creation.
    The filter script can be used to filter data based on the specified conditions.
    Supports multiple output types (ScriptBlock, String) and formats (PowerShell, ActiveDirectory, EntraId).

.PARAMETER Filter
    The PSObject containing the filter conditions. This parameter is mandatory for the 'Default' parameter set and cannot be null or empty.
    Expected structure: [PSCustomObject]@{ and = @(...); or = @(...) }

.PARAMETER Expression
    A custom filter expression string. When provided, this parameter takes precedence over the Filter parameter.
    This parameter is mandatory for the 'Expr' parameter set.

.PARAMETER OutputType
    Specifies the output type for the filter script. Valid values are 'ScriptBlock' (default) or 'String'.
    Only applicable when using the 'Default' parameter set.

.PARAMETER OutputFormat
    Specifies the output format for the filter script. Valid values are 'PowerShell' (default), 'ActiveDirectory', or 'EntraId'.
    Only applicable when using the 'Default' parameter set.

.OUTPUTS
    [System.Collections.Hashtable]
        - The key 'FilterScript' contains the filter script as a ScriptBlock (when OutputType is 'ScriptBlock').
        - The key 'FilterString' contains the filter script as a String (when OutputType is 'String').


.EXAMPLE
    PS> $customFilterObject = [PSCustomObject]@{ and = @(@{ property = 'Name'; operator = 'eq'; value = 'John' }) }
    PS> $customFilterObject = [PSCustomObject]@{ and = @(@{ property = 'Name'; operator = 'eq'; value = 'John' },@{ property = 'Enabled'; operator = 'eq'; value = $true }) }
    PS> $customFilterObject = [PSCustomObject]@{ and = @(@{ property = 'Name'; operator = 'eq'; value = 'John' },@{ property = 'Enabled'; operator = 'eq'; value = $true }); or = @(@{ property = 'Department'; operator = 'eq'; value = 'IT' }) }
    PS> $customFilterObject = [PSCustomObject]@{ and = @(@{ property = 'Name'; operator = 'eq'; value = 'John' },@{ property = 'Enabled'; operator = 'eq'; value = $true }); or = @(@{ property = 'Department'; operator = 'eq'; value = 'IT' }; @{ property = 'ExpireDate'; operator = 'eq'; value = (Get-Date) }; @{ property = 'ListOfFruites'; operator = 'in'; value = @('apple', 'banana') }) }
    PS> $customFilterObject = [PSCustomObject]@{ or = @(@{ property = 'Name'; operator = 'eq'; value = 'John' },@{ property = 'Enabled'; operator = 'eq'; value = $true }) }


    PS> $customFilter = ConvertTo-FilterScript -Expression "StartsWith('DisplayName', 'EntraId-GroupName-')" -OutputType ScriptBlock -OutputFormat EntraId -Verbose
    PS> $customFilter = ConvertTo-FilterScript -Filter $customFilterObject -OutputType String -OutputFormat ActiveDirectory -Verbose
    PS> $customFilter = ConvertTo-FilterScript -Filter $customFilterObject -OutputType ScriptBlock -OutputFormat ActiveDirectory -Verbose
    PS> $customFilter = ConvertTo-FilterScript -Filter $customFilterObject -OutputType String -OutputFormat EntraId -Verbose
    PS> $customFilter = ConvertTo-FilterScript -Filter $customFilterObject -OutputType ScriptBlock -OutputFormat EntraId -Verbose
    PS> $customFilter = ConvertTo-FilterScript -Filter $customFilterObject -OutputType String -OutputFormat PowerShell -Verbose
    PS> $customFilter = ConvertTo-FilterScript -Filter $customFilterObject -OutputType ScriptBlock -OutputFormat PowerShell -Verbose
    PS> $AnyObjectList | Where-Object -FilterScript $customFilter['FilterScript']

.NOTES
    Author: klee-it
    PowerShell Version: 5.1, 7.x
#>

###
### FUNCTION: convert a PSObject to a filter script
###
function ConvertTo-FilterScript
{
    [OutputType([System.Collections.Hashtable])]
    [CmdLetBinding(DefaultParameterSetName = 'Default')]

    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Expr')]
        [ValidateNotNullOrEmpty()]
        [String] $Expression,

        [Parameter(Mandatory = $true, ParameterSetName = 'Default')]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject] $Filter,

        [Parameter(Mandatory = $false, ParameterSetName = 'Default')]
        [ValidateSet('ScriptBlock', 'String')]
        [String] $OutputType = 'ScriptBlock',

        [Parameter(Mandatory = $false, ParameterSetName = 'Default')]
        [ValidateSet('PowerShell', 'ActiveDirectory', 'EntraId')]
        [String] $OutputFormat = 'PowerShell'
    )

    function Get-FilterArray
    {
        [OutputType([System.String])]
        [CmdLetBinding(DefaultParameterSetName = 'Default')]

        param(
            [Parameter(Mandatory = $true)]
            [ValidateNotNullOrEmpty()]
            [PSCustomObject] $FilterSection,

            [Parameter(Mandatory = $false)]
            [ValidateSet('and', 'or')]
            [String] $LogicalOperator = 'and',

            [Parameter(Mandatory = $false)]
            [ValidateSet('PowerShell', 'ActiveDirectory', 'EntraId')]
            [String] $OutputFormat = 'PowerShell'
        )

        Write-Verbose -Message "Generate filter array for logical operator '$($LogicalOperator)'..."

        $FilterArray = $null
        if ($FilterSection)
        {
            switch ($OutputFormat)
            {
                'PowerShell' { $PropertyNamePrefix = '$_.'; $OperatorPrefix = '-' }
                'ActiveDirectory' { $PropertyNamePrefix = ''; $OperatorPrefix = '-' }
                'EntraId' { $PropertyNamePrefix = ''; $OperatorPrefix = '' }
            }

            $FilterArray = $FilterSection | ForEach-Object {

                $PropertyName = if ($_.property -match '[\W_]') { "'$($_.property)'" } else { "$($_.property)" }

                if ( ($_.value -is [Int32]) -or ($_.value -is [Int64]) )
                {
                    "$($PropertyNamePrefix)$PropertyName $($OperatorPrefix)$($_.operator) $($_.value)"
                }
                elseif ($_.value -is [bool])
                {
                    if ($OutputFormat -eq 'EntraId')
                    {
                        "$($PropertyNamePrefix)$PropertyName $($_.operator) $($_.value.ToString().ToLower())"
                    }
                    else
                    {
                        "$($PropertyNamePrefix)$PropertyName $($OperatorPrefix)$($_.operator) '$($_.value)'"
                    }
                }
                elseif ( $_.value -is [Array] )
                {
                    "$($PropertyNamePrefix)$PropertyName $($OperatorPrefix)$($_.operator) @('$($_.value -join "','")')"
                }
                elseif ($_.value -is [DateTime])
                {
                    if ($PropertyNamePrefix -eq '$_.')
                    {
                        "([DateTime]$($PropertyNamePrefix)$PropertyName) $($OperatorPrefix)$($_.operator) ([DateTime]'$($_.value)')"
                    }
                    else
                    {
                        "$($PropertyNamePrefix)$PropertyName $($OperatorPrefix)$($_.operator) ([DateTime]'$($_.value)')"
                    }
                }
                else
                {
                    "$($PropertyNamePrefix)$PropertyName $($OperatorPrefix)$($_.operator) '$($_.value)'"
                }
            }

            $FilterArray = '{0}' -f ( $FilterArray -join " $($OperatorPrefix)$($LogicalOperator) " )
        }

        Write-Output -InputObject $FilterArray
    }

    try
    {
        # use custom expression if provided
        if ($PSBoundParameters.ContainsKey('Expression'))
        {
            Write-Verbose -Message "Use custom expression: '$($Expression)'"
            Write-Output -InputObject (@{ FilterScript = [ScriptBlock]::Create( $Expression ) })
        }

        else
        {
            # Generate filter script
            Write-Verbose -Message 'Generate filter script...'

            # initialize output variable
            $Output = ''

            # filterscript: and
            $FilterArray_AND = $null
            if ($Filter.and)
            {
                $FilterArray_AND = Get-FilterArray -FilterSection $Filter.and -LogicalOperator 'and' -OutputFormat $OutputFormat
            }

            # filterscript: or
            $FilterArray_OR = $null
            if ($Filter.or)
            {
                $FilterArray_OR = Get-FilterArray -FilterSection $Filter.or -LogicalOperator 'or' -OutputFormat $OutputFormat
            }

            # new 'FilterScript' query
            if ( ($null -ne $FilterArray_AND) -and ($null -ne $FilterArray_OR) )
            {
                $topLevelAnd = if ($OutputFormat -eq 'EntraId') { 'and' } else { '-and' }
                $Output = "($($FilterArray_AND)) $($topLevelAnd) ($($FilterArray_OR))"
            }
            elseif ( ($null -ne $FilterArray_AND) -and ($null -eq $FilterArray_OR) )
            {
                $Output = "$($FilterArray_AND)"
            }
            elseif ( ($null -eq $FilterArray_AND) -and ($null -ne $FilterArray_OR) )
            {
                $Output = "$($FilterArray_OR)"
            }

            Write-Verbose -Message "FilterScript: $($Output)"

            # check if the output filter is empty
            if ([String]::IsNullOrEmpty($Output))
            {
                Write-Warning 'No filter conditions were provided; the output filter is empty.'
            }

            # return filter script
            if ($OutputType -eq 'String')
            {
                Write-Output -InputObject (@{ FilterString = "$($Output)" })
            }
            else
            {
                Write-Output -InputObject (@{ FilterScript = [ScriptBlock]::Create( $Output ) })
            }
        }
    }
    catch
    {
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
}
