<?php
/**
 * Add event_planner module to Composer autoload configuration
 */

$composer_file = '/opt/drupal/composer.json';
$json = json_decode(file_get_contents($composer_file), true);

// Ensure autoload.psr-4 exists
if (!isset($json['autoload'])) {
    $json['autoload'] = ['psr-4' => []];
}
if (!isset($json['autoload']['psr-4'])) {
    $json['autoload']['psr-4'] = [];
}

// Add event_planner module
$json['autoload']['psr-4']['Drupal\\event_planner\\'] = 'web/modules/custom/event_planner/src/';

// Write back to file
file_put_contents($composer_file, json_encode($json, JSON_UNESCAPED_SLASHES | JSON_PRETTY_PRINT) . "\n");

echo "✓ Added event_planner to composer.json\n";
echo "✓ Now run: composer dump-autoload -o\n";
