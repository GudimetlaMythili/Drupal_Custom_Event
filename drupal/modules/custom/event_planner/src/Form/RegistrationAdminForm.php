<?php

declare(strict_types=1);

namespace Drupal\event_planner\Form;

use Drupal\Core\Datetime\DrupalDateTime;
use Drupal\Core\Form\FormBase;
use Drupal\Core\Form\FormStateInterface;
use Drupal\event_planner\Repository\EventRepository;
use Symfony\Component\DependencyInjection\ContainerInterface;
use Symfony\Component\HttpFoundation\Response;

/**
 * Administrative overview for registrations with CSV export.
 */
class RegistrationAdminForm extends FormBase {

  public function __construct(private readonly EventRepository $eventRepository) {}

  public static function create(ContainerInterface $container): static {
    return new static($container->get('event_planner.event_repository'));
  }

  public function getFormId(): string {
    return 'event_planner_registration_admin_form';
  }

  public function buildForm(array $form, FormStateInterface $form_state): array {
    $date_options = $this->eventRepository->getAllEventDates();
    if (!$date_options) {
      $form['empty'] = [
        '#markup' => $this->t('No registrations available yet.'),
      ];
      return $form;
    }

    $selected_date = $form_state->getValue('event_date') ?: array_key_first($date_options);
    if ($selected_date && !isset($date_options[$selected_date])) {
      $selected_date = array_key_first($date_options);
      $form_state->setValue('event_date', $selected_date);
    }

    $event_options = $selected_date ? $this->eventRepository->getEventsByDate((int) $selected_date) : [];
    $selected_event = $form_state->getValue('event_id') ?: array_key_first($event_options);
    if ($selected_event && !isset($event_options[$selected_event])) {
      $selected_event = array_key_first($event_options);
      $form_state->setValue('event_id', $selected_event);
    }

    $form['container'] = [
      '#type' => 'container',
      '#attributes' => ['id' => 'event-planner-wrapper'],
    ];

    $form['container']['filters'] = [
      '#type' => 'container',
    ];

    $form['container']['filters']['event_date'] = [
      '#type' => 'select',
      '#title' => $this->t('Event date'),
      '#options' => $date_options,
      '#default_value' => $selected_date,
      '#required' => TRUE,
      '#ajax' => [
        'callback' => '::updateAll',
        'wrapper' => 'event-planner-wrapper',
      ],
    ];

    $form['container']['filters']['event_wrapper'] = [
      '#type' => 'container',
      '#attributes' => ['id' => 'event-planner-filters'],
    ];

    $form['container']['filters']['event_wrapper']['event_id'] = [
      '#type' => 'select',
      '#title' => $this->t('Event name'),
      '#options' => $event_options,
      '#default_value' => $selected_event,
      '#required' => TRUE,
      '#ajax' => [
        'callback' => '::updateRegistrations',
        'wrapper' => 'event-planner-registrations',
      ],
    ];

    $form['container']['actions'] = ['#type' => 'actions'];
    $form['container']['actions']['export'] = [
      '#type' => 'submit',
      '#value' => $this->t('Export CSV'),
      '#submit' => ['::submitExport'],
    ];

    $form['container']['registrations'] = [
      '#type' => 'container',
      '#attributes' => ['id' => 'event-planner-registrations'],
    ];

    $filters = [
      'event_date' => $selected_date ? (int) $selected_date : NULL,
      'event_id' => $selected_event ? (int) $selected_event : NULL,
    ];
    $registrations = $this->eventRepository->getRegistrations($filters);
    $count = $this->eventRepository->countRegistrations($filters);

    $header = [
      $this->t('Name'),
      $this->t('Email'),
      $this->t('Event date'),
      $this->t('College'),
      $this->t('Department'),
      $this->t('Submission date'),
    ];

    $rows = [];
    foreach ($registrations as $registration) {
      $rows[] = [
        $registration['full_name'],
        $registration['email'],
        DrupalDateTime::createFromTimestamp($registration['event_date'])->format('Y-m-d'),
        $registration['college_name'],
        $registration['department'],
        DrupalDateTime::createFromTimestamp($registration['created'])->format('Y-m-d H:i'),
      ];
    }

    $form['container']['registrations']['count'] = [
      '#markup' => $this->t('Total participants: @total', ['@total' => $count]),
      '#prefix' => '<p>',
      '#suffix' => '</p>',
    ];

    $form['container']['registrations']['table'] = [
      '#type' => 'table',
      '#header' => $header,
      '#rows' => $rows,
      '#empty' => $this->t('No registrations found for the selected filters.'),
    ];

    return $form;
  }

  public function updateAll(array &$form, FormStateInterface $form_state): array {
    $form_state->setRebuild(TRUE);
    return $form['container'];
  }

  public function updateRegistrations(array &$form, FormStateInterface $form_state): array {
    $form_state->setRebuild(TRUE);
    return $form['container']['registrations'];
  }

  public function submitForm(array &$form, FormStateInterface $form_state): void {}

  public function submitExport(array &$form, FormStateInterface $form_state): void {
    $filters = [
      'event_date' => (int) $form_state->getValue('event_date'),
      'event_id' => (int) $form_state->getValue('event_id'),
    ];
    $registrations = $this->eventRepository->getRegistrations($filters);

    $lines = [[
      'Full Name',
      'Email',
      'Event Date',
      'Event Name',
      'Category',
      'College',
      'Department',
      'Submitted',
    ]];

    foreach ($registrations as $registration) {
      $lines[] = [
        $registration['full_name'],
        $registration['email'],
        DrupalDateTime::createFromTimestamp($registration['event_date'])->format('Y-m-d'),
        $registration['event_name'],
        $registration['category'],
        $registration['college_name'],
        $registration['department'],
        DrupalDateTime::createFromTimestamp($registration['created'])->format('Y-m-d H:i:s'),
      ];
    }

    $csv = '';
    foreach ($lines as $line) {
      $csv .= $this->escapeCsv($line) . "\r\n";
    }

    $response = new Response($csv);
    $response->headers->set('Content-Type', 'text/csv');
    $response->headers->set('Content-Disposition', 'attachment; filename="event-registrations.csv"');
    $form_state->setResponse($response);
  }

  private function escapeCsv(array $fields): string {
    $escaped = [];
    foreach ($fields as $value) {
      $value = (string) $value;
      if (str_contains($value, '"') || str_contains($value, ',') || str_contains($value, "\n")) {
        $value = '"' . str_replace('"', '""', $value) . '"';
      }
      $escaped[] = $value;
    }
    return implode(',', $escaped);
  }

}
