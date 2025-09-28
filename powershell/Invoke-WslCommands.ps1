<#
.SYNOPSIS
    Deploys and manages WinGet applications for installation, removal, update checks, and upgrades.

.DESCRIPTION
    This function provides a unified interface for managing WinGet applications. It automatically locates the WinGet executable, checks for the presence of AppInstaller, and supports installing, removing, listing, checking for available updates, and upgrading apps. Progress reporting can be disabled by updating user settings.

.PARAMETER Scope
    Specifies the scope for WinGet operations. Valid values are 'user' or 'machine'. Default is 'user'.

.PARAMETER Install
    Installs the app specified by the Id in AdditionalArguments.

.PARAMETER Removal
    Removes the app specified by the Id in AdditionalArguments.

.PARAMETER Update
    Upgrades all available WinGet apps.

.PARAMETER CheckAvailableUpdates
    Checks for available updates without performing upgrades.

.PARAMETER ListInstalled
    Lists installed WinGet apps.

.PARAMETER DisableProgress
    Disables progress reporting in WinGet by updating user settings.

.PARAMETER AdditionalArguments
    Additional arguments to pass to the WinGet command (e.g., '--id <AppId>').

.OUTPUTS
    [PSCustomObject] with properties:
        Scope            [string] - The scope used for the operation.
        Command          [string] - The WinGet command executed.
        UpdatesAvailable [bool]   - Indicates if updates are available.
        ConsoleOutput    [object] - Output from WinGet command.

.EXAMPLE
    PS> Deploy-WingetApps -Update
    Upgrades all available WinGet apps for the current user.

    PS> Deploy-WingetApps -Scope machine -CheckAvailableUpdates
    Checks for available updates for machine scope.

    PS> Deploy-WingetApps -Install -AdditionalArguments @('--id Microsoft.PowerToys')
    Installs Microsoft PowerToys for the current user.

    PS> Deploy-WingetApps -Removal -AdditionalArguments @('--id Microsoft.PowerToys')
    Removes Microsoft PowerToys for the current user.

    PS> Deploy-WingetApps -ListInstalled
    Lists all installed WinGet apps for the current user.

.NOTES
    Author: klee-it
    PowerShell Version: 5.1, 7.x
    Dependencies: WinGet, AppInstaller
#>

