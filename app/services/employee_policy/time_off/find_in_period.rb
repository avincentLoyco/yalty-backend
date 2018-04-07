module EmployeePolicy
  module TimeOff
    class FindInPeriod < EmployeePolicy::FindInPeriod
      TIME_OFF_FILTERS = [:filter_time_off_category].freeze

      def call
        Account.current.employee_time_off_policies.where(filters(time_off_filters))
      end

      private

      def time_off_filters
        DEFAULT_FILTERS + TIME_OFF_FILTERS
      end

      def filter_time_off_category
        parent_table_id.present? ? { time_off_category_id: parent_table_id } : {}
      end
    end
  end
end
