<?php

declare(strict_types=1);

namespace Drupal\event_planner\Form;

use Drupal\Core\Datetime\DrupalDateTime;
use Drupal\Core\Form\FormBase;
use Drupal\Core\Form\FormStateInterface;
use Drupal\event_planner\Repository\EventRepository;
use Drupal\event_planner\Service\EmailNotificationService;
use Symfony\Component\DependencyInjection\ContainerInterface;

/**
 * Public registration form for Event Planner events.
 */
class EventRegistrationForm extends FormBase {

  public function __construct(
    private readonly EventRepository $eventRepository,
    private readonly EmailNotificationService $emailNotificationService,
  ) {}

  public static function create(ContainerInterface $container): static {
    return new static(
      $container->get('event_planner.event_repository'),
      $container->get('event_planner.email_notifier')
    );
  }

  public function getFormId(): string {
    return 'event_planner_registration_form';
  }

  public function buildForm(array $form, FormStateInterface $form_state): array {
    $form['#attributes']['novalidate'] = 'novalidate';

    $active_categories = $this->eventRepository->getActiveCategories();
    if (!$active_categories) {
      $form['message'] = [
        '#markup' => $this->t('Registrations are currently closed. Please check back later.'),
      ];
      return $form;
    }

    $selected_category = $form_state->getValue('category');
    if (!$selected_category || !isset($active_categories[$selected_category])) {
      $selected_category = array_key_first($active_categories);
      $form_state->setValue('category', $selected_category);
    }

    $date_options = $selected_category
      ? $this->eventRepository->getEventDatesByCategory($selected_category)
      : [];

    $selected_date = $form_state->getValue('event_date') ?: array_key_first($date_options);
    if ($selected_date && !isset($date_options[$selected_date])) {
      $selected_date = NULL;
    }

    $event_options = ($selected_category && $selected_date)
      ? $this->eventRepository->getEventsByCategoryAndDate($selected_category, (int) $selected_date)
      : [];

    $form['full_name'] = [
      '#type' => 'textfield',
      '#title' => $this->t('Full name'),
      '#required' => TRUE,
      '#maxlength' => 255,
    ];

    $form['email'] = [
      '#type' => 'email',
      '#title' => $this->t('Email address'),
      '#required' => TRUE,
      '#maxlength' => 255,
    ];

    $form['college_name'] = [
      '#type' => 'textfield',
      '#title' => $this->t('College name'),
      '#required' => TRUE,
      '#maxlength' => 255,
    ];

    $form['department'] = [
      '#type' => 'textfield',
      '#title' => $this->t('Department'),
      '#required' => TRUE,
      '#maxlength' => 255,
    ];

    $form['category'] = [
      '#type' => 'select',
      '#title' => $this->t('Category of the event'),
      '#options' => $active_categories,
      '#required' => TRUE,
      '#default_value' => $selected_category,
      '#ajax' => [
        'callback' => '::updateEventDates',
        'wrapper' => 'event-date-wrapper',
      ],
    ];

    $form['event_date_wrapper'] = [
      '#type' => 'container',
      '#attributes' => ['id' => 'event-date-wrapper'],
    ];

    $form['event_date_wrapper']['event_date'] = [
      '#type' => 'select',
      '#title' => $this->t('Event date'),
      '#options' => $date_options,
      '#required' => TRUE,
      '#default_value' => $selected_date,
      '#ajax' => [
        'callback' => '::updateEventNames',
        'wrapper' => 'event-name-wrapper',
      ],
      '#empty_option' => $this->t('- Select -'),
    ];

    $form['event_name_wrapper'] = [
      '#type' => 'container',
      '#attributes' => ['id' => 'event-name-wrapper'],
    ];

    $form['event_name_wrapper']['event_id'] = [
      '#type' => 'select',
      '#title' => $this->t('Event name'),
      '#required' => TRUE,
      '#options' => $event_options,
      '#empty_option' => $this->t('- Select -'),
      '#default_value' => $form_state->getValue('event_id') ?: array_key_first($event_options),
    ];

    $form['actions'] = ['#type' => 'actions'];
    $form['actions']['submit'] = [
      '#type' => 'submit',
      '#value' => $this->t('Submit registration'),
      '#button_type' => 'primary',
    ];

    return $form;
  }

  public function updateEventDates(array &$form, FormStateInterface $form_state): array {
    $form_state->setRebuild(TRUE);
    return $form['event_date_wrapper'];
  }

  public function updateEventNames(array &$form, FormStateInterface $form_state): array {
    $form_state->setRebuild(TRUE);
    return $form['event_name_wrapper'];
  }

  public function validateForm(array &$form, FormStateInterface $form_state): void {
    foreach (['full_name', 'college_name', 'department'] as $field) {
      $value = (string) $form_state->getValue($field);
      if (!preg_match('/^[A-Za-z0-9 ]+$/', $value)) {
        $form_state->setErrorByName($field, $this->t('@field may only contain letters, numbers, and spaces.', ['@field' => $form[$field]['#title']]));
      }
    }

    $category = $form_state->getValue('category');
    $date_value = $form_state->getValue('event_date');
    $event_id = $form_state->getValue('event_id');

    if (!$category || !$date_value || !$event_id) {
      $form_state->setErrorByName('event_id', $this->t('Please select a category, event date, and event.'));
      return;
    }

    $event = $this->eventRepository->getEvent((int) $event_id);
    if (!$event || $event['category'] !== $category || $event['event_date'] !== (int) $date_value) {
      $form_state->setErrorByName('event_id', $this->t('Selected event is no longer available. Please choose another.'));
      return;
    }

    $email = strtolower((string) $form_state->getValue('email'));
    if ($this->eventRepository->registrationExists($event['event_date'], $email)) {
      $form_state->setErrorByName('email', $this->t('You have already registered for an event on @date.', [
        '@date' => DrupalDateTime::createFromTimestamp($event['event_date'])->format('Y-m-d'),
      ]));
    }
  }

  public function submitForm(array &$form, FormStateInterface $form_state): void {
    $event = $this->eventRepository->getEvent((int) $form_state->getValue('event_id'));
    if (!$event) {
      $this->messenger()->addError($this->t('Unable to locate the selected event.'));
      $form_state->setRebuild(TRUE);
      return;
    }

    $registration = [
      'event_id' => $event['id'],
      'full_name' => $form_state->getValue('full_name'),
      'email' => strtolower((string) $form_state->getValue('email')),
      'college_name' => $form_state->getValue('college_name'),
      'department' => $form_state->getValue('department'),
      'category' => $event['category'],
      'event_date' => $event['event_date'],
      'event_name' => $event['event_name'],
    ];

    $this->eventRepository->createRegistration($registration);

    $categories = $this->eventRepository->getCategories();
    $this->emailNotificationService->notify($registration, $categories[$event['category']] ?? $event['category']);

    $this->messenger()->addStatus($this->t('Thank you for registering. A confirmation email has been sent.'));
    $form_state->setRedirect('<current>');
  }

}
