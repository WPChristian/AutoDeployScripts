Add-PSSnapin VMware.VimAutomation.Core
2	Add-PSSnapin VMware.VimAutomation.Vds
3	if(get-item HKLM:\SOFTWARE\Microsoft\PowerShell\1\PowerShellSnapIns\VMware.VimAutomation.Core){
4	    . ((get-item HKLM:\SOFTWARE\Microsoft\PowerShell\1\PowerShellSnapIns\VMware.VimAutomation.Core).GetValue("ApplicationBase")+"\Scripts\Initialize-PowerCLIEnvironment.ps1")
5	}
6	else
7	{
8	    write-warning "PowerCLI Path not found in registry, please set path to Initialize-PowerCLIEnvironment.ps1 manually. Is PowerCli aleady installed?"
9	    . "D:\Programs (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts\Initialize-PowerCLIEnvironment.ps1"
10	}
11	 
12	# Connect to vCenter
13	$sVCenterHost="vcenter.subdomain.domain.local"
14	Write-Host -NoNewline " Connecting to vCenter..."
15	Connect-VIServer $sVCenterHost -ErrorAction SilentlyContinue -WarningAction SilentlyContinue |out-null
16	if(!$?){
17	    Write-Host -ForegroundColor Red " Could not connect to $sVCenterHost"
18	    exit 2
19	}
20	else{
21	    Write-Host "ok"
22	}