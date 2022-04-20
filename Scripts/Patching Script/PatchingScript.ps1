#===============================================================================
# Name: 	PatchingScript.ps1
# Date: 	11/18/2021
# Author: 	Alex Zajork
# Purpose: 	Provide information about servers during patching. 
#			Reboots servers in selected group.
#===============================================================================


#=============================================================
# Functions
#=============================================================

function Get-PatchGroupSelection{
    $PatchGroups = ($serverList | Select-Object -Property PatchGroup -Unique)
    write-host "`nPatch groups:" 
    $PatchGroups | out-host	
    $patchGroupResponse = Read-Host "`nEnter patch group name"
    $selectedServers = $serverList | Where-Object -Property PatchGroup -eq  $patchGroupResponse 
    return $selectedServers;
}

function Get-ServerUptime
{
    param([string] $computerName)
    try {
        $os = Get-WmiObject Win32_OperatingSystem -computerName $computerName.Trim()
        $boottime = $OS.converttodatetime($OS.LastBootUpTime)
        $timespan = New-TimeSpan (get-date $boottime)  
        $timeElapsed = "D:" + $timespan.Days + " H:" + $timespan.Hours + " M:" + $timespan.Minutes + " S:" + $timespan.Seconds;
        $psObject = [PsCustomObject]@{
            ServerName = $computerName
            BootDateTime = $OS.converttodatetime($OS.LastBootUpTime)
            TimeElapsed = $timeElapsed
        };
        return $psObject;
    }
    catch {
        write-host "Unable to reach server $computerName"
    }
}



#=============================================================
# Import server list
#=============================================================
$serverList = "";
try {
    $serverList = Import-Csv -Path $PSScriptRoot\PatchingScriptServerList.csv;
}
catch {
    Write-Host "Server list was not found. Script is expecting file "  $PSScriptRoot\PatchingScriptServerList.csv -BackgroundColor Red;
    Write-Host "Script exiting.";
    Start-Sleep -Seconds 5;
    Exit;
}


