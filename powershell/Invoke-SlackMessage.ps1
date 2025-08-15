<#
.SYNOPSIS
    Sends a message to a Slack channel using a webhook URL or Slack API.

.DESCRIPTION
    This function sends a message to a Slack channel using the specified webhook URL or Slack API. 
    It allows specifying the message content, including images, text blocks, and fact sets.

.PARAMETER Token
    The Slack API token to use for sending the message. This parameter is mandatory when using the Slack API.

.PARAMETER ChannelId
    The ID of the Slack channel to send the message to. This parameter is mandatory when using the Slack API.

.PARAMETER URL
    The webhook URL to use for sending the message. This parameter is mandatory when using the webhook.

.PARAMETER Message
    The message content to be sent. This parameter is mandatory and should be an array of PSCustomObject.

.OUTPUTS
    [System.Management.Automation.PSObject]
        - The response from the Slack webhook or API.

.EXAMPLE
    PS> $SlackSplat = @{
        URL = 'https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX'
        Message = @(
            [PSCustomObject]@{
                type = "Image"
                url = "https://anywebsite.com/image.png"
                height = "30px"
                altText = "Problem report"
            },
            [PSCustomObject]@{
                type = "TextBlock"
                text = "**TEST POST**"
                style = "heading"
            },
            [PSCustomObject]@{
                type = "FactSet"
                facts = @(
                    [PSCustomObject]@{
                        title = "Powershell"
                        value = "is cool"
                    },
                    [PSCustomObject]@{
                        title = "Slack API"
                        value = "is awesome"
                    }
                )
            }
        )
    }
    PS> Invoke-SlackMessage @SlackSplat

.NOTES
    Author: klee-it
    PowerShell Version: 5.1, 7.x
    Documentation:
    - Chat.PostMessage: https://api.slack.com/methods/chat.postMessage
    - Rate Limits: https://api.slack.com/apis/rate-limits
    - List of Errors: https://api.slack.com/methods/chat.postMessage#errors
    Dependencies:
    - App must be installed in the workspace and have the necessary permissions.
    - App must be added to the channel or group where the message will be posted. (Scope: chat.write)
#>

###
### FUNCTION: invoke Slack message
###
Function Invoke-SlackMessage
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding(DefaultParameterSetName="Default")]

    param(
        [Parameter(Mandatory=$True, ParameterSetName="Api")]
        [ValidateScript({$_ -match '^xoxb-[0-9]{11}-[0-9]{13}-[0-9a-zA-Z]{24}$'})]
        [String] $Token,

        [Parameter(Mandatory=$True, ParameterSetName="Api")]
        [ValidateScript({$_ -match '^C[0-9A-Z]{10}$'})]
        [String] $ChannelId,

        [Parameter(Mandatory=$True, ParameterSetName="WebHook")]
        [ValidateScript({$_ -match '^https://hooks.slack.com/services/.*'})]
        [String] $URL,

        [Parameter(Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [Object[]] $Message
    )

    try
    {
        Write-Verbose -Message 'Create Slack message...'

        # create request body
        $requestBody = [PSCustomObject]@{
            "blocks" = @()
        }

        if ($PSCmdlet.ParameterSetName -eq 'Api') {
            $requestBody | Add-Member -MemberType 'NoteProperty' -Name "channel" -Value "$($ChannelId)"
            $requestBody | Add-Member -MemberType 'NoteProperty' -Name "text" -Value "It seems there is a problm with the blocks section - this is the fallback text"
        }

        # create section
        foreach ($Line in $Message)
        {
            $requestBody.blocks += [PSCustomObject]@{
                "type" = "section"
                "text" = [PSCustomObject]@{
                    "type" = "mrkdwn"
                    "text" = "$($Line)"
                }
            }
        }

        Write-Verbose -Message "Message: $($requestBody | ConvertTo-Json -Compress -Depth 10)"

        # post Slack message
        Write-Verbose -Message 'Send Slack message...'
        $webRequestSplat = @{
            Uri         = ''
            Method      = 'Post'
            Body        = $($requestBody | ConvertTo-Json -Compress -Depth 10)
            ContentType = 'application/json'
        }

        if ($PSCmdlet.ParameterSetName -eq 'Api') {
            $webRequestSplat['Uri'] = 'https://slack.com/api/chat.postMessage'
            $webRequestSplat['Headers'] = @{
                'Authorization' = "Bearer $($Token)"
            }
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'WebHook') {
            $webRequestSplat['Uri'] = "$($URL)"
        }

        Write-Verbose -Message "Splat: $($webRequestSplat | ConvertTo-Json -Compress)"
        
        $outputInfo = Invoke-RestMethod @webRequestSplat

        if ($outputInfo.ok -eq $True)
        {
            Write-Verbose -Message 'Slack message sent successfully'
        }
        else
        {
            Write-Warning -Message 'Slack message failed'
        }

        Write-Output -InputObject $outputInfo
    }
    catch
    {
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
}
