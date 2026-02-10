# ============================================
# DreamWorks Event Planner - Seed Test Data
# ============================================
# This script populates the database with sample
# events and registrations for testing purposes.
#
# Usage:
#   .\seed-data.ps1           - Seed test data
#   .\seed-data.ps1 -Verify   - Just verify existing data
#   .\seed-data.ps1 -Clear    - Remove test data only
# ============================================

param(
    [switch]$Verify,
    [switch]$Clear
)

$ErrorActionPreference = "Stop"

# Colors
function Write-Step { param($msg) Write-Host "`n>> $msg" -ForegroundColor Cyan }
function Write-OK { param($msg) Write-Host "   [OK] $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "   [WARN] $msg" -ForegroundColor Yellow }
function Write-Fail { param($msg) Write-Host "   [FAIL] $msg" -ForegroundColor Red }
function Write-Info { param($msg) Write-Host "   [INFO] $msg" -ForegroundColor Gray }

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  DreamWorks Event Planner                 " -ForegroundColor Cyan
Write-Host "  Test Data Seeder                         " -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# --------------------------------------------
# Check if containers are running
# --------------------------------------------
Write-Step "Checking Environment"

$dbContainer = podman ps --filter "name=event-planner-db" --format "{{.Names}}" 2>$null
if (-not $dbContainer) {
    Write-Fail "Database container is not running"
    Write-Host "`nStart the containers first: .\start.ps1" -ForegroundColor Yellow
    exit 1
}
Write-OK "Database container is running"

# --------------------------------------------
# Database connection details
# --------------------------------------------
$DB_NAME = "drupal"
$DB_USER = "drupal"
$DB_PASSWORD = "drupal"

# Load from .env if exists
if (Test-Path ".\.env") {
    Get-Content ".\.env" | ForEach-Object {
        if ($_ -match '^([^#][^=]+)=(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            if ($key -eq "POSTGRES_DB") { $DB_NAME = $value }
            if ($key -eq "POSTGRES_USER") { $DB_USER = $value }
            if ($key -eq "POSTGRES_PASSWORD") { $DB_PASSWORD = $value }
        }
    }
}

# Function to run SQL in the database container
function Invoke-SQL {
    param([string]$SQL)
    $result = podman exec event-planner-db psql -U $DB_USER -d $DB_NAME -t -c $SQL 2>&1
    # Join array results into a single string
    if ($result -is [array]) {
        return ($result -join "`n")
    }
    return $result
}

# Function to run SQL file
function Invoke-SQLFile {
    param([string]$FilePath)
    $result = podman exec -i event-planner-db psql -U $DB_USER -d $DB_NAME 2>&1
    return $result
}

# --------------------------------------------
# Check if tables exist
# --------------------------------------------
Write-Step "Checking Database Tables"

$tablesStr = Invoke-SQL "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('event_planner_events', 'event_planner_registrations');"

if ($tablesStr -notmatch "event_planner_events") {
    Write-Fail "Table 'event_planner_events' not found"
    Write-Host "`nThe Event Planner module may not be installed properly." -ForegroundColor Yellow
    Write-Host "Visit http://localhost:8080 and enable the module first." -ForegroundColor Yellow
    exit 1
}
Write-OK "event_planner_events table exists"

if ($tablesStr -notmatch "event_planner_registrations") {
    Write-Fail "Table 'event_planner_registrations' not found"
    exit 1
}
Write-OK "event_planner_registrations table exists"

# --------------------------------------------
# Clear test data only
# --------------------------------------------
if ($Clear) {
    Write-Step "Clearing Test Data"
    
    $deleteRegs = Invoke-SQL "DELETE FROM event_planner_registrations WHERE email LIKE '%@example.com' OR email LIKE '%@test.com';"
    Write-OK "Cleared test registrations"
    
    $deleteEvents = Invoke-SQL "DELETE FROM event_planner_events WHERE event_name LIKE 'Demo:%' OR event_name LIKE 'Test:%';"
    Write-OK "Cleared demo events"
    
    Write-Host "`n============================================" -ForegroundColor Green
    Write-Host "  Test Data Cleared                        " -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    exit 0
}

# --------------------------------------------
# Verify existing data
# --------------------------------------------
if ($Verify) {
    Write-Step "Verifying Existing Data"
    
    $eventCount = (Invoke-SQL "SELECT COUNT(*) FROM event_planner_events;").Trim()
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $activeEvents = (Invoke-SQL "SELECT COUNT(*) FROM event_planner_events WHERE registration_start <= $now AND registration_end >= $now;").Trim()
    $regCount = (Invoke-SQL "SELECT COUNT(*) FROM event_planner_registrations;").Trim()
    
    Write-Host ""
    Write-Host "   Database Statistics:" -ForegroundColor White
    Write-Host "   ------------------------------------"
    Write-Host "   Total Events:        $eventCount"
    Write-Host "   Active Events:       $activeEvents (registration open)"
    Write-Host "   Total Registrations: $regCount"
    
    Write-Host ""
    Write-Host "   Recent Events:" -ForegroundColor White
    Write-Host "   ------------------------------------"
    $events = Invoke-SQL "SELECT id || '. ' || SUBSTRING(event_name, 1, 40) || ' (' || category || ')' FROM event_planner_events ORDER BY created DESC LIMIT 5;"
    $events -split "`n" | ForEach-Object {
        $line = $_.Trim()
        if ($line) { Write-Host "   $line" }
    }
    
    Write-Host ""
    Write-Host "   Recent Registrations:" -ForegroundColor White
    Write-Host "   ------------------------------------"
    $regs = Invoke-SQL "SELECT full_name || ' - ' || email || ' (' || category || ')' FROM event_planner_registrations ORDER BY created DESC LIMIT 5;"
    $regs -split "`n" | ForEach-Object {
        $line = $_.Trim()
        if ($line) { Write-Host "   $line" }
    }
    
    exit 0
}

# --------------------------------------------
# Seed test data
# --------------------------------------------
Write-Step "Seeding Test Data"

# Check if demo data already exists
$existingDemo = (Invoke-SQL "SELECT COUNT(*) FROM event_planner_events WHERE event_name LIKE 'Demo:%';").Trim()
if ([int]$existingDemo -gt 0) {
    Write-Warn "Demo events already exist ($existingDemo found)"
    Write-Info "Clearing existing demo data first..."
    Invoke-SQL "DELETE FROM event_planner_registrations WHERE email LIKE '%@example.com' OR email LIKE '%@test.com';" | Out-Null
    Invoke-SQL "DELETE FROM event_planner_events WHERE event_name LIKE 'Demo:%' OR event_name LIKE 'Test:%';" | Out-Null
}

# Copy and execute the SQL file
$sqlFile = ".\drupal\seed-data.sql"
if (-not (Test-Path $sqlFile)) {
    Write-Fail "Seed data file not found: $sqlFile"
    exit 1
}

Write-Info "Loading seed data from $sqlFile..."

# Read and execute SQL
$sqlContent = Get-Content $sqlFile -Raw
$result = $sqlContent | podman exec -i event-planner-db psql -U $DB_USER -d $DB_NAME 2>&1

# Check for errors
if ($LASTEXITCODE -ne 0) {
    Write-Fail "Error executing seed data"
    Write-Host $result -ForegroundColor Red
    exit 1
}

Write-OK "Seed data loaded successfully"

# --------------------------------------------
# Verify seeded data
# --------------------------------------------
Write-Step "Verifying Seeded Data"

$eventCount = (Invoke-SQL "SELECT COUNT(*) FROM event_planner_events WHERE event_name LIKE 'Demo:%';").Trim()
$now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$activeEvents = (Invoke-SQL "SELECT COUNT(*) FROM event_planner_events WHERE event_name LIKE 'Demo:%' AND registration_start <= $now AND registration_end >= $now;").Trim()
$regCount = (Invoke-SQL "SELECT COUNT(*) FROM event_planner_registrations WHERE email LIKE '%@example.com' OR email LIKE '%@test.com';").Trim()

Write-OK "Created $eventCount demo events ($activeEvents with open registration)"
Write-OK "Created $regCount test registrations"

# Show summary
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  Test Data Seeded Successfully!           " -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green

Write-Host ""
Write-Host "Demo Events Created:" -ForegroundColor White
Write-Host "  - Introduction to Python Programming (Online Workshop)"
Write-Host "  - AI Innovation Hackathon 2026 (Hackathon)"
Write-Host "  - Tech Summit 2026 (Conference)"
Write-Host "  - Cloud Computing Fundamentals (One-day Workshop)"
Write-Host "  - Advanced Machine Learning (Online Workshop)"
Write-Host "  - Web Development Bootcamp (Online Workshop)"
Write-Host "  - 2 Past/Inactive events for testing"

Write-Host ""
Write-Host "Test Registrations Created:" -ForegroundColor White
Write-Host "  - 13 sample registrations across different events"
Write-Host "  - Various colleges and departments"

Write-Host ""
Write-Host "Verify the data:" -ForegroundColor Cyan
Write-Host "  Registration Form: http://localhost:8080/event-planner/register"
Write-Host "  Events Admin:      http://localhost:8080/admin/dreamworks/event-planner/events"
Write-Host "  Registrations:     http://localhost:8080/admin/dreamworks/event-planner/registrations"
Write-Host ""
Write-Host "Commands:" -ForegroundColor Cyan
Write-Host "  .\seed-data.ps1 -Verify  - Show data statistics"
Write-Host "  .\seed-data.ps1 -Clear   - Remove test data only"
Write-Host ""
