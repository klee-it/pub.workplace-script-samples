<#
.SYNOPSIS
    Converts a PromQL string into a PowerShell object.

.DESCRIPTION
    This PowerShell function parses a PromQL string and converts it into a PowerShell object. The function extracts the header information (if present) and the metric data, including metric name, labels, and value.

.PARAMETER PromQLString
    The PromQL string to be converted.

.OUTPUTS
    [PSCustomObject]
        - Header: Contains MetricHelpName, MetricHelpText, MetricTypeName, MetricTypeValue.
        - Data: Contains MetricName, MetricLabels, MetricValue.

.EXAMPLE
    PS> ConvertFrom-PromQL -PromQLString '# HELP http_requests_total The total number of HTTP requests.\n# TYPE http_requests_total counter\nhttp_requests_total{method="post",code="200"} 1027'

.NOTES
    Author: klee-it
    PowerShell Version: 5.1, 7.x
#>

###
### FUNCTION: parse PromQL string
###
function ConvertFrom-PromQL
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding(DefaultParameterSetName="Default")]

    param(
        [Parameter(Mandatory = $True)]
        [String] $PromQLString
    )
    
    try
    {
        $promQLData = [PSCustomObject]@{
            Header = [PSCustomObject]@{
                MetricHelpName = $null
                MetricHelpText = $null
                MetricTypeName = $null
                MetricTypeValue = $null
            }
            Data = [PSCustomObject]@{
                MetricName = $null
                MetricLabels = $null
                MetricValue = $null
            }
        }
        
        # Extract the header if present
        if ($PromQLString -match "# HELP (?<metricHelpName>[^\s]+) (?<metricHelpText>.+)$([System.Environment]::NewLine)# TYPE (?<metricTypeName>[^\s]+) (?<metricTypeValue>[^\s]+)$([System.Environment]::NewLine)(?<metricData>.+)")
        {
            $promQLData.Header.MetricHelpName = $matches['metricHelpName']
            $promQLData.Header.MetricHelpText = $matches['metricHelpText']
            $promQLData.Header.MetricTypeName = $matches['metricTypeName']
            $promQLData.Header.MetricTypeValue = $matches['metricTypeValue']
            $PromQLString = $matches['metricData']
        }

        # Extract metric name, labels, and value
        if ($PromQLString -match '^(?!\W)(?<metricName>[^\{]+)\{(?<metricLabels>[^\}]+)\} (?<metricValue>[^\s]+)$')
        {
            $promQLData.Data.MetricName = $matches['metricName']
            $labelsString = $matches['metricLabels']
            $promQLData.Data.MetricValue = $matches['metricValue']

            # Parse labels into a hashtable
            $labels = @{}
            foreach ( $label in ($labelsString -split ',') )
            {
                if ($label -match '^(?<key>[^=]+)="(?<value>[^"]+)"$')
                {
                    $labels[$matches['key']] = $matches['value']
                }
            }
            $promQLData.Data.MetricLabels = $labels
        }
        # Extract metric name and value
        elseif ($PromQLString -match '^(?<metricName>[^\s]+) (?<metricValue>[^\s]+)$')
        {
            $promQLData.Data.MetricName = $matches['metricName']
            $promQLData.Data.MetricLabels = $null
            $promQLData.Data.MetricValue = $matches['metricValue']
        }
        else
        {
            throw "Invalid PromQL string format"
        }

        # Set the content of the return object
        Write-Output -InputObject $promQLData
    }
    catch
    {
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
}
