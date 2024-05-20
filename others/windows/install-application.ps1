# Basic information
# |__ Version: 2024-05-17
# |__ Command: powershell.exe -NoLogo -WindowStyle Hidden -ExecutionPolicy ByPass -File ".\install-application.ps1"
# Example json file
# {
#     "_version": "2024-05-17",
#     "application": {
#         "display_name": "Google Chrome",
#         "version": "87.0.4280.88",
#         "install_path": [
#             "C:\\Program Files\\Google\\Chrome\\Application",
#             "C:\\Program Files (x86)\\Google\\Chrome\\Application"
#         ],
#         "exec_name": "chrome.exe",
#         "registry_name": "",
#         "registry_exclusion_name": "",
#         "registry_exclusion_uninstall_string": ""
#     },
#     "setup": {
#         "file": "ChromeSetup.exe",
#         "arguments": [
#             "/silent",
#             "/install"
#         ],
#         "parameters": {
#             "Wait": true,
#             "NoNewWindow": true
#         },
#         "sleep": "no"
#     },
#     "setup_parameter": {
#         "check_other_installation": "yes",
#         "check_other_installation_by": "file", # file / file+version / folder / registry
#         "replace_other_installation": "no"
#     },
#     "pre_setup": {
#         "enabled": "no",
#         "file": "pre-script.cmd",
#         "arguments": "",
#         "parameters": {
#             "Wait": true,
#             "NoNewWindow": true
#         },
#         "sleep": "no"
#     },
#     "post_setup": {
#         "enabled": "no",
#         "file": "post-script.cmd",
#         "arguments": "",
#         "parameters": {
#             "Wait": true,
#             "NoNewWindow": true
#         },
#         "sleep": "no"
#     }
# }

# set system parameters
$exit_code = 0

# set logging parameters
$script:enable_write_logging = $true
$script:LogFilePath     = "$($env:ProgramData)\Custom\$($script:MyScriptInfo.BaseName)"
$script:LogFileName     = "$($script:MyScriptInfo.BaseName).log"

# set configuration parameters
$script:ConfigFilePath  = "$($PSScriptRoot)"
$script:ConfigFileName  = "$($script:MyScriptInfo.BaseName).json"
$script:ConfigObject    = {}

