<?php

declare(strict_types=1);

namespace Drupal\event_planner\Repository;

use Drupal\Component\Datetime\TimeInterface;
use Drupal\Core\Database\Connection;
use Drupal\Core\Datetime\DrupalDateTime;

/**
 * Repository service for Event Planner data access.
 */
class EventRepository {

  public const TABLE_EVENTS = 'event_planner_events';
  public const TABLE_REGISTRATIONS = 'event_planner_registrations';

  private const CATEGORIES = [
    'online_workshop' => 'Online Workshop',
    'hackathon' => 'Hackathon',
    'conference' => 'Conference',
    'one_day_workshop' => 'One-day Workshop',
  ];

  public function __construct(
    private readonly Connection $database,
    private readonly TimeInterface $time,
  ) {}

  /**
   * Returns configured event categories.
   */
  public function getCategories(): array {
    return self::CATEGORIES;
  }

  /**
   * Creates a new event record.
   */
  public function createEvent(array $values): int {
    $fields = [
      'registration_start' => $values['registration_start'],
      'registration_end' => $values['registration_end'],
      'event_date' => $values['event_date'],
      'event_name' => $values['event_name'],
      'category' => $values['category'],
      'created' => $this->time->getRequestTime(),
    ];

    return (int) $this->database->insert(self::TABLE_EVENTS)
      ->fields($fields)
      ->execute();
  }

  /**
   * Returns event records.
   */
  public function getEvents(bool $active_only = FALSE): array {
    $query = $this->database->select(self::TABLE_EVENTS, 'e')
      ->fields('e')
      ->orderBy('event_date', 'ASC')
      ->orderBy('event_name', 'ASC');

    if ($active_only) {
      $now = $this->time->getRequestTime();
      $query->condition('registration_start', $now, '<=')
        ->condition('registration_end', $now, '>=');
    }

    $results = [];
    foreach ($query->execute() as $record) {
      $results[] = $this->mapEventRecord((array) $record);
    }

    return $results;
  }

  /**
   * Returns an event.
   */
  public function getEvent(int $event_id): ?array {
    $record = $this->database->select(self::TABLE_EVENTS, 'e')
      ->fields('e')
      ->condition('id', $event_id)
      ->execute()
      ->fetchAssoc();

    return $record ? $this->mapEventRecord($record) : NULL;
  }

  /**
   * Returns distinct event dates for a category.
   */
  public function getEventDatesByCategory(string $category, bool $active_only = TRUE): array {
    $query = $this->database->select(self::TABLE_EVENTS, 'e')
      ->fields('e', ['event_date'])
      ->condition('category', $category)
      ->orderBy('event_date', 'ASC')
      ->distinct();

    if ($active_only) {
      $now = $this->time->getRequestTime();
      $query->condition('registration_start', $now, '<=')
        ->condition('registration_end', $now, '>=');
    }

    $dates = [];
    foreach ($query->execute()->fetchCol() as $timestamp) {
      $dates[(string) $timestamp] = DrupalDateTime::createFromTimestamp((int) $timestamp)->format('Y-m-d');
    }

    return $dates;
  }

  /**
   * Returns event options by category and date.
   */
  public function getEventsByCategoryAndDate(string $category, int $event_date, bool $active_only = TRUE): array {
    $query = $this->database->select(self::TABLE_EVENTS, 'e')
      ->fields('e')
      ->condition('category', $category)
      ->condition('event_date', $event_date)
      ->orderBy('event_name', 'ASC');

    if ($active_only) {
      $now = $this->time->getRequestTime();
      $query->condition('registration_start', $now, '<=')
        ->condition('registration_end', $now, '>=');
    }

    $options = [];
    foreach ($query->execute() as $record) {
      $options[(int) $record->id] = (string) $record->event_name;
    }

    return $options;
  }

