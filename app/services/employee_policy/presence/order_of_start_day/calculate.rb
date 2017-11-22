module EmployeePolicy
  module Presence
    class OrderOfStartDay::Calculate
      attr_reader :presence_policy, :effective_at

      def self.call(presence_policy_id, effective_at)
        new(presence_policy_id, effective_at).call
      end

      def initialize(presence_policy_id, effective_at)
        @presence_policy = Account.current.presence_policies.find(presence_policy_id)
        @effective_at    = effective_at
      end

      def call
        calculated_order_of_start_day = effective_at.wday.eql?(0) ? 7 : effective_at.wday

        if presence_policy.presence_days.pluck(:order).include?(calculated_order_of_start_day)
          calculated_order_of_start_day
        else
          presence_policy.presence_days.pluck(:order).first
        end
      end
    end
  end
end
