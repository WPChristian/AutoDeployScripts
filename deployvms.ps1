#. "C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\vim.psc1"
. "C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts\Initialize-PowerCLIEnvironment.ps1"

## Functions 

function GetLargestDStore {

	#Get's a list of datastores and excludes based on matches of "Name1" etc. Only gets free space and datastore Name
	$datastores = get-datastore | where {$_.Name -notmatch "Name1|Name2|Name3"} | select Name,FreeSpaceMB

	#Sets some static info
	$LargestFreeSpace = "0"
	$LargestDatastore = $null

	#Performs the calculation of which datastore has most free space
	foreach ($datastore in $datastores) {
		if ($Datastore.FreeSpaceMB -gt $LargestFreeSpace) {	
				$LargestFreeSpace = $Datastore.FreeSpaceMB
				$LargestDatastore = $Datastore.name
		}
	}

#Writes out the result to the PowerShell Console		
	write-host "$LargestDatastore is the largest store with $LargestFreeSpace MB Free"
	return $LargestDatastore
}

function PowerONDevices {

	param ($devices)
	
	$prompt = Read-Host "Would you like to power-on all devices or a single device at a time? `n[Please enter yes, no, or single]"
	
	if ($prompt -match "yes") {
	
		Start-VM -VM $devices
	
	}
	elseif ($prompt -match "no") {
	
		break
	
	}
	elseif ($prompt -match "single") {
	
		foreach ($device in $devices) {
		
			$PowerOn = Read-Host "Would you like to Power On $device? `n[Please enter yes or no]"
			
			if ($PowerOn -match "yes") {
			
				Start-VM -VM $device
			}
			elseif ($PowerOn -match "no") {
			
				break
			
			}
			else {
			
				Write-Host "Please enter either yes or no"
			}
		}
	}
}


$VCenterHost = "vc-prd-chi-01"

$User = Read-Host "Please enter your vCenter Username"

$Pass = Read-Host -assecurestring "Please enter your vCenter Password"

Write-Host -NoNewline "Connecting to VSphere Server...`n"
#Connect-VIServer vc-prd-chi-01 -User $User -Password $Pass -ErrorAction SilentlyContinue -WarningAction SilentlyContinue |out-null
#if(!$?){
#    Write-Host -ForegroundColor Red " Could not connect to $VCenterHost"
#    exit 2
#}
#else{
   Write-Host "Successfully connected to server.`n"
#}




## Define the variables to use
$VMHost = Get-VMHost -Name vms-dev-ast-06.trustwave.com
$VDSwitch = Get-VDSwitch -Name Test-Env-VDSwitch

# Portgroup to reserve mirror ports
$HoldPortgroup = Get-VDPortgroup -Name "Switch-Holder"

# WAN Network Adapter for router to use
$WANPortgroup = Get-VDPortgroup -Name "Switch-Holder"

$Switchholder = Get-VM -Name Switch-Holder
$HoldAdapters = Get-NetworkAdapter -VM $Switchholder

# Get the user's name and create a unique ID
$Owner = Read-Host "Please enter your first initial and last name without spaces"

# Set the amount of clients to deploy

$MaxDevices = 5
[int]$Win7Count = Read-Host "Please enter the number of Windows 7 clients to deploy"

while($Win7Count -gt $MaxDevices){ 
	[int]$Win7Count = Read-Host "Please enter a number less than $MaxDevices"
}

$ID = Get-Random -Minimum 99 -Maximum 999

$RootFolder = Get-Folder -Name NAC-Test-Env-Clean

Write-Host "Creating your environment folder...`n"

$EnvFolder = $RootFolder | New-Folder -Name "$Owner-$ID"

Write-Host "Successfully created your folder: $EnvFolder`n"



## Define VM Names and Templates to Use
$SensorName = ($SensorTemplate = Get-Template -Name _TEMPLATE_-nacsnsr-4.3) -replace "_TEMPLATE_", "$Owner-$ID"
$CMName = ($CMTemplate = Get-Template -Name _TEMPLATE_-naccm-4.3) -replace "_TEMPLATE_", "$Owner-$ID"
$WinCientName = ($WinTemplate = Get-Template -Name _TEMPLATE_-win7-x64-client) -replace "_TEMPLATE_", "$Owner-$ID"
$RouterName = ($RouterTemplate = Get-Template -Name _TEMPLATE_-centos64_x64-router) -replace "_TEMPLATE_", "$Owner-$ID"

# Authentication Servers 
$DomainControllerName = ($DomainControllerTemplate = Get-Template -Name _TEMPLATE_-WindowsServer2012_R2_x64-Auther) -replace "_TEMPLATE_", "$Owner-$ID"

## Create the VMs
Write-Host "Identifying largest datastore..."
$Datastore = GetLargestDStore
Write-Host "Creating Your VMs...`n"
$Sensor = New-VM -VMHost $VMHost -Name $SensorName -Template $SensorTemplate -Location $EnvFolder -Datastore $Datastore
$Datastore = GetLargestDStore
$CM = New-VM -VMHost $VMHost -Name $CMName -Template $CMTemplate -Location $EnvFolder -Datastore $Datastore

