# Nessus Integration — post-install script (PowerShell)
#
# Recreates the Latest Transform with proper permissions and clears the
# "Deferred installations" warning in Fleet.
#
# Usage:
#   .\post-install.ps1
#   .\post-install.ps1 -Es https://es:9200 -Kbn https://kbn:5601 -Auth elastic:changeme

param(
    [string]$Es   = "https://localhost:9200",
    [string]$Kbn  = "https://localhost:5601",
    [string]$Auth = "elastic:changeme"
)

$ErrorActionPreference = "Stop"

Add-Type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAll : ICertificatePolicy {
    public bool CheckValidationResult(ServicePoint sp, X509Certificate cert, WebRequest req, int problem) { return true; }
}
"@ -ErrorAction SilentlyContinue
[System.Net.ServicePointManager]::CertificatePolicy = [TrustAll]::new()
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

$TID  = "logs-nessus.nessus_vulnerability_latest-default-0.1.0"
$b64  = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($Auth))
$hdr  = @{ Authorization = "Basic $b64" }
$hdrK = @{ Authorization = "Basic $b64"; "kbn-xsrf" = "true" }
$json = Join-Path $PSScriptRoot "transform_create.json"

Write-Host "=== Nessus post-install ===" -ForegroundColor Cyan
Write-Host "ES:  $Es"
Write-Host "KBN: $Kbn"
Write-Host ""

# ── 1. Recreate transform ────────────────────────────────────────────
Write-Host "[1/3] Stopping & deleting existing transform..." -ForegroundColor Yellow
try { Invoke-RestMethod -Uri "$Es/_transform/$TID/_stop?force=true" -Method POST -Headers $hdr } catch {}
try { Invoke-RestMethod -Uri "$Es/_transform/$TID" -Method DELETE -Headers $hdr } catch {}

Write-Host "[2/3] Creating transform..." -ForegroundColor Yellow
$body = Get-Content $json -Raw
Invoke-RestMethod -Uri "$Es/_transform/$TID" -Method PUT -Headers $hdr `
    -ContentType "application/json" -Body $body
Invoke-RestMethod -Uri "$Es/_transform/$TID/_start" -Method POST -Headers $hdr

# ── 2. Clear deferred flag ───────────────────────────────────────────
Write-Host "[3/3] Clearing 'Deferred installations' flag..." -ForegroundColor Yellow
try {
    $pkg = Invoke-RestMethod -Uri "$Kbn/api/saved_objects/epm-packages/nessus" -Method GET -Headers $hdrK
    foreach ($item in $pkg.attributes.installed_es) {
        if ($item.type -eq "transform") { $item.deferred = $false }
    }
    $patch = @{ attributes = @{ installed_es = $pkg.attributes.installed_es } } | ConvertTo-Json -Depth 10
    Invoke-RestMethod -Uri "$Kbn/api/saved_objects/epm-packages/nessus" -Method PUT -Headers $hdrK `
        -ContentType "application/json" -Body $patch | Out-Null
    Write-Host "  Done." -ForegroundColor Green
} catch {
    Write-Host "  (skipped: $_)" -ForegroundColor DarkGray
}

Write-Host "`n=== Done. Transform is running. ===" -ForegroundColor Green
