#This script allows to export in CSV format  list of  VMs from VMWARE  vCenter

# --- Variables ---
$vcenter = "VC.Domain.Example" #<=Set here your Vcetner DNS name or IP
$path = [Environment]::GetFolderPath("MyDocuments") + "\vm_grouped_report.csv"

# --- Import  Module of ESXi.PowerCLI ---
Import-Module VMware.PowerCLI -ErrorAction Stop

# --- Ignore  messages about possible SSL problems ---
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null

# --- Login ---
Connect-VIServer $vcenter

# --- Data  Collecting ---
$vms = Get-VM | ForEach-Object {
    $vm = $_
    $view = Get-View $vm.Id

    [PSCustomObject]@{
        Name          = $vm.Name
        PowerState    = [string]$vm.PowerState
        NumCPU        = [int]$vm.NumCPU
        MemoryGB      = [math]::Round($vm.MemoryGB, 2)
        UsedGB        = [math]::Round($view.Summary.Storage.Committed / 1GB, 2)
        ProvisionedGB = [math]::Round(($view.Summary.Storage.Committed + $view.Summary.Storage.Uncommitted) / 1GB, 2)
        VMHost        = [string]$vm.VMHost
    }
}

# --- Sorting ---
$poweredOff = $vms | Where-Object { $_.PowerState -eq "PoweredOff" } | Sort-Object Name
$poweredOn  = $vms | Where-Object { $_.PowerState -eq "PoweredOn" }  | Sort-Object Name

# --- Report ---
$report = @()

# PoweredOFF State first
$report += $poweredOff

# PoweredON State second 
$report += $poweredOn

# Total calculation at the  end:  OFF -> ON -> GRAND TOTAL
$report += [PSCustomObject]@{
    Name          = "TOTAL PoweredOff"
    PowerState    = ""
    NumCPU        = ($poweredOff | Measure-Object NumCPU -Sum).Sum
    MemoryGB      = [math]::Round((($poweredOff | Measure-Object MemoryGB -Sum).Sum), 2)
    UsedGB        = [math]::Round((($poweredOff | Measure-Object UsedGB -Sum).Sum), 2)
    ProvisionedGB = [math]::Round((($poweredOff | Measure-Object ProvisionedGB -Sum).Sum), 2)
    VMHost        = ""
}

$report += [PSCustomObject]@{
    Name          = "TOTAL PoweredOn"
    PowerState    = ""
    NumCPU        = ($poweredOn | Measure-Object NumCPU -Sum).Sum
    MemoryGB      = [math]::Round((($poweredOn | Measure-Object MemoryGB -Sum).Sum), 2)
    UsedGB        = [math]::Round((($poweredOn | Measure-Object UsedGB -Sum).Sum), 2)
    ProvisionedGB = [math]::Round((($poweredOn | Measure-Object ProvisionedGB -Sum).Sum), 2)
    VMHost        = ""
}

$report += [PSCustomObject]@{
    Name          = "GRAND TOTAL"
    PowerState    = ""
    NumCPU        = ($vms | Measure-Object NumCPU -Sum).Sum
    MemoryGB      = [math]::Round((($vms | Measure-Object MemoryGB -Sum).Sum), 2)
    UsedGB        = [math]::Round((($vms | Measure-Object UsedGB -Sum).Sum), 2)
    ProvisionedGB = [math]::Round((($vms | Measure-Object ProvisionedGB -Sum).Sum), 2)
    VMHost        = ""
}

# --- Export ---
$report | Export-Csv $path -NoTypeInformation -Encoding utf8BOM -UseCulture

Write-Host "Готово: $path" -ForegroundColor Green