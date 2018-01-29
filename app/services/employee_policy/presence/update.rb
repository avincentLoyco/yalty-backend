module EmployeePolicy
  module Presence
    class Update
      attr_reader :params

      def self.call(params)
        new(params).call
      end

      def initialize(params)
        @params = params
      end

      def call
        params[:order_of_start_day] = EmployeePolicy::Presence::OrderOfStartDay::Calculate.call(
          employee_presence_policy.presence_policy.id, params[:effective_at]
        )
        attributes =
          params.merge(previous_order_of_start_day: employee_presence_policy.order_of_start_day)

        result = CreateOrUpdateJoinTable.call(
          EmployeePresencePolicy, PresencePolicy, params, employee_presence_policy
        )

        EmployeePolicy::Presence::Balances::Update.call(
          result[:result], attributes, employee_presence_policy.effective_at
        )
        result
      end

      private

      def employee_presence_policy
        EmployeePresencePolicy.find(params[:id])
      end
    end
  end
end
