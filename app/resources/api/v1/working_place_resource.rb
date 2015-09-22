module API
  module V1
    class WorkingPlaceResource < JSONAPI::Resource
      attribute :name
      has_many :employees

      def self.records(options = {})
        Account.current.working_places
      end
    end
  end
end
