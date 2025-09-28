#
## basic information:
## |__ This script renames the device to a defined naming convention.
#
## Supported PowerShell versions:
## |__ v5.1
#
## location: all client devices
#
## restrictions:
## |__ Windows workstations
#

# set system parameters
$exit_code = 0

# get script info
$script:MyScriptInfo = Get-Item -Path "$($MyInvocation.MyCommand.Path)"

# set logging parameters
$script:enable_write_logging = $true
$script:LogFilePath          = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\Custom\RenameWorkstation"
$script:LogFileName          = "$($script:MyScriptInfo.BaseName).log"
$script:LogStream            = $null
$script:LogOptionAppend      = $false

###
### FUNCTION: write a log of the script
###
function Write-Logging
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding(DefaultParameterSetName="Default")]

    param(
        [Parameter(Mandatory=$false)]
        [String] $Value = '',

        [Parameter(Mandatory=$false)]
        [String] $Module = '',

        [Parameter(Mandatory=$false)]
        [ValidateScript({$_ -eq -1 -or $_ -match "^\d+$"})]
        [int] $Level = -1,

        [Parameter(Mandatory=$false)]
        [ValidateSet('None', 'Host', 'Warning')]
        [String] $StdOut = 'Host',

        [Parameter(Mandatory=$false)]
        [HashTable] $OptionsSplat = @{}
    )
    
    try
    {
        # set log file path
        $FilePath = "$($script:LogFilePath)"
        If (-Not (Test-Path -Path "$($FilePath)"))
        {
            New-Item -Path "$($FilePath)" -ItemType "Directory" -Force | Out-Null
        }
        
        $File   = Join-Path -Path "$($FilePath)" -ChildPath "$($script:LogFileName)"
        $prefix = ''
        
        # set prefix
        switch ($Level)
        {
            # default level
            -1 { $prefix = '' }
            # root level
            0  { $prefix = '# ' }
            # sub level
            default { $prefix = "$((1..$($Level) | ForEach-Object { "|__" }) -join '') " }
        }
        
        # set log message
        $logMessage = "$($prefix)$($Value)"
        $logDetails = "[$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")] [$($env:computername)] [$($env:UserName)] [$($env:UserDomain)] [$($Module)]"

        # write to stdout
        switch ($StdOut)
        {
            'Host'        { $OptionsSplat['Object'] = "$($logMessage)"; Write-Host @OptionsSplat }
            'Warning'     { $OptionsSplat['Message'] = "$($logMessage)"; Write-Warning @OptionsSplat }
            default       { break }
        }

        # check size of log file
        if (Test-Path -Path "$($File)" -PathType 'Leaf')
        {
            # if max size reached, create new log file
            if ((Get-Item -Path "$($File)").length -gt 10Mb)
            {
                if (-Not ( [string]::IsNullOrEmpty($script:LogStream) ) )
                {
                    $script:LogStream.close()
                    $script:LogStream = $null
                }
            }
        }

        # check if logging is enabled
        if ($script:enable_write_logging)
        {
            # check if file stream exists already
            if ( [string]::IsNullOrEmpty($script:LogStream) )
            {
                $script:LogStream = [System.IO.StreamWriter]::new("$($File)", $script:LogOptionAppend, [Text.Encoding]::UTF8) # path, append, encoding
            }
            
            # write log line
            if (-Not ( [string]::IsNullOrEmpty($script:LogStream) ) )
            {
                $script:LogStream.WriteLine("$($logDetails) $($logMessage)")
            }
            else
            {
                throw "Log stream failed to load"
            }
        }

        # clean-up
        Get-Variable -Name 'FilePath' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
        Get-Variable -Name 'File' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
        Get-Variable -Name 'prefix' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
        Get-Variable -Name 'logMessage' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
        Get-Variable -Name 'logDetails' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
    }
    catch
    {
        Write-Warning -Message "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
}