###
### FUNCTION: Manage WinGet apps for installation, removal or available updates and optionally upgrades them
###
function Invoke-WslCommands
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding(DefaultParameterSetName = 'Default')]

    param(
        [Parameter(Mandatory = $false)]
        [Switch] $Version = $false,

        [Parameter(Mandatory = $false)]
        [Switch] $Status = $false,

        [Parameter(Mandatory = $false)]
        [Switch] $ListDistros = $false,

        [Parameter(Mandatory = $false)]
        [Switch] $Update = $false,

        [Parameter(Mandatory = $false)]
        [Object[]] $AdditionalArguments = @()
    )

    function ConvertFrom-WslCliOutput
    {
        [OutputType([System.Management.Automation.PSObject])]
        [CmdLetBinding(DefaultParameterSetName = 'Default')]

        param(
            [Parameter(Mandatory = $false)]
            [String] $InputString = '',

            [Parameter(Mandatory = $false)]
            [Switch] $IsKeyValuePair = $false,

            [Parameter(Mandatory = $false)]
            [Switch] $IsKeyValueList = $false
        )

        try
        {
            # validate input
            if ( [String]::IsNullOrEmpty($InputString) )
            {
                throw 'InputString is null or empty.'
            }

            # create output object
            $outputInfo = [PSCustomObject]@{
                Content    = @()
                RawContent = "$($InputString.Clone().Trim())"
            }

            # split the input string into an array of lines
            $InputObject = $InputString.Clone().Trim().Split("`n")
            Write-Verbose -Message "Input Object Length: $($InputObject.Length)"

            # define how the input should be parsed
            if ($IsKeyValuePair)
            {
                foreach ($line in $InputObject)
                {
                    $lineTrimmed = "$($line)".Trim()
                    Write-Verbose -Message "Line: $($lineTrimmed)"

                    # skip empty lines
                    if ( [String]::IsNullOrEmpty($lineTrimmed) )
                    {
                        continue
                    }

                    if ($lineTrimmed -match '^(?<Key>.+?): (?<Value>.+)$')
                    {
                        $outputInfo.Content += [PSCustomObject]@{
                            Name    = "$($Matches['Key'].Trim())"
                            Version = "$($Matches['Value'].Trim())"
                        }
                    }
                }
            }
            elseif ($IsKeyValueList)
            {
                $outputInfo.Content += [PSCustomObject]@{
                    Name    = "$( $InputObject[0].Trim().TrimEnd(':') )"
                    Version = $InputObject[1..($InputObject.Length - 1)]
                }
            }
            else
            {
                Write-Verbose -Message 'Raw output will be returned'
            }
            
            Write-Output -InputObject $outputInfo

            # clean-up
            Get-Variable -Name 'InputObject' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
        }
        catch
        {
            Write-Warning -Message "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
        }
    }

    function Get-WslExecutable
    {
        [OutputType([System.String])]
        [CmdLetBinding(DefaultParameterSetName = 'Default')]

        param()

        try
        {
            # search for wsl executable
            Write-Verbose -Message 'Search for wsl executable'
            $WslDirectories = @()
            $WslDirectories += "C:\Users\$($Env:USERNAME)\AppData\Local\Microsoft\WindowsApps\wsl.exe"
            $WslDirectories += 'C:\Windows\System32\wsl.exe'
            Write-Verbose -Message "Wsl directories: $($WslDirectories -join ', ')"

            # determine which wsl executable to use
            Write-Verbose -Message 'Determine which wsl executable to use'
            $WslExecutable = $WslDirectories | Where-Object { Test-Path -Path "$($_)" -PathType 'Leaf' } | Select-Object -First 1
            Write-Verbose -Message "Wsl executable: $($WslExecutable)"

            # clean-up
            Get-Variable -Name 'WslDirectories' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force

            # check if Wsl executable is available
            if (-not $WslExecutable)
            {
                throw 'Wsl not found'
            }

            # output wsl executable
            Write-Output -InputObject "$($WslExecutable)"
        }
        catch
        {
            Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
        }
    }

    function Invoke-WslCommand
    {
        [OutputType([System.String])]
        [CmdLetBinding(DefaultParameterSetName = 'Default')]

        param(
            [Parameter(Mandatory = $false)]
            [ValidateScript({ Test-Path -Path "$($_)" -PathType 'Leaf' })]
            [String] $FilePath,

            [Parameter(Mandatory = $false)]
            [Object[]] $AdditionalArguments = @()
        )

        try
        {
            Write-Verbose -Message "File Path: $($FilePath)"
            Write-Verbose -Message "Additional Arguments: $($AdditionalArguments -join ', ')"
            $AdditionalArguments = $AdditionalArguments | Select-Object -Unique
            Write-Verbose -Message "Unique Additional Arguments: $($AdditionalArguments -join ', ')"

            # create splat
            $ProcessStartInfo = New-Object Diagnostics.ProcessStartInfo
            $ProcessStartInfo.FileName = "$($FilePath)"
            $ProcessStartInfo.Arguments = "$($AdditionalArguments -join ' ')"
            $ProcessStartInfo.UseShellExecute = $false
            $ProcessStartInfo.StandardOutputEncoding = [System.Text.Encoding]::Unicode
            $ProcessStartInfo.RedirectStandardOutput = $true

            $Process = [Diagnostics.Process]::Start($ProcessStartInfo)
            
            $ProcessResult = $Process.StandardOutput.ReadToEnd()
            
            $Process.WaitForExit()

            Write-Verbose -Message "Output:$([Environment]::NewLine)$($ProcessResult)"
            Write-Output -InputObject "$($ProcessResult)"

            # clean-up
            Get-Variable -Name 'ProcessStartInfo' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
            Get-Variable -Name 'Process' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
            Get-Variable -Name 'ProcessResult' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
        }
        catch
        {
            Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
        }
    }

    try
    {
        $outputInfo = [PSCustomObject]@{
            Command       = ''
            ConsoleOutput = ''
        }

        # get Wsl excutable
        $WslExecutable = Get-WslExecutable

        Write-Verbose -Message "Run Wsl command (User: $($env:USERNAME))"

        # list versions of WSL modules
        if ($Version)
        {
            Write-Verbose -Message 'List versions'
            $Splat = @{
                FilePath            = "$($WslExecutable)"
                AdditionalArguments = @('--version') + $AdditionalArguments
            }

            $outputInfo.Command = "$($Splat.FilePath) $($Splat.AdditionalArguments -join ' ')"
            $CliOutput = Invoke-WslCommand @Splat
            $outputInfo.ConsoleOutput = ConvertFrom-WslCliOutput -InputString "$($CliOutput)" -IsKeyValuePair
            Get-Variable -Name 'Splat' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
            Get-Variable -Name 'CliOutput' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
        }
        elseif ($Status)
        {
            Write-Verbose -Message 'List status'
            $Splat = @{
                FilePath            = "$($WslExecutable)"
                AdditionalArguments = @('--status') + $AdditionalArguments
            }

            $outputInfo.Command = "$($Splat.FilePath) $($Splat.AdditionalArguments -join ' ')"
            $CliOutput = Invoke-WslCommand @Splat
            $outputInfo.ConsoleOutput = ConvertFrom-WslCliOutput -InputString "$($CliOutput)" -IsKeyValuePair
            Get-Variable -Name 'Splat' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
            Get-Variable -Name 'CliOutput' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
        }
        # list installed WSL distributions
        elseif ($ListDistros)
        {
            Write-Verbose -Message 'List distributions'
            $Splat = @{
                FilePath            = "$($WslExecutable)"
                AdditionalArguments = @('--list') + $AdditionalArguments
            }

            $outputInfo.Command = "$($Splat.FilePath) $($Splat.AdditionalArguments -join ' ')"
            $CliOutput = Invoke-WslCommand @Splat
            $outputInfo.ConsoleOutput = ConvertFrom-WslCliOutput -InputString "$($CliOutput)" -IsKeyValueList
            Get-Variable -Name 'Splat' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
            Get-Variable -Name 'CliOutput' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
        }
        elseif ($Update)
        {
            Write-Verbose -Message 'Run update'
            $Splat = @{
                FilePath            = "$($WslExecutable)"
                AdditionalArguments = @('--update') + $AdditionalArguments
            }

            $outputInfo.Command = "$($Splat.FilePath) $($Splat.AdditionalArguments -join ' ')"
            $CliOutput = Invoke-WslCommand @Splat
            $outputInfo.ConsoleOutput = ConvertFrom-WslCliOutput -InputString "$($CliOutput)"
            Get-Variable -Name 'Splat' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
            Get-Variable -Name 'CliOutput' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
        }
        else
        {
            throw 'No action specified. Use -Version to list available WSL versions.'
        }

        Write-Output -InputObject $outputInfo
    }
    catch
    {
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
    finally
    {
        # clean-up
        Get-Variable -Name 'WslExecutable' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
    }
}