#=============================================================
# Start script
#=============================================================
do{ #loop while continue is Y

    #=============================================================    
    #Task Selection
    #=============================================================
    Write-Host "`nChoose Task`n-----------"
    write-Host "h - Help"
    Write-Host "1 - Take snapshot of Windows service status";
    Write-Host "2 - Stop & disable application services";
    Write-Host "3 - Reboot Servers";
    Write-Host "4 - Check Server Uptime";
    Write-Host "5 - Enable & Start application services";
    Write-Host "6 - (Validation) Compare captured service status with current service status";
    Write-Host "8 - (Validation) Get installed patch list";
    Write-Host "9 - (View Script Configuration) Display servers in patch group";
    Write-Host "0 - Exit";
    $taskResponse = Read-Host "Enter selection"

    #=============================================================
    #Task H - Help
    #=============================================================	
    if($taskResponse.Trim().ToUpper() -eq "H")
    {
        Write-Host "`n"
        Write-Host "Patching Script Help"
        Write-Host "---------------------"
        Write-Host "About"  -BackgroundColor Blue
        Write-Host "This script requres a PatchingScriptServerList.csv file to be located in the same directory as the script. The headers of the csv file must be 'ServerName', 'RebootGroup', and 'PatchGroup'"
        Write-Host "This script was built and tested with WINDOWS PowerShell v5.1. Note that this differs from the .NET Core cross-platform PowerShell implementation.`n`n"

        write-Host "h - Help" -BackgroundColor Blue
        write-host "Displays this help print out.`n"

        Write-Host "1 - Take snapshot of Windows service status" -BackgroundColor Blue
        Write-Host "Captures the service status and service startup type of all services running on the servers in the specified patch group.`n"        

        Write-Host "2 - Stop & disable application services" -BackgroundColor Blue
        Write-Host "Stops application services in the selected patch group. This task will first prompt for selection of a patch group. It will then display a list of services found (in csv) running on servers in the selected patch group. Prompts for confirmation before stopping services. Servers, Services, and PatchGroup comes from the PatchingScriptServiceList.csv file found in the same directory as this script.`n"

        Write-Host "3 - Reboot Servers" -BackgroundColor Blue
        Write-Host "Reboots servers in the selected patch group and reboot group. A list of servers to be rebooted will be shown for confirmation before any reboot commands are issued.`n"
   
        Write-Host "4 - Check Server Uptime" -BackgroundColor Blue
        Write-Host "Returns the time the server was booted as well as elapsed time since server was booted. Can be exported to CSV.`n"

        Write-Host "5 - Enable & Start application services" -BackgroundColor Blue
        Write-Host "Starts application services in the selected patch group. This task will first prompt for selection of a patch group. It will then display a list of services found (in csv) running on servers in the selected patch group. Prompts for confirmation before starting services. Servers, Services, and PatchGroup comes from the PatchingScriptServiceList.csv file found in the same directory as this script.`n"

        Write-Host "6 - (Validation) Compare captured service status with current service status" -BackgroundColor Blue
        Write-Host "Take snapshot of Windows service status must be ran prior to running this task. This task imports the CSV from the prior service status snapshot. It then gets the current service status and compares the two, alerting if any service that was running before is no longer running or any service startup type has changed."
        write-host "In the script root directory there is a PatchingScriptCompareStatusIgnoredServices.csv file. This file can be used to tell the script to ignore changes in Windows services that start and stop automatically. This CSV should have two columns. 1 ServiceName 2 Comments. Comments are optional.`n"

        Write-Host "8 - (Validation) Get installed patch list" -BackgroundColor Blue
        Write-Host "Returns a list of all patches installed on servers in the the selected patch group within the last 7 days. Results can be exported to a CSV.`n"

        Write-Host "9 - (View Script Configuration) Display servers in patch group" -BackgroundColor Blue
        Write-Host "Prints the contents of the patch group as imported from the PatchingScriptServerList csv`n"
    }

	#=============================================================
	# Task 1 - Take snapshot of Windows service status
	#=============================================================
    elseif ($taskResponse -eq 1)
    {
        write-host "`nThis will capture a list of all running services on the servers in the patch group"
        $serverSelection = Get-PatchGroupSelection
        $serverSelection | Out-Host

        write-host "Fetching service status for..."
        $serverServiceStatus = new-object System.Collections.ArrayList;
        foreach ($server in $serverSelection.serverName)
        {
            write-host $server
            $services = $null; #clear for loop
            try {
                $services = Get-Service -ComputerName $server;
                foreach ($service in $services)
                {
                    $PsObject = [PsCustomObject]@{
                        ServerName = $server
                        ServiceName = $service.Name
                        ServiceStatus = $service.Status
                        ServiceStartType = $service.StartType
                    }
                    $serverServiceStatus.Add($PsObject) | out-null;
                }
            }
            catch {
                write-host "Error retrieving service status from server $server" -backgroundColor red;
            }
        }

        #Export results to CSV
        $patchGroupName = $serverSelection | Select-Object -ExpandProperty PatchGroup -Unique;
	    $exportPath = $PSScriptRoot + "\CSV Exports\" + (Get-Date).ToShortDateString().Replace("/","_") + "_" + $patchGroupName + "_ServiceStatus.csv"
	    $serverServiceStatus | Export-Csv -Path $exportPath -NoTypeInformation	
	    Write-Host Exported CSV to $exportPath	
    }

    #=============================================================
    # Task 2 - Stop & disable application services
    #=============================================================
    elseif($taskResponse -eq 2)
    {
        $serviceList = $null;
        try {
            $serviceList = Import-Csv -Path $PSScriptRoot\PatchingScriptServiceList.csv;
        }
        catch {
            Write-Host "Unable to import $PSScriptRoot\PatchingScriptServiceList.csv";
        }

        Write-Host "`nThe following services were found in the PatchingScriptServiceList csv."
        $serviceList | Out-Host;

        #prompt for patch group to stop services on.
        $patchGroupResponse = $null;
        $patchGroupResponse = Read-Host "Enter patch group name to stop services in group";
        $patchGroupResponse = $patchGroupResponse.Trim().ToUpper();

        $selectedServices = $null;
        $selectedServices = $serviceList | Where-Object -Property PatchGroup -eq $patchGroupResponse

        #Show status of all serives in selected reboot group. Prompt for confirmaiton
        write-host "`nWARNING! The following services will be stopped and the startup type set to disabled." -BackgroundColor red;
        $selectedServices | out-host;

        #Confirm action
        $continueResponse = Read-Host "Enter `"STOP`" to continue stopping application services"
        if($continueResponse -ceq "STOP"){
            Write-Host "";
            Write-Host "Stopping application services..." -backgroundColor blue;

            #Stop each service
            foreach($service in $selectedServices){
                Write-Host "Stopping $($service.ServerName) - $($service.ServiceName)"
                try{
                    $svc = (get-service -computerName $service.ServerName -Name $service.ServiceName);                 
                    $svc.Stop();
                    $svc.WaitForStatus("Stopped", '00:00:45'); 
                    
                    $svc | Set-Service -StartupType Disabled

                    write-host "Service stopped and startup type set to Disabled!";
                }
                catch{
                    Write-Host "WARNING! Service did not stop within 45 seconds. May need to force end process." -backgroundColor red;
                }
            }
        }
        else{
            write-host "Canceled. Services will NOT be stopped.";
        }

        #Notify service have stopped. Remind to restart.
    }

	#=============================================================
	# Task 3 - Reboot Servers
	#=============================================================
	elseif ($taskResponse -eq 3){
		write-host "`n*****WARNING**** `nThis action will force reboot all servers in the selected reboot group!`n A list of servers to be rebooted will be presented for confirmation prior to issuing reboot commands" -BackgroundColor RED -ForegroundColor WHITE

        #Prompt for patch group and displays servers in selected patch group
        $patchGroupServers = Get-PatchGroupSelection;
        $patchGroupServers | Out-Host;

        #Prompt for reboot group
        $rebootGroupResponse = Read-Host "Enter reboot group name"
        $rebootGroupResponse = $rebootGroupResponse.Trim().ToUpper();

        #Get the servers in the selected reboot group
        $rebootGroupNames = $patchGroupServers | where-object -property RebootGroup -eq $rebootGroupResponse;
        
        #Print the servers in the selected patch group and reboot group
        write-host "`nThe following servers are in the $patchGroupResponse patch group and the $rebootGroupResponse reboot group. ***** THESE SERVERS WILL BE REBOOTED! DOUBLE CHECK THIS LIST! *****. Enter REBOOT to continue rebooting the selected servers below." -BackgroundColor Red
        $rebootGroupNames | Out-Host

        write-host "Type REBOOT to continue" -backgroundColor RED
        $rebootResponse = read-host

        #Proceed to reboot
        if ($rebootResponse -eq "REBOOT"){
            write-host "`nProceeding to reboot the following servers" -BackgroundColor RED
            $rebootGroupNames | Select-Object -Property ServerName | Out-Host
            foreach($serverToBeRebooted in $rebootGroupNames.ServerName)
            {
                write-host "Rebooting $serverToBeRebooted"
                Restart-Computer -ComputerName $serverToBeRebooted -Force
            }
        }
        else{
            write-host "Invalid selection. Servers will NOT be rebooted."
        }

	}
    
    #=============================================================
    # Task 4 - Check Server Uptime
    #=============================================================
    elseif($taskResponse -eq 4)
    {
        #Prompt for and get servers in selected patch group
        $selectedServers = Get-PatchGroupSelection  
		$serverUptimeList = New-Object System.Collections.ArrayList
        foreach($server in $selectedServers)
        {
            #Get server uptime
            write-host "Getting server uptime - " $server.ServerName   
			$uptime = Get-ServerUptime -computerName $server.ServerName
			$PsObject = [PsCustomObject]@{
				ServerName = $server.ServerName
				BootDateTime = $uptime.BootDateTime
				HoursUptime = $uptime.TimeElapsed
			};
			$serverUptimeList.Add($PsObject) | Out-Null;			
		}
        #Print server uptime
        $serverUptimeList | Format-Table

        #Export to CSV?
        $exportResponse = Read-Host "`nExport results to CSV? (y/n)"
		if ($exportResponse.ToUpper() -eq "Y")
        {
            $patchGroupName = ($selectedServers | Select-Object -ExpandProperty PatchGroup -Unique);
            $exportPath = $PSScriptRoot + "\CSV Exports\" + (Get-Date).ToShortDateString().Replace("/","_") + "_" + $patchGroupName + "_ServerUptime.csv"
			$serverUptimeList | Export-Csv -Path $exportPath -NoTypeInformation	
			Write-Host Exported CSV to $exportPath
        }
    }

	#=============================================================
	# Task 5 - Enable & Start application services
	#=============================================================
    elseif ($taskResponse -eq 5)
    {
        $serviceList = $null;
        try {
            $serviceList = Import-Csv -Path $PSScriptRoot\PatchingScriptServiceList.csv;
        }
        catch {
            Write-Host "Unable to import $PSScriptRoot\PatchingScriptServiceList.csv";
        }

        Write-Host "`nThe following services were found in the PatchingScriptServiceList csv."
        $serviceList | Out-Host;

        #prompt for patch group to stop services on.
        $patchGroupResponse = $null;
        $patchGroupResponse = Read-Host "Enter patch group name to start services in group";
        $patchGroupResponse = $patchGroupResponse.Trim().ToUpper();

        $selectedServices = $null;
        $selectedServices = $serviceList | Where-Object -Property PatchGroup -eq $patchGroupResponse

        #Show status of all serives in selected reboot group. Prompt for confirmaiton
        write-host "`The following services will be started and their StartupType restored." -BackgroundColor red;
        $selectedServices | out-host;

        #Confirm action
        $continueResponse = Read-Host "Enter `"START`" to continue starting application services"
        if($continueResponse -ceq "START"){
            Write-Host "";
            Write-Host "Starting application services..." -backgroundColor blue;

            #Start each service
            foreach($service in $selectedServices){
                Write-Host "Starting $($service.ServerName) - $($service.ServiceName)"
                try{
                    $svc = (get-service -computerName $service.ServerName -Name $service.ServiceName);   
                    $svc | Set-Service -StartupType $service.ServiceStartupType
                    Start-Sleep -Seconds 1
                    $svc.Start();
                    $svc.WaitForStatus("Running", '00:00:45'); 
                    write-host "Service started and startup type reset!";
                }
                catch{
                    Write-Host "WARNING! Service did not start within 45 seconds. You may need to troubleshoot this." -backgroundColor red;
                }
            }
        }
        else{
            write-host "Canceled. Services will NOT be started.";
        }
    }

    #=============================================================
	# Task 6 - (Validation) Compare captured service status with current service status
	#=============================================================
    elseif ($taskResponse -eq 6)
    {
        #Prompt for and get servers in patch group
        $serverSelection = Get-PatchGroupSelection

        #Import previously captured service status
        $capturedServiceStatus = $null; 
        $patchGroupName = $serverSelection | Select-Object -ExpandProperty PatchGroup -Unique;
        $capturedServiceStatusImportPath = $PSScriptRoot + "\CSV Exports\" + (Get-Date).ToShortDateString().Replace("/","_") + "_" + $patchGroupName + "_ServiceStatus.csv";
        try {
            $capturedServiceStatus = Import-Csv -Path $capturedServiceStatusImportPath;
            write-host "Imported $capturedServiceStatusImportPath"
        }
        catch {
            write-host "$capturedServiceStatusImportPath was not found. You must run the capture service status task first." -BackgroundColor Red
        }

        #Import list of services to ignore. These are mainly windows services that start and stop automatically.
        $capturedServicesToIgnore = $null; 
        try {
            $capturedServicesToIgnorePath = $PSScriptRoot + "\PatchingScriptCompareStatusIgnoredServices.csv";
            $capturedServicesToIgnore = Import-Csv -Path $capturedServicesToIgnorePath
            write-host "Imported $capturedServicesToIgnorePath"
        }
        catch {
            write-host "$capturedServicesToIgnorePath  was not found." -BackgroundColor Red
            $capturedServiceStatus = $null; #Prevent us from moving forward with the compare
        }

        if($capturedServiceStatus.Count -gt 0)
        {
            #Get current service status
            $currentServiceStatus = $null;
            $currentServiceStatus = new-object System.Collections.ArrayList;
            write-host "Fetching service status for..."
            foreach ($server in $serverSelection.ServerName)
            {
                write-host $server
                $services = $null; #clear for loop
                try {
                    $services = Get-Service -ComputerName $server;
                    foreach ($service in $services)
                    {
                        $PsObject = [PsCustomObject]@{
                            ServerName = $server
                            ServiceName = $service.Name
                            ServiceStatus = $service.Status
                            ServiceStartType = $service.StartType
                        }
                        $currentServiceStatus.Add($PsObject) | out-null;
                    }        
                }
                catch {
                    write-host "Error retrieving service status from server $server" -BackgroundColor red;
                }
            }

            #Progress update
            Write-Host "Current service status captured. Starting compare..."

            #Iterate through captured services to check current status
            $changedServices = New-Object System.Collections.ArrayList;
            foreach ($record in $capturedServiceStatus)
            {
                #Search for server & service match in currentServerStatus
                $currentService = "";
                $currentService = $currentServiceStatus | where-object {($_.ServerName -eq $record.ServerName) -and ($_.ServiceName -eq $record.ServiceName)}

                if($currentService.Count -eq 0){
                    write-host "Warning, no captured service status found for $record.ServerName - $record.ServiceName"
                }
                else{
                    #Compare service status, service statup type
                    if (($record.serviceStatus -eq $currentService.ServiceStatus) -and ($record.serviceStartType -eq $currentService.ServiceStartType))
                    {
                        #write-host $record.ServerName $record.ServiceName $recrod.ServiceStatus $record.ServiceStartType all match. #Debugging
                        #No action required here. Service status and Service Startup Type match. Yay.
                    }
                    else{
                        #Only alert and if the service that has changed is NOT in the ignored services list
                        if(!$capturedServicesToIgnore.ServiceName.Contains($($record.ServiceName)))
                        {
                            #service status and startup do not match
                            Write-host "warning $($record.ServerName) $($record.ServiceName) was $($record.ServiceStatus) status and set to $($record.ServiceStartType) and is now $($currentService.ServiceStatus) and $($currentService.ServiceStartType)" -backgroundColor red;
                            $psobject = [PsCustomObject]@{
                                ServerName = $record.ServerName
                                ServiceName = $record.ServiceName
                                CapturedServiceStatus = $record.ServiceStatus
                                CapturedServiceStartType = $record.ServiceStartType
                                CurrentServiceStatus = $currentService.ServiceStatus
                                CurrentServiceStartType = $currentService.ServiceStartType
                            };
                            $changedServices.Add($psobject) | Out-Null;
                        }
                    }
                }
            }
            if ($changedServices.Count -eq 0)
            {
                write-host "No change in service status or start type between snapshot and current service status";
            }

            #export CSV
            $exportResponse = Read-Host "`nExport results to CSV? (y/n)"
            if ($exportResponse.Trim().ToUpper() -eq "Y")
            {
                $patchGroupName = $serverSelection | Select-Object -ExpandProperty PatchGroup -Unique;
                $exportPath = $PSScriptRoot + "\CSV Exports\" + (Get-Date).ToShortDateString().Replace("/","_") + "_" + $patchGroupName + "_CompareServiceStatus.csv"
                $changedServices | Export-Csv -Path $exportPath -NoTypeInformation	
                Write-Host Exported CSV to $exportPath
            }
        } #capturedServiceStatus -gt 0
    }

	
	
	#=============================================================
	# Task 8 - (Validation) Get installed patch list
	#=============================================================
	elseif ($taskResponse -eq 8)
    {
        $selectedServers = Get-PatchGroupSelection
		$patchList = New-Object System.Collections.ArrayList
		write-host "`nThis will display any patches installed in the last 7 days."
        foreach($server in $selectedServers)
        {
            write-host "Getting patches - $($server.ServerName)"
            $patches = Get-HotFix -ComputerName $server.ServerName | Where-Object -Property InstalledOn -GT ((Get-Date).AddDays(-7).ToShortDateString())
            foreach($patch in $patches)
            {
                $PsObject = [PsCustomObject]@{
                    ServerName = $patch.PSComputerName
                    Description = $patch.Description
                    HotFixID = $patch.HotFixID
                    InstalledBy = $patch.InstalledBy
                    InstalledOn = $patch.InstalledOn
                };
                $patchList.Add($PsObject) | Out-Null;
            }
        }
        $patchList | Format-Table #print to screen
		
		#export CSV
		$exportResponse = Read-Host "`nExport results to CSV? (y/n)"
		if ($exportResponse.ToUpper() -eq "Y")
		{
            $pachGroupName = $selectedServers | Select-Object -ExpandProperty PatchGroup -Unique;
			$exportPath = $PSScriptRoot + "\CSV Exports\" + (Get-Date).ToShortDateString().Replace("/","_") + "_" + $pachGroupName + "_patches.csv"
			$patchList | Export-Csv -Path $exportPath -NoTypeInformation	
			Write-Host Exported CSV to $exportPath
		}
	}

    #=============================================================
	# Task 9 - (View Script Configuration) Display servers in patch group
	#=============================================================
    elseif ($taskResponse -eq 9)
    {
        $serverSelection = Get-PatchGroupSelection;
        $serverSelection | Format-Table;
    }

    #=============================================================
	# Exit
	#=============================================================
    elseif ($taskResponse -eq 0)
    {
        write-host "`nScript complete."
        exit;
    }
	
	#=============================================================
	# Invalid task selection response
	#=============================================================
    else
    {
        Write-Host "Selection not recognized. Please try again"
    }

	#========================================================================
	# Run script again?
	#========================================================================
	$Continue = Read-Host -Prompt "`nWould you like to run the script again? (y/n)"

} while ($Continue.ToUpper() -eq 'Y')

Write-Host "`nScript complete.`n"