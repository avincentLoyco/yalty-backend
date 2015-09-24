module API
  module V1
    class SettingsController < JSONAPI::ResourceController
      include API::V1::ParamsManagement
      include API::V1::ExceptionsHandler

      def show
        setup_request
        process_request_operations
      end

      def update
        setup_request
        process_request_operations
      end

      private

      def setup_request(id = Account.current.try(:id).to_s)
        @request = JSONAPI::Request.new(params.merge(id: id), context: context, key_formatter: key_formatter)

        render_errors(@request.errors) unless @request.errors.empty?
      rescue => e
        handle_exceptions(e)
      end
    end
  end
end
