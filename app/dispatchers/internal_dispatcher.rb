class InternalDispatcher
  def update(notification_type:, resource: nil)
    recipients = Notifications::Recipient.call(notification_type, resource)
    return if recipients.empty?
    recipients.each do |recipient|
      Notification.create!(
        notification_type: notification_type, user: recipient, resource: resource
      )
    end
  end
end
