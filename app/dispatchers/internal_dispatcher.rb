class InternalDispatcher
  def update(notification_type:, resource: nil)
    recipient = Notifications::Recipient.call(notification_type, resource)
    return unless recipient
    Notification.create!(
      notification_type: notification_type, user: recipient, resource: resource
    )
  end
end
