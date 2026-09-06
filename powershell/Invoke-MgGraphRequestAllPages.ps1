<#
.SYNOPSIS
    Invoke a Microsoft Graph API request and retrieve all results across paginated responses.

.DESCRIPTION
    Sends a Microsoft Graph API request using the provided input hashtable parameters and retrieves all pages of results, combining them into a single array. Supports client-driven pagination using $top and $skip as well as server-driven pagination with @odata.nextLink. Provides safeguards against infinite loops and options to insert delay between requests to prevent throttling.

.PARAMETER InputObject
    Hashtable of parameters for Invoke-MgGraphRequest (e.g. Uri, Method, Headers).

.PARAMETER WaitTime
    Number of seconds to wait between paginated requests. Default: 0.

.PARAMETER MaxPages
    Maximum number of pages to retrieve before stopping. Default: 10000.

.PARAMETER UseClientDrivenPagination
    If present, use $top/$skip for pagination instead of relying on server-driven @odata.nextLink.

.PARAMETER StopOnMaxPages
    If present, throw an error when max pages is reached; otherwise just warn and exit.

.PARAMETER IsNested
    Switch. Used internally for recursion/nested invocation. Default: $false.

.OUTPUTS
    [System.Management.Automation.PSObject[]]
    Array of results aggregated from all pages.

.EXAMPLE
    PS> Invoke-MgGraphRequestAllPages -InputObject @{ Uri = 'https://graph.microsoft.com/v1.0/users'; Method = 'GET' }

    Gets all users from Microsoft Graph, automatically handling paging to retrieve all results.

.NOTES
    Author   : klee-it
    PowerShell: 5.1, 7+
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
        [Int] $WaitTime = 0,

        [Parameter(Mandatory = $false)]
        [ValidateScript( { $_ -ge 0 } )]
        [Int] $MaxPages = 10000, # safety guard to prevent infinite loops in case of unexpected API behavior

        [Parameter(Mandatory = $false)]
        [Switch] $UseClientDrivenPagination = $false,

        [Parameter(Mandatory = $false)]
        [Switch] $StopOnMaxPages = $false,

        [Parameter(Mandatory = $false)]
        [Switch] $IsNested = $false
    )

    try
    {
        $requestObject = $InputObject.Clone()
        $webContent = [System.Collections.Generic.List[Object]]::new()

        if ($UseClientDrivenPagination)
        {
            $queryTop = 100
            $querySkip = 0
            $paginationExitReason = 'maxPages'

            for ($i = 0; $i -lt $MaxPages; $i++)
            {
                $newRequestObject = $requestObject.Clone()
                $querySeparator = if ($newRequestObject.Uri -match '\?') { '&' } else { '?' }
                $newRequestObject.Uri = "$($newRequestObject.Uri)$($querySeparator)`$top=$($queryTop)&`$skip=$($querySkip)"
                $webResult = Invoke-MgGraphRequest @newRequestObject
                Write-Verbose "Total count: $($webResult.'@odata.count')"
                Get-Variable -Name 'querySeparator' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
                Get-Variable -Name 'newRequestObject' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force

                # no results found
                if (@($webResult.value).Count -eq 0) { $paginationExitReason = 'empty'; break }

                # add results to the web content
                $webContent.AddRange(@($webResult.value)) | Out-Null
                Write-Verbose "Processed count: $($webContent.Count)"

                # update the query skip
                $querySkip += $queryTop

                # last page reached
                if (@($webResult.value).Count -lt $queryTop) { $paginationExitReason = 'complete'; break }

                # sleep for a short duration to avoid throttling
                if ($WaitTime -gt 0) { Start-Sleep -Seconds $WaitTime }
            }

            if ($paginationExitReason -eq 'maxPages')
            {
                if ($webResult.'@odata.count' -and $webContent.Count -lt $webResult.'@odata.count')
                {
                    Write-Warning "Collected $($webContent.Count) of $($webResult.'@odata.count') reported items."
                }

                if ($StopOnMaxPages )
                {
                    throw "Client-driven pagination stopped after $($MaxPages) pages ($($webContent.Count) items). Results may be incomplete."
                }
                else
                {
                    Write-Warning -Message "Client-driven pagination stopped after $($MaxPages) pages ($($webContent.Count) items). Results may be incomplete."
                }
            }
        }
        else
        {
            $webResult = Invoke-MgGraphRequest @requestObject
            Write-Verbose "Total count: $($webResult.'@odata.count')"

            $webContent.AddRange(@($webResult.value)) | Out-Null
            Write-Verbose "Processed count: $($webContent.Count)"

            $webResult_NextLink = "$($webResult.'@odata.nextLink')"
            $webResult_PreviousLink = "$($requestObject.Uri)"
            $pageIndex = 0
            $visitedUris = [System.Collections.Generic.HashSet[string]]::new( [System.StringComparer]::OrdinalIgnoreCase )
            [void]$visitedUris.Add($requestObject.Uri)

            # go through all pages
            while ([String]::IsNullOrEmpty($webResult_NextLink) -eq $false)
            {
                $pageIndex++
                if ($pageIndex -ge $MaxPages)
                {
                    if ($StopOnMaxPages )
                    {
                        throw "Pagination stopped after $($MaxPages) pages to avoid infinite loop."
                    }
                    else
                    {
                        Write-Warning -Message "Pagination stopped after $($MaxPages) pages to avoid infinite loop."
                        break
                    }
                }

                if ($webResult_NextLink -eq $webResult_PreviousLink)
                {
                    if ($StopOnMaxPages )
                    {
                        throw 'Next link is the same as previous link. Stopping pagination to avoid infinite loop.'
                    }
                    else
                    {
                        Write-Warning -Message 'Next link is the same as previous link. Stopping pagination to avoid infinite loop.'
                        break
                    }
                }
                else
                {
                    Write-Verbose "Next link: $($webResult_NextLink)"
                }

                # check if the next link has already been visited
                if ($visitedUris.Contains($webResult_NextLink))
                {
                    if ($StopOnMaxPages )
                    {
                        throw 'Next link has already been visited. Stopping pagination to avoid infinite loop.'
                    }
                    else
                    {
                        Write-Warning -Message 'Next link has already been visited. Stopping pagination to avoid infinite loop.'
                        break
                    }
                }
                [void]$visitedUris.Add($webResult_NextLink)

                # update the request object
                $requestObject.Uri = "$($webResult_NextLink)"

                # invoke the next link
                $webResult = Invoke-MgGraphRequest @requestObject

                # update the previous link
                $webResult_PreviousLink = "$($requestObject.Uri)"
                $webResult_NextLink = "$($webResult.'@odata.nextLink')"
                $webContent.AddRange(@($webResult.value)) | Out-Null
                Write-Verbose "Processed count: $($webContent.Count)"

                # sleep for a short duration to avoid throttling
                if ($WaitTime -gt 0) { Start-Sleep -Seconds $WaitTime }
            }
        }

        # return all pages
        Write-Output -InputObject $webContent.ToArray()
    }
    catch
    {
        if ( ($IsNested -eq $false) -and ($_.Exception.Message -like '*Too many retries performed.*') )
        {

            Write-Warning -Message 'Too many retries performed. Waiting for 5 minutes and retrying...'
            Start-Sleep -Seconds 300
            # retry from the beginning
            Write-Output -InputObject (Invoke-MgGraphRequestAllPages -InputObject $InputObject -WaitTime $WaitTime -MaxPages $MaxPages -UseClientDrivenPagination:$UseClientDrivenPagination -StopOnMaxPages:$StopOnMaxPages -IsNested)
        }
        else
        {
            Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
        }
    }
}
