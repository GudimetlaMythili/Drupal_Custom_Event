# Event Planner Module

A custom Drupal 10 module that allows users to register for events via a custom form, stores registrations, and sends email notifications.

## Overview

The Event Planner module provides a complete event registration workflow for Drupal 10:
- Administrators define events with registration windows
- End users submit registrations during the defined period
- Submissions are stored in custom database tables
- Email confirmations are sent to users and optionally to administrators
- Admin dashboard provides filtering and CSV export functionality

## Installation

### Using Podman Setup (Recommended)

The module is automatically mounted when using the provided Podman setup:

```powershell
cd c:\CH_Sourcecode\DreamWorks\event-planner
.\start.ps1
```

The startup script automatically:
1. Installs Drupal
2. Enables the event_planner module
3. Creates database tables
4. Configures email settings

### Manual Installation

1. Copy the `event_planner` directory into `web/modules/custom`
2. Ensure the database user has permission to create tables
3. Enable the module:
   ```bash
   drush en event_planner -y
   ```
4. (Optional) Import schema manually using `event_planner.sql`

## URLs

| Path | Description | Access |
|------|-------------|--------|
| `/event-planner/register` | Public registration form | Public |
| `/admin/dreamworks/event-planner/events` | Event configuration | Admin |
| `/admin/dreamworks/event-planner/registrations` | Registration listing | Admin |
| `/admin/config/dreamworks/event-planner/settings` | Module settings | Admin |

## Forms

### A. Event Configuration Form

**Path:** `/admin/dreamworks/event-planner/events`
**Permission:** `administer event planner`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| Event Name | textfield | Yes | Name of the event |
| Category | select | Yes | Online Workshop, Hackathon, Conference, One-day Workshop |
| Registration Start | datetime | Yes | When registration opens |
| Registration End | datetime | Yes | When registration closes |
| Event Date | date | Yes | Date of the event |

### B. Event Registration Form

**Path:** `/event-planner/register`
**Access:** Public (only available during registration window)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| Full Name | textfield | Yes | Registrant's full name |
| Email Address | email | Yes | Registrant's email |
| College Name | textfield | Yes | College/institution name |
| Department | textfield | Yes | Department name |
| Category | select | Yes | AJAX - fetched from active events |
| Event Date | select | Yes | AJAX - filtered by selected category |
| Event Name | select | Yes | AJAX - filtered by category and date |

### C. Settings Form

**Path:** `/admin/config/dreamworks/event-planner/settings`
**Permission:** `administer event planner`

| Field | Type | Description |
|-------|------|-------------|
| Admin notification email | email | Email address for admin notifications |
| Enable admin notifications | checkbox | Toggle admin email alerts |

### D. Registration Admin Form

**Path:** `/admin/dreamworks/event-planner/registrations`
**Permission:** `access event registrations overview`

- Event Date dropdown filter
- Event Name dropdown filter (AJAX based on date)
- Total participants count
- Tabular display of registrations
- CSV Export button

## Database Tables

### event_planner_events

```sql
CREATE TABLE event_planner_events (
  id SERIAL PRIMARY KEY,
  registration_start INTEGER NOT NULL,
  registration_end INTEGER NOT NULL,
  event_date INTEGER NOT NULL,
  event_name VARCHAR(255) NOT NULL,
  category VARCHAR(64) NOT NULL,
  created INTEGER NOT NULL
);
```

### event_planner_registrations

```sql
CREATE TABLE event_planner_registrations (
  id SERIAL PRIMARY KEY,
  event_id INTEGER NOT NULL,
  full_name VARCHAR(255) NOT NULL,
  email VARCHAR(255) NOT NULL,
  college_name VARCHAR(255) NOT NULL,
  department VARCHAR(255) NOT NULL,
  category VARCHAR(64) NOT NULL,
  event_date INTEGER NOT NULL,
  event_name VARCHAR(255) NOT NULL,
  created INTEGER NOT NULL
);
```

## Validation Rules

