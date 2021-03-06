function Add-SqlTable {
    <#
    .Synopsis
        Adds a SQL Table
    .Description
        Creates a new Table in SQL
    
    .Link
        Select-SQL
    .Link
        Update-SQL
    #>
    param(
    # The name of the SQL table
    [Parameter(Mandatory=$true)]
    [string]$TableName,

    # The columns to create within the table
    [Parameter(Mandatory=$true)]
    [string[]]$Column,

    # The keytype to use
    [ValidateSet('Guid', 'Hex', 'SmallHex', 'Sequential', 'Named', 'Parameter')]
    [string]$KeyType  = 'Sequential',

    # The data types of each column
    [string[]]$DataType,
    
    # A connection string or a setting containing a connection string.
    [Parameter(Mandatory=$true)]
    [Alias('ConnectionString', 'ConnectionSetting')]
    [string]$ConnectionStringOrSetting    )

    begin {
        if ($ConnectionStringOrSetting -notlike "*;*") {
            $ConnectionString = Get-SecureSetting -Name $ConnectionStringOrSetting -ValueOnly
        } else {
            $ConnectionString =  $ConnectionStringOrSetting
        }
        if (-not $ConnectionString) {
            throw "No Connection String"
            return
        }
        $sqlConnection = New-Object Data.SqlClient.SqlConnection "$connectionString"
        $sqlConnection.Open()
    }

    process {
        $columnsAndTypes = @()
        $rowKeySqlType = if ($KeyType -ne 'Sequential') {
            "char(100)"
        } else {
            "bigint"
        }
        $columnsAndTypes += "RowKey $rowKeySqlType NOT NULL Unique CLUSTERED"
        $columnsAndTypes +=
            for($i =0; $i -lt $Column.Count; $i++) {
                $columnDataType = 
                    if ($dataType -and $DataType[$i]) {
                        $datatype[$i]
                    } else {
                        "varchar(max)"
                    }
                "`"$($Column[$i])`" $columnDataType"
            }
        $createstatement = "CREATE TABLE $tableName (
    $($ColumnsAndTypes -join (',' + [Environment]::NewLine + "   "))
)"                
        
        $sqlAdapter= New-Object "Data.SqlClient.SqlDataAdapter" ($createStatement, $sqlConnection)
        $sqlAdapter.SelectCommand.CommandTimeout = 0
        $dataSet = New-Object Data.DataSet
        $rowCount = $sqlAdapter.Fill($dataSet)
    }

    end {
         
        if ($sqlConnection) {
            $sqlConnection.Close()
            $sqlConnection.Dispose()
        }
        
    }
}