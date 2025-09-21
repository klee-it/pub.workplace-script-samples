<#
.SYNOPSIS
    Sends a message to a Microsoft Teams channel using a webhook URL.

.DESCRIPTION
    This function sends a message to a Microsoft Teams channel using the specified webhook URL. 
    It allows specifying the message content, including images, text blocks, and fact sets.

.PARAMETER URL
    The webhook URL to use for sending the message. This parameter is mandatory.

.PARAMETER Message
    The message content to be sent. This parameter is mandatory and should be an array of PSCustomObject.

.OUTPUTS
    [System.Management.Automation.PSObject]
        - The response from the Microsoft Teams webhook.

.EXAMPLE
    PS> $MsTeamsSplat = @{
        URL = 'https://anywebsite.com/webhook'
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
                        title = "MS Teams worflows"
                        value = "is crazy shit"
                    }
                )
            }
        )
    }
    PS> Invoke-MsTeamsMessage @MsTeamsSplat

.NOTES
    Author: klee-it
    PowerShell Version: 5.1, 7.x
    Documentation: https://learn.microsoft.com/en-us/microsoftteams/platform/webhooks-and-connectors/how-to/connectors-using?tabs=cURL%2Ctext1
#>

###
### FUNCTION: invoke MS Teams message
###
function Invoke-MsTeamsMessage
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding(DefaultParameterSetName = 'Default')]

    param(
        [Parameter(Mandatory = $True)]
        [ValidateScript({ $_ -match '^https://.+.logic.azure.com:443/workflows/.*' })]
        [String] $URL,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [Object[]] $Message
    )

    try
    {
        Write-Verbose -Message 'Create MS Teams message...'

        # create request body
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
