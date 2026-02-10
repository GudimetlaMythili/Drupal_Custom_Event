# DreamWorks Event Planner - Start Script for Podman on Windows
# Usage: .\start.ps1
#
# This script:
# 1. Checks prerequisites (Podman installation)
# 2. Sets up the Podman environment (machine, network, volumes)
# 3. Starts the containers (PostgreSQL, MailHog, Drupal)

param(
    [switch]$Force  # Force recreate containers
)

$ErrorActionPreference = "Stop"
$ProjectName = "event-planner"

# ============================================
# HELPER FUNCTIONS
# ============================================

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

function Write-Err {
    param([string]$Message)
    Write-Host "   [ERROR] $Message" -ForegroundColor Red
}

function Test-PodmanInstalled {
    try {
        $null = Get-Command podman -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Test-PodmanMachineRunning {
    $status = podman machine list --format "{{.Running}}" 2>$null | Select-Object -First 1
    return ($status -eq "true" -or $status -eq "Currently running")
}

function Test-ContainerExists {
    param([string]$Name)
    $exists = podman ps -a --format "{{.Names}}" 2>$null | Where-Object { $_ -eq $Name }
    return [bool]$exists
}

function Test-ContainerRunning {
    param([string]$Name)
    $running = podman ps --format "{{.Names}}" 2>$null | Where-Object { $_ -eq $Name }
    return [bool]$running
}

function Test-NetworkExists {
    param([string]$Name)
    $exists = podman network ls --format "{{.Name}}" 2>$null | Where-Object { $_ -eq $Name }
    return [bool]$exists
}

function Wait-ForDatabase {
    param([string]$Container, [string]$User, [int]$MaxRetries = 30)
    
    for ($i = 1; $i -le $MaxRetries; $i++) {
        $result = podman exec $Container pg_isready -U $User 2>$null
        if ($LASTEXITCODE -eq 0) {
            return $true
        }
        Write-Host "   Waiting for database... ($i/$MaxRetries)" -ForegroundColor Gray
        Start-Sleep -Seconds 2
    }
    return $false
}

# ============================================
# MAIN SCRIPT
# ============================================

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  DreamWorks Event Planner                 " -ForegroundColor Cyan
Write-Host "  Setup & Start Script                     " -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# --------------------------------------------
# PHASE 1: CHECK PREREQUISITES
# --------------------------------------------
Write-Step "Phase 1: Checking Prerequisites"

# Check Podman installation
if (-not (Test-PodmanInstalled)) {
    Write-Err "Podman is not installed or not in PATH"
    Write-Host ""
    Write-Host "Please install Podman Desktop from: https://podman-desktop.io/" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

$podmanVersion = podman --version
Write-Success "Podman installed: $podmanVersion"

# Check if podman-compose is available
$usePodmanCompose = $false
try {
    $composeVersion = podman-compose --version 2>$null
    if ($LASTEXITCODE -eq 0) {
        $usePodmanCompose = $true
        Write-Success "podman-compose available: $composeVersion"
    }
} catch {
    Write-Info "podman-compose not found (optional)"
    Write-Host "         Install with: pip install podman-compose" -ForegroundColor Gray
}

# --------------------------------------------
# PHASE 2: SETUP PODMAN ENVIRONMENT
# --------------------------------------------
Write-Step "Phase 2: Setting Up Podman Environment"

# Initialize and start Podman machine if needed
if (-not (Test-PodmanMachineRunning)) {
    Write-Info "Podman machine is not running"
    
    # Check if machine exists
    $machineList = podman machine list --format "{{.Name}}" 2>$null
    if (-not $machineList) {
        Write-Info "Initializing Podman machine (first-time setup)..."
        podman machine init
        if ($LASTEXITCODE -ne 0) {
            Write-Err "Failed to initialize Podman machine"
            exit 1
        }
        Write-Success "Podman machine initialized"
    }
    
    Write-Info "Starting Podman machine..."
    podman machine start
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Failed to start Podman machine"
        exit 1
    }
    Write-Success "Podman machine started"
} else {
    Write-Success "Podman machine is running"
}

# Load environment variables
$envFile = Join-Path $PSScriptRoot ".env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match "^([^#=]+)=(.*)$") {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            [Environment]::SetEnvironmentVariable($key, $value, "Process")
        }
    }
    Write-Success "Environment variables loaded from .env"
} else {
    Write-Info "No .env file found, using defaults"
}

# Set default values
$POSTGRES_DB = if ($env:POSTGRES_DB) { $env:POSTGRES_DB } else { "drupal" }
$POSTGRES_USER = if ($env:POSTGRES_USER) { $env:POSTGRES_USER } else { "drupal" }
$POSTGRES_PASSWORD = if ($env:POSTGRES_PASSWORD) { $env:POSTGRES_PASSWORD } else { "drupal" }

# Create network if needed
$NetworkName = "event_planner_network"
if (-not (Test-NetworkExists $NetworkName)) {
    Write-Info "Creating network: $NetworkName"
    podman network create $NetworkName
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Failed to create network"
        exit 1
    }
    Write-Success "Network created: $NetworkName"
} else {
    Write-Success "Network exists: $NetworkName"
}