  /**
   * Checks if a registration exists for event date and email.
   */
  public function registrationExists(int $event_date, string $email): bool {
    $query = $this->database->select(self::TABLE_REGISTRATIONS, 'r')
      ->condition('event_date', $event_date)
      ->condition('email', $email)
      ->countQuery();

    return (bool) $query->execute()->fetchField();
  }

  /**
   * Stores a registration.
   */
  public function createRegistration(array $values): int {
    $fields = $values + ['created' => $this->time->getRequestTime()];
    return (int) $this->database->insert(self::TABLE_REGISTRATIONS)
      ->fields($fields)
      ->execute();
  }

  /**
   * Returns available categories with active registration windows.
   */
  public function getActiveCategories(): array {
    $now = $this->time->getRequestTime();
    $query = $this->database->select(self::TABLE_EVENTS, 'e')
      ->fields('e', ['category'])
      ->condition('registration_start', $now, '<=')
      ->condition('registration_end', $now, '>=')
      ->groupBy('category')
      ->orderBy('category', 'ASC');

    $map = [];
    foreach ($query->execute()->fetchCol() as $value) {
      if (isset(self::CATEGORIES[$value])) {
        $map[$value] = self::CATEGORIES[$value];
      }
    }

    return $map;
  }

  /**
   * Returns registrations matching filters.
   */
  public function getRegistrations(array $filters = []): array {
    $query = $this->database->select(self::TABLE_REGISTRATIONS, 'r')
      ->fields('r')
      ->orderBy('created', 'DESC');

    if (!empty($filters['event_date'])) {
      $query->condition('event_date', $filters['event_date']);
    }
    if (!empty($filters['event_id'])) {
      $query->condition('event_id', $filters['event_id']);
    }

    $results = [];
    foreach ($query->execute() as $record) {
      $results[] = $this->mapRegistrationRecord((array) $record);
    }

    return $results;
  }

  /**
   * Counts registrations for filters.
   */
  public function countRegistrations(array $filters = []): int {
    $query = $this->database->select(self::TABLE_REGISTRATIONS, 'r');

    // Apply conditions BEFORE calling countQuery()
    if (!empty($filters['event_date'])) {
      $query->condition('r.event_date', $filters['event_date']);
    }
    if (!empty($filters['event_id'])) {
      $query->condition('r.event_id', $filters['event_id']);
    }

    return (int) $query->countQuery()->execute()->fetchField();
  }

  /**
   * Returns distinct event dates for admin filters.
   */
  public function getAllEventDates(): array {
    $query = $this->database->select(self::TABLE_EVENTS, 'e')
      ->fields('e', ['event_date'])
      ->distinct()
      ->orderBy('event_date', 'ASC');

    $options = [];
    foreach ($query->execute()->fetchCol() as $timestamp) {
      $options[(string) $timestamp] = DrupalDateTime::createFromTimestamp((int) $timestamp)->format('Y-m-d');
    }
    return $options;
  }

  /**
   * Returns event options for a specific date.
   */
  public function getEventsByDate(int $event_date): array {
    $query = $this->database->select(self::TABLE_EVENTS, 'e')
      ->fields('e', ['id', 'event_name'])
      ->condition('event_date', $event_date)
      ->orderBy('event_name', 'ASC');

    $options = [];
    foreach ($query->execute() as $row) {
      $options[(int) $row->id] = (string) $row->event_name;
    }

    return $options;
  }

  /**
   * Helper that maps raw event DB records.
   */
  private function mapEventRecord(array $record): array {
    $record['registration_start'] = (int) $record['registration_start'];
    $record['registration_end'] = (int) $record['registration_end'];
    $record['event_date'] = (int) $record['event_date'];
    $record['created'] = (int) $record['created'];
    return $record;
  }

  /**
   * Helper that maps registration records.
   */
  private function mapRegistrationRecord(array $record): array {
    $record['event_id'] = (int) $record['event_id'];
    $record['event_date'] = (int) $record['event_date'];
    $record['created'] = (int) $record['created'];
    $record['id'] = (int) $record['id'];
    return $record;
  }

}
