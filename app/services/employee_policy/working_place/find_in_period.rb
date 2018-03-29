module EmployeePolicy
  module WorkingPlace
    class FindInPeriod < EmployeePolicy::FindInPeriod
      WORKING_PLACE_FILTERS = [:filter_working_place].freeze

      def call
        Account.current.employee_working_places.where(filters(working_place_filters))
      end

      private

      def working_place_filters
        DEFAULT_FILTERS + WORKING_PLACE_FILTERS
      end

      def filter_working_place
        parent_table_id.present? ? { working_place_id: parent_table_id } : {}
      end
    end
  end
end
