module API
  module V1
    class UserSettingsController < ApplicationController
      authorize_resource class: 'Account::User'
      include UserSettingsRules
      include Exceptions

      def show
        render_resource(resource)
      end

      def update
        verified_params(gate_rules) do |attributes|
          check_old_password(attributes[:password_params]) if attributes[:password_params]
          params = prepare_attributes(attributes)
          if resource.update(params)
            render_no_content
          else
            resource_invalid_error(resource)
          end
        end
      end

      private

      def check_old_password(attributes)
        return if resource.authenticate(attributes.delete(:old_password))
        fail InvalidPasswordError.new(resource, message: 'Given Password Invalid')
      end

      def prepare_attributes(attributes)
        attributes.merge(attributes.delete(:password_params).to_h)
      end

      def resource
        @resource ||= Account::User.current
      end

      def resource_representer
        ::Api::V1::UserSettingsRepresenter
      end
    end
  end
end
