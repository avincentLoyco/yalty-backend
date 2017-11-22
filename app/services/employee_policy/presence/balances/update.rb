module EmployeePolicy
  module Presence
    class Balances::Update
      attr_reader :employee_presence_policy, :effective_at, :order_of_start_day,
        :previous_effective_at, :previous_order_of_start_day

      def self.call(employee_presence_policy, attributes = {}, previous_effective_at = nil)
        new(employee_presence_policy, attributes, previous_effective_at).call
      end

      def initialize(employee_presence_policy, attributes = {}, previous_effective_at = nil)
        @employee_presence_policy    = employee_presence_policy
        @previous_order_of_start_day = attributes[:previous_order_of_start_day]
        @order_of_start_day          = attributes[:order_of_start_day]

        @effective_at          = attributes[:effective_at] || employee_presence_policy.effective_at
        @previous_effective_at = previous_effective_at
      end

      def call
        params_for_service =
          [employee_presence_policy, effective_at.to_date, previous_effective_at, nil]

        if order_of_start_day && order_of_start_day != employee_presence_policy.order_of_start_day
          params_for_service.push(order_of_start_day)
        end

        return if effective_at_or_order_of_start_day_not_changed?
        FindAndUpdateEmployeeBalancesForJoinTables.call(*params_for_service)
      end

      private

      def effective_at_or_order_of_start_day_not_changed?
        previous_effective_at.present? &&
          previous_effective_at == employee_presence_policy.effective_at &&
          ((previous_order_of_start_day.present? && order_of_start_day.present? &&
          order_of_start_day == previous_order_of_start_day) || order_of_start_day.nil?)
      end
    end
  end
end
