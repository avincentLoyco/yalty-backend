module API
  module V1
    class WorkingPlaceResource < JSONAPI::Resource
      model_name 'WorkingPlace'
      attribute :name
      has_many :employees, class_name: 'Employee'

      def self.records(options = {})
        Account.current.working_places
      end
    end
  end
end
