###
### FUNCTION: invoke a MS SQL query
###
# Example:
# |__ Query: "Select getdate()"
# |__ ConnectionString: "Data Source=<fqdn>; User ID=<username>; Password=<password>; Initial Catalog=<database>"

function Invoke-MsSqlQuery
{
    [OutputType([System.Management.Automation.PSObject])]
    [CmdLetBinding(DefaultParameterSetName="Default")]

    param(
        [Parameter(Mandatory = $True)]
        [String] $Query,
        
        [Parameter(Mandatory = $true)]
        [String] $ConnectionString
    )
    
    try
    {
        $sqlConnection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
        $sqlCommand    = New-Object System.Data.SqlClient.SqlCommand($Query, $sqlConnection)
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
