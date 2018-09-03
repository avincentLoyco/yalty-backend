module Notifications
  module Recipients
    class TimeOffProcessed
      method_object :resource

      def call
        resource.user
      end
    end
  end
end
