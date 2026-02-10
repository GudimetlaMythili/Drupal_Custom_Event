<?php

declare(strict_types=1);

namespace Drupal\event_planner\Form;

use Drupal\Core\Form\ConfigFormBase;
use Drupal\Core\Form\FormStateInterface;

/**
 * Configuration form for Event Planner settings.
 */
class EventSettingsForm extends ConfigFormBase {

  protected function getEditableConfigNames(): array {
    return ['event_planner.settings'];
  }

  public function getFormId(): string {
    return 'event_planner_settings_form';
  }

  public function buildForm(array $form, FormStateInterface $form_state): array {
    $config = $this->config('event_planner.settings');

    $form['notify_admin'] = [
      '#type' => 'checkbox',
      '#title' => $this->t('Send administrator notifications'),
      '#default_value' => $config->get('notify_admin'),
      '#description' => $this->t('Send a notification email to the configured administrator for each registration.'),
    ];

    $form['admin_notification_email'] = [
      '#type' => 'email',
      '#title' => $this->t('Administrator email'),
      '#default_value' => $config->get('admin_notification_email'),
      '#required' => FALSE,
      '#states' => [
        'visible' => [
          ':input[name="notify_admin"]' => ['checked' => TRUE],
        ],
        'required' => [
          ':input[name="notify_admin"]' => ['checked' => TRUE],
        ],
      ],
    ];

    return parent::buildForm($form, $form_state);
  }

  public function validateForm(array &$form, FormStateInterface $form_state): void {
    parent::validateForm($form, $form_state);
    if ($form_state->getValue('notify_admin') && !$form_state->getValue('admin_notification_email')) {
      $form_state->setErrorByName('admin_notification_email', $this->t('Please provide an administrator email address.'));
    }
  }

  public function submitForm(array &$form, FormStateInterface $form_state): void {
    $this->config('event_planner.settings')
      ->set('notify_admin', (bool) $form_state->getValue('notify_admin'))
      ->set('admin_notification_email', $form_state->getValue('admin_notification_email'))
      ->save();
    parent::submitForm($form, $form_state);
  }

}
