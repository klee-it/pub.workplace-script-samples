###
### FUNCTION: invoke MS Teams message
###
Function Invoke-MsTeamsMessage
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding(DefaultParameterSetName="Default")]

    param(
        [Parameter(Mandatory=$True)]
        [ValidateScript({$_ -match '^https://.+.logic.azure.com:443/workflows/.*'})]
        [String] $URL,

        [Parameter(Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [Object[]] $Message
    )

    try
    {
        Write-Verbose -Message 'Create MS Teams message...'

        # create request body
        $requestBody = [PSCustomObject]@{
            type = 'message'
            attachments = @(
                [PSCustomObject]@{
                    contentType = 'application/vnd.microsoft.card.adaptive'
                    contentUrl = $null
                    content = [PSCustomObject]@{
                        '$schema' = 'http://adaptivecards.io/schemas/adaptive-card.json'
                        type = 'AdaptiveCard'
                        version = '1.4'
                        body = $Message
                    }
                }
            )
        }
        Write-Verbose -Message "Message: $($requestBody | ConvertTo-Json -Compress -Depth 10)"

        # post MS Teams message
        Write-Verbose -Message 'Send MS Teams message...'
        $webRequestSplat = @{
            Uri         = "$($URL)"
            Method      = 'Post'
            Body        = $($requestBody | ConvertTo-Json -Compress -Depth 10)
            ContentType = 'application/json'
        }
        Write-Verbose -Message "Splat: $($webRequestSplat | ConvertTo-Json -Compress)"
        
        $outputInfo = Invoke-RestMethod @webRequestSplat
        Write-Verbose -Message 'MS Teams message sent successfully'

        Write-Output -InputObject $outputInfo
    }
    catch
    {
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
}
