<#
.SYNOPSIS
    Executes a MS SQL query.

.DESCRIPTION
    This function executes a MS SQL query using the provided connection string and query string.
    It returns the result of the query as a DataTable.

.PARAMETER Query
    The SQL query to be executed. This parameter is mandatory.

.PARAMETER ConnectionString
    The connection string to the MS SQL database. This parameter is mandatory.

.OUTPUTS
    [System.Management.Automation.PSObject]
        The result of the executed query.

.EXAMPLE
    PS> Invoke-MsSqlQuery -Query "SELECT GETDATE()" -ConnectionString "Data Source=<fqdn>; User ID=<username>; Password=<password>; Initial Catalog=<database>"

.NOTES
    Author: klee-it
    PowerShell Version: 5.1, 7.x
#>

###
### FUNCTION: invoke a MS SQL query
###
function Invoke-MsSqlQuery
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding(DefaultParameterSetName = 'Default')]

    param(
        [Parameter(Mandatory = $True)]
        [String] $Query,
        
        [Parameter(Mandatory = $true)]
        [String] $ConnectionString
    )
    
    try
    {
        $sqlConnection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
        $sqlCommand = New-Object System.Data.SqlClient.SqlCommand($Query, $sqlConnection)
        $sqlConnection.Open()

        $sqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter $sqlCommand
        $sqlDataset = New-Object System.Data.DataSet
        $sqlAdapter.Fill($sqlDataset) | Out-Null

        $sqlConnection.Close()
        Write-Output -InputObject $sqlDataset.Tables
    }
    catch
    {
        Write-Error "[$($_.InvocationInfo.ScriptLineNumber)] $($_.Exception.Message)"
    }
}
