module Api::V1
  class NotificationRepresenter < BaseRepresenter
    def complete
      {
        notification_type:  resource.notification_type,
        resource_type:      resource.resource_type,
        resource_id:        resource.resource_id,
        user_id:            resource.user_id,
      }
      .merge(basic)
    end
  end
end
