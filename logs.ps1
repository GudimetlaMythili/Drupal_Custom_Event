# DreamWorks Event Planner - Logs Script for Podman on Windows
# Usage: .\logs.ps1 [service]
# Examples:
#   .\logs.ps1          - Show all logs
#   .\logs.ps1 drupal   - Show Drupal logs only
#   .\logs.ps1 db       - Show Database logs only
#   .\logs.ps1 mailhog  - Show MailHog logs only

param(
    [Parameter(Position=0)]
    [ValidateSet("", "drupal", "db", "mailhog", "all")]
    [string]$Service = "all"
)

$ErrorActionPreference = "SilentlyContinue"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  DreamWorks Event Planner - Logs          " -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Map service names to container names
$containerMap = @{
    "drupal"  = "event-planner-drupal"
    "db"      = "event-planner-db"
    "mailhog" = "event-planner-mailhog"
}

function Show-Logs {
    param([string]$ContainerName, [string]$DisplayName)
    
    $exists = podman ps --format "{{.Names}}" | Select-String -Pattern "^$ContainerName$"
    if ($exists) {
        Write-Host "=== $DisplayName Logs ===" -ForegroundColor Yellow
        podman logs --tail 50 $ContainerName
        Write-Host ""
    } else {
        Write-Host "[SKIP] $DisplayName is not running" -ForegroundColor Gray
    }
}

if ($Service -eq "all" -or $Service -eq "") {
    # Show status first
    Write-Host "Container Status:" -ForegroundColor Yellow
    podman ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | Select-String -Pattern "event-planner"
    Write-Host ""
    
    # Show logs for all services
    foreach ($svc in @("drupal", "db", "mailhog")) {
        Show-Logs -ContainerName $containerMap[$svc] -DisplayName $svc.ToUpper()
    }
    
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "To follow logs in real-time:" -ForegroundColor Yellow
    Write-Host "  podman logs -f event-planner-drupal" -ForegroundColor Gray
    Write-Host "  podman logs -f event-planner-db" -ForegroundColor Gray
    Write-Host "  podman logs -f event-planner-mailhog" -ForegroundColor Gray
} else {
    $containerName = $containerMap[$Service]
    if ($containerName) {
        Write-Host "Following logs for $Service (Ctrl+C to exit)..." -ForegroundColor Yellow
        Write-Host ""
        podman logs -f $containerName
    }
}
