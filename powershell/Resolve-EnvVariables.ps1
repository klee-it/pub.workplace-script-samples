<#
.SYNOPSIS
    Recursively resolves environment and script variable placeholders in input objects.

.DESCRIPTION
    Defines a function that replaces all instances of {{Env:VARNAME}}, {{Script:VARNAME}}, and {{PSScriptRoot}} in strings, arrays, hashtables, and custom objects with their corresponding values. Supports nested and complex objects.

.PARAMETER InputObject
    The object (string, array, hashtable, or PSObject) in which to resolve variable placeholders.

.OUTPUTS
    [PSCustomObject], [System.String], [System.Array], or [System.Collections.Hashtable]
        The input object with all variable placeholders resolved.

.EXAMPLE
    PS> Resolve-EnvVariables -InputObject "Path is {{Env:PATH}}"
    Path is C:\Windows\System32;...

    PS> $obj = [PSCustomObject]@{Path="{{Env:PATH}}"; Home="{{Env:USERPROFILE}}"; Root="{{PSScriptRoot}}"}
    PS> Resolve-EnvVariables -InputObject $obj
    Path : C:\Windows\System32;...
    Home : C:\Users\username
    Root : C:\Workspace\github\...

.NOTES
    Author: klee-it
    PowerShell Version: 5.1, 7.x
#>

###
### FUNCTION: Resolve environment variables in input objects
###
function Resolve-EnvVariables
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding(DefaultParameterSetName = 'Default')]

    param(
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSObject] $InputObject = ''
    )

    function Replace-EnvVariable
    {
        [OutputType([System.String])]
        [CmdLetBinding(DefaultParameterSetName = 'Default')]

        param(
            [Parameter(Mandatory = $false)]
            [System.String] $InputString = '',

            [Parameter(Mandatory = $false)]
            [System.String] $SearchPattern = '\{\{(?:Env|Script):(.*?)\}\}'
        )

        try
        {
            Write-Verbose -Message "Replacing environment variables in input string: $($InputString)"

            if ($InputString -match "$($SearchPattern)")
            {
                $SearchResult = Select-String -InputObject "$($InputString)" -Pattern "$($SearchPattern)" -AllMatches

                foreach ($match in $SearchResult.Matches)
                {
                    $MatchValue = "$($match.value)"
                    $MatchString = "$($match.groups[1])"
                    Write-Verbose -Message "MatchValue: $($MatchValue) - MatchString: $($MatchString)"
        
                    if ($MatchString -eq 'PSScriptRoot')
                    {
                        $EnvPath = $PSScriptRoot
                    }
                    elseif ($MatchValue -match '\{\{Env:(.*?)\}\}')
                    {
                        # $EnvPath = (Get-Item -Path Env:\$MatchString).Value
                        $EnvPath = [Environment]::GetEnvironmentVariable($MatchString)
                    }
                    elseif ($MatchValue -match '\{\{Script:(.*?)\}\}')
                    {
                        $EnvPath = Get-Variable -Name "$($MatchString)" -Scope 'Script' | Select-Object -ExpandProperty Value
                    }
                    else
                    {
                        Write-Error -Message "Unknown environment variable format: $($MatchValue)"
                        continue
                    }
                    $InputString = ($InputString).replace($MatchValue, $EnvPath)
                }
        
                Write-Output -InputObject $InputString
            }
            else
            {
                Write-Verbose -Message 'No environment variables found in input string.'
                Write-Output -InputObject $InputString
            }
        }
        catch
        {
            Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
        }
    }

    try
    {
        if ($null -eq $InputObject)
        {
            Write-Verbose -Message 'InputObject is null, returning empty string.'
            $InputObject = ''
        }
        Write-Verbose -Message "InputObject type: $($InputObject.GetType() | Select-Object FullName, BaseType)"

        # Replace environment variable
        # if ($InputObject -is [System.Management.Automation.PSObject] -or $InputObject -is [System.Management.Automation.PSCustomObject])
        if ($InputObject -is [System.Collections.Hashtable])
        {
            $OutputObject = @{}

            foreach ($item in $InputObject.GetEnumerator())
            {
                $key = $item.Key
                $value = $item.Value

                if ($value -is [System.String])
                {
                    $value = Replace-EnvVariable -InputString "$($value)"
                    Write-Verbose -Message "Environment variable updated for key: $($key)"
                }
                else
                {
                    # Recursively resolve for nested objects/arrays/hashtables
                    $value = Resolve-EnvVariables -InputObject $value
                }

                $OutputObject.Add("$($key)", $value)
            }
        }
        elseif ($InputObject -is [System.Array] -or $InputObject -is [System.Object[]])
        {
            $OutputObject = @()

            foreach ($item in $InputObject)
            {
                if ($item -is [System.String])
                {
                    $OutputObject += Replace-EnvVariable -InputString "$($item)"
                    Write-Verbose -Message 'Environment variable updated in array item'
                }
                else
                {
                    # Recursively resolve for nested objects/arrays/hashtables
                    $OutputObject += Resolve-EnvVariables -InputObject $item
                }
            }
        }
        elseif ($InputObject -is [System.Collections.Generic.List[Object]])
        {
            $OutputObject = New-Object System.Collections.Generic.List[Object]

            foreach ($item in $InputObject)
            {
                if ($item -is [System.String])
                {
                    $OutputObject.Add( (Replace-EnvVariable -InputString "$($item)") )
                    Write-Verbose -Message 'Environment variable updated in list item'
                }
                else
                {
                    # Recursively resolve for nested objects/arrays/hashtables
                    $OutputObject.Add( (Resolve-EnvVariables -InputObject $item) )
                }
            }
        }
        elseif ($InputObject -is [System.String])
        {
            # Handle string input
            $OutputObject = Replace-EnvVariable -InputString "$($InputObject)"
            Write-Verbose -Message 'Environment variable updated in string input'
        }
        elseif ($InputObject -is [System.Management.Automation.PSCustomObject])
        {
            $OutputObject = [PSCustomObject]@{}

            foreach ($element in $InputObject.PSObject.Properties.Name)
            {
                Write-Verbose -Message "Resolving environment variables in element: $($element)"
                
                if ($InputObject.$($element) -is [System.String])
                {
                    Add-Member -InputObject $OutputObject -MemberType 'NoteProperty' -Name "$($element)" -Value ( Replace-EnvVariable -InputString "$($InputObject.$($element))" )
                    Write-Verbose -Message "Element: $($element) - Environment variable updated"
                }
                else
                {
                    # Handle non-string elements (arrays, hashtables, etc.)
                    Add-Member -InputObject $OutputObject -MemberType 'NoteProperty' -Name "$($element)" -Value ( Resolve-EnvVariables -InputObject $InputObject.$($element) )
                }
            }
        }
        else
        {
            Write-Verbose -Message "Unsupported input type: $($InputObject.GetType().FullName). Returning input object as is."
            $OutputObject = $InputObject
        }

        Write-Output -InputObject $OutputObject
    }
    catch
    {
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
}