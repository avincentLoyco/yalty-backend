module Notifications
  module Recipients
    class TimeOffRequest
      method_object :resource

      def call
        resource.manager || resource.employee.account.admins
      end
    end
  end
end