###
### FUNCTION: set client tls protocols
###
Function Set-ClientTlsProtocols
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding(DefaultParameterSetName="Default")]

    param()
    
    # set function parameters
    try
    {
        # find and include all available protocols 'Tls12' or higher
        $AvailableTls = [enum]::GetValues('Net.SecurityProtocolType') | Where-Object { $_ -ge 'Tls12' }
    
        $AvailableTls.ForEach({
            [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor $_
        })
    }
    catch
    {
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
}

###
### FUNCTION: get logged on users
###
Function Get-LoggedOnUsers
{
    [CmdLetBinding(DefaultParameterSetName="Default")]

    # set function parameters
    $ErrorActionPreference = 'Stop'
    $return_object = [PSCustomObject]@{
        errorcode = -1
        content = @()
    }
    
    try
    {
        Write-Logging -Value "# $($MyInvocation.MyCommand)"
        
        # get query raw output
        $QueryRawData = (&query 'user' | Out-String -Stream)
        
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
        foreach ($line in $QueryRawData | Select-Object -Skip 1)
        {
            # Insert bars on the same positions, and then split the line into separate parts using these bars.
            $fenceIndexes | ForEach-Object { $line = $line.Insert($_, "|") }
            $parts = $line -split '\|' | ForEach-Object { $_.Trim() }
            
            # Parse each part as a strongly typed value, using the UI Culture if needed.
            $return_object.content += [PSCustomObject] @{
                IsCurrent   = ($parts[0] -eq '>')
                Username    = $parts[1]
                SessionName = $parts[2]
                Id          = [int]($parts[3])
                State       = $parts[4]
                IdleTime    = $parts[5] #$(if($parts[5] -ne '.' -and $parts[5] -ne 'none' -and (-not [string]::IsNullOrWhitespace($parts[5]))) { [TimeSpan]::ParseExact($parts[5], $timeSpanFormats, [CultureInfo]::CurrentUICulture) } else { [TimeSpan]::Zero })
                LogonTime   = $parts[6] #[DateTime]::ParseExact($parts[6], "g", [CultureInfo]::CurrentUICulture)
            }
        }
        
        $return_object.errorcode = 0
    }
    catch
    {
        Write-Logging -Value "### ERROR: $($MyInvocation.MyCommand) ###"
        $return_object.errorcode = $($_.Exception.HResult)
        Write-Logging -Value "Message: [$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
        Write-Logging -Value "### ERROR END ###"
    }
    finally
    {
        $ErrorActionPreference = 'Continue' # default value
    }

    return $return_object
}

###
### FUNCTION: invoke device restart
###
Function Invoke-DeviceRestart
{
    [CmdLetBinding(DefaultParameterSetName="Default")]

    # set function parameters
    $ErrorActionPreference = 'Stop'
    $return_object = [PSCustomObject]@{
        errorcode = 0
        content = @()
    }
    
    try
    {
        Write-Logging -Value '--------------------------------------------------'
        Write-Logging -Value "# $($MyInvocation.MyCommand)"
        
        # set function parameters
        $DeviceRebootAllowed = $true
        
        # check if device reboot is allowed
        $LoggedOnUsers = Get-LoggedOnUsers

        if ($LoggedOnUsers.errorcode -eq 0)
        {
            $ActiveUsers = $LoggedOnUsers.content | Where-Object { $_.State -eq 'Active'}
            $ActiveUserCount = ($ActiveUsers | Measure-Object).Count

            if ($ActiveUserCount -ne 0)
            {
                $DeviceRebootAllowed = $false
                Write-Logging -Value "|__ Current logged on user(s): $($ActiveUsers | ConvertTo-Json -Compress)"
            }
        }
        else
        {
            $DeviceRebootAllowed = $false
        }

        Remove-Variable -Name "LoggedOnUsers" -Force

        # restart device
        if ($DeviceRebootAllowed)
        {
            Restart-Computer -Force
            Write-Logging -Value "|__ Device reboot invoked"
        }
        else
        {
            Write-Logging -Value "|__ Device reboot skipped"
        }
    }
    catch
    {
        Write-Logging -Value "### ERROR: $($MyInvocation.MyCommand) ###"
        $return_object.errorcode = $($_.Exception.HResult)
        Write-Logging -Value "Message: [$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
        Write-Logging -Value "### ERROR END ###"
    }
    finally
    {
        $ErrorActionPreference = 'Continue' # default value
    }

    return $return_object
}

###
### MAIN SCRIPT
###
try
{
    $ErrorActionPreference = 'Stop'
    
    Write-Logging -Value '### SCRIPT BEGIN #################################'

    # tell PowerShell to use TLS12 or higher 
    $SystemTlsVersion = [Net.ServicePointManager]::SecurityProtocol
    Set-ClientTlsProtocols | Out-Null

    Write-Logging -Value '--------------------------------------------------'

    # get current device name
    Write-Logging -Value "# Get current device name..."
    $currentDeviceName = "$($env:computername)"
    Write-Logging -Value "|__ Current device name: $($currentDeviceName)"

    # check if current device name matches naming convention
    Write-Logging -Value "# Check if current device name matches naming convention..."
    if ($currentDeviceName -notmatch '^[a-zA-Z]{3}-[a-zA-Z0-9]{7,}$')
    {
        if ($currentDeviceName -match '^[a-zA-Z]{3}-.*$')
        {
            # generate new hostname
            $newDeviceName = "$( $currentDeviceName.Substring(0,3) )-$( Get-CimInstance -ClassName 'Win32_Bios' -Namespace 'root/CIMV2' | Select-Object -ExpandProperty SerialNumber )".ToUpper()
            Write-Logging -Value "|__ New device name: $($newDeviceName)"
            
            # set new hostname
            if ($newDeviceName -match '^[a-zA-Z]{3}-[a-zA-Z0-9]{7,}$')
            {
                Rename-Computer -NewName "$($newDeviceName)" -Restart:$false -Force
                Write-Logging -Value "|__ New device name set successfully"
                Invoke-DeviceRestart | Out-Null
            }
            else
            {
                Write-Logging -Value "|__ New device name doesn't fit naming convention - maybe because of virtual machine or other reasons"
            }
        }
        else
        {
            Write-Logging -Value "|__ Current device name miss location shortcut"
        }
    }
    else
    {
        Write-Logging -Value "|__ Device name already fits naming convention"
    }
    
    Write-Logging -Value '### SCRIPT END ###################################'
}
catch
{
    Write-Logging -Value "### ERROR: MAIN ###"
    $exit_code = $($_.Exception.HResult)
    Write-Logging -Value "Message: [$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    Write-Logging -Value "### ERROR END ###"
}
finally
{
    $ErrorActionPreference = 'Continue' # default value

    # close log stream
    if (-Not ( [string]::IsNullOrEmpty($script:LogStream) ) )
    {
        Write-Logging -Value "Log stream closed"
        $script:LogStream.close()
        $script:LogStream = $null
    }

    # Be nice and set session security protocols back to how we found them.
    [Net.ServicePointManager]::SecurityProtocol = $SystemTlsVersion
}

exit $exit_code