<#
.SYNOPSIS
    Retrieves information about users currently logged on to the local system.

.DESCRIPTION
    Uses the 'query user' command to gather details about user sessions on the local machine, including username, session name, session ID, state, idle time, and logon time. Handles cases where no users are logged on and parses the output into structured objects.

.OUTPUTS
    [PSCustomObject]
        An object for each logged-on user session.

.EXAMPLE
    PS> Get-LoggedOnUsers

.NOTES
    Author: klee-it
    Compatible with: PowerShell 5.1, 7.x
#>

###
### FUNCTION: get logged on users
###
Function Get-LoggedOnUsers
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding(DefaultParameterSetName="Default")]

    param()

    try
    {
        Write-Verbose -Message 'Get local user sessions...'

        # get query raw output
        $QueryRawData = (& 'C:\WINDOWS\system32\query.exe' 'user' | Out-String -Stream)
        
        # set temp output because nobody is logged on
        if ( [string]::IsNullOrWhitespace($QueryRawData) )
        {
            $QueryRawData = @(
                " USERNAME              SESSIONNAME        ID  STATE   IDLE TIME  LOGON TIME"
                ">temp                  rdp-tcp#33         00  Disc            .  $(Get-Date -format 'dd.MM.yyyy HH:mm')"
            )
        }

        # move "ID" to steps before, because of bigger ID numbers: 2, 22, 222, 2222
        $QueryRawData[0] = $QueryRawData[0].replace('  ID', 'ID  ')
        
        # Take the header text and insert a '|' before the start of every HEADER - although defined as inserting a bar after every 2 or more spaces, or after the space at the start.
        $fencedHeader = $QueryRawData[0] -replace '(^\s|\s{2,})', '$1|'

        # Now get the positions of all bars.
        $fenceIndexes = ($fencedHeader | Select-String '\|' -AllMatches).Matches.Index
        
        # set timespan format for IdleTime
        $timeSpanFormats = [string[]]@("d\+hh\:mm", "h\:mm", "%m")
        
        # go trough the lines
        $outputInfo = @()
        foreach ($line in $QueryRawData | Select-Object -Skip 1)
        {
            # Insert bars on the same positions, and then split the line into separate parts using these bars.
            $fenceIndexes | ForEach-Object { $line = $line.Insert($_, "|") }
            $parts = $line -split '\|' | ForEach-Object { $_.Trim() }
            
            # Parse each part as a strongly typed value, using the UI Culture if needed.
            $outputInfo += [PSCustomObject] @{
                IsCurrent   = ($parts[0] -eq '>')
                Username    = $parts[1]
                SessionName = $parts[2]
                Id          = [int]($parts[3])
                State       = $parts[4]
                IdleTime    = $parts[5] #$(if($parts[5] -ne '.' -and $parts[5] -ne 'none' -and (-not [string]::IsNullOrWhitespace($parts[5]))) { [TimeSpan]::ParseExact($parts[5], $timeSpanFormats, [CultureInfo]::CurrentUICulture) } else { [TimeSpan]::Zero })
                LogonTime   = $parts[6] #[DateTime]::ParseExact($parts[6], "g", [CultureInfo]::CurrentUICulture)
            }
        }

        Write-Verbose -Message "Number of sessions: $(($outputInfo | Measure-Object).Count)"
        Write-Verbose -Message "Session details: $($outputInfo | ConvertTo-Json -Compress)"

        Write-Output -InputObject $outputInfo
    }
    catch
    {
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
}
