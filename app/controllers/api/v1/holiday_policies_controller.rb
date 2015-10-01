module API
  module V1
    class HolidayPoliciesController < JSONAPI::ResourceController
      include API::V1::Exceptions
      include API::V1::ExceptionsHandler

      before_action :lock_destroy, only: [:destroy_relationship]

      private

      def lock_destroy
        if params[:relationship] == "holidays"
          raise ForbiddenAction.new(params[:action])
        end
      rescue => e
        handle_exceptions(e)
      end
    end
  end
end
