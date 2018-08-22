class EmailDispatcher
  include ActiveSupport::Configurable

  UnsupportedNotificationType = Class.new(StandardError)

  config_accessor :notification_mailer do
    ::NotificationMailer
  end

  def update(notification_type:, resource:)
    recipients = Notifications::Recipient.call(notification_type, resource)
    return if recipients.empty?
    notification_mailer.public_send(notification_type, recipients, resource).deliver_later
  rescue NoMethodError
    raise UnsupportedNotificationType, "notification #{notification_type} is not supported"
  end
end
