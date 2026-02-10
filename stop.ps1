# DreamWorks Event Planner - Stop Script for Podman on Windows
# Usage: .\stop.ps1 [-RemoveVolumes]

param(
    [switch]$RemoveVolumes  # Also remove data volumes
)

$ErrorActionPreference = "SilentlyContinue"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host ">> $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "   [OK] $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "   [INFO] $Message" -ForegroundColor Yellow
}

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  DreamWorks Event Planner - Stopping      " -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# Check if podman-compose is available
$usePodmanCompose = $false
try {
    $null = podman-compose --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        $usePodmanCompose = $true
    }
} catch {}

Write-Step "Stopping Containers"

if ($usePodmanCompose) {
    Set-Location $PSScriptRoot
    podman-compose -f podman-compose.yml down
    Write-Success "Containers stopped via podman-compose"
} else {
    $containers = @("event-planner-drupal", "event-planner-mailhog", "event-planner-db")
    
    foreach ($container in $containers) {
        $exists = podman ps -a --format "{{.Names}}" | Where-Object { $_ -eq $container }
        if ($exists) {
            Write-Info "Stopping: $container"
            podman stop $container 2>$null
            podman rm $container 2>$null
            Write-Success "Stopped: $container"
        } else {
            Write-Host "   [SKIP] $container (not found)" -ForegroundColor Gray
        }
    }
}

if ($RemoveVolumes) {
    Write-Step "Removing Data Volumes"
    
    $volumes = @("event_planner_db_data", "event_planner_drupal_files", "event_planner_drupal_private")
    foreach ($volume in $volumes) {
        $exists = podman volume ls --format "{{.Name}}" | Where-Object { $_ -eq $volume }
        if ($exists) {
            podman volume rm $volume 2>$null
            Write-Success "Removed: $volume"
        }
    }
    
    Write-Host ""
    Write-Host "   All data has been removed. Next start will be fresh." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  Event Planner Stopped                    " -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Data volumes are preserved by default." -ForegroundColor Gray
Write-Host "To remove all data: .\stop.ps1 -RemoveVolumes" -ForegroundColor Gray
Write-Host ""
Write-Host "Restart: .\start.ps1" -ForegroundColor Cyan
Write-Host ""
