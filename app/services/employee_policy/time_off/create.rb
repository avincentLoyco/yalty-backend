module EmployeePolicy
  module TimeOff
    class Create
      attr_reader :event, :time_off_policy_amount

      def self.call(event_id, time_off_policy_amount)
        new(event_id, time_off_policy_amount).call
      end

      def initialize(event_id, time_off_policy_amount)
        @event                  = Employee::Event.find(event_id)
        @time_off_policy_amount = time_off_policy_amount
      end

      def call
        CreateOrUpdateJoinTable.new(EmployeeTimeOffPolicy, TimeOffPolicy, attributes).call
        EmployeeTimeOffPolicy.find_by(employee_event_id: event.id)
      end

      def time_off_policy
        Policy::TimeOff::FindOrCreateByAmount.call(
          time_off_policy_amount,
          event.employee.account.id
        )
      end

      private

      def attributes
        {
          effective_at: event.effective_at,
          effective_till: nil,
          employee_id: event.employee_id,
          occupation_rate: event.attribute_value("occupation_rate"),
          time_off_policy_id: time_off_policy.id,
          employee_event_id: event.id,
        }
      end
    end
  end
end
