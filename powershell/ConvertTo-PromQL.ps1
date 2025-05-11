<#
.SYNOPSIS
    Parses a PromQL string.

.DESCRIPTION
    This function takes various parameters related to a Prometheus metric and generates a PromQL string.
    The PromQL string can be used to query Prometheus metrics.

.PARAMETER MetricName
    The name of the metric. This parameter is mandatory.

.PARAMETER MetricLabels
    The labels associated with the metric. This can be a Hashtable or a PSCustomObject. This parameter is optional.

.PARAMETER MetricValue
    The value of the metric. This parameter is mandatory.

.PARAMETER MetricType
    The type of the metric. Valid values are 'counter', 'gauge', 'histogram', and 'summary'. Default is 'gauge'. This parameter is optional.

.PARAMETER MetricHelp
    The help text for the metric. Default is 'No help available.'. This parameter is optional.

.PARAMETER SkipHeader
    A switch to indicate whether to skip the metric header in the output. Default is false. This parameter is optional.

.OUTPUTS
    [System.String]
        The generated PromQL string.

.EXAMPLE
    ConvertTo-PromQL -MetricName 'http_requests_total' -MetricValue '1027'

.EXAMPLE
    PS> $labels = @{method='get'; code='200'}
    PS> ConvertTo-PromQL -MetricName 'http_requests_total' -MetricLabels $labels -MetricValue '1027'

.NOTES
    Author: klee-it
    PowerShell Version: 5.1, 7.x
#>

###
### FUNCTION: parse PromQL string
###
function ConvertTo-PromQL
{
    [OutputType([System.String])]
    [CmdLetBinding(DefaultParameterSetName="Default")]

    param(
        [Parameter(Mandatory = $True)]
        [String] $MetricName,

        [Parameter(Mandatory = $False)]
        [Object] $MetricLabels = $null,

        [Parameter(Mandatory = $True)]
        [String] $MetricValue,

        [Parameter(Mandatory = $False)]
        [ValidateSet('counter', 'gauge', 'histogram', 'summary')]
        [String] $MetricType = 'gauge',

        [Parameter(Mandatory = $False)]
        [String] $MetricHelp = 'No help available.',

        [Parameter(Mandatory = $False)]
        [Switch] $SkipHeader = $false
    )
    
    try
    {
        # Initialize an empty array to hold the labels
        $labels = @()

        # Check if the input is a Hashtable
        if ($MetricLabels -is [HashTable])
        {
            foreach ($key in $MetricLabels.Keys)
            {
                $labels += "$($key)=`"$($MetricLabels["$($key)"])`""
            }
        }

        # Check if the input is a PSCustomObject
        elseif ($MetricLabels -is [PSCustomObject])
        {
            foreach ($property in $MetricLabels.PSObject.Properties)
            {
                $labels += "$($property.Name)=`"$($property.Value)`""
            }
        }

        # If no labels are provided, just use the metric name and value
        elseif ( [string]::IsNullOrEmpty($MetricLabels) )
        {
            $labels = @()
        }
        else
        {
            throw "Unsupported data type. Please provide a Hashtable, PSCustomObject, or null."
        }

        # Join the labels into a single string
        $labelsString = $labels -join ','

        # Construct the PromQL string
        if ($labelsString)
        {
            $promqlString = "$($MetricName){$($labelsString)} $($MetricValue)"
        }
        else
        {
            $promqlString = "$($MetricName) $($MetricValue)"
        }

        # Add the metric header if SkipHeader is not specified
        if (-Not $SkipHeader)
        {
            $MetricHeader = "# HELP $($MetricName) $( $MetricHelp.TrimEnd('.') ).$([System.Environment]::NewLine)# TYPE $($MetricName) $($MetricType)"
            $promqlString = "$($MetricHeader)$([System.Environment]::NewLine)$($promqlString)"
        }

        # add last line break
        $promqlString += "$([System.Environment]::NewLine)"

        # Set the content of the return object
        Write-Output -InputObject $promqlString
    }
    catch
    {
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
}
