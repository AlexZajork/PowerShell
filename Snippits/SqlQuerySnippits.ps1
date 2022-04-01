#================================================================================================= 
# NAME:     	SqlQuerySnippits.ps1
# AUTHOR:  	 	Alex Zajork
# DATE:     	04/01/2022
# PURPOSE:		Examples for how to query MS SQL server from PowerShell
#  				Select Query, Call Stored Procedure, Insert Records.
#=================================================================================================

#========================================================================
# Variables
#========================================================================
[string]$DBServerName = "DatabaseServerNameHere"
[string]$DatabaseName = "DatabaseHere"  
[string]$ConnectionString = "Server={0};Database={1}; Trusted_Connection=True" -f "$DBServerName", "$DatabaseName"
[string]$scriptDirectory = $PSScriptRoot


#==============================
# Execute SQL Query
#==============================
function Get-SqlData
{
	#Returns records in a data set
	Param([string] $SelectQuery )
	$con = New-Object System.Data.SqlClient.SqlConnection
	$con.ConnectionString = $ConnectionString
	$cmd = New-Object System.Data.SqlClient.SqlCommand
	$cmd.CommandText = $SelectQuery
	$cmd.Connection = $con
    $cmd.CommandTimeout = 120 #default is 30
	$da = New-Object System.Data.SqlClient.SqlDataAdapter
	$da.SelectCommand = $cmd
	$ds = New-Object System.Data.DataSet
	$da.Fill($ds, "Table") | Out-Null
	$con.close()
	Return $ds
}
# Use
#-----
$query = "SELECT TOP 100 * FROM TableName"
$ds = Get-SqlData -SelectQuery $query  
$recordCount = $ds.Tables[0].Rows.Count
write-host ("Found " +  $recordCount + " records")
foreach($row in $ds.Tables[0].Rows)


#==============================
# Execute SQL Stored Procedure
#==============================
function Get-SqlDataFromStoredProcedure
{
	Param(
        [string] $equipmentId 
    )
	$con = New-Object System.Data.SqlClient.SqlConnection
	$con.ConnectionString = $ConnectionString
	$cmd = New-Object System.Data.SqlClient.SqlCommand
    $cmd.CommandType = [System.Data.CommandType]'StoredProcedure'
	$cmd.CommandText = 'StoredProcedureNameHere'  
    $cmd.Connection = $con
	#Add Parameters
	$cmd.Parameters.AddWithValue("equipmentId", $equipmentId) | Out-Null
	$da = New-Object System.Data.SqlClient.SqlDataAdapter
	$da.SelectCommand = $cmd
	$ds = New-Object System.Data.DataSet
	$da.Fill($ds, "Table") | Out-Null
	$con.close()
	Return $ds
}
# Use
#-----
$data = Get-SqlDataFromStoredProcedure -equipmentId "3343"
foreach ($row in $data.tables["Table"].rows)
{
	write-host $row.EquipmentName
}




#========================================================================
# Insert Records Into MS SQL DB
#========================================================================
$InsertQuery = "INSERT INTO TableName (Field1, Field2)
                VALUES(@value1, @value2)"			
[int]$numOfRecordsImported = 0
$sqlConn=New-Object System.Data.SqlClient.SQLConnection
$ConnectionString = "Server={0};Database={1};Integrated Security=True;Connect Timeout={2}" -f "$ServerName", "$DatabaseName", 30
$sqlConn.ConnectionString = $ConnectionString
$sqlConn.Open()
$cmd = New-Object system.Data.SqlClient.SqlCommand($InsertQuery,$sqlConn)
for( [int]$Count = 0; $Count -le $CountOfRecordsToInsert; $Count++)
{
	$cmd.Parameters.Clear()
	$cmd.Parameters.AddWithValue("@value1", $List[$Count].Value1)
	$cmd.Parameters.AddWithValue("@value2", $List[$Count].Value1)
	$numOfRowsAffected = $cmd.ExecuteNonQuery()
	$numOfRecordsImported = $numOfRecordsImported + $numOfRowsAffected
}
$sqlConn.Close()
Echo "$numOfRecordsImported records(s) imported."
