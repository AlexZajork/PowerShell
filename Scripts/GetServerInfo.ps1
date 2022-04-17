#================================================================================================= 
# NAME:     	GetServerInfo.ps1
# AUTHOR:  	 	Alex Zajork
# DATE:     	2/3/21
# PURPOSE:		To Gather specific properties from a list of servers
# ================================================================================================

$CSV = import-csv -Path C:\Users\Alex\Desktop\ComputerList.csv;
 
$Computers = $CSV.Name;
$Collection = New-Object System.Collections.ArrayList
foreach($computer in $Computers)
{
    $ComputerName = $computer;
    $OS = ""
    $IP = ""
    $CPU = ""
    $Memory = ""

    $OS = (Invoke-Command -ComputerName $ComputerName -ScriptBlock {(Get-WmiObject Win32_OperatingSystem | select-object Caption)} | Select-Object -Property Caption).Caption
    $IP = (ping -n 1 $ComputerName| Select-String "Reply from").ToString().Split(":")[0].Replace("Reply from ", "")
    $Memory = Invoke-Command -ComputerName $ComputerName -ScriptBlock { (systeminfo | Select-String "Total Physical Memory").ToString().Replace("Total Physical Memory:","").Replace(" ", "") };
    $CPU = Invoke-Command -ComputerName $ComputerName -ScriptBlock { (Get-WmiObject -Class Win32_Processor -ComputerName. | Select-Object -Property Name).Name }
    
    $PsObject = [PsCustomObject]@{
        ComputerName = $ComputerName
        OS = $OS
        IP = $IP
        Memoery = $Memory
        CPU = $CPU[0] + " " + $CPU.Count + " CPUs"
    };

    $Collection.Add($PsObject) | Out-Null;
}
$Collection | Export-Csv C:\Users\Alex\Desktop\ServerInfo.csv -NoTypeInformation