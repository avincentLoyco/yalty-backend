module API
  module V1
    class HolidayPolicyResource < JSONAPI::Resource
      model_name 'HolidayPolicy'
      has_many :holidays, class_name: 'Holiday'
      has_many :employees, class_name: 'Employee'
      has_many :working_places, class_name: 'WorkingPlace'

      attribute :name
      before_create :setup_account

      def self.records(options = {})
        Account.current.holiday_policies
      end

      private

      def setup_account
        model.account = Account.current
      end
    end
  end
end
