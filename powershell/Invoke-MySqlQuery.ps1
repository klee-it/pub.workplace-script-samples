<#
.SYNOPSIS
    Executes a MySQL query.

.DESCRIPTION
    This function executes a MySQL query using the provided connection string and query string.
    It returns the result of the query.

.PARAMETER Query
    The SQL query to be executed. This parameter is mandatory.

.PARAMETER ConnectionString
    The connection string to the MySQL database. This parameter is mandatory.

.PARAMETER Driver
    The path to the MySQL Connector/NET driver. This parameter is optional and defaults to "C:\Program Files (x86)\MySQL\MySQL Connector NET 9.1\MySql.Data.dll".

.OUTPUTS
    [System.Management.Automation.PSObject]
        The result of the executed query.

.EXAMPLE
    PS> Invoke-MySqlQuery -Query "SHOW TABLES" -ConnectionString 'server=<fqdn>;user id=<username>;password=<password>;database=<database>;pooling=false'

.NOTES
    Author: klee-it
    PowerShell Version: 5.1, 7.x
    Dependencies: MySQL Connector/NET => https://dev.mysql.com/downloads/connector/net/
#>

###
### FUNCTION: invoke a mysql query
###
function Invoke-MySqlQuery
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding(DefaultParameterSetName="Default")]

    param(
        [Parameter(Mandatory = $True)]
        [String] $Query,
        
        [Parameter(Mandatory = $true)]
        [String] $ConnectionString,

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [String] $Driver = "C:\Program Files (x86)\MySQL\MySQL Connector NET 9.1\MySql.Data.dll"
    )
    
    try
    {
        # Check if the driver file exists
        if (-Not (Test-Path -Path "$($Driver)" -PathType 'Leaf'))
        {
            throw "The driver file does not exist."
        }
        
        # Load the driver
        [Void][System.Reflection.Assembly]::LoadFrom($Driver);

        # Create a connection
        $mySqlConnection = New-Object MySql.Data.MySqlClient.MySqlConnection
        $mySqlConnection.ConnectionString = $ConnectionString
        $mySqlConnection.Open()
        
        # Create a command
        $mySqlCommand = New-Object MySql.Data.MySqlClient.MySqlCommand
        $mySqlCommand.Connection = $mySqlConnection
        $mySqlCommand.CommandText = $Query
        $myExecuteReader = $mySqlCommand.ExecuteReader()

        while($myExecuteReader.Read())
        {
            $myExecuteReader.GetString(0)
        }
        
        # Close the connection
        # $myExecuteReader.Close()
        $mySqlConnection.Close()

        Write-Output -InputObject $myExecuteReader
    }
    catch
    {
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
}
