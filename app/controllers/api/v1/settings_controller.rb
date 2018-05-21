module API
  module V1
    class SettingsController < API::ApplicationController
      include SettingsSchemas
      include DoorkeeperAuthorization
      before_action :subdomain_access!, only: :show
      skip_action_callback :authenticate!, only: :show
      authorize_resource class: "Account::User", only: :update

      def show
        if Account::User.current.present?
          render_resource(resource)
        else
          render json: resource_representer.new(resource).public_data
        end
      end

      def update
        verified_dry_params(dry_validation_schema) do |attributes|
          resource.attributes = attributes
          subdomain_change = resource.subdomain_changed?

          resource.save!
          render_response_or_redirect(subdomain_change)
        end
      end

      private

      def current_resource_owner
        user
      end

      def resource
        Account.current
      end

      def user
        Account::User.current
      end

      def resource_representer
        ::Api::V1::SettingsRepresenter
      end

      def render_response_or_redirect(subdomain_change)
        render_no_content && return unless subdomain_change
        render json: { redirect_uri: authorization_uri }, status: :moved_permanently
      end
    end
  end
end
