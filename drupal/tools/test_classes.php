<?php
require '/opt/drupal/vendor/autoload.php';

$classes = [
    'Drupal\event_planner\Form\EventRegistrationForm',
    'Drupal\event_planner\Form\EventConfigForm',
    'Drupal\event_planner\Repository\EventRepository',
    'Drupal\event_planner\Service\EmailNotificationService'
];

foreach ($classes as $class) {
    $exists = class_exists($class);
    echo "Class $class: " . ($exists ? "FOUND" : "NOT FOUND") . "\n";
}
