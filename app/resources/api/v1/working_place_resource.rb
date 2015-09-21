module API
  module V1
    class WorkingPlaceResource < JSONAPI::Resource

      def self.records(options = {})
        Account.current.working_places
      end
    end
  end
end
