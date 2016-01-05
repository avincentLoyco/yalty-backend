module API
  module V1
    class UsersController < ApplicationController
      include UserRules

      def index
        render_resource(resources)
      end

      def show
        render_resource(resource)
      end

      def create
        verified_params(gate_rules) do |attributes|
          if attributes.key?(:employee)
            employee_id = attributes.delete(:employee)[:id]
            employee = Account.current.employees.find(employee_id)
          end

          unless attributes[:password].present?
            attributes[:password] = SecureRandom.urlsafe_base64(16)
          end

          resource = Account.current.users.new(attributes)
          if resource.save
            employee.update!(account_user_id: resource.id) if employee
            send_user_credentials(resource, attributes[:password])
            render_resource(resource, status: :created)
          else
            resource_invalid_error(resource)
          end
        end
      end

      def update
        verified_params(gate_rules) do |attributes|
          if attributes.key?(:employee)
            employee_id = attributes.delete(:employee)[:id]
            employee = Account.current.employees.find(employee_id)
          end

          if resource.update(attributes)
            employee.update!(account_user_id: resource.id) if employee
            render_no_content
          else
            resource_invalid_error(resource)
          end
        end
      end

      def destroy
        resource.destroy!
        render_no_content
      end

      private

      def resources
        @resources ||= Account.current.users
      end

      def resource
        @resource ||= resources.find(params[:id])
      end

      def resource_representer
        ::Api::V1::UserRepresenter
      end

      def send_user_credentials(user, password)
        subdomain = Account.current.subdomain
        UserMailer.credentials(
          user.id,
          password,
          subdomain + '.' + ENV['YALTY_APP_DOMAIN']
        ).deliver_later
      end
    end
  end
end
