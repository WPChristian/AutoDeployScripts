. "C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts\Initialize-PowerCLIEnvironment.ps1"

Write-Host "`n`n!! WARNING: Please use extreme caution while using this tool. It allows the bulk removal of any VM to which your account has access.`n
Remember, with great power comes great derpability...`n"

$FolderName = Read-Host "Please enter the folder name of the VM's that you wish to delete"
$Folder = Get-Folder -Name $FolderName
$VMS = $Folder | Get-VM 
$Sensor = Get-VM -Name "$FolderName-nacsnsr*"
$Switchholder = Get-VM -Name Switch-Holder
$HoldAdapters = Get-NetworkAdapter -VM $Switchholder


Write-Host "These are the VMs that you will be deleting: `n"

foreach ($VM in $VMS) {
    
    Write-Host "$VM"

}

$question = "`nARE YOU SURE THESE ARE THE VMs THAT YOU WANT TO DELETE?"

$choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
$choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes'))
$choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&No'))

$decision = $Host.UI.PromptForChoice($message, $question, $choices, 1)
if ($decision -eq 0) {
    Stop-VM $VMS -Confirm:$False
    $Adapters = Get-NetworkAdapter -VM $Sensor
    $SensorMon = $Adapters[1].NetworkName
    $HoldMonId = $SensorMon -replace "Test-Env-MonSess-0", ""
    $MonPortGroup = Get-VDPortGroup -Name $SensorMon
    Remove-Folder $Folder -Deletepermanently
    Write-Host "Releasing Mirroring Port..."
    Set-NetworkAdapter -NetworkAdapter $HoldAdapters[$HoldMonId] -PortGroup $MonPortGroup -Confirm:$False
    Write-Host "Success!"

} else {
  Write-Host "`nNot deleting VMs."
}

Write-Host "`nDONE."