#
## basic information:
## |__ This script will check and detect if registry settings are set correctly, if not, it will fix it
# 
## Supported PowerShell versions:
## |__ v5.1
#
## location: Intune
#

# set strict mode
$ErrorActionPreference = 'Stop'

# set system parameters
$exit_code = 0

# get script info
$script:MyScriptInfo = Get-Item -Path "$($MyInvocation.MyCommand.Path)"

# set logging parameters
$script:enable_write_logging = $true
$script:LogFilePath          = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\Custom\Remediations\EnableLongPaths"
$script:LogFileName          = "$($script:MyScriptInfo.BaseName).log"
$script:LogStream            = $null
$script:LogOptionAppend      = $false

# set device parameters
$script:DeviceOSName = Get-CimInstance -ClassName 'Win32_OperatingSystem' | Select-Object -ExpandProperty 'Caption'
$script:DeviceConfig = [PSCustomObject]@{
    RegistrySettings = [PSCustomObject]@{
        skip = $false
        list = @(
            [PSCustomObject]@{ Action = "add"; Description = "Enable long paths"; Path = "HKLM:\\SYSTEM\\CurrentControlSet\\Control\\FileSystem"; Name = "LongPathsEnabled"; Value = 1; Type = "DWORD" }
        )
    }
}

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
### MAIN SCRIPT
###
try
{
    Write-Logging -Value '### SCRIPT BEGIN #################################'
            
    ###
    ### Get system information
    ###
    Write-Logging -Value "Get system information..."
    Write-Logging -Value "Current User: $($env:UserName)"
    Write-Logging -Value "Computername: $($Env:ComputerName)"
    Write-Logging -Value "Firmware Type: $($Env:Firmware_Type)"
    Write-Logging -Value "OS Name: $($script:DeviceOSName)"
    Write-Logging -Value "OS Architecture: $(Get-CimInstance -ClassName 'Win32_OperatingSystem' | Select-Object -ExpandProperty 'OSArchitecture')"
    Write-Logging -Value "OS Install Date: $(Get-CimInstance -ClassName 'Win32_OperatingSystem' | Select-Object -ExpandProperty 'InstallDate')"
    Write-Logging -Value "OS Last Boot: $(Get-CimInstance -ClassName 'Win32_OperatingSystem' | Select-Object -ExpandProperty 'LastBootUpTime')"
    Write-Logging -Value "Time zone: $(Get-TimeZone | Select-Object -ExpandProperty Id)"
    Write-Logging -Value "Is64BitProcess: $([Environment]::Is64BitProcess)"
    Write-Logging -Value "Is64BitOperatingSystem: $([Environment]::Is64BitOperatingSystem)"
    Write-Logging -Value "PowerShell Edition: $($PSVersionTable.PSEdition)"
    Write-Logging -Value "PowerShell Version: $($PSVersionTable.PSVersion)"

    # Registry settings
    if ($DeviceConfig.RegistrySettings.skip -eq $false)
    {
        ###
        ### Set registry settings
        ###
        Write-Logging -Value "# Manage registry settings..."

        foreach ($item in $DeviceConfig.RegistrySettings.list)
        {
            Write-Logging -Value "[$($item.Action)] $($item.Path)"

            # If the registry key exists, proceed with checking registry values
            if (Test-Path -Path "$($item.Path)")
            {
                # Check if the registry key exists
                $regEntryExists = Get-ItemProperty -Path "$($item.Path)" -Name "$($item.Name)" -ErrorAction 'SilentlyContinue'

                # If the registry key exists, fetch its value
                if ($regEntryExists)
                {
                    if ($item.action -eq 'remove')
                    {
                        # If the registry key exists and the action is 'remove', remove the registry entry
                        Remove-ItemProperty -Path "$($item.Path)" -Name "$($item.Name)" | Out-Null
                        Write-Logging -Value "|__ Registry key '$($item.Name)' removed"
                    }
                    else
                    {
                        # If the registry key exists, fetch its current value
                        $currentValue = Get-ItemProperty -Path "$($item.Path)" | Select-Object -ExpandProperty "$($item.Name)" -ErrorAction 'SilentlyContinue'

                        # Check if the registry value matches the required value
                        if ($currentValue -eq $item.Value)
                        {
                            Write-Logging -Value "|__ Registry key '$($item.Name)' exists and matches the required value."
                        }
                        else
                        {
                            # If the current value does not match the required value, update it
                            Set-ItemProperty -Path "$($item.Path)" -Name "$($item.Name)" -Value $item.Value | Out-Null
                            Write-Logging -Value "|__ Registry key '$($item.Name)' updated to the required value '$($item.Value)'"
                        }

                        Get-Variable -Name 'currentValue' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
                    }
                }
                else
                {
                    # If the registry key does not exist, create it
                    if ($item.Action -ne 'remove')
                    {
                        New-ItemProperty -Path "$($item.Path)" -Name "$($item.Name)" -Value $item.Value -PropertyType "$($item.Type)" | Out-Null
                        Write-Logging -Value "|__ Registry key '$($item.Name)' created with the required value '$($item.Value)'"
                    }
                }

                Get-Variable -Name 'regEntryExists' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
            }
            else
            {
                # If the registry key does not exist, create it along with the specified registry entries
                if ($item.Action -ne 'remove')
                {
                    New-Item -Path "$($item.Path)" -Force | Out-Null
                    New-ItemProperty -Path "$($item.Path)" -Name "$($item.Name)" -Value $item.Value -PropertyType "$($item.Type)" | Out-Null
                    Write-Logging -Value "|__ Registry key '$($item.Name)' created with the required value '$($item.Value)'"
                }
            }
        }

        Write-Logging -Value '--------------------------------------------------'
    }

    Write-Logging -Value '### SCRIPT END ###################################'
}
catch
{
    $exit_code = $($_.Exception.HResult)
    Write-Logging -Value "Error: [$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
}
finally
{
    # close log stream
    if (-Not ( [string]::IsNullOrEmpty($script:LogStream) ) )
    {
        Write-Logging -Value "Log stream closed"
        $script:LogStream.close()
        $script:LogStream = $null
    }
}

exit $exit_code
