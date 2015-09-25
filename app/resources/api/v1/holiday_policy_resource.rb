module API
  module V1
    class HolidayPolicyResource < JSONAPI::Resource
      model_name 'HolidayPolicy'
      attribute :name

      def self.records(options = {})
        Account.current.holiday_policies
      end
    end
  end
end
