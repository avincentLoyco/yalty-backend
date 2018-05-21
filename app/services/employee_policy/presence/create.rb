module EmployeePolicy
  module Presence
    class Create
      attr_reader :params

      def self.call(params)
        new(params).call
      end

      def initialize(params)
        @params = params
      end

      def call
        result = CreateOrUpdateJoinTable.call(EmployeePresencePolicy, PresencePolicy, attributes)
        EmployeePolicy::Presence::Balances::Update.call(result[:result], attributes)

        result
      end

      private

      def event
        Employee::Event.find(params[:event_id])
      end

      def attributes
        {
          effective_at: event.effective_at,
          employee_id: event.employee_id,
          order_of_start_day: EmployeePolicy::Presence::OrderOfStartDay::Calculate.call(
            params[:presence_policy_id], event.effective_at
          ),
          presence_policy_id: params[:presence_policy_id],
          employee_event_id: event.id,
        }
      end
    end
  end
end
