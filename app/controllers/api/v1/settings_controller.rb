module API
  module V1
    class SettingsController < JSONAPI::ResourceController
      def show
        render json: Account.current.to_json, status: 200
      end

      def update
        Account.current.update(settings_attributes)
        render status: :no_content, nothing: true
      end

      private

      def settings_data
        params.require(:data)
      end

      def settings_attributes
        settings_data
          .require(:attributes)
          .permit(:company_name, :subdomain, :timezone, :default_locale)
      end
    end
  end
end
