module EmployeePolicy
  module WorkingPlace
    class Destroy
      attr_reader :employee_working_place, :employee, :effective_at

      def self.call(employee_working_place)
        new(employee_working_place).call
      end

      def initialize(employee_working_place)
        @employee_working_place = employee_working_place
        @employee               = employee_working_place.employee
        @effective_at           = employee_working_place.effective_at
      end

      def call
        ActiveRecord::Base.transaction do
          employee_working_place.destroy!
          ClearResetJoinTables.new(employee, effective_at, nil, nil).call
          EmployeePolicy::WorkingPlace::Duplicates::Destroy.call(employee_working_place)
          EmployeePolicy::WorkingPlace::Balances::Update.call(employee_working_place)
        end
      end
    end
  end
end
