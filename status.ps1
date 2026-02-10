# DreamWorks Event Planner - Status Script for Podman on Windows
# Usage: .\status.ps1

$ErrorActionPreference = "SilentlyContinue"

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "$Title" -ForegroundColor Yellow
    Write-Host ("-" * 40) -ForegroundColor Gray
}

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  DreamWorks Event Planner - Status        " -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# Podman Status
Write-Section "Podman Environment"

try {
    $podmanVersion = podman --version 2>$null
    Write-Host "  Podman:    $podmanVersion" -ForegroundColor Green
} catch {
    Write-Host "  Podman:    NOT INSTALLED" -ForegroundColor Red
    exit 1
}

$machineInfo = podman machine list --format "{{.Name}}|{{.Running}}|{{.CPUs}}|{{.Memory}}" 2>$null | Select-Object -First 1
if ($machineInfo) {
    $parts = $machineInfo -split "\|"
    $machineName = $parts[0]
    $isRunning = $parts[1] -eq "true"
    $cpus = $parts[2]
    $memory = $parts[3]
    
    if ($isRunning) {
        Write-Host "  Machine:   $machineName (Running)" -ForegroundColor Green
        Write-Host "  Resources: $cpus CPUs, $memory RAM" -ForegroundColor Gray
    } else {
        Write-Host "  Machine:   $machineName (Stopped)" -ForegroundColor Yellow
    }
} else {
    Write-Host "  Machine:   Not initialized" -ForegroundColor Yellow
}

# Container Status
Write-Section "Containers"

$containers = @(
    @{ Name = "event-planner-drupal"; Service = "Drupal"; URL = "http://localhost:8080" },
    @{ Name = "event-planner-db"; Service = "PostgreSQL"; URL = "" },
    @{ Name = "event-planner-mailhog"; Service = "MailHog"; URL = "http://localhost:8025" }
)

foreach ($container in $containers) {
    $status = podman ps -a --filter "name=$($container.Name)" --format "{{.Status}}" 2>$null
    
    if ($status -match "^Up") {
        $uptime = $status -replace "Up ", ""
        Write-Host "  [RUNNING]  $($container.Service)" -ForegroundColor Green -NoNewline
        Write-Host " ($uptime)" -ForegroundColor Gray
        if ($container.URL) {
            Write-Host "             $($container.URL)" -ForegroundColor Cyan
        }
    } elseif ($status) {
        Write-Host "  [STOPPED]  $($container.Service)" -ForegroundColor Yellow -NoNewline
        Write-Host " - $status" -ForegroundColor Gray
    } else {
        Write-Host "  [MISSING]  $($container.Service)" -ForegroundColor Red
    }
}

# Network Status
Write-Section "Network"

$networkExists = podman network ls --format "{{.Name}}" | Where-Object { $_ -eq "event_planner_network" }
if ($networkExists) {
    Write-Host "  [EXISTS]   event_planner_network" -ForegroundColor Green
} else {
    Write-Host "  [MISSING]  event_planner_network" -ForegroundColor Red
}

# Volume Status
Write-Section "Data Volumes"

$volumes = @(
    @{ Name = "event_planner_db_data"; Description = "PostgreSQL data" },
    @{ Name = "event_planner_drupal_files"; Description = "Drupal files" },
    @{ Name = "event_planner_drupal_private"; Description = "Private files" }
)

foreach ($volume in $volumes) {
    $exists = podman volume ls --format "{{.Name}}" | Where-Object { $_ -eq $volume.Name }
    if ($exists) {
        Write-Host "  [EXISTS]   $($volume.Name)" -ForegroundColor Green
    } else {
        Write-Host "  [MISSING]  $($volume.Name)" -ForegroundColor Gray -NoNewline
        Write-Host " (will be created on start)" -ForegroundColor DarkGray
    }
}

# Quick Health Check
Write-Section "Health Check"

$drupalRunning = podman ps --format "{{.Names}}" | Where-Object { $_ -eq "event-planner-drupal" }
if ($drupalRunning) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:8080" -TimeoutSec 5 -UseBasicParsing -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) {
            Write-Host "  Drupal:    Responding (HTTP 200)" -ForegroundColor Green
        } else {
            Write-Host "  Drupal:    HTTP $($response.StatusCode)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  Drupal:    Not responding yet (may be starting)" -ForegroundColor Yellow
    }
} else {
    Write-Host "  Drupal:    Container not running" -ForegroundColor Gray
}

$mailhogRunning = podman ps --format "{{.Names}}" | Where-Object { $_ -eq "event-planner-mailhog" }
if ($mailhogRunning) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:8025" -TimeoutSec 5 -UseBasicParsing -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) {
            Write-Host "  MailHog:   Responding (HTTP 200)" -ForegroundColor Green
        }
    } catch {
        Write-Host "  MailHog:   Not responding" -ForegroundColor Yellow
    }
} else {
    Write-Host "  MailHog:   Container not running" -ForegroundColor Gray
}

# Commands
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Commands:" -ForegroundColor Yellow
Write-Host "  .\start.ps1         - Start all services" -ForegroundColor Gray
Write-Host "  .\start.ps1 -Force  - Recreate containers" -ForegroundColor Gray
Write-Host "  .\stop.ps1          - Stop all services" -ForegroundColor Gray
Write-Host "  .\logs.ps1          - View logs" -ForegroundColor Gray
Write-Host "  .\logs.ps1 drupal   - Follow Drupal logs" -ForegroundColor Gray
Write-Host ""