### Text Fields (Full Name, College Name, Department)
- Required
- Only letters, numbers, and spaces allowed
- Regex: `/^[A-Za-z0-9 ]+$/`
- Error: "Field may only contain letters, numbers, and spaces."

### Email Address
- Required
- Valid email format (Drupal's email validation)

### Duplicate Prevention
- Combination of Email + Event Date must be unique
- Error: "You have already registered for an event on [date]."

### Registration Window
- Form only displays if current time is within registration start/end
- Message: "Registrations are currently closed. Please check back later."

## Email Notifications

### Using Drupal Mail API

Emails are sent using `hook_mail()` in `event_planner.module`:

```php
function event_planner_mail(string $key, array &$message, array $params): void {
  switch ($key) {
    case 'user_confirmation':
      // User confirmation email
      break;
    case 'admin_notification':
      // Admin notification email
      break;
  }
}
```

### Email Content

**User Confirmation:**
- Subject: "Event registration confirmation: [Event Name]"
- Body: Name, Event Name, Category, Event Date

**Admin Notification:**
- Subject: "New event registration: [Event Name]"
- Body: Name, Email, Category, Event Date, Event Name, College, Department

### Email Service

`EmailNotificationService` handles sending:

```php
class EmailNotificationService {
  public function notify(array $registration, string $category_label): void {
    // Send user confirmation
    $this->mailManager->mail('event_planner', 'user_confirmation', ...);
    
    // Send admin notification if enabled
    if ($config->get('notify_admin')) {
      $this->mailManager->mail('event_planner', 'admin_notification', ...);
    }
  }
}
```

## Configuration

### Config API

Settings are stored using Drupal's Configuration API:

**Schema:** `config/schema/event_planner.schema.yml`
```yaml
event_planner.settings:
  type: config_object
  mapping:
    admin_notification_email:
      type: email
    notify_admin:
      type: boolean
```

**Default values:** `config/install/event_planner.settings.yml`
```yaml
admin_notification_email: ''
notify_admin: true
```

## Permissions

Defined in `event_planner.permissions.yml`:

| Permission | Title | Description |
|------------|-------|-------------|
| `administer event planner` | Administer Event Planner | Manage configuration and events |
| `access event registrations overview` | Access Event Registrations Overview | View and export registrations |

## Services

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

## Technical Constraints Met

- [x] Drupal 10.x compatible
- [x] No contrib modules used
- [x] PSR-4 autoloading
- [x] Dependency Injection (no `\Drupal::service()` in business logic)
- [x] Drupal coding standards
- [x] Custom database tables
- [x] Form API for all forms
- [x] AJAX callbacks for cascading dropdowns
- [x] Config API for settings
- [x] Drupal Mail API for notifications
- [x] Custom permissions
- [x] CSV export functionality

## File Structure

```
event_planner/
├── config/
│   ├── install/
│   │   └── event_planner.settings.yml
│   └── schema/
│       └── event_planner.schema.yml
├── src/
│   ├── Form/
│   │   ├── EventConfigForm.php
│   │   ├── EventRegistrationForm.php
│   │   ├── EventSettingsForm.php
│   │   └── RegistrationAdminForm.php
│   ├── Repository/
│   │   └── EventRepository.php
│   └── Service/
│       └── EmailNotificationService.php
├── event_planner.info.yml
├── event_planner.install
├── event_planner.links.menu.yml
├── event_planner.module
├── event_planner.permissions.yml
├── event_planner.routing.yml
├── event_planner.services.yml
├── event_planner.sql
└── README.md
```

## Development

### Clear Cache

```bash
drush cr
```

### Check Module Status

```bash
drush pm:list --status=enabled | grep event_planner
```

### Database Queries

```sql
-- View all events
SELECT * FROM event_planner_events;

-- View all registrations
SELECT * FROM event_planner_registrations;

-- Count registrations per event
SELECT event_name, COUNT(*) as count 
FROM event_planner_registrations 
GROUP BY event_name;
```

## License

DreamWorks Event Planner - Internal Use
