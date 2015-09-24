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
        Account.current.update!(settings_attributes)
        render status: :no_content, nothing: true
      end

      private

      def settings_data
        params.require(:data)
      end

      def settings_attributes
        setup_params
        settings_data
          .require(:attributes)
          .permit(:company_name, :subdomain, :timezone, :default_locale)
      end

      def setup_request(id = Account.current.try(:id))
        @request = JSONAPI::Request.new(params.merge(id: id), context: context, key_formatter: key_formatter)

        render_errors(@request.errors) unless @request.errors.empty?
      rescue => e
        handle_exceptions(e)
      end
    end
  end
end
