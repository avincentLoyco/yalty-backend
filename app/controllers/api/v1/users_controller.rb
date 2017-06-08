module API
  module V1
    class UsersController < ApplicationController
      authorize_resource class: 'Account::User', except: :create
      include DoorkeeperAuthorization
      include UserSchemas

      def index
        render_resource(resources)
      end

      def show
        render_resource(resource)
      end

      def create
        verified_dry_params(dry_validation_schema) do |attributes|
          load_related_employee(attributes)

          @resource = Account.current.users.new(attributes)

          authorize! :create, resource

          resource.save!
          send_user_invitation
          render_resource(resource, status: :created)
        end
      end

      def update
        verified_dry_params(dry_validation_schema) do |attributes|
          load_related_employee(attributes)

          authorize! :update, attributes[:employee] if attributes[:employee]
          authorize! :update, resource

          if attributes[:password_params]&.key?(:old_password)
            check_old_password(attributes[:password_params])
          end

          resource.update!(attributes.merge(attributes.delete(:password_params).to_h))
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
      rescue ActiveRecord::RecordNotFound => e
        Account::User.where(account: Account.current, id: params[:id], role: 'yalty').first ||
          raise(e)
      end

      def current_resource_owner
        resource
      end

      def resource_representer
        ::Api::V1::UserRepresenter
      end

      def load_related_employee(attributes)
        return unless attributes.key?(:employee)

        employee_id = attributes.delete(:employee).try(:[], :id)
        attributes[:employee] = employee_id ? Account.current.employees.find(employee_id) : nil
      end

      def check_old_password(attributes)
        return if resource.authenticate(attributes.delete(:old_password))
        raise InvalidPasswordError.new(resource, messages: { error: [ 'Given Password Invalid' ] })
      end

      def send_user_invitation
        UserMailer.user_invitation(
          resource.id,
          authorization_uri
        ).deliver_later
      end
    end
  end
end
