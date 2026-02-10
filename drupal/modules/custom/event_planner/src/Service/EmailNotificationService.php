<?php

declare(strict_types=1);

namespace Drupal\event_planner\Service;

use Drupal\Core\Config\ConfigFactoryInterface;
use Drupal\Core\Datetime\DrupalDateTime;
use Drupal\Core\Mail\MailManagerInterface;
use Drupal\Core\Session\AccountProxyInterface;

/**
 * Handles outbound notification emails for event registrations.
 */
class EmailNotificationService {

  public function __construct(
    private readonly MailManagerInterface $mailManager,
    private readonly ConfigFactoryInterface $configFactory,
    private readonly AccountProxyInterface $currentUser,
  ) {}

  /**
   * Sends confirmation and optional admin notifications.
   */
  public function notify(array $registration, string $category_label): void {
    $date = DrupalDateTime::createFromTimestamp($registration['event_date'])->format('Y-m-d');

    $params = [
      'full_name' => $registration['full_name'],
      'event_name' => $registration['event_name'],
      'event_date' => $date,
      'category' => $category_label,
      'email' => $registration['email'],
      'college_name' => $registration['college_name'],
      'department' => $registration['department'],
    ];

    $this->mailManager->mail('event_planner', 'user_confirmation', $registration['email'], $this->currentUser->getPreferredLangcode(), $params);

    $config = $this->configFactory->get('event_planner.settings');
    if ($config->get('notify_admin') && ($admin_email = $config->get('admin_notification_email'))) {
      $this->mailManager->mail('event_planner', 'admin_notification', $admin_email, $this->currentUser->getPreferredLangcode(), $params);
    }
  }

}
