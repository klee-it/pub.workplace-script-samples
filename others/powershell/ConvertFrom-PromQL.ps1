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
        if ($PromQLString -match '# HELP (?<metricHelpName>[^\s]+) (?<metricHelpText>.+)\n# TYPE (?<metricTypeName>[^\s]+) (?<metricTypeValue>[^\s]+)\n(?<metricData>.+)')
        {
            $promQLData.Header.MetricHelpName = $matches['metricHelpName']
            $promQLData.Header.MetricHelpText = $matches['metricHelpText']
            $promQLData.Header.MetricTypeName = $matches['metricTypeName']
            $promQLData.Header.MetricTypeValue = $matches['metricTypeValue']
            $PromQLString = $matches['metricData']
        }

        # Extract metric name, labels, and value
        if ($PromQLString -match '^(?<metricName>[^\{]+)\{(?<metricLabels>[^\}]+)\} (?<metricValue>[^\s]+)$')
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
