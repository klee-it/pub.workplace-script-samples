###
### FUNCTION: convert a PSObject to a filter script
###
Function ConvertTo-FilterScript
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding(DefaultParameterSetName="Default")]

    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject] $Filter
    )
    
    try
    {
        # Generate filter script
        Write-Verbose -Message "Generate filter script..."
        if ($Filter)
        {
            $FilterScript = @{}
            
            # filterscript: and
            $FilterArray_AND = $null
            if ($Filter.and)
            {
                $FilterArray_AND = $Filter.and | Foreach-Object {
                    if ( ($_.value -is [Int]) -or ($_.value -is [Int32]) -or ($_.value -is [Int64]) ) #-or ($_.value -is [Boolean]) -or ($_.value -is [bool]) )
                    {
                        "`$_.$($_.property) -$($_.operator) $($_.value)"
                    }
                    else
                    {
                        "`$_.$($_.property) -$($_.operator) '$($_.value)'"
                    }
                }

                $FilterArray_AND = '{0}' -f ( $FilterArray_AND -join " -and " )
            }

            # filterscript: or
            $FilterArray_OR = $null
            if ($Filter.or)
            {
                $FilterArray_OR = $Filter.or | Foreach-Object {
                    if ( ($_.value -is [Int]) -or ($_.value -is [Int32]) -or ($_.value -is [Int64]) ) #-or ($_.value -is [Boolean]) -or ($_.value -is [bool]) )
                    {
                        "`$_.$($_.property) -$($_.operator) $($_.value)"
                    }
                    else
                    {
                        "`$_.$($_.property) -$($_.operator) '$($_.value)'"
                    }
                }

                $FilterArray_OR = '{0}' -f ( $FilterArray_OR -join " -or " )
            }

            # new 'FilterScript' query
            if ( ($FilterArray_AND) -and ($FilterArray_OR) )
            {
                $FilterScript["FilterScript"] = [ScriptBlock]::Create( "($($FilterArray_AND)) -and ($($FilterArray_OR))" )
            }
            elseif ( ($FilterArray_AND) -and (-Not $FilterArray_OR) )
            {
                $FilterScript["FilterScript"] = [ScriptBlock]::Create( "$($FilterArray_AND)" )
            }
            elseif ( (-Not $FilterArray_AND) -and ($FilterArray_OR) )
            {
                $FilterScript["FilterScript"] = [ScriptBlock]::Create( "$($FilterArray_OR)" )
            }

            Write-Verbose -Message "FilterScript: $($FilterScript.Values)"

            # clear variable
            Get-Variable -Name "FilterArray_AND" -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
            Get-Variable -Name "FilterArray_OR" -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
        }
        else
        {
            throw 'Filterscript not defined'
        }

        Get-Variable -Name "Filter" -ErrorAction 'SilentlyContinue' | Remove-Variable -Force

        # return filter script
        Write-Output -InputObject $FilterScript
    }
    catch
    {
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
}
