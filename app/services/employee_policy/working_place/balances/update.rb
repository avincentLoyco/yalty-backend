module EmployeePolicy
  module WorkingPlace
    class Balances::Update
      attr_reader :employee_working_place, :effective_at, :previous_effective_at, :resource

      def self.call(employee_working_place, attributes = {}, previous_effective_at = nil,
        resource = nil)
        new(employee_working_place, attributes, previous_effective_at, resource).call
      end

      def initialize(employee_working_place, attributes = {}, previous_effective_at = nil,
        resource = nil)

        @employee_working_place = employee_working_place
        @resource               = resource
        @effective_at           = attributes[:effective_at] || employee_working_place.effective_at
        @previous_effective_at  = previous_effective_at
      end

      def call
        FindAndUpdateEmployeeBalancesForJoinTables.call(
          employee_working_place,
          effective_at.to_date,
          previous_effective_at,
          resource
        )
      end
    end
  end
end
