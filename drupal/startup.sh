#!/bin/bash
set -euo pipefail

echo "======================================"
echo "DreamWorks Event Planner - Starting"
echo "======================================"
echo ""

# Get database host from environment
DB_HOST="${DRUPAL_DB_HOST:-db}"
DB_PORT="${DRUPAL_DB_PORT:-5432}"
DB_NAME="${DRUPAL_DB_NAME:-drupal}"
DB_USER="${DRUPAL_DB_USER:-drupal}"
DB_PASS="${DRUPAL_DB_PASSWORD:-drupal}"

# Email configuration
MAIL_MODE="${MAIL_MODE:-mailhog}"

echo "Configuration:"
echo "  Database: ${DB_USER}@${DB_HOST}:${DB_PORT}/${DB_NAME}"
echo "  Mail Mode: ${MAIL_MODE}"
echo ""

# Install required tools
echo "Installing required tools..."
apt-get update -qq
apt-get install -y -qq msmtp msmtp-mta postgresql-client ca-certificates > /dev/null 2>&1 || true
echo "  [OK] Tools installed"

# Wait for database to be ready
echo ""
echo "Waiting for database..."
RETRIES=30
until pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" 2>/dev/null || [ $RETRIES -eq 0 ]; do
    echo "  Waiting for PostgreSQL at ${DB_HOST}:${DB_PORT}... ($((RETRIES--)) attempts left)"
    sleep 2
done

if [ $RETRIES -eq 0 ]; then
    echo "  [ERROR] Database not ready after 30 attempts"
    exit 1
fi
echo "  [OK] Database is ready"

# Ensure event_planner is in composer autoload
echo ""
echo "Configuring autoload for event_planner module..."
if [ -f /opt/drupal-tools/ensure_autoload.php ]; then
    php /opt/drupal-tools/ensure_autoload.php || echo "  [WARNING] Autoload configuration skipped"
fi

# ============================================
# EMAIL CONFIGURATION
# ============================================
echo ""
echo "Configuring mail system (${MAIL_MODE})..."

case "${MAIL_MODE}" in
    gmail)
        GMAIL_USER="${GMAIL_USER:-}"
        GMAIL_APP_PASSWORD="${GMAIL_APP_PASSWORD:-}"
        
        if [ -z "$GMAIL_USER" ] || [ -z "$GMAIL_APP_PASSWORD" ]; then
            echo "  [ERROR] Gmail credentials not set. Set GMAIL_USER and GMAIL_APP_PASSWORD in .env"
            echo "  Falling back to MailHog..."
            MAIL_MODE="mailhog"
        else
            cat > /etc/msmtprc << EOF
defaults
auth on
tls on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile /tmp/msmtp.log

account gmail
host smtp.gmail.com
port 587
from ${GMAIL_USER}
user ${GMAIL_USER}
password ${GMAIL_APP_PASSWORD}

account default : gmail
EOF
            echo "  [OK] Gmail SMTP configured"
            echo "  [OK] Sending from: ${GMAIL_USER}"
        fi
        ;;
        
    outlook)
        OUTLOOK_USER="${OUTLOOK_USER:-}"
        OUTLOOK_PASSWORD="${OUTLOOK_PASSWORD:-}"
        
        if [ -z "$OUTLOOK_USER" ] || [ -z "$OUTLOOK_PASSWORD" ]; then
            echo "  [ERROR] Outlook credentials not set. Set OUTLOOK_USER and OUTLOOK_PASSWORD in .env"
            echo "  Falling back to MailHog..."
            MAIL_MODE="mailhog"
        else
            cat > /etc/msmtprc << EOF
defaults
auth on
tls on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile /tmp/msmtp.log

account outlook
host smtp.office365.com
port 587
from ${OUTLOOK_USER}
user ${OUTLOOK_USER}
password ${OUTLOOK_PASSWORD}

