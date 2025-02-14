```powershell
###
### FUNCTION: invoke Slack message
### |_ App must be installed in the workspace and have the necessary permissions.
### |_ App must be added to the channel or group where the message will be posted. (Scope: chat.write)
### |_ Option 1: Incoming WebHooks
### |_ Option 2: Slack API (chat.postMessage)
### |_|_ chat.postMessage: https://api.slack.com/methods/chat.postMessage
### |_|_ rate limits: https://api.slack.com/apis/rate-limits
### |_|_ list of errors: https://api.slack.com/methods/chat.postMessage#errors
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
```