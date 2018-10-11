module Policy
  module TimeOff
    class CreateCounterForCategory
      attr_reader :time_off_category

      def self.call(time_off_category)
        new(time_off_category).call
      end

      def initialize(time_off_category)
        @time_off_category = time_off_category
      end

      def call
        ActiveRecord::Base.transaction do
          create_time_off_policy.tap do |time_off_policy|
            create_employee_time_off_policies(time_off_policy.id)
          end
        end
      end

      private

      def create_time_off_policy
        TimeOffPolicy.create!(
          start_day: 1,
          start_month: 1,
          policy_type: "counter",
          time_off_category_id: time_off_category.id,
          name: time_off_category.name
        )
      end

      def create_employee_time_off_policies(time_off_policy_id)
        EmployeeTimeOffPolicy.create!(employee_time_off_policies(time_off_policy_id))
      end

      def employee_time_off_policies(time_off_policy_id)
        employee_ids.map do |employee_id|
          {
            employee_id: employee_id,
            time_off_policy_id: time_off_policy_id,
            time_off_category_id: time_off_category.id,
            effective_at: current_time,
          }
        end
      end

      def employee_ids
        @employee_ids ||= Account.current.employees.active_at_date(current_time).pluck(:id)
      end

      def current_time
        @current_time ||= Time.current
      end
    end
  end
end
