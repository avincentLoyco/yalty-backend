module API
  module V1
    class CompanyEventsController < API::ApplicationController
      include CompanyEventsSchemas

      before_action :authorize_action

      def index
        render_resource(resources)
      end

      def show
        render_resource(resource)
      end

      def create
        verified_dry_params(dry_validation_schema) do |attributes|
          event_params = filtered_params(attributes).merge(account_id: Account.current.id)
          @resource = CompanyEvent.create!(event_params)
          handle_and_render_resource(attributes)
        end
      end

      def update
        verified_dry_params(dry_validation_schema) do |attributes|
          resource.update!(filtered_params(attributes))
          handle_and_render_resource(attributes)
        end
      end

      def destroy
        resource.destroy!
        send_email_about_the_change
        render_no_content
      end

      private

      def handle_and_render_resource(attributes)
        assign_files(file_ids_from(attributes))
        send_email_about_the_change
        render_resource(resource)
      end

      def filtered_params(attributes)
        file_ids = file_ids_from(attributes)
        return attributes.except(:files) unless file_ids.present?
        attributes.except(:files).merge(file_ids: file_ids)
      end

      def assign_files(file_ids)
        @resource.files.where(id: file_ids).each do |company_file|
          company_file.update!(file: File.open(company_file.find_file_path.first))
        end
      end

      def file_ids_from(attributes)
        attributes[:files]&.map { |file_data| file_data[:id] }
      end

      def resources
        @resources ||= Account.current.company_events
      end

      def resource
        @resource ||= resources.find(params[:id])
      end

      def resource_representer
        ::Api::V1::CompanyEventRepresenter
      end

      def authorize_action
        authorize!(action_name.to_sym, CompanyEvent, current_user)
      end

      def send_email_about_the_change
        CompanyEventsMailer
          .event_changed(Account.current, resource, current_user.id, action_name)
          .deliver_later
      end
    end
  end
end
