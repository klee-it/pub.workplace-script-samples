<#
.SYNOPSIS
    Sends a message to a Microsoft Teams channel using a webhook URL.

.DESCRIPTION
    The Invoke-MsTeamsMessage function posts an Adaptive Card to a Microsoft Teams workflow webhook.

.PARAMETER URL
    The Teams workflow webhook URL (logic.azure.com).

.PARAMETER Message
    Adaptive Card body elements to include in the card.

.OUTPUTS
    [System.Management.Automation.PSObject]
        The response from the Microsoft Teams webhook.

.EXAMPLE
    PS> $MsTeamsSplat = @{
        URL = "https://prod-00.westus.logic.azure.com:443/workflows/abc"
        Message = @(
            [PSCustomObject]@{
                type = "TextBlock"
                text = "**TEST POST**"
                style = "heading"
            }
        )
    }
    PS> Invoke-MsTeamsMessage @MsTeamsSplat
    Sends an Adaptive Card to the Teams workflow webhook.

.NOTES
    Author: klee-it
    PowerShell Version: 7.x
    Documentation: https://learn.microsoft.com/en-us/microsoftteams/platform/webhooks-and-connectors/how-to/connectors-using?tabs=cURL%2Ctext1
#>

###
### FUNCTION: invoke MS Teams message
###
function Invoke-MsTeamsMessage
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding()]

    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({ $_ -match '^https://.+.logic.azure.com:443/workflows/.*' })]
        [String] $URL,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Object[]] $Message
    )

    Write-Verbose -Message 'Create MS Teams message...'

    $requestBody = [PSCustomObject]@{
        type        = 'message'
        attachments = @(
            [PSCustomObject]@{
                contentType = 'application/vnd.microsoft.card.adaptive'
                contentUrl  = $null
                content     = [PSCustomObject]@{
                    '$schema' = 'http://adaptivecards.io/schemas/adaptive-card.json'
                    type      = 'AdaptiveCard'
                    version   = '1.4'
                    body      = $Message
                }
            }
        )
    }
    Write-Verbose -Message "Message: $($requestBody | ConvertTo-Json -Compress -Depth 10)"

    Write-Verbose -Message 'Send MS Teams message...'
    $statusCode = 0
    $webRequestSplat = @{
        Uri                = "$($URL)"
        Method             = 'Post'
        Body               = $($requestBody | ConvertTo-Json -Compress -Depth 10)
        ContentType        = 'application/json'
        SkipHttpErrorCheck = $true
        StatusCodeVariable = 'statusCode'
    }
    Write-Verbose -Message "Splat: $($webRequestSplat | ConvertTo-Json -Compress)"

    $outputInfo = Invoke-RestMethod @webRequestSplat

    if ($statusCode -ge 400)
    {
        throw "Teams request failed: HTTP $($statusCode)"
    }

    Write-Verbose -Message 'MS Teams message sent successfully'
    Write-Output -InputObject $outputInfo
}