account default : outlook
EOF
            echo "  [OK] Outlook SMTP configured"
            echo "  [OK] Sending from: ${OUTLOOK_USER}"
        fi
        ;;
        
    sendgrid)
        SENDGRID_API_KEY="${SENDGRID_API_KEY:-}"
        SMTP_FROM="${SMTP_FROM:-noreply@dreamworks.local}"
        
        if [ -z "$SENDGRID_API_KEY" ]; then
            echo "  [ERROR] SendGrid API key not set. Set SENDGRID_API_KEY in .env"
            echo "  Falling back to MailHog..."
            MAIL_MODE="mailhog"
        else
            cat > /etc/msmtprc << EOF
defaults
auth on
tls on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile /tmp/msmtp.log

account sendgrid
host smtp.sendgrid.net
port 587
from ${SMTP_FROM}
user apikey
password ${SENDGRID_API_KEY}

account default : sendgrid
EOF
            echo "  [OK] SendGrid SMTP configured"
            echo "  [OK] Sending from: ${SMTP_FROM}"
        fi
        ;;
        
    custom)
        SMTP_HOST="${SMTP_HOST:-}"
        SMTP_PORT="${SMTP_PORT:-587}"
        SMTP_USER="${SMTP_USER:-}"
        SMTP_PASSWORD="${SMTP_PASSWORD:-}"
        SMTP_FROM="${SMTP_FROM:-noreply@dreamworks.local}"
        SMTP_TLS="${SMTP_TLS:-on}"
        
        if [ -z "$SMTP_HOST" ] || [ -z "$SMTP_USER" ]; then
            echo "  [ERROR] Custom SMTP settings incomplete. Set SMTP_HOST, SMTP_USER, etc. in .env"
            echo "  Falling back to MailHog..."
            MAIL_MODE="mailhog"
        else
            cat > /etc/msmtprc << EOF
defaults
auth on
tls ${SMTP_TLS}
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile /tmp/msmtp.log

account custom
host ${SMTP_HOST}
port ${SMTP_PORT}
from ${SMTP_FROM}
user ${SMTP_USER}
password ${SMTP_PASSWORD}

