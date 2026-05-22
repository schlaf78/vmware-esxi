# --- configuration ---
$vcenter = "vcnl.valhalla.local"
$path = [Environment]::GetFolderPath("MyDocuments") + "\vm_snapshots_report.tsv"

# --- load PowerCLI module ---
Import-Module VMware.PowerCLI -ErrorAction Stop

# --- ignore invalid SSL certificates ---
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false | Out-Null

# --- connect to vCenter ---
Connect-VIServer $vcenter

# --- collect VMs with snapshots ---
$report = Get-VM | Sort-Object Name | ForEach-Object {
    $vm = $_
    $snapshots = Get-Snapshot -VM $vm -ErrorAction SilentlyContinue

    if ($snapshots -and $snapshots.Count -gt 0) {
        [PSCustomObject]@{
            VMName         = $vm.Name
            PowerState     = [string]$vm.PowerState
            SnapshotStatus = "Has Snapshot"
            SnapshotSizeGB = [math]::Round((($snapshots | Measure-Object SizeGB -Sum).Sum), 2)
        }
    }
}

# --- calculate grand total ---
$totalSnapGB = [math]::Round((($report | Measure-Object SnapshotSizeGB -Sum).Sum), 2)

$report += [PSCustomObject]@{
    VMName         = "GRAND TOTAL"
    PowerState     = ""
    SnapshotStatus = ""
    SnapshotSizeGB = $totalSnapGB
}

# --- export report ---
$report | Export-Csv $path `
    -NoTypeInformation `
    -Encoding Unicode `
    -Delimiter "`t"

# --- print result ---
Write-Host "Report saved: $path" -ForegroundColor Green
Write-Host "VMs with snapshots: $(($report | Where-Object { $_.VMName -ne 'GRAND TOTAL' }).Count)" -ForegroundColor Yellow
Write-Host "Total snapshot size GB: $totalSnapGB" -ForegroundColor Yellow