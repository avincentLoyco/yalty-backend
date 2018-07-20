module Api::V1
  class NotificationRepresenter < BaseRepresenter
    def complete
      {
        notification_type:  resource.notification_type,
        resource:           notification_resource,
        user_id:            resource.user_id,
      }
      .merge(basic)
    end


    private

    def notification_resource
      resource_representer.new(resource.resource).for_notification
    end

    def resource_representer
      Api::V1.const_get(resource.resource.class.name + "Representer")
    end
  end
end
