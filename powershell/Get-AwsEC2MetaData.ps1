<#
.SYNOPSIS
    Retrieves the AWS EC2 instance metadata using the Instance Metadata Service (IMDS).

.DESCRIPTION
    This function fetches metadata information of an AWS EC2 instance using the Instance Metadata Service (IMDS).
    It supports both IMDSv1 and IMDSv2 protocols. The function attempts to use IMDSv1 first and falls back
    to IMDSv2 if necessary. The metadata is retrieved for the specified sub-URLs and returned as a hashtable.

.PARAMETER BaseUrl
    The base URL for the AWS EC2 instance metadata service. Default is "http://169.254.169.254/latest".

.PARAMETER SubUrls
    An array of sub-URLs for the specific metadata to retrieve. Default is "meta-data/instance-id".

.PARAMETER ImdsVersion
    The version of the Instance Metadata Service to use. Valid values are "IMDSv1" and "IMDSv2".
    Default is "IMDSv1".

.OUTPUTS
    [System.Collections.Hashtable]
        A hashtable containing the metadata information retrieved from the AWS EC2 instance metadata service.

.EXAMPLE
    PS> Get-AwsEC2MetaData
    Name                           Value
    ----                           -----
    http://169.254.169.254/latest/meta-data/instance-id i-00000000000000000

    PS> Get-AwsEC2MetaData -ImdsVersion "IMDSv2"
    Name                           Value
    ----                           -----
    http://169.254.169.254/latest/meta-data/instance-id i-00000000000000000

    PS> Get-AwsEC2MetaData -ImdsVersion "LocalSSM"
    Name                           Value
    ----                           -----
    get-instance-information        @{instanceId=i-00000000000000000; region=us-east-1; accountId=000000000000}

    PS> Get-AwsEC2MetaData -SubUrls @('meta-data/instance-id', 'meta-data/ami-id')
    Name                           Value
    ----                           -----
    http://169.254.169.254/latest/meta-data/instance-id i-00000000000000000
    http://169.254.169.254/latest/meta-data/ami-id ami-00000000000000000

.NOTES
    Author: klee-it
    PowerShell Version: 5.1, 7.x
    Additional information: This function requires the script to be executed on an AWS EC2 instance.
    Metadata Urls:
    - http://169.254.169.254/latest/dynamic/instance-identity/document
#>

###
### FUNCTION: Get AWS EC2 instance metadata
###
function Get-AwsEC2MetaData
{
    [OutputType([System.Collections.Hashtable])]
    [CmdLetBinding(DefaultParameterSetName = 'Default')]

    param (
        [Parameter(Mandatory = $false)]
        [ValidateScript({ $_ -match '^http://' })]
        [String] $BaseUrl = 'http://169.254.169.254/latest',
        
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [String[]] $SubUrls = @('meta-data/instance-id'),

        [Parameter(Mandatory = $false)]
        [ValidateSet('IMDSv1', 'IMDSv2', 'LocalSSM')]
        [String] $ImdsVersion = 'IMDSv1'
    )

    try
    {
        # set output object
        $outputInfo = @{}
        
        foreach ($ApiUrl in $SubUrls)
        {
            # local SSM
            if ($ImdsVersion -eq 'LocalSSM')
            {
                try
                {
                    $outputInfo['get-instance-information'] = & 'C:\Program Files\Amazon\SSM\ssm-cli.exe' get-instance-information
                }
                catch
                {
                    Write-Warning 'Failed to retrieve instance ID using Local SSM.'
                }
            }

            # IMDSv1
            if ($ImdsVersion -eq 'IMDSv1')
            {
                try
                {
                    $requestUri = "$($BaseUrl.TrimEnd('/'))/$($ApiUrl.TrimStart('/'))"
                    $outputInfo["$($requestUri)"] = (New-Object System.Net.WebClient).DownloadString("$($requestUri)")
    
                    # clean-up
                    Get-Variable -Name 'requestUri' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
                }
                catch
                {
                    Write-Warning 'Failed to retrieve instance ID using IMDSv1. Attempting to use IMDSv2.'
                    $ImdsVersion = 'IMDSv2'
                }
            }
        
            # IMDSv2
            if ($ImdsVersion -eq 'IMDSv2')
            {
                try
                {
                    # set urls
                    $requestUri = "$($BaseUrl.TrimEnd('/'))/$($ApiUrl.TrimStart('/'))"
                    $requestApiTokenUri = "$($BaseUrl.TrimEnd('/'))/api/token"
    
                    # get token
                    $ApiToken = Invoke-RestMethod -Headers @{'X-aws-ec2-metadata-token-ttl-seconds' = '21600' } -Method 'PUT' -Uri "$($requestApiTokenUri)"
                    
                    # get metadata information
                    $outputInfo["$($requestUri)"] = Invoke-RestMethod -Headers @{'X-aws-ec2-metadata-token' = "$($ApiToken)" } -Method 'GET' -Uri "$($requestUri)"
    
                    # clean-up
                    Get-Variable -Name 'requestUri' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
                    Get-Variable -Name 'requestApiTokenUri' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
                }
                catch
                {
                    Write-Warning 'Failed to retrieve instance ID using IMDSv2.'
                }
            }
        }

        # return output info
        Write-Output -InputObject $outputInfo

        # clean-up
        Get-Variable -Name 'outputInfo' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
    }
    catch
    {
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
}