account default : custom
EOF
            echo "  [OK] Custom SMTP configured"
            echo "  [OK] Host: ${SMTP_HOST}:${SMTP_PORT}"
            echo "  [OK] Sending from: ${SMTP_FROM}"
        fi
        ;;
        
    mailhog|*)
        # Get MailHog host from MAILER_DSN or default
        if [[ "${MAILER_DSN:-}" =~ smtp://([^:]+): ]]; then
            MAILHOG_HOST="${BASH_REMATCH[1]}"
        else
            MAILHOG_HOST="mailhog"
        fi
        
        cat > /etc/msmtprc << EOF
defaults
auth off
tls off
logfile /tmp/msmtp.log

account mailhog
host ${MAILHOG_HOST}
port 1025
from noreply@dreamworks.local

account default : mailhog
EOF
        echo "  [OK] MailHog configured (testing mode)"
        echo "  [OK] View emails at: http://localhost:8025"
        ;;
esac

chmod 600 /etc/msmtprc
echo "sendmail_path = \"/usr/bin/msmtp -t\"" > /usr/local/etc/php/conf.d/sendmail.ini

# Set up file system
echo ""
echo "Setting up file system..."
mkdir -p /var/www/private /var/www/html/sites/default/files
chown -R www-data:www-data /var/www/private /var/www/html/sites/default/files 2>/dev/null || true
chmod -R 775 /var/www/private /var/www/html/sites/default/files 2>/dev/null || true
echo "  [OK] File system ready"

# ============================================
# AUTOMATED DRUPAL INSTALLATION
# ============================================
echo ""
echo "======================================"
echo "Checking Drupal Installation Status"
echo "======================================"

SITE_INSTALLED=false

# Check if Drupal is already installed
if [ -f /var/www/html/sites/default/settings.php ]; then
    TABLE_CHECK=$(PGPASSWORD="${DB_PASS}" psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -tAc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users';" 2>/dev/null || echo "0")
    if [ "$TABLE_CHECK" = "1" ]; then
        echo "  [OK] Drupal is already installed"
        SITE_INSTALLED=true
    fi
fi

if [ "$SITE_INSTALLED" = false ]; then
    echo "  [INFO] Drupal not installed. Starting automated installation..."
    echo ""
    
    # Install Drush
    echo "Installing Drush..."
    cd /opt/drupal
    composer require drush/drush -W --no-interaction 2>&1 | tail -5
    echo "  [OK] Drush installed"
    
    # Make settings.php writable for installation
    chmod 666 /var/www/html/sites/default/settings.php 2>/dev/null || true
    chmod 777 /var/www/html/sites/default 2>/dev/null || true
    
    # Run Drupal installation
    echo ""
    echo "Installing Drupal (this may take a few minutes)..."
    cd /opt/drupal
    ./vendor/bin/drush site:install standard \
        --db-url="pgsql://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${DB_NAME}" \
        --site-name="DreamWorks Event Planner" \
        --account-name="admin" \
        --account-pass="admin" \
        --account-mail="admin@dreamworks.local" \
        --locale="en" \
        --yes \
        2>&1 | while read line; do echo "  $line"; done
    
    echo "  [OK] Drupal installed successfully"
    SITE_INSTALLED=true
    
    # Restore permissions
    chmod 444 /var/www/html/sites/default/settings.php 2>/dev/null || true
    chmod 555 /var/www/html/sites/default 2>/dev/null || true
fi

# ============================================
# ENABLE EVENT PLANNER MODULE
# ============================================
if [ "$SITE_INSTALLED" = true ]; then
    echo ""
    echo "======================================"
    echo "Enabling Event Planner Module"
    echo "======================================"
    
    cd /opt/drupal
    
    # Check if drush exists
    if [ ! -f ./vendor/bin/drush ]; then
        echo "  [INFO] Installing Drush..."
        composer require drush/drush -W --no-interaction 2>&1 | tail -3
    fi
    
    # Check if module is already enabled
    MODULE_ENABLED=$(./vendor/bin/drush pm:list --status=enabled --format=list 2>/dev/null | grep -c "event_planner" || echo "0")
    
    if [ "$MODULE_ENABLED" = "0" ]; then
        echo "  [INFO] Enabling event_planner module..."
        ./vendor/bin/drush pm:enable event_planner --yes 2>&1 | while read line; do echo "  $line"; done
        echo "  [OK] Event Planner module enabled"
    else
        echo "  [OK] Event Planner module already enabled"
    fi
    
    # Clear cache
    echo ""
    echo "Clearing Drupal cache..."
    ./vendor/bin/drush cr 2>/dev/null || true
    echo "  [OK] Cache cleared"
fi

# ============================================
# FINAL OUTPUT
# ============================================
echo ""
echo "======================================"
echo "Setup Complete!"
echo "======================================"
echo ""
echo "Access URLs:"
echo "  Drupal:        http://localhost:8080"
echo "  Admin Login:   http://localhost:8080/user/login"
echo "                 Username: admin"
echo "                 Password: admin"
echo ""
echo "Event Planner URLs:"
echo "  Register:      http://localhost:8080/event-planner/register"
echo "  Manage Events: http://localhost:8080/admin/dreamworks/event-planner/events"
echo "  Registrations: http://localhost:8080/admin/dreamworks/event-planner/registrations"
echo "  Settings:      http://localhost:8080/admin/config/dreamworks/event-planner/settings"
echo ""
echo "Email Mode: ${MAIL_MODE}"
if [ "${MAIL_MODE}" = "mailhog" ]; then
    echo "  MailHog UI:  http://localhost:8025"
else
    echo "  Emails will be sent to real recipients!"
fi
echo "======================================"
echo ""
echo "Starting Apache..."

# Start Apache
exec apache2-foreground
