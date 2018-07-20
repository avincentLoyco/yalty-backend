module Notifications
  class Recipient
    UnsupportedNotificationType = Class.new(StandardError)

    method_object :notification_type, :resource

    def call
      case notification_type.to_sym
      when :time_off_approved, :time_off_declined
        resource.employee&.user
      when :time_off_request
        resource.manager
      end
    end
  end
end
