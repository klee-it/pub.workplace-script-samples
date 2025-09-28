<#
.SYNOPSIS
    Downloads a file from a specified URI to a local destination.

.DESCRIPTION
    This function downloads a file from a given URI to a specified local destination. 
    It supports both WebClient and WebRequest methods for downloading files and allows 
    additional arguments to be passed for customization.

.PARAMETER Uri
    The URI of the file to download. Supports HTTP, HTTPS, UNC paths, and custom AM-prefixed URIs.

.PARAMETER AdditionalArguments
    A hashtable of additional arguments to customize the download request. Optional.

.PARAMETER Destination
    The local directory where the file will be saved. Must be a valid directory path.

.PARAMETER FileName
    The name of the file to save locally. If not provided, the file name is derived from the URI.

.PARAMETER Method
    The method to use for downloading the file. Valid options are 'WebClient' and 'WebRequest'. Default is 'WebClient'.

.OUTPUTS
    [System.IO.FileInfo]
        Returns the downloaded file as a FileInfo object.

.EXAMPLE
    PS> Invoke-FileDownload -Uri "https://example.com/file.txt" -Destination "C:\Downloads"

    Downloads the file from the specified URI to the C:\Downloads directory.

.EXAMPLE
    PS> Invoke-FileDownload -Uri "https://example.com/file.txt" -Destination "C:\Downloads" -FileName "custom_name.txt"

    Downloads the file from the specified URI and saves it as custom_name.txt in the C:\Downloads directory.

.NOTES
    Author: klee-it
    PowerShell Version: 5.1, 7.x
    Additional information: This function requires internet access for HTTP/HTTPS URIs.
    Dependencies: Set-ClientTlsProtocols
#>

###
### FUNCTION: Invoke file download
###
function Invoke-FileDownload
{
    [OutputType([System.IO.FileInfo])]
    [CmdLetBinding(DefaultParameterSetName = 'Default')]

    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({
                $_ -match '^(http|https)://.*$' -or
                $_ -match '^\\.*' -or
                $_ -match '^[A-Z]?:\\.*' -or
                $_ -match '^file://.*' -or
                $_ -match '^AM_[0-9A-Z_]+:.*'
            })]
        [Uri] $Uri,

        [Parameter(Mandatory = $false)]
        [Hashtable] $AdditionalArguments = @{},

        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path -Path "$($_)" -PathType 'Container' })]
        [String] $Destination,

        [Parameter(Mandatory = $false)]
        [String] $FileName = '',

        [Parameter(Mandatory = $false)]
        [ValidateSet('WebClient', 'WebRequest')]
        [String] $Method = 'WebClient'
    )

    try
    {
        # tell PowerShell to use TLS12 or higher 
        $SystemTlsVersion = [Net.ServicePointManager]::SecurityProtocol
        Set-ClientTlsProtocols
        
        # get the local file name
        if ( [String]::IsNullOrEmpty($FileName) )
        {
            $LocalFileName = Join-Path -Path "$($Destination)" -ChildPath "$([io.path]::GetFileName($Uri))"
        }
        else
        {
            $LocalFileName = Join-Path -Path "$($Destination)" -ChildPath "$($FileName)"
        }

        # check if filename is plausible
        if ( [io.path]::GetFileName($LocalFileName) -notmatch '^[A-Za-z0-9_.-]+\.[A-Za-z0-9]{3,}$' )
        {
            throw 'The file name is empty or invalid.'
        }
        
        # invoke file download
        if ($Method -eq 'WebClient')
        {
            # create web client
            $dlWebClient = New-Object System.Net.WebClient

            # set additional arguments
            if ($AdditionalArguments.ContainsKey('Headers'))
            {
                foreach ($key in $AdditionalArguments['Headers'].Keys)
                {
                    $dlWebClient.Headers.Add($key, $AdditionalArguments['Headers'][$key])
                }
            }
            
            # download file
            $dlWebClient.DownloadFile($Uri, $LocalFileName)
            
            # dispose of web client
            $dlWebClient.Dispose()

            # clean-up
            Get-Variable -Name 'dlWebClient' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
        }
        elseif ($Method -eq 'WebRequest')
        {
            # create web request
            $dlSplat = @{
                Uri             = $Uri
                OutFile         = $LocalFileName
                UseBasicParsing = $true
            }

            # set additional arguments
            if ($AdditionalArguments)
            {
                foreach ($key in $AdditionalArguments.Keys)
                {
                    $dlSplat[$key] = $AdditionalArguments[$key]
                }
            }

            # download file
            Invoke-WebRequest @dlSplat

            # clean-up
            Get-Variable -Name 'dlSplat' -ErrorAction 'SilentlyContinue' | Remove-Variable -Force
        }
        else
        {
            throw "The method '$($Method)' is not supported."
        }

        # return download object
        Write-Output -InputObject ( Get-Item -Path "$($LocalFileName)" )
    }
    catch
    {
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
    finally
    {
        # Be nice and set session security protocols back to how we found them.
        [Net.ServicePointManager]::SecurityProtocol = $SystemTlsVersion
    }
}
