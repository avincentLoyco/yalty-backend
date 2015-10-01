module API
  module V1
    class WorkingPlaceResource < JSONAPI::Resource
      model_name 'WorkingPlace'
      attributes :name, :holiday_policy_id
      has_many :employees, class_name: 'Employee'

      before_create :setup_account

      def self.records(_options = {})
        Account.current.working_places
      end

      private

      def setup_account
        model.account = Account.current
      end
    end
  end
end
