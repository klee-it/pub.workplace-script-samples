<#
.SYNOPSIS
    Sends a message to a Slack channel using a webhook URL or Slack API.

.DESCRIPTION
    The Invoke-SlackMessage function sends a message to a Slack channel using a webhook URL or chat.postMessage.
    Each Message item is posted as a markdown section block.

.PARAMETER Token
    The Slack bot token (xoxb-...). Required for the Api parameter set.

.PARAMETER ChannelId
    The Slack channel ID (for example C0123456789). Required for the Api parameter set.

.PARAMETER URL
    The Slack incoming webhook URL. Required for the WebHook parameter set.

.PARAMETER Message
    The message lines to send. Each item is converted to a markdown section block.

.OUTPUTS
    [System.Management.Automation.PSObject]
        The response from the Slack webhook or API.

.EXAMPLE
    PS> $SlackSplat = @{
        URL     = "https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX"
        Message = @(
            "*TEST POST*"
            "PowerShell is cool"
            "Slack API is awesome"
        )
    }
    PS> Invoke-SlackMessage @SlackSplat
    Sends each string as a Slack markdown section block via webhook.

.EXAMPLE
    PS> Invoke-SlackMessage -URL "https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX" -Message "Hello Slack"
    Sends a webhook message to Slack.

.EXAMPLE
    PS> Invoke-SlackMessage -Token "xoxb-12345678901-1234567890123-abcdefghijklmnopqrstuvwx" -ChannelId "C0123456789" -Message "Hello Slack"
    Sends a chat.postMessage request to Slack.

.NOTES
    Author: klee-it
    PowerShell Version: 7.x
    Documentation:
    - Chat.PostMessage: https://api.slack.com/methods/chat.postMessage
    - Rate Limits: https://api.slack.com/apis/rate-limits
    - List of Errors: https://api.slack.com/methods/chat.postMessage#errors
    Dependencies:
    - App must be installed in the workspace and have the necessary permissions.
    - App must be added to the channel or group where the message will be posted. (Scope: chat:write)
#>

###
### FUNCTION: invoke Slack message
###
function Invoke-SlackMessage
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding(DefaultParameterSetName = 'WebHook')]

    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Api')]
        [ValidateScript({ $_ -match '^xoxb-[0-9]{11}-[0-9]{13}-[0-9a-zA-Z]{24}$' })]
        [String] $Token,

        [Parameter(Mandatory = $true, ParameterSetName = 'Api')]
        [ValidateScript({ $_ -match '^C[0-9A-Z]{10}$' })]
        [String] $ChannelId,

        [Parameter(Mandatory = $true, ParameterSetName = 'WebHook')]
        [ValidateScript({ $_ -match '^https://hooks.slack.com/services/.*' })]
        [String] $URL,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Object[]] $Message
    )

    Write-Verbose -Message 'Create Slack message...'

    $requestBody = [PSCustomObject]@{
        'blocks' = @()
    }

    if ($PSCmdlet.ParameterSetName -eq 'Api')
    {
        $requestBody | Add-Member -MemberType 'NoteProperty' -Name 'channel' -Value "$($ChannelId)"
        $requestBody | Add-Member -MemberType 'NoteProperty' -Name 'text' -Value 'It seems there is a problem with the blocks section - this is the fallback text'
    }

    foreach ($Line in $Message)
    {
        $requestBody.blocks += [PSCustomObject]@{
            'type' = 'section'
            'text' = [PSCustomObject]@{
                'type' = 'mrkdwn'
                'text' = "$($Line)"
            }
        }
    }

    Write-Verbose -Message "Message: $($requestBody | ConvertTo-Json -Compress -Depth 10)"
    Write-Verbose -Message 'Send Slack message...'

    $statusCode = 0
    $webRequestSplat = @{
        Uri                = ''
        Method             = 'Post'
        Body               = $($requestBody | ConvertTo-Json -Compress -Depth 10)
        ContentType        = 'application/json'
        SkipHttpErrorCheck = $true
        StatusCodeVariable = 'statusCode'
    }

    if ($PSCmdlet.ParameterSetName -eq 'Api')
    {
        $webRequestSplat['Uri'] = 'https://slack.com/api/chat.postMessage'
        $webRequestSplat['Headers'] = @{
            'Authorization' = "Bearer $($Token)"
        }
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'WebHook')
    {
        $webRequestSplat['Uri'] = "$($URL)"
    }

    Write-Verbose -Message "Splat: $($webRequestSplat | ConvertTo-Json -Compress)"

    $outputInfo = Invoke-RestMethod @webRequestSplat

    if ($statusCode -ge 400)
    {
        throw "Slack request failed: HTTP $($statusCode)"
    }

    if ($null -ne $outputInfo.ok -and $outputInfo.ok -ne $true)
    {
        if ($outputInfo.error)
        {
            throw "Slack API error: $($outputInfo.error)"
        }

        throw 'Slack message failed'
    }

    Write-Verbose -Message 'Slack message sent successfully'
    Write-Output -InputObject $outputInfo
}
