
Write-Host "`n`n!! WARNING: Please use extreme caution while using this tool. It allows the bulk removal of any VM to which your account has access.`n
Remember, with great power comes great derpability...`n"

$FolderName = Read-Host "Please enter the folder name of the VM's that you wish to delete"

$VMS = Get-VM -Name "$FolderName*"

$Prompt = Write-Host "These are the VMs that you will be deleting: `n"

foreach ($VM in $VMS) {
    
    Write-Host "$VM"

}
 
$question = "`nARE YOU SURE THESE ARE THE VMs THAT YOU WANT TO DELETE? (Please enter yes or no)"

$choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
$choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes'))
$choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&No'))

$decision = $Host.UI.PromptForChoice($message, $question, $choices, 1)
if ($decision -eq 0) {
  Write-Host 'confirmed'
} else {
  Write-Host 'cancelled'
}