#
## documentation:
## |__ Check and detect available updates
# 
## location: local computer
#
## notes:
## |__ use Chocolatey to check for available updates
#

# set system parameters
$exit_code = 0

# get script info
$script:MyScriptInfo = Get-Item -Path "$($MyInvocation.MyCommand.Path)"

# set logging parameters
$script:enable_write_logging = $true
$script:LogFilePath          = "$($PSScriptRoot)"
$script:LogFileName          = "$($script:MyScriptInfo.BaseName).log"

###
### FUNCTION: write a log of the script
###
Function Write-Logging
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
    Write-Logging -Value '### SCRIPT BEGIN #################################' -Mode 'set'
    $ErrorActionPreference = 'Stop'

    # tell PowerShell to use TLS12 or higher 
    $SystemTlsVersion = [Net.ServicePointManager]::SecurityProtocol
    Set-ClientTlsProtocols | Out-Null

    Write-Logging -Value '--------------------------------------------------'

    # run update by Chocolatey
    try
    {
        # run update by Chocolatey
        Write-Logging -Value "# Run upgrade by Chocolatey..."
        
        $Choco_FullFileName = Get-Command -Name 'choco' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
        #$Choco_FullFileName = "$($env:ChocolateyInstall)"
        #$Choco_FullFileName = 'C:\ProgramData\Chocolatey'
        
        if ( Test-Path -Path "$($Choco_FullFileName)" )
        {
            Write-Logging -Value "|__ Chocolatey source: $($Choco_FullFileName)"

            # list available updates
            Write-Logging -Value "|__ Check and detect available updates..."
            # $updates = choco upgrade all --whatif --confirm
            $ProcessStartInfo = New-Object Diagnostics.ProcessStartInfo
            $ProcessStartInfo.FileName = "$($Choco_FullFileName)"
            $ProcessStartInfo.Arguments = "upgrade all --confirm --whatif"
            $ProcessStartInfo.UseShellExecute = $false
            $ProcessStartInfo.StandardOutputEncoding = [Text.Encoding]::UTF8
            $ProcessStartInfo.RedirectStandardOutput = $true
            $Process = [Diagnostics.Process]::Start($ProcessStartInfo)
            $updates = $Process.StandardOutput.ReadToEnd()
            $Process.WaitForExit()
            Write-Logging -Value "$([Environment]::NewLine)$($updates)"

            # check result if updates are available
            $updatesAvailable = $updates | Select-String -Pattern '.*upgrades available' -Quiet

            # clean-up
            Remove-Variable -Name "ProcessStartInfo"
            Remove-Variable -Name "Process"
            Remove-Variable -Name "updates"
                
            if ($updatesAvailable)
            {
                # updates available
                Write-Logging -Value "|__ Updates available, run upgrade process"
                $ProcessStartInfo = New-Object Diagnostics.ProcessStartInfo
                $ProcessStartInfo.FileName = "$($Choco_FullFileName)"
                $ProcessStartInfo.Arguments = "upgrade all --confirm"
                $ProcessStartInfo.UseShellExecute = $false
                $ProcessStartInfo.StandardOutputEncoding = [Text.Encoding]::UTF8
                $ProcessStartInfo.RedirectStandardOutput = $true
                $Process = [Diagnostics.Process]::Start($ProcessStartInfo)
                $updates = $Process.StandardOutput.ReadToEnd()
                $Process.WaitForExit()
                Write-Logging -Value "$([Environment]::NewLine)$($updates)"

                # clean-up
                Remove-Variable -Name "ProcessStartInfo"
                Remove-Variable -Name "Process"
                Remove-Variable -Name "updates"

                Write-Logging -Value "|__ Chocolatey upgrade done"
            }
            else
            {
                Write-Logging -Value "|__ Update not required"
            }
                
            # clean-up
            Remove-Variable -Name "updatesAvailable" -Force
        }
        else
        {
            Throw "Chocolatey not found"
        }
    }
    catch
    {
        Throw $_
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

    # Be nice and set session security protocols back to how we found them.
    [Net.ServicePointManager]::SecurityProtocol = $SystemTlsVersion
}

exit $exit_code