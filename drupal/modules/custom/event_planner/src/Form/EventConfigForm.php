<?php

declare(strict_types=1);

namespace Drupal\event_planner\Form;

use Drupal\Core\Datetime\DrupalDateTime;
use Drupal\Core\Form\FormBase;
use Drupal\Core\Form\FormStateInterface;
use Drupal\event_planner\Repository\EventRepository;
use Symfony\Component\DependencyInjection\ContainerInterface;

/**
 * Administrative form for creating event configurations.
 */
class EventConfigForm extends FormBase {

  public function __construct(private readonly EventRepository $eventRepository) {}

  public static function create(ContainerInterface $container): static {
    return new static($container->get('event_planner.event_repository'));
  }

  public function getFormId(): string {
    return 'event_planner_event_config_form';
  }

  public function buildForm(array $form, FormStateInterface $form_state): array {
    $form['event_name'] = [
      '#type' => 'textfield',
      '#title' => $this->t('Event name'),
      '#required' => TRUE,
      '#maxlength' => 255,
    ];

    $form['category'] = [
      '#type' => 'select',
      '#title' => $this->t('Category'),
      '#required' => TRUE,
      '#options' => $this->eventRepository->getCategories(),
      '#empty_option' => $this->t('- Select -'),
    ];

    $form['registration_start'] = [
      '#type' => 'datetime',
      '#title' => $this->t('Registration start'),
      '#required' => TRUE,
      '#default_value' => DrupalDateTime::createFromTimestamp(time()),
    ];

    $form['registration_end'] = [
      '#type' => 'datetime',
      '#title' => $this->t('Registration end'),
      '#required' => TRUE,
      '#default_value' => DrupalDateTime::createFromTimestamp(strtotime('+7 days')),
    ];

    $form['event_date'] = [
      '#type' => 'date',
      '#title' => $this->t('Event date'),
      '#required' => TRUE,
      '#default_value' => date('Y-m-d', strtotime('+10 days')),
    ];

    $form['actions'] = ['#type' => 'actions'];
    $form['actions']['submit'] = [
      '#type' => 'submit',
      '#value' => $this->t('Save event'),
      '#button_type' => 'primary',
    ];

    $form['existing'] = [
      '#type' => 'details',
      '#title' => $this->t('Existing events'),
      '#open' => TRUE,
    ];

    $rows = [];
    foreach ($this->eventRepository->getEvents() as $event) {
      $rows[] = [
        $event['event_name'],
        $this->eventRepository->getCategories()[$event['category']] ?? $event['category'],
        DrupalDateTime::createFromTimestamp($event['registration_start'])->format('Y-m-d H:i'),
        DrupalDateTime::createFromTimestamp($event['registration_end'])->format('Y-m-d H:i'),
        DrupalDateTime::createFromTimestamp($event['event_date'])->format('Y-m-d'),
      ];
    }

    $form['existing']['table'] = [
      '#type' => 'table',
      '#header' => [
        $this->t('Event name'),
        $this->t('Category'),
        $this->t('Registration start'),
        $this->t('Registration end'),
        $this->t('Event date'),
      ],
      '#rows' => $rows,
      '#empty' => $this->t('No events configured yet.'),
    ];

    return $form;
  }

  public function validateForm(array &$form, FormStateInterface $form_state): void {
    $start = $form_state->getValue('registration_start');
    $end = $form_state->getValue('registration_end');
    $event_date = $form_state->getValue('event_date');

    if ($start instanceof DrupalDateTime && $end instanceof DrupalDateTime && $start > $end) {
      $form_state->setErrorByName('registration_end', $this->t('Registration end must be after the start.'));
    }

    if ($event_date && $start instanceof DrupalDateTime) {
      $event_day = strtotime($event_date . ' 00:00:00');
      if ($event_day < $start->getTimestamp()) {
        $form_state->setErrorByName('event_date', $this->t('Event date must be after registration start.'));
      }
    }
  }

  public function submitForm(array &$form, FormStateInterface $form_state): void {
    /** @var \Drupal\Core\Datetime\DrupalDateTime $start */
    $start = $form_state->getValue('registration_start');
    /** @var \Drupal\Core\Datetime\DrupalDateTime $end */
    $end = $form_state->getValue('registration_end');

    $values = [
      'event_name' => $form_state->getValue('event_name'),
      'category' => $form_state->getValue('category'),
      'registration_start' => $start->getTimestamp(),
      'registration_end' => $this->normalizeEndTimestamp($end),
      'event_date' => strtotime($form_state->getValue('event_date') . ' 00:00:00'),
    ];

    $this->eventRepository->createEvent($values);
    $this->messenger()->addStatus($this->t('Event %name saved.', ['%name' => $values['event_name']]));
    $form_state->setRedirect('<current>');
  }

  private function normalizeEndTimestamp(DrupalDateTime $end): int {
    $datetime = clone $end;
    $datetime->setTime(23, 59, 59);
    return $datetime->getTimestamp();
  }

}
