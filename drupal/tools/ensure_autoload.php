<?php
/**
 * Ensure event_planner module is in PHP autoload before Drupal starts
 */

$autoload_file = '/opt/drupal/vendor/composer/autoload_psr4.php';

if (!file_exists($autoload_file)) {
    echo "✗ Autoload file not found: $autoload_file\n";
    exit(1);
}

$content = file_get_contents($autoload_file);

// Check if event_planner is already there
if (strpos($content, 'event_planner') !== false) {
    echo "✓ event_planner already in autoload\n";
    exit(0);
}

// Add event_planner to the PSR-4 array
// Find the Drupal\Component entry and add after it
$content = str_replace(
    "'Drupal\\\\Component\\\\' => array(\$baseDir . '/web/core/lib/Drupal/Component'),",
    "'Drupal\\\\Component\\\\' => array(\$baseDir . '/web/core/lib/Drupal/Component'),\n    'Drupal\\\\event_planner\\\\' => array(\$baseDir . '/web/modules/custom/event_planner/src'),",
    $content,
    $count
);

if ($count === 0) {
    echo "✗ Could not find Drupal\\Component entry in autoload\n";
    exit(1);
}

file_put_contents($autoload_file, $content);
echo "✓ event_planner added to autoload\n";
