<#
.SYNOPSIS
    Invokes a Microsoft Graph API request and retrieves all paginated results.

.DESCRIPTION
    This function sends a request to the Microsoft Graph API using the provided parameters and automatically follows pagination links to collect all items across multiple pages. The combined results are returned as a single array.

.PARAMETER InputObject
    A hashtable containing the parameters for the Invoke-MgGraphRequest cmdlet, such as Uri and Method.

.OUTPUTS
    [System.Management.Automation.PSObject]
        Returns an array of objects from all pages of the Graph API response.

.EXAMPLE
    PS> Invoke-MgGraphRequestAllPages -InputObject @{ Uri = "https://graph.microsoft.com/v1.0/users"; Method = "GET" }

    Retrieves all users from Microsoft Graph, handling pagination automatically.

.NOTES
    Author: klee-it
    PowerShell Version: 5.1, 7.x
    Dependencies: Invoke-MgGraphRequest
#>

###
### FUNCTION: Invoke MgGraph request and get all pages
###
function Invoke-MgGraphRequestAllPages
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding(DefaultParameterSetName = 'Default')]

    param(
        [Parameter(Mandatory = $true)]
        [HashTable] $InputObject,

        [Parameter(Mandatory = $false)]
        [ValidateScript( { $_ -ge 0 } )]
        [Int] $WaitTime = 3
    )
    
    # set function parameters
    try
    {
        $WebResult = Invoke-MgGraphRequest @InputObject

        $WebContent = @()
        $WebContent += $WebResult.value
        $WebResult_NextLink = $WebResult.'@odata.nextLink'

        # go through all pages
        while ($WebResult_NextLink -ne $null)
        {
            $InputObject.Uri = "$($WebResult_NextLink)"
            $WebResult = Invoke-MgGraphRequest @InputObject
            
            $WebResult_NextLink = $WebResult.'@odata.nextLink'
            $WebContent += $WebResult.value

            # sleep for a short duration to avoid throttling
            if ($WaitTime -gt 0)
            {
                Start-Sleep -Seconds $WaitTime
            }
        }

        # return all pages
        Write-Output -InputObject $WebContent
    }
    catch
    {
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
}
