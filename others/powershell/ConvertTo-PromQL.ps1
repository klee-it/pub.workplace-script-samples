###
### FUNCTION: parse PromQL string
###
function ConvertTo-PromQL
{
    [OutputType([System.Management.Automation.PSObject])]
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
            $MetricHeader = "# HELP $($MetricName) $($MetricHelp).`n# TYPE $($MetricName) $($MetricType)"
            $promqlString = "$($MetricHeader)`n$($promqlString)"
        }

        # add last line break
        $promqlString += "`n"

        # Set the content of the return object
        Write-Output -InputObject $promqlString
    }
    catch
    {
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
}
