module EmployeePolicy
  module Presence
    class FindInPeriod < EmployeePolicy::FindInPeriod
      PRESENCE_FILTERS = [:filter_presence_policy].freeze

      def call
        Account.current.employee_presence_policies.where(filters(presence_filters))
      end

      private

      def presence_filters
        DEFAULT_FILTERS + PRESENCE_FILTERS
      end

      def filter_presence_policy
        parent_table_id.present? ? { presence_policy_id: parent_table_id } : {}
      end
    end
  end
end
