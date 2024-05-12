#
## basic information:
## |__ This script renames the device to a defined naming convention.
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
    [CmdLetBinding(DefaultParameterSetName="Default")]

    param(
      [Parameter(Mandatory=$false)]
      [String] $Value  = '',

      [Parameter(Mandatory=$false)]
      [ValidateSet('None', 'Error', 'Host', 'Output', 'Warning')]
      [String] $StdOut = 'Host',

      [Parameter(Mandatory=$false)]
      [HashTable] $OptionsSplat = @{}
    )
    
    # set function parameters
    $ErrorActionPreference = 'Stop'
    $return_code = $True
    
    try
    {
        # set log file path
        $FilePath = "$($script:LogFilePath)"
        If (-Not (Test-Path -Path "$($FilePath)"))
        {
            New-Item -Path "$($FilePath)" -ItemType "Directory" -Force | Out-Null
        }
        
        $FileName       = "$($script:LogFileName)"
        $File           = "$($FilePath)\$($FileName)"
        
        $datetime       = "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")"
        $hostname       = "$($env:computername)"
        $username       = "$($env:UserName)"
        $userdomain     = "$($env:UserDomain)"
        
        # write to stdout
        switch ($StdOut)
        {
            'Error'       { $OptionsSplat['Message'] = "$($Value)"; Write-Error @OptionsSplat }
            'Host'        { $OptionsSplat['Object'] = "$($Value)"; Write-Host @OptionsSplat }
            'Output'      { $OptionsSplat['InputObject'] = "$($Value)"; Write-Output @OptionsSplat }
            'Warning'     { $OptionsSplat['Message'] = "$($Value)"; Write-Warning @OptionsSplat }
            default       { break }
        }

        # check size of log file
        if (Test-Path -Path "$($File)" -PathType Leaf)
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
                $script:LogStream.WriteLine("[$datetime] [$hostname] [$username] [$userdomain] $Value")
            }
            else
            {
                throw "Log stream failed to load"
            }
        }
    }
    catch
    {
        Write-Host "### ERROR: $($MyInvocation.MyCommand) ###"
        $return_code = $($_.Exception.HResult)
        Write-Host "Message: [$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
        Write-Host "### ERROR END ###"
        exit $return_code
    }
    finally
    {
        $ErrorActionPreference = 'Continue' # default value
    }

    #return $return_code
}

###
### FUNCTION: set client tls protocols
###
Function Set-ClientTlsProtocols
{
    [CmdLetBinding(DefaultParameterSetName="Default")]
    
    # set function parameters
    $ErrorActionPreference = 'Stop'
    $return_code = $True
    
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
        Write-Logging -Value "### ERROR: $($MyInvocation.MyCommand) ###"
        $return_code = $($_.Exception.HResult)
        Write-Logging -Value "Message: [$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
        Write-Logging -Value "### ERROR END ###"
    }
    finally
    {
        $ErrorActionPreference = 'Continue' # default value
    }

    return $return_code
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
            $newDeviceName = "$( $currentDeviceName.Substring(0,3) )-$( Get-WmiObject -class win32_bios | Select-Object -ExpandProperty SerialNumber )".ToUpper()
            Write-Logging -Value "|__ New device name: $($newDeviceName)"
            
            # set new hostname
            if ($newDeviceName -match '^[a-zA-Z]{3}-[a-zA-Z0-9]{7,}$')
            {
                Rename-Computer -NewName "$($newDeviceName)" -Restart:$false -Force
                Write-Logging -Value "|__ New device name set successfully"
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