$WinClients = @()
for ($i=1; $i -le $Win7Count; $i++) {
	$Datastore = GetLargestDStore
	$WinClient = New-VM -VMHost $VMHost -Name "$WinCientName-$i" -Template $WinTemplate -Location $EnvFolder -Datastore $Datastore
	$WinClients += $WinClient
}
$Datastore = GetLargestDStore
$Router = New-VM -VMHost $VMHost -Name $RouterName -Template $RouterTemplate -Location $EnvFolder -Datastore $Datastore
$Datastore = GetLargestDStore
$DomainController = New-VM -VMHost $VMHost -Name $DomainControllerName -Template $DomainControllerTemplate -Location $EnvFolder -Datastore $Datastore
$vms = $Router, $Sensor, $CM, $DomainController
$vms += $WinClients

Write-Host "VMs successfully created."
 


## Initialize Device Network Adapters
Write-Host "Initializing Device Network Adapters...`n"
$SensorMgmtAdapter = Get-NetworkAdapter -VM $Sensor -Name "Network adapter 1"
$SensorMonAdapter = Get-NetworkAdapter -VM $Sensor -Name "Network adapter 2"
$SensorIntAdapter = Get-NetworkAdapter -VM $Sensor -Name "Network adapter 3"

$CMAdapter = Get-NetworkAdapter -VM $CM -Name "Network adapter 1"

$RouterWANAdapter = Get-NetworkAdapter -VM $Router -Name "Network adapter 1"
$RouterMgmtAdapter = Get-NetworkAdapter -VM $Router -Name "Network adapter 2"
$RouterIntAdapter = Get-NetworkAdapter -VM $Router -Name "Network adapter 3"

$WinClientAdapter = Get-NetworkAdapter -VM $WinClient -Name "Network adapter 1"

$DomainControllerAdapter = Get-NetworkAdapter -VM $DomainController -Name "Network adapter 1"

Write-Host "Adapters successfully initialized.`n"

## Identify Available PortGroups 
Write-Host "Identifying available mirroring port.`n"

## This needs to be optimized. Preferably by moving everything after line 189 out of the loop.
foreach ($HoldAdapter in $HoldAdapters){
	
	
	# Identify an available Mirroring port group
	if ($HoldAdapter.NetworkName -match "Test-Env-MonSess"){
	
		Write-Host "Available mirroring port found.`n"
		
		$OpenPortgroup = Get-VDPortgroup -Name $HoldAdapter.NetworkName
		$GroupID = $HoldAdapter.NetworkName -replace "Test-Env-MonSess-", ""
		
		# Prepare associated management and Intranet portgroups
		$OpenMgmtPortgroup = Get-VDPortgroup -Name "Test-Env-Mgmt-$GroupID"
		$OpenIntPortgroup = Get-VDPortgroup -Name "Test-Env-Intra-$GroupID"		
		
		Write-Host "Configuring device network adapters:`n"
		
		# Move hold-vm's adapter off of held portgroup to the hold portgroup		
		Set-NetworkAdapter -NetworkAdapter $HoldAdapter -PortGroup $HoldPortgroup
	
		
		# Move sensors monitor interface to the mirroring portgroup		
		Set-NetworkAdapter -NetworkAdapter $SensorMonAdapter -PortGroup $OpenPortgroup -Confirm:$False
	
		# Move all devices management network interfaces to the corresponding port group
		Set-NetworkAdapter -NetworkAdapter $SensorMgmtAdapter -PortGroup $OpenMgmtPortgroup -Confirm:$False
		Set-NetworkAdapter -NetworkAdapter $SensorIntAdapter -PortGroup $OpenIntPortgroup -Confirm:$False
		
		Set-NetworkAdapter -NetworkAdapter $CMAdapter -PortGroup $OpenMgmtPortgroup -Confirm:$False
		
		Set-NetworkAdapter -NetworkAdapter $RouterWANAdapter -PortGroup $WANPortgroup -Confirm:$False
		Set-NetworkAdapter -NetworkAdapter $RouterMgmtAdapter -PortGroup $OpenMgmtPortgroup -Confirm:$False
		Set-NetworkAdapter -NetworkAdapter $RouterIntAdapter -PortGroup $OpenIntPortgroup -Confirm:$False
		
		Set-NetworkAdapter -NetworkAdapter $DomainControllerAdapter -PortGroup $OpenMgmtPortgroup -Confirm:$False
		
		Set-NetworkAdapter -NetworkAdapter $WinClientAdapter -PortGroup $OpenIntPortgroup -Confirm:$False
		
		Write-Host "Network adapters successfully configured.`n"
		
		Start-VM $vms

		Write-Host "Your environment's folder name is: $EnvFolder"

		$RouterIP = 0

		while ($RouterIP = 0 ){
			$RouterIP = [string]$Router.guest.IPAddress[0]
			Write-Host "Your gateway device is located at: " 
			Write-Host $RouterIP
			Write-Host "CM Address is at: http://" $RouterIP
			Write-Host "SSH connectivity to gateway router is at: " $RouterIP ":22"
			Write-Host "SSH connectivity to CM is at: " $RouterIP ":23"
			Write-Host "SSH connectivity to Sensor is at: " $RouterIP ":24"
		}
		
		break
		
	}

}

## Need to add message if there are no mirroring ports are available.


Disconnect-VIServer -Server $VCenterHost