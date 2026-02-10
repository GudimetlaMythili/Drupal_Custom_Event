<?php

/**
 * @file
 * DreamWorks Event Planner - Drupal settings
 * 
 * This configuration supports both podman-compose and manual Podman setups.
 * Environment variables are used for all connection settings.
 */

include $app_root . '/' . $site_path . '/default.settings.php';

// Database configuration - supports both 'db' (compose) and 'event-planner-db' (manual)
$databases['default']['default'] = [
    'database' => getenv('DRUPAL_DB_NAME') ?: 'drupal',
    'username' => getenv('DRUPAL_DB_USER') ?: 'drupal',
    'password' => getenv('DRUPAL_DB_PASSWORD') ?: 'drupal',
    'prefix' => '',
    'host' => getenv('DRUPAL_DB_HOST') ?: 'db',
    'port' => getenv('DRUPAL_DB_PORT') ?: '5432',
    'namespace' => 'Drupal\\pgsql\\Driver\\Database\\pgsql',
    'driver' => 'pgsql',
    'autoload' => 'core/modules/pgsql/src/Driver/Database/pgsql/',
];

// Security settings
$settings['hash_salt'] = getenv('DRUPAL_HASH_SALT') ?: 'event-planner-salt-change-in-production';
$settings['update_free_access'] = FALSE;

// Configuration sync directory
$settings['config_sync_directory'] = getenv('DRUPAL_CONFIG_SYNC_DIR') ?: '/var/www/html/config/sync';

// Private files path
$settings['file_private_path'] = getenv('DRUPAL_PRIVATE_FILES_PATH') ?: '/var/www/private';

// Trusted host patterns for Podman/container access
$settings['trusted_host_patterns'] = [
    '^localhost$',
    '^127\\.0\\.0\\.1$',
    '^\[::1\]$',
    '^drupal$',
    '^event-planner-drupal$',
    // Add your domain when deploying to production
];

// Performance settings
$settings['container_yamls'][] = $app_root . '/' . $site_path . '/services.yml';

// Load local settings if present (for development overrides)
if (file_exists($app_root . '/' . $site_path . '/settings.local.php')) {
    include $app_root . '/' . $site_path . '/settings.local.php';
}
