module API
  module V1
    class UsersController < ApplicationController
      load_and_authorize_resource class: 'Account::User', except: :create

      include UserRules

      def index
        render_resource(resources)
      end

      def show
        render_resource(resource)
      end

      def create
        verified_params(gate_rules) do |attributes|
          set_related_employee(attributes)

          @resource = Account.current.users.new(attributes)

          authorize! :create, resource
          if resource.save
            send_user_credentials(resource, attributes[:password])
            render_resource(resource, status: :created)
          else
            resource_invalid_error(resource)
          end
        end
      end

      def update
        verified_params(gate_rules) do |attributes|
          set_related_employee(attributes)

          if resource.update(attributes)
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

      def set_related_employee(attributes)
        return nil unless attributes.key?(:employee)

        employee_id = attributes.delete(:employee)[:id]
        attributes[:employee] = Account.current.employees.find(employee_id)
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