# --------------------------------------------
# PHASE 3: START CONTAINERS
# --------------------------------------------
Write-Step "Phase 3: Starting Containers"

if ($usePodmanCompose -and -not $Force) {
    # Use podman-compose for simpler management
    Write-Info "Using podman-compose..."
    Set-Location $PSScriptRoot
    podman-compose -f podman-compose.yml up -d
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Failed to start containers with podman-compose"
        exit 1
    }
    Write-Success "All containers started via podman-compose"
} else {
    # Manual container management
    $projectRoot = $PSScriptRoot
    
    # Container definitions
    $containers = @(
        @{
            Name = "event-planner-db"
            Image = "docker.io/library/postgres:15"
            Hostname = "db"
            Ports = @()
            Environment = @(
                "POSTGRES_DB=$POSTGRES_DB",
                "POSTGRES_USER=$POSTGRES_USER",
                "POSTGRES_PASSWORD=$POSTGRES_PASSWORD"
            )
            Volumes = @(
                "event_planner_db_data:/var/lib/postgresql/data:Z"
            )
            WaitFor = $null
        },
        @{
            Name = "event-planner-mailhog"
            Image = "docker.io/mailhog/mailhog:latest"
            Hostname = "mailhog"
            Ports = @("1025:1025", "8025:8025")
            Environment = @()
            Volumes = @()
            WaitFor = $null
        },
        @{
            Name = "event-planner-drupal"
            Image = "docker.io/library/drupal:10-apache"
            Hostname = "drupal"
            Ports = @("8080:80")
            Environment = @(
                "DRUPAL_DB_HOST=event-planner-db",
                "DRUPAL_DB_PORT=5432",
                "DRUPAL_DB_NAME=$POSTGRES_DB",
                "DRUPAL_DB_USER=$POSTGRES_USER",
                "DRUPAL_DB_PASSWORD=$POSTGRES_PASSWORD",
                "MAILER_DSN=smtp://event-planner-mailhog:1025",
                "DRUPAL_SITE_NAME=DreamWorks Event Planner"
            )
            Volumes = @(
                "${projectRoot}/drupal/modules/custom:/var/www/html/modules/custom:Z",
                "${projectRoot}/drupal/settings.php:/var/www/html/sites/default/settings.php:ro,Z",
                "${projectRoot}/drupal/config/sync:/var/www/html/config/sync:Z",
                "${projectRoot}/drupal/tools:/opt/drupal-tools:ro,Z",
                "${projectRoot}/drupal/startup.sh:/var/www/html/startup.sh:ro,Z"
            )
            Command = "/var/www/html/startup.sh"
            WaitFor = "event-planner-db"
        }
    )
    
    foreach ($container in $containers) {
        $name = $container.Name
        
        # Check if container needs to be recreated
        if ($Force -and (Test-ContainerExists $name)) {
            Write-Info "Removing existing container: $name"
            podman stop $name 2>$null
            podman rm $name 2>$null
        }
        
        if (Test-ContainerRunning $name) {
            Write-Success "Container already running: $name"
            continue
        }
        
        if (Test-ContainerExists $name) {
            Write-Info "Starting existing container: $name"
            podman start $name
            if ($LASTEXITCODE -ne 0) {
                Write-Err "Failed to start container: $name"
                exit 1
            }
            Write-Success "Container started: $name"
            continue
        }
        
        # Wait for dependency if specified
        if ($container.WaitFor) {
            Write-Info "Waiting for dependency: $($container.WaitFor)"
            if (-not (Wait-ForDatabase -Container $container.WaitFor -User $POSTGRES_USER)) {
                Write-Err "Dependency $($container.WaitFor) did not become ready"
                exit 1
            }
            Write-Success "Dependency ready: $($container.WaitFor)"
        }
        
        # Build podman run command
        Write-Info "Creating container: $name"
        
        $args = @("run", "-d", "--name", $name, "--hostname", $container.Hostname, "--network", $NetworkName)
        
        foreach ($port in $container.Ports) {
            $args += @("-p", $port)
        }
        
        foreach ($envVar in $container.Environment) {
            $args += @("-e", $envVar)
        }
        
        foreach ($volume in $container.Volumes) {
            $args += @("-v", $volume)
        }
        
        $args += $container.Image
        
        if ($container.Command) {
            $args += $container.Command
        }
        
        # Execute podman run
        & podman @args
        
        if ($LASTEXITCODE -ne 0) {
            Write-Err "Failed to create container: $name"
            exit 1
        }
        
        Write-Success "Container created: $name"
    }
}

