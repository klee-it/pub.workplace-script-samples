<#
.SYNOPSIS
    Retrieves ARGB color values in hex format for specified color names.

.DESCRIPTION
    The Get-ARGBColor function returns ARGB color values in hex format for one or more color names.
    It supports PowerShell 5.1 using [Windows.Media.Colors] and PowerShell 7.x using [System.Drawing.Color].
    The function outputs a custom object containing the color name and its corresponding ARGB value.

.PARAMETER Colors
    An array of color names to retrieve ARGB values for. Defaults to all available colors in the relevant color class.

.OUTPUTS
    [PSCustomObject]
        - ARGB: The ARGB value of the color in hex format.
        - Color: The name of the color.

.EXAMPLE
    PS> Get-ARGBColor -Colors 'Red', 'Blue'
    Returns the ARGB values for Red and Blue.

.NOTES
    Author: klee-it
    PowerShell Version: 5.1, 7.x
#>

###
### FUNCTION: get ARGB color in hex format (PowerShell v5.1)
###
function Get-ARGBColor
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding(DefaultParameterSetName = 'Default')]

    param
    (
        [Parameter(Mandatory = $false)]
        [String[]] $Colors = ( [Windows.Media.Colors] | Get-Member -Static -Type 'Property' | Select-Object -Expand 'Name' )
    )

    try
    {
        # load required assembly
        Add-Type -AssemblyName 'PresentationFramework'

        # get colors
        $outputInfo = @()
        foreach ($ColorName in $Colors)
        {
            Write-Verbose -Message "Getting ARGB value for color '$($ColorName)'"

            $outputInfo += [PSCustomObject]@{
                ARGB  = "$( [Windows.Media.Colors]::$ColorName )"
                Color = $ColorName
            }
        }

        # return output object
        Write-Output -InputObject $outputInfo
    }
    catch
    {
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
}


###
### FUNCTION: get ARGB color in hex format (PowerShell v7.x)
###
function Get-ARGBColor2
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding(DefaultParameterSetName = 'Default')]

    param
    (
        [Parameter(Mandatory = $false)]
        [String[]] $Colors = ( [System.Drawing.Color] | Get-Member -Static -Type 'Property' | Select-Object -Expand 'Name' )
    )

    try
    {
        # load required assembly
        Add-Type -AssemblyName 'PresentationFramework'

        # get colors
        $outputInfo = @()
        foreach ($ColorName in $Colors)
        {
            Write-Verbose -Message "Getting ARGB value for color '$($ColorName)'"

            # $colors = [enum]::GetValues([System.ConsoleColor])
            $outputInfo += [PSCustomObject]@{
                ARGB  = "$( ([System.Drawing.Color]::$ColorName).ToArgb() )"
                Color = $ColorName
            }
        }

        # return output object
        Write-Output -InputObject $outputInfo
    }
    catch
    {
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
}
