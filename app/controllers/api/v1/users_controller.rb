module API
  module V1
    class UsersController < ApplicationController
      authorize_resource class: 'Account::User', except: :create

      include UserRules

      def index
        render_resource(resources)
      end

      def show
        render_resource(resource)
      end

      def create
        verified_params(gate_rules) do |attributes|
          load_related_employee(attributes)

          @resource = Account.current.users.new(attributes)

          authorize! :create, resource
          resource.save!
          send_user_credentials(resource)
          render_resource(resource, status: :created)
        end
      end

      def update
        verified_params(gate_rules) do |attributes|
          load_related_employee(attributes)

          authorize! :update, attributes[:employee] if attributes[:employee]
          authorize! :update, resource
          resource.update!(attributes)
          render_no_content
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

      def load_related_employee(attributes)
        return unless attributes.key?(:employee)

        employee_id = attributes.delete(:employee).try(:[], :id)
        attributes[:employee] = employee_id ? Account.current.employees.find(employee_id) : nil
      end

      def send_user_credentials(user)
        subdomain = Account.current.subdomain
        UserMailer.credentials(
          user.id,
          user.password,
          subdomain + '.' + ENV['YALTY_APP_DOMAIN']
        ).deliver_later
      end
    end
  end
end
