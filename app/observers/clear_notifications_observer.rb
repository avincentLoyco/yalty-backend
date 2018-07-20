class ClearNotificationsObserver
  def update(notification_type:, resource:)
    case notification_type
    when :time_off_declined, :time_off_approved
      Notification.where(
        notification_type: "time_off_request",
        resource: resource
      ).update_all(seen: true)
    end
  end
end