# --------------------------------------------
# PHASE 4: VERIFY SETUP
# --------------------------------------------
Write-Step "Phase 4: Verifying Setup"

Start-Sleep -Seconds 3

$allRunning = $true
foreach ($containerName in @("event-planner-db", "event-planner-mailhog", "event-planner-drupal")) {
    if (Test-ContainerRunning $containerName) {
        Write-Success "$containerName is running"
    } else {
        Write-Err "$containerName is NOT running"
        $allRunning = $false
    }
}

# ============================================
# FINAL OUTPUT
# ============================================
Write-Host ""
if ($allRunning) {
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "  Event Planner Started Successfully!      " -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
} else {
    Write-Host "============================================" -ForegroundColor Yellow
    Write-Host "  Some containers may have issues          " -ForegroundColor Yellow
    Write-Host "  Run .\logs.ps1 to investigate            " -ForegroundColor Yellow
    Write-Host "============================================" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Services:" -ForegroundColor Cyan
Write-Host "  Drupal:       http://localhost:8080" -ForegroundColor White
Write-Host "  MailHog UI:   http://localhost:8025" -ForegroundColor White
Write-Host "  MailHog SMTP: localhost:1025" -ForegroundColor White
Write-Host ""
Write-Host "First-time Drupal setup:" -ForegroundColor Yellow
Write-Host "  1. Visit http://localhost:8080" -ForegroundColor White
Write-Host "  2. Complete Drupal installation wizard" -ForegroundColor White
Write-Host "  3. Database settings:" -ForegroundColor White
Write-Host "       Type: PostgreSQL" -ForegroundColor Gray
Write-Host "       Host: db (or event-planner-db)" -ForegroundColor Gray
Write-Host "       Port: 5432" -ForegroundColor Gray
Write-Host "       Database: $POSTGRES_DB" -ForegroundColor Gray
Write-Host "       Username: $POSTGRES_USER" -ForegroundColor Gray
Write-Host "       Password: $POSTGRES_PASSWORD" -ForegroundColor Gray
Write-Host "  4. Enable 'Event Planner' module at /admin/modules" -ForegroundColor White
Write-Host ""
Write-Host "Commands:" -ForegroundColor Cyan
Write-Host "  .\status.ps1  - Check container status" -ForegroundColor Gray
Write-Host "  .\logs.ps1    - View container logs" -ForegroundColor Gray
Write-Host "  .\stop.ps1    - Stop all containers" -ForegroundColor Gray
Write-Host ""
