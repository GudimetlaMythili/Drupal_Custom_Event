# DreamWorks Event Planner

A complete event management system built with Drupal 10, PostgreSQL, and MailHog for email testing, running on Podman containers for Windows.

## Table of Contents
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
  - [Test Data Seeding](#test-data-seeding)
- [Accessing the Application](#accessing-the-application)
- [Event Planner Module](#event-planner-module)
- [Database Tables](#database-tables)
- [Validation & Business Rules](#validation--business-rules)
- [Email Configuration](#email-configuration)
- [Admin Features](#admin-features)
- [Technical Details](#technical-details)
- [Troubleshooting](#troubleshooting)
- [Development](#development)

---

## Project Structure

```
event-planner/
├── drupal/                              # Drupal application files
│   ├── modules/custom/event_planner/    # Custom event management module
│   │   ├── src/
│   │   │   ├── Form/
│   │   │   │   ├── EventConfigForm.php        # Admin event configuration
│   │   │   │   ├── EventRegistrationForm.php  # Public registration form
│   │   │   │   ├── EventSettingsForm.php      # Module settings
│   │   │   │   └── RegistrationAdminForm.php  # Admin registrations list
│   │   │   ├── Repository/
│   │   │   │   └── EventRepository.php        # Database access layer
│   │   │   └── Service/
│   │   │       └── EmailNotificationService.php  # Email handling
│   │   ├── config/
│   │   │   ├── install/
│   │   │   │   └── event_planner.settings.yml
│   │   │   └── schema/
│   │   │       └── event_planner.schema.yml
│   │   ├── event_planner.info.yml
│   │   ├── event_planner.install
│   │   ├── event_planner.module
│   │   ├── event_planner.permissions.yml
│   │   ├── event_planner.routing.yml
│   │   ├── event_planner.services.yml
│   │   ├── event_planner.sql
│   │   └── README.md
│   ├── config/sync/                     # Drupal configuration sync
│   ├── tools/                           # PHP utility scripts
│   ├── settings.php                     # Drupal database settings
│   └── startup.sh                       # Container startup script
├── mailhog/                             # MailHog configuration
├── podman-compose.yml                   # Podman/Docker compose file
├── .env                                 # Environment variables
├── .gitignore                           # Git ignore rules
├── start.ps1                            # Start containers (Windows)
├── stop.ps1                             # Stop containers (Windows)
├── logs.ps1                             # View container logs (Windows)
├── status.ps1                           # Check container status (Windows)
├── seed-data.ps1                        # Seed test data for verification
└── README.md                            # This file
```

---

## Prerequisites

### Windows Setup

1. **Install Podman Desktop** from https://podman-desktop.io/

2. **Initialize Podman machine** (run in PowerShell as Administrator):
   ```powershell
   podman machine init
   podman machine start
   ```

3. **Install podman-compose** (recommended):
   ```powershell
   pip install podman-compose
   ```

---

## Quick Start

### Option 1: Using PowerShell Scripts (Recommended)

```powershell
cd c:\CH_Sourcecode\DreamWorks\event-planner

# Start all services (automated Drupal installation)
.\start.ps1

# Check status
.\status.ps1

# View logs
.\logs.ps1

# Stop all services
.\stop.ps1

# Force recreate containers
.\start.ps1 -Force

# Stop and remove all data
.\stop.ps1 -RemoveVolumes

# Seed test data for verification
.\seed-data.ps1

# Verify data statistics
.\seed-data.ps1 -Verify

# Clear only test data
.\seed-data.ps1 -Clear
```

### Test Data Seeding

The `seed-data.ps1` script populates the database with sample events and registrations for testing:

**Demo Events Created (8 total):**
- Introduction to Python Programming (Online Workshop)
- AI Innovation Hackathon 2026 (Hackathon)
- Tech Summit 2026 (Conference)
- Cloud Computing Fundamentals (One-day Workshop)
- Advanced Machine Learning (Online Workshop)
- Web Development Bootcamp (Online Workshop)
- 2 Past/Inactive events for admin listing testing

**Test Registrations Created (13 total):**
- Sample users from various colleges (MIT, Stanford, Harvard, Caltech, etc.)
- Registrations across different event categories and dates
- Test emails using `@example.com` and `@test.com` domains

### Option 2: Using podman-compose

```powershell
cd event-planner
podman-compose up -d
podman-compose down
```

---

## Accessing the Application

### Service URLs

| Service | URL | Description |
|---------|-----|-------------|
| Drupal | http://localhost:8080 | Main application |
| Admin Login | http://localhost:8080/user/login | Login page |
| MailHog UI | http://localhost:8025 | Email testing interface |

### Default Credentials

| Account | Username | Password |
|---------|----------|----------|
| Drupal Admin | `admin` | `admin` |
| Database | `drupal` | `drupal` |

### Event Planner URLs

| Path | Description | Access |
|------|-------------|--------|
| `/event-planner/register` | Public registration form | Public |
| `/admin/dreamworks/event-planner/events` | Manage events | Admin |
| `/admin/dreamworks/event-planner/registrations` | View registrations | Admin |
| `/admin/config/dreamworks/event-planner/settings` | Module settings | Admin |

---

## Event Planner Module

### Features

- **Event Configuration:** Admins can create events with registration windows
- **Public Registration:** Users can register for events via a custom form
- **AJAX Dropdowns:** Category → Date → Event cascading selection
- **Duplicate Prevention:** Prevents same email registering for same event date
- **Email Notifications:** Confirmation emails to users and optional admin notifications
- **Admin Dashboard:** View, filter, and export registrations
- **CSV Export:** Export registration data with all fields

### A. Event Configuration Form (Admin)

Accessible at `/admin/dreamworks/event-planner/events`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| Event Name | Text | Yes | Name of the event |
| Category | Dropdown | Yes | Online Workshop, Hackathon, Conference, One-day Workshop |
| Registration Start | DateTime | Yes | When registration opens |
| Registration End | DateTime | Yes | When registration closes |
| Event Date | Date | Yes | Date of the event |

### B. Event Registration Form (Public)

Accessible at `/event-planner/register` (only during registration window)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| Full Name | Text | Yes | Registrant's full name |
| Email Address | Email | Yes | Registrant's email |
| College Name | Text | Yes | College/institution name |
| Department | Text | Yes | Department name |
| Category | Dropdown | Yes | Fetched from admin-configured events |
| Event Date | Dropdown | Yes | AJAX-filtered by category |
| Event Name | Dropdown | Yes | AJAX-filtered by category and date |

---

## Database Tables

### event_planner_events

Stores event configurations created by administrators.

| Column | Type | Description |
|--------|------|-------------|
| id | SERIAL | Primary key |
| registration_start | INTEGER | Registration start timestamp |
| registration_end | INTEGER | Registration end timestamp |
| event_date | INTEGER | Event date timestamp |
| event_name | VARCHAR(255) | Event name |
| category | VARCHAR(64) | Event category |
| created | INTEGER | Record creation timestamp |

### event_planner_registrations

Stores registration submissions from users.

| Column | Type | Description |
|--------|------|-------------|
| id | SERIAL | Primary key |
| event_id | INTEGER | Foreign key to events table |
| full_name | VARCHAR(255) | Registrant's full name |
| email | VARCHAR(255) | Registrant's email |
| college_name | VARCHAR(255) | College name |
| department | VARCHAR(255) | Department |
| category | VARCHAR(64) | Event category (snapshot) |
| event_date | INTEGER | Event date timestamp (snapshot) |
| event_name | VARCHAR(255) | Event name (snapshot) |
| created | INTEGER | Submission timestamp |

SQL schema is available in `drupal/modules/custom/event_planner/event_planner.sql`

---

## Validation & Business Rules

### Registration Form Validation

1. **Required Fields:** All fields are mandatory
2. **Email Format:** Standard email validation
3. **Special Characters:** Text fields only allow letters, numbers, and spaces
   - Regex: `/^[A-Za-z0-9 ]+$/`
4. **Duplicate Prevention:** Same email cannot register for the same event date
5. **Registration Window:** Form only available during the configured registration period

### User-Friendly Messages

- "Full name may only contain letters, numbers, and spaces."
- "You have already registered for an event on [date]."
- "Registrations are currently closed. Please check back later."

---

## Email Configuration

### Email Modes

Configure in `.env` file by setting `MAIL_MODE`:

| Mode | Description |
|------|-------------|
| `mailhog` | Testing mode - emails captured in MailHog UI (default) |
| `gmail` | Send via Gmail SMTP |
| `outlook` | Send via Outlook/Office 365 SMTP |
| `sendgrid` | Send via SendGrid API |
| `custom` | Custom SMTP server |

### MailHog (Default - Testing)

```env
MAIL_MODE=mailhog
```
- View all emails at: http://localhost:8025
- No real emails sent

### Gmail Configuration

```env
MAIL_MODE=gmail
GMAIL_USER=your-email@gmail.com
GMAIL_APP_PASSWORD=your-16-char-app-password
```

**Note:** Requires App Password from https://myaccount.google.com/apppasswords

### Outlook Configuration

```env
MAIL_MODE=outlook
OUTLOOK_USER=your-email@outlook.com
OUTLOOK_PASSWORD=your-password
```

### SendGrid Configuration

```env
MAIL_MODE=sendgrid
SENDGRID_API_KEY=SG.xxxxxxxxxxxxxx
SMTP_FROM=noreply@yourdomain.com
```

### Custom SMTP

```env
MAIL_MODE=custom
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USER=your-username
SMTP_PASSWORD=your-password
SMTP_FROM=noreply@example.com
SMTP_TLS=on
```

### Email Content

**User Confirmation Email:**
- Subject: "Event registration confirmation: [Event Name]"
- Body: Name, Event Name, Category, Event Date

**Admin Notification Email:**
- Subject: "New event registration: [Event Name]"
- Body: Name, Email, Category, Event Date, Event Name, College, Department

---

## Admin Features

### Settings Page

`/admin/config/dreamworks/event-planner/settings`

- **Admin notification email:** Email address for admin notifications
- **Enable/disable admin notifications:** Toggle admin email alerts

### Registration Listing

`/admin/dreamworks/event-planner/registrations`

- **Filter by Event Date:** Dropdown with all event dates
- **Filter by Event Name:** AJAX dropdown based on selected date
- **Total Participants:** Count of registrations matching filters
- **Table Display:** Name, Email, Event Date, College, Department, Submission Date
- **CSV Export:** Download all matching registrations

### Permissions

| Permission | Description |
|------------|-------------|
| `administer event planner` | Manage events and settings |
| `access event registrations overview` | View and export registrations |

---

## Technical Details

### Technology Stack

- **CMS:** Drupal 10.x
- **Database:** PostgreSQL 15
- **Email Testing:** MailHog
- **Containers:** Podman (Docker-compatible)
- **Language:** PHP 8.4

### Drupal Coding Standards

- **PSR-4 Autoloading:** All classes under `src/` directory
- **Dependency Injection:** Services injected via constructors
- **No `\Drupal::service()`:** In business logic classes
- **Form API:** Custom forms using Drupal Form API
- **Database API:** Drupal's database abstraction layer
- **Config API:** Settings stored in configuration

### Services

Defined in `event_planner.services.yml`:

```yaml
services:
  event_planner.event_repository:
    class: 'Drupal\event_planner\Repository\EventRepository'
    arguments: ['@database', '@datetime.time']

  event_planner.email_notifier:
    class: 'Drupal\event_planner\Service\EmailNotificationService'
    arguments: ['@plugin.manager.mail', '@config.factory', '@current_user']
```

---

## Troubleshooting

### Podman Machine Not Running

```powershell
podman machine start
```

### Container Won't Start

```powershell
# Check logs
podman logs event-planner-drupal

# Recreate containers
.\stop.ps1
.\start.ps1 -Force
```

### Database Connection Issues

```powershell
# Check if database is running
podman exec event-planner-db pg_isready -U drupal

# Access database directly
podman exec -it event-planner-db psql -U drupal -d drupal
```

### Clear Drupal Cache

```powershell
podman exec event-planner-drupal bash -c "cd /opt/drupal && ./vendor/bin/drush cr"
```

### Reset Everything

```powershell
.\stop.ps1 -RemoveVolumes
.\start.ps1
```

### Network Issues

```powershell
podman network rm event_planner_network
podman network create event_planner_network
.\start.ps1
```

---

## Development

### Modifying the Event Planner Module

The module is mounted from `drupal/modules/custom/event_planner`. Changes are reflected immediately after cache clear:

```powershell
podman exec event-planner-drupal bash -c "cd /opt/drupal && ./vendor/bin/drush cr"
```

### Database Access

```powershell
# Connect to PostgreSQL
podman exec -it event-planner-db psql -U drupal -d drupal

# View tables
\dt

# Query events
SELECT * FROM event_planner_events;

# Query registrations
SELECT * FROM event_planner_registrations;
```

### View Container Logs

```powershell
# All logs
.\logs.ps1

# Follow specific container
podman logs -f event-planner-drupal
```

### File Locations Inside Container

| Path | Description |
|------|-------------|
| `/opt/drupal` | Drupal root |
| `/var/www/html` | Web root |
| `/var/www/html/modules/custom/event_planner` | Module directory |
| `/opt/drupal/vendor/bin/drush` | Drush executable |

---

## Container Details

### Containers

| Container | Image | Ports |
|-----------|-------|-------|
| event-planner-drupal | drupal:10-apache | 8080:80 |
| event-planner-db | postgres:15 | - |
| event-planner-mailhog | mailhog/mailhog | 1025:1025, 8025:8025 |

### Volumes

| Volume | Purpose |
|--------|---------|
| event_planner_db_data | PostgreSQL data |
| event_planner_drupal_files | Drupal public files |
| event_planner_drupal_private | Drupal private files |

### Network

All containers are connected via `event_planner_network` bridge network.

---

## License

DreamWorks Event Planner - Internal Use
