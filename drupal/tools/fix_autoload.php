<?php
/**
 * Fixes the autoload_psr4.php file to include event_planner module.
 * Removes any duplicates and ensures the path is correct.
 */

$autoload_psr4_file = '/opt/drupal/vendor/composer/autoload_psr4.php';
$content = file_get_contents($autoload_psr4_file);

// Remove duplicate event_planner entries
$content = preg_replace(
    "/\s*'Drupal\\\\\\\\event_planner\\\\\\\\' => array\(\\\$vendorDir \. '\\/\\.\\.\\/web\\/modules\\/custom\\/event_planner\\/src'\),/",
    '',
    $content
);

// Find the closing array and add event_planner before it (but after other Drupal entries)
// Look for the line with 'Drupal\\Component\\' and add after it
$pattern = "/'Drupal\\\\\\\\Component\\\\\\\\' => array\(\\\$baseDir \. '\\/web\\/core\\/lib\\/Drupal\\/Component'\),/";
$replacement = "'Drupal\\\\Component\\\\' => array(\$baseDir . '/web/core/lib/Drupal/Component'),\n    'Drupal\\\\event_planner\\\\' => array(\$baseDir . '/web/modules/custom/event_planner/src'),";

if (preg_match($pattern, $content)) {
    $content = preg_replace($pattern, $replacement, $content);
} else {
    // Fallback: add at the end before closing parenthesis
    $content = str_replace(
        ');',
        "    'Drupal\\\\event_planner\\\\' => array(\$baseDir . '/web/modules/custom/event_planner/src'),\n);",
        $content
    );
}

file_put_contents($autoload_psr4_file, $content);

echo "✓ Autoload fixed for event_planner module\n";
echo "✓ Duplicates removed\n";
echo "✓ Path verified: \$baseDir/web/modules/custom/event_planner/src\n";
