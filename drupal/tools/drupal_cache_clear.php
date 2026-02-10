<?php

/**
 * Drupal cache clear script using Drupal's API.
 * This properly rebuilds all caches including the class registry.
 */

use Drupal\Core\DrupalKernel;
use Symfony\Component\HttpFoundation\Request;

$autoloader = require_once '/opt/drupal/vendor/autoload.php';

$request = Request::createFromGlobals();
$kernel = DrupalKernel::createFromRequest($request, $autoloader, 'prod');
$kernel->boot();

// Get the container
$container = $kernel->getContainer();

// Clear all caches
\Drupal::service('cache.bootstrap')->deleteAll();
\Drupal::service('cache.config')->deleteAll();
\Drupal::service('cache.data')->deleteAll();
\Drupal::service('cache.default')->deleteAll();
\Drupal::service('cache.discovery')->deleteAll();
\Drupal::service('cache.entity')->deleteAll();
\Drupal::service('cache.render')->deleteAll();

// Rebuild router
\Drupal::service('router.builder')->rebuild();

// Invalidate container
\Drupal::service('kernel')->invalidateContainer();

echo "Drupal cache cleared successfully using Drupal API\n";
