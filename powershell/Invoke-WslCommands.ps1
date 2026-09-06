<#
.SYNOPSIS
    Invokes WSL commands to query and manage Windows Subsystem for Linux distributions.

.DESCRIPTION
    This function provides a unified interface for managing WSL commands. It supports querying WSL version, checking WSL status, listing available distributions, performing updates, and passing additional arguments to WSL commands. It includes output parsing capabilities for key-value pairs and lists.

.PARAMETER Version
    Displays the WSL version information.

.PARAMETER Status
    Displays the current WSL status.

.PARAMETER ListDistros
    Lists all available WSL distributions.

.PARAMETER Update
    Performs WSL update operations.

.PARAMETER AdditionalArguments
    Additional arguments to pass to the WSL command.

.OUTPUTS
    [PSCustomObject] with properties:
        Content    [array]  - Parsed content from WSL command output.
        RawContent [string] - Raw output from WSL command.

.EXAMPLE
    PS> Invoke-WslCommands -Version
    Displays WSL version information.

    PS> Invoke-WslCommands -ListDistros
    Lists all available WSL distributions.

    PS> Invoke-WslCommands -Status
    Displays the current WSL status.

    PS> Invoke-WslCommands -Update
    Performs WSL update operations.

.NOTES
    Author: klee-it
    PowerShell Version: 5.1, 7.x
    Dependencies: WSL (Windows Subsystem for Linux)
#>

###
### FUNCTION: Invoke WSL commands to query and manage distributions
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
            $InputObject = $InputString.Clone().Trim().Split( [System.Environment]::NewLine )
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
