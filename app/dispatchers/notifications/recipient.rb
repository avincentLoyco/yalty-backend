module Notifications
  class Recipient
    method_object :notification_type, :resource

    def call
      return [] unless recipients_class
      Array.wrap(recipients_class.call(resource)).compact
    end

    private

    def recipients_class
      case notification_type.to_sym
      when :time_off_approved, :time_off_declined
        Notifications::Recipients::TimeOffProcessed
      when :time_off_request
        Notifications::Recipients::TimeOffRequest
      end
    end
  end
end