# set installation parameters
$script:RunPreSetup             = $false
$script:RunSetup                = $false
$script:RunPostSetup            = $false

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
      [String] $Mode   = 'add',
      
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
            if ((Get-Item -Path "$($File)").length -gt 10mb)
            {
                $Mode = "set"
            }
        }

        # check if logging is enabled
        if ($script:enable_write_logging)
        {
            switch ($Mode) {
                # create new logfile with the value
                "set" { Set-Content -Path "$($File)" -Value "[$datetime] [$hostname] [$username] [$userdomain] $Value" -Encoding 'UTF8'; break }
                # add existing value
                "add" { Add-Content -Path "$($File)" -Value "[$datetime] [$hostname] [$username] [$userdomain] $Value" -Encoding 'UTF8'; break }
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
### FUNCTION: write system details log
###
function Invoke-SystemDetailsLog
{
    [CmdLetBinding(DefaultParameterSetName="Default")]
    
    # set function parameters
    $ErrorActionPreference = 'Stop'
    $return_code = 0
    
    try
    {
        # Write-Logging -Value '--------------------------------------------------'
        # Write-Logging -Value "### $($MyInvocation.MyCommand) ###"
        
        # set system details object
        $SystemDetails = [PSCustomObject]@{
            PowerShellVersion       = "$($PSVersionTable.PSVersion)"
            PowerShellEdition       = "$($PSVersionTable.PSEdition)"
            Is64BitProcess          = [Environment]::Is64BitProcess
            Is64BitOperatingSystem  = [Environment]::Is64BitOperatingSystem
            RuntimeUser             = "$([System.Security.Principal.WindowsIdentity]::GetCurrent() | Select-Object -ExpandProperty Name)"
            LastBootDateTime        = Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object -ExpandProperty LastBootUpTime
            LastBootUpTime          = $null
            ComputerInfo            = $null
            OsType                  = $null
        }

        # PowerShell v7
        if ($PSVersionTable.PSEdition -eq 'Core' -and $PSVersionTable.PSVersion.major -ge 7)
        {
            $SystemDetails.LastBootUpTime = Get-Uptime
            $SystemDetails.ComputerInfo = Get-ComputerInfo
            $SystemDetails.OsType = $PSVersionTable.OS
        }

        Write-Logging -Value "System Details: $($SystemDetails | ConvertTo-Json -Depth 3 -Compress)" -StdOut 'None'
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
### FUNCTION: read configuration file
###
function Import-Configuration
{
    if (Test-Path -Path "$($script:ConfigFilePath)\$($script:ConfigFileName)")
    {
        # convert from json to powershell object
        $script:ConfigObject = Get-Content -Path "$($script:ConfigFilePath)\$($script:ConfigFileName)" -Encoding UTF8 | ConvertFrom-Json
        Write-Logging -Value "Import of configuration file successfully completed"

        # Replace environment variable in configuration
        Update-EnvVariables

        # Write-Host ($script:ConfigObject | ConvertTo-Json)
    }
    else
    {
        Write-Logging -Value "Config doesn't exist: $($script:ConfigFilePath)\$($script:ConfigFileName)"
    }
}

###
### FUNCTION: replace environment variables from config
###
function Update-EnvVariables
{
    # Replace environment variable
    if ($script:ConfigObject)
    {
        foreach ($element in $script:ConfigObject.psobject.properties.name)
        {
            foreach ($field in $script:ConfigObject.$($element).psobject.properties.name)
            {
                # Write-Logging -Value "Element: $($element) - Field: $($field)"
                
                if ($script:ConfigObject.$($element).$($field) -like '*$($Env:*)*')
                {
                    $SearchResult = Select-String -InputObject "$($script:ConfigObject.$($element).$($field))" -Pattern '\$\((.*?)\)' -AllMatches
                    
                    foreach ($match in $SearchResult.Matches)
                    {
                        $MatchValue = "$($match.value)"
                        $MatchString = "$($match.groups[1])"
                        # Write-host "MatchValue: $($MatchValue)"
                        # Write-host "MatchString: $($MatchString)"
                        
                        $EnvVariable = $MatchString.split(':')[1]
                        $EnvPath = (Get-Item -Path Env:\$EnvVariable).Value
                        $script:ConfigObject.$($element).$($field) = ($script:ConfigObject.$($element).$($field)).replace($MatchValue, $EnvPath)
                    }
                    Write-Logging -Value "Element: $($element) - Field: $($field) - Environment variable updated"
                }
            }
        }

        Write-Logging -Value "Update environment variables in configuration file successfully completed"
    }
    else
    {
        Write-Logging -Value "Config import missing"
    }
}

###
### FUNCTION: Get status of application installation
###
function Get-ApplicationStatus
{
    try
    {
        $ErrorActionPreference = 'Stop'

        # set parameter
        $OtherInstallationExists = $false

        # check if other installation exists
        if ($script:ConfigObject.setup_parameter.check_other_installation -eq 'yes')
        {
            Write-Logging -Value "[$($script:ConfigObject.application.display_name)] Check if other installation exists"
            
            # check other installation by ...
            switch -Wildcard ($script:ConfigObject.setup_parameter.check_other_installation_by)
            {
                "file*" {
                    Write-Logging -Value "[$($script:ConfigObject.application.display_name)] check other installation by: file*"
                    
                    # check if application is already installed
                    foreach ($install_path in $script:ConfigObject.application.install_path)
                    {
                        Write-Logging -Value "[$($script:ConfigObject.application.display_name)] check other installation by path: $($install_path)\$($script:ConfigObject.application.exec_name)"

                        if (Test-Path -Path "$($install_path)\$($script:ConfigObject.application.exec_name)" -PathType Leaf)
                        {
                            Write-Logging -Value "[$($script:ConfigObject.application.display_name)] Application file already exist"

                            if ($script:ConfigObject.setup_parameter.check_other_installation_by -eq 'file+version')
                            {
                                $CurrentItem = Get-Item -Path "$($install_path)\$($script:ConfigObject.application.exec_name)"
                                [Version]$CurrentItem_version = "$($CurrentItem.VersionInfo.FileVersion -replace '[\D]', '.')"
                                [Version]$NewItem_version = "$($script:ConfigObject.application.version -replace '[\D]', '.')"
                                
                                Write-Logging -Value "[$($script:ConfigObject.application.display_name)] Current application version: '$($CurrentItem_version)' ($($CurrentItem.VersionInfo.FileVersion))"
                                Write-Logging -Value "[$($script:ConfigObject.application.display_name)] New application version: '$($NewItem_version)' ($($script:ConfigObject.application.version))"

                                if ( $CurrentItem_version -ge $NewItem_version )
                                {
                                    Write-Logging -Value "[$($script:ConfigObject.application.display_name)] Current application version '$($CurrentItem_version)' is newer or equal to setup file '$($NewItem_version)'"
                                    $OtherInstallationExists = $true
                                    break
                                }

                                Remove-Variable -Name "CurrentItem"
                                Remove-Variable -Name "CurrentItem_version"
                                Remove-Variable -Name "NewItem_version"
                            }
                            else {
                                $OtherInstallationExists = $true
                            }
                            break
                        }
                    };
                    break
                }
                "folder" {
                    Write-Logging -Value "[$($script:ConfigObject.application.display_name)] check other installation by: folder"
                    
                    # check if application is already installed
                    foreach ($install_path in $script:ConfigObject.application.install_path)
                    {
                        if (Test-Path -Path "$($install_path)" -PathType Container)
                        {
                            Write-Logging -Value "[$($script:ConfigObject.application.display_name)] Application directory already exist"
                            $OtherInstallationExists = $true
                            break
                        }
                    };
                    break
                }
                "registry" {
                    Write-Logging -Value "[$($script:ConfigObject.application.display_name)] check other installation by: registry"
                    
                    # check if application is already installed
                    $LatestVersion = [Version]"$($script:ConfigObject.application.version -replace '[\D]', '.')"
                    $MinVersion = ([Version]"$($script:ConfigObject.application.version -replace '[\D]', '.')").Major

                    Write-Logging -Value "[$($script:ConfigObject.application.display_name)] Registry based detection: $($script:ConfigObject.application.registry_name) - v$($LatestVersion)"
                    Write-Logging -Value "[$($script:ConfigObject.application.display_name)] Collecting installed applications from registry..."
                    $ReadRegistry = Get-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction 'SilentlyContinue' | Select-Object DisplayName, DisplayVersion, Publisher, InstallDate, VersionMajor, VersionMinor, PSChildName, UninstallString, InstallLocation
                    $ReadRegistry += Get-ItemProperty -Path 'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction 'SilentlyContinue' | Select-Object DisplayName, DisplayVersion, Publisher, InstallDate, VersionMajor, VersionMinor, PSChildName, UninstallString, InstallLocation
                    $ReadRegistry += Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction 'SilentlyContinue' | Select-Object DisplayName, DisplayVersion, Publisher, InstallDate, VersionMajor, VersionMinor, PSChildName, UninstallString, InstallLocation
                    Write-Logging -Value "[$($script:ConfigObject.application.display_name)] RegInfo pulled-in, starting comparisons "

                    ### set basic filter script
                    $FilterScript = { $_.DisplayName -like "$($script:ConfigObject.application.registry_name)" -and ($_.VersionMajor -ge $MinVersion -or $_.VersionMajor -eq $null ) }
                    
                    ### filter by appname exclusion
                    if (-Not ( [string]::IsNullOrWhiteSpace("$($script:ConfigObject.application.registry_exclusion_name)") ) )
                    {
                        Write-Logging -Value "[$($script:ConfigObject.application.display_name)] AppName exclusion variable specified: $($script:ConfigObject.application.registry_exclusion_name)"

                        $FilterScript = [ScriptBlock]::Create($FilterScript.ToString() + ' -and $_.DisplayName -notlike "$($script:ConfigObject.application.registry_exclusion_name)"')
                    }

                    ### filter by uninstall string exclusion
                    if (-Not ( [string]::IsNullOrWhiteSpace("$($script:ConfigObject.application.registry_exclusion_uninstall_string)") ) )
                    {
                        Write-Logging -Value "[$($script:ConfigObject.application.display_name)] UninstallString exclusion variable specified: $($script:ConfigObject.application.registry_exclusion_uninstall_string)"

                        $FilterScript = [ScriptBlock]::Create($FilterScript.ToString() + ' -and $_.UninstallString -notlike "$($script:ConfigObject.application.registry_exclusion_uninstall_string)"')
                    }

                    $LocalAppInfo = $ReadRegistry | Where-Object -FilterScript $FilterScript
                    Write-Logging -Value "[$($script:ConfigObject.application.display_name)] Number of installed applications: $( ($LocalAppInfo | Measure-Object).Count )"

                    # if application is installed check version
                    if ( ($LocalAppInfo | Measure-Object).Count -le 0 )
                    { 
                        Write-Logging -Value "[$($script:ConfigObject.application.display_name)] Specified application: $($script:ConfigObject.application.registry_name) is either invalid or application is not installed"
                        $OtherInstallationExists = $false
                    }
                    elseif ( ($LocalAppInfo | Measure-Object).Count -eq 1 )
                    {
                        # we assign comparable value through [System.Version] parameter to all object in array and sort them by latest version being on top
                        $ActualVersion = [Version]"$($LocalAppInfo.DisplayVersion -replace '[\D]', '.')"

                        # more blabla to log, trust me, you'll need it for tests
                        Write-Logging -Value "[$($script:ConfigObject.application.display_name)] Local installed application name: '$($LocalAppInfo.DisplayName)' with version: '$($LocalAppInfo.DisplayVersion)'"

                        If ($ActualVersion -ge $LatestVersion)
                        {
                            Write-Logging -Value "[$($script:ConfigObject.application.display_name)] Client version: $($ActualVersion), Pushed version: $($LatestVersion)"
                            Write-Logging -Value "[$($script:ConfigObject.application.display_name)] Update not required due to client having newer version OR its the same"
                            $OtherInstallationExists = $true
                        }
                        else
                        { 
                            Write-Logging -Value "[$($script:ConfigObject.application.display_name)] Actual version: $($ActualVersion), Compared version: $($LatestVersion)"
                            Write-Logging -Value "[$($script:ConfigObject.application.display_name)] Update for $($LocalAppInfo.DisplayName) required, updating to version $($LatestVersion)"
                            $OtherInstallationExists = $false
                        }

                        Remove-Variable -Name "ActualVersion"
                    }
                    else
                    { 
                        Write-Logging -Value "[$($script:ConfigObject.application.display_name)] Too many applications found: $($LocalAppInfo.DisplayName -join ' / ')"
                        $OtherInstallationExists = $true
                    }
                    
                    Remove-Variable -Name "LocalAppInfo"
                    Remove-Variable -Name "FilterScript"
                    Remove-Variable -Name "ReadRegistry"
                    Remove-Variable -Name "MinVersion"
                    Remove-Variable -Name "LatestVersion";
                    break
                }
                default {
                    Write-Logging -Value "[$($script:ConfigObject.application.display_name)] Value to check other installation not supported: $($script:ConfigObject.setup_parameter.check_other_installation_by)";
                    break
                }
            }
        }

        # check if existing installation should be replaced
        if ( ($script:ConfigObject.setup_parameter.replace_other_installation -eq "no") -And ($OtherInstallationExists -eq $true) )
        {
            Write-Logging -Value "[$($script:ConfigObject.application.display_name)] Application replacement not allowed"
            $script:RunPreSetup = $false
        }
        else
        {
            Write-Logging -Value "[$($script:ConfigObject.application.display_name)] Application replacement allowed, continue with setup"
            $script:RunPreSetup = $true
        }
    }
    catch
    {
        Write-Logging -Value "### ERROR: $($MyInvocation.MyCommand) ###"
        Write-Logging -Value "Message: [$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
        Write-Logging -Value "### ERROR END ###"
    }
    finally
    {
        $ErrorActionPreference = 'Continue' # default value
    }
}

###
### FUNCTION: Install Application
###
function Install-Application
{
    param(
      [Parameter(Mandatory=$true)] [String] $Mode
    )
        
    try
    {
        $ErrorActionPreference = 'Stop'

        # set setup file parameters
        $SetupFile = $script:ConfigObject.$($Mode).file
        $SetupFile_Ext = $SetupFile.split(".")[-1]
        $SetupArguments = $script:ConfigObject.$($Mode).arguments
        $SetupParameters = $script:ConfigObject.$($Mode).parameters
        $SetupSleep = $script:ConfigObject.$($Mode).sleep
        
        # set start process parameters
        $StartProcessSplat = @{
            FilePath = ''
            ArgumentList = @()
        }
        $SetupParameters.PsObject.Properties | ForEach-Object {$StartProcessSplat[$_.Name] = $_.Value }

        # set sleep parameter
        $StartSleep = 30 #seconds

        # check if setup file path corresponds to Powershell execution path
        if ($SetupFile.substring(0,3) -notlike '*:\' -and $SetupFile.substring(0,2) -ne '.\')
        {
            switch ( $SetupFile_Ext )
            {
                "msi" { break }
                default {
                    $SetupFile = "$($PSScriptRoot)\$($SetupFile)"
                    break
                }
            }
        }

        Write-Logging -Value "[$($script:ConfigObject.application.display_name)] [$($SetupFile_Ext)] Installation [$Mode] will be started: $($SetupFile)"

        # check setup file extension and set file path and arguments
        switch ( $SetupFile_Ext )
        {
            "msi" {
                $StartProcessSplat["FilePath"] = 'msiexec.exe'
                $StartProcessSplat["ArgumentList"] += "/i `"$($SetupFile)`""
                $StartProcessSplat["ArgumentList"] += $SetupArguments
                break
            }
            "ps1" {
                $StartProcessSplat["FilePath"] = "$($Env:SystemRoot)\system32\WindowsPowerShell\v1.0\powershell.exe"
                $StartProcessSplat["ArgumentList"] += "-ExecutionPolicy ByPass"
                $StartProcessSplat["ArgumentList"] += "-File `"$($SetupFile)`""
                break
            }
            default { 
                Write-Logging -Value "[$($script:ConfigObject.application.display_name)] [$($SetupFile_Ext)] Use default installation"
                $StartProcessSplat["FilePath"] = "$($SetupFile)"
                $StartProcessSplat["ArgumentList"] += $SetupArguments
                break
            }
        }

        # remove argument list if empty
        if ( [string]::IsNullOrEmpty($StartProcessSplat["ArgumentList"]) )
        {
            $StartProcessSplat.Remove("ArgumentList")
        }

        # start installation of setup file
        if ($StartProcessSplat["FilePath"])
        {
            Write-Logging -Value "[$($script:ConfigObject.application.display_name)] Start process with paramter list: $($StartProcessSplat | ConvertTo-Json -Depth 3 -Compress)"
            Write-Logging -Value "[$($script:ConfigObject.application.display_name)] Start process with paramter list"
            Start-Process @StartProcessSplat

            # check if script should sleep after installation
            if ($SetupSleep -eq 'yes')
            {
                Write-Logging -Value "[$($script:ConfigObject.application.display_name)] Sleep for $($StartSleep) seconds"
                Start-Sleep -Seconds $StartSleep
            }

            switch ($Mode)
            {
                "pre_setup" {
                    $script:RunSetup = $true
                    break
                }
                "setup" {
                    $script:RunPostSetup = $true
                    break
                }
                "post_setup" {
                    break
                }
                default {
                    break
                }
            }
            
        }
    }
    catch
    {
        Write-Logging -Value "### ERROR: $($MyInvocation.MyCommand) ###"
        Write-Logging -Value "Message: [$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
        Write-Logging -Value "### ERROR END ###"
    }
    finally
    {
        $ErrorActionPreference = 'Continue' # default value
    }
}

###
### MAIN SCRIPT
###
try
{
    $ErrorActionPreference = 'Stop'

    # import configuration
    Import-Configuration

    Write-Logging -Value "[$($script:ConfigObject.application.display_name)] ### SCRIPT BEGIN #################################"
    Write-Logging -Value "[$($script:ConfigObject.application.display_name)] Json version: $($script:ConfigObject._version)"

    # get system detail log
    Invoke-SystemDetailsLog | Out-Null

    # check if other installation exists
    Get-ApplicationStatus
    
    # run pre-setup
    if ($script:RunPreSetup)
    {
        # check pre setup is enabled ...
        if ($script:ConfigObject.pre_setup.enabled -eq 'yes')
        {
            Write-Logging -Value "[$($script:ConfigObject.application.display_name)] Start with Pre-Setup"
            Install-Application -Mode 'pre_setup'
        }
        else
        {
            $script:RunSetup = $true
        }
    }

    # run setup
    if ($script:RunSetup)
    {
        Write-Logging -Value "[$($script:ConfigObject.application.display_name)] Start with Setup"
        Install-Application -Mode 'setup'
    }
    
    # run post-setup
    if ($script:RunPostSetup)
    {
        # check post setup is enabled ...
        if ($script:ConfigObject.post_setup.enabled -eq 'yes')
        {
            Write-Logging -Value "[$($script:ConfigObject.application.display_name)] Start with Post-Setup"
            Install-Application -Mode 'post_setup'
        }
    }

    Write-Logging -Value "[$($script:ConfigObject.application.display_name)] ### SCRIPT END ###################################"
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
}

exit $exit_code