# --- настройки ---
$vcenter = "vcnl.valhalla.local"
$path = [Environment]::GetFolderPath("MyDocuments") + "\vm_grouped_report.csv"

# --- загрузка PowerCLI ---
Import-Module VMware.PowerCLI -ErrorAction Stop

# --- игнор SSL ---
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null

# --- логин ---
Connect-VIServer $vcenter

# --- сбор данных ---
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

# --- сортировка и группы ---
$poweredOff = $vms | Where-Object { $_.PowerState -eq "PoweredOff" } | Sort-Object Name
$poweredOn  = $vms | Where-Object { $_.PowerState -eq "PoweredOn" }  | Sort-Object Name

# --- отчёт ---
$report = @()

# Сначала выключенные
$report += $poweredOff

# Потом включённые
$report += $poweredOn

# Потом итоги в конце: OFF -> ON -> GRAND TOTAL
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

# --- экспорт ---
$report | Export-Csv $path -NoTypeInformation -Encoding utf8BOM -UseCulture

Write-Host "Готово: $path" -ForegroundColor Green