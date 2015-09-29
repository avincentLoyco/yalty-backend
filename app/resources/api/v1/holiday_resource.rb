module API
  module V1
    class HolidayResource < JSONAPI::Resource
      model_name 'Holiday'
      attributes :name, :date, :holiday_policy_id
      has_one :holiday_policy, class_name: 'HolidayPolicy'

      def self.records(options = {})
        Holiday.where(holiday_policy_id: Account.current.holiday_policies.pluck(:id))
      end
    end
  end
end
