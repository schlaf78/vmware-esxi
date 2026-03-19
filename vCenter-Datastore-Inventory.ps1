#This script allows to export in CSV format  list of  Datastores from VMWARE  vCenter

# --- настройки ---
$vcenter = "VC.Domain.Example" #<=Set here your Vcetner DNS name or IP
$path = [Environment]::GetFolderPath("MyDocuments") + "\datastores_report.csv"

# --- Import  Module of ESXi.PowerCLI ---
Import-Module VMware.PowerCLI -ErrorAction Stop

# --- Ignore  messages about possible SSL problems ---
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null

# --- Login ---
Connect-VIServer $vcenter

# --- Data  Collecting ---
$datastores = Get-View -ViewType Datastore | Sort-Object Name | ForEach-Object {
    $capacityGB = [math]::Round(($_.Summary.Capacity / 1GB), 2)
    $freeGB     = [math]::Round(($_.Summary.FreeSpace / 1GB), 2)
    $usedGB     = [math]::Round((($_.Summary.Capacity - $_.Summary.FreeSpace) / 1GB), 2)

    [PSCustomObject]@{
        Name        = $_.Name
        Type        = $_.Summary.Type
        CapacityGB  = $capacityGB
        UsedGB      = $usedGB
        FreeGB      = $freeGB
        UsedPercent = if ($_.Summary.Capacity -gt 0) {
            [math]::Round(((($_.Summary.Capacity - $_.Summary.FreeSpace) / $_.Summary.Capacity) * 100), 2)
        } else {
            0
        }
    }
}

# --- Total sizing report ---
$totalCapacity = [math]::Round((($datastores | Measure-Object CapacityGB -Sum).Sum), 2)
$totalUsed     = [math]::Round((($datastores | Measure-Object UsedGB -Sum).Sum), 2)
$totalFree     = [math]::Round((($datastores | Measure-Object FreeGB -Sum).Sum), 2)
$totalPercent  = if ($totalCapacity -gt 0) {
    [math]::Round((($totalUsed / $totalCapacity) * 100), 2)
} else {
    0
}

$report = @()
$report += $datastores
$report += [PSCustomObject]@{
    Name        = "GRAND TOTAL"
    Type        = ""
    CapacityGB  = $totalCapacity
    UsedGB      = $totalUsed
    FreeGB      = $totalFree
    UsedPercent = $totalPercent
}

# --- Export ---
$report | Export-Csv $path -NoTypeInformation -Encoding utf8BOM -UseCulture

Write-Host "Готово: $path" -ForegroundColor Green