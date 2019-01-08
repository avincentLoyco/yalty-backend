module API
  module V1
    class TimeEntriesController < API::ApplicationController
      authorize_resource except: :create
      include TimeEntriesSchemas
      include AppDependencies[
        create_time_entry: "use_cases.time_entries.create",
        destroy_time_entry: "use_cases.time_entries.destroy",
        update_time_entry: "use_cases.time_entries.update",
      ]

      def show
        render_resource(resource)
      end

      def index
        render_resource(resources)
      end

      def create
        authorize! :create, TimeEntry

        verified_dry_params(dry_validation_schema) do |attributes|
          resource = create_time_entry.call(
            params: attributes.except(:presence_day),
            presence_day: presence_day,
          )
          render_resource(resource, status: :created)
        end
      end

      def update
        verified_dry_params(dry_validation_schema) do |attributes|
          update_time_entry.call(
            time_entry: resource,
            params: attributes,
          )
          render_no_content
        end
      end

      def destroy
        destroy_time_entry.call(time_entry: resource)
        render_no_content
      end

      private

      def resource
        @resource ||= Account.current.time_entries.find(params[:id])
      end

      def resources
        @resources ||= presence_day.time_entries
      end

      def presence_day
        @presence_day ||= Account.current.presence_days.find(presence_day_id)
      end

      def presence_day_id
        return params[:presence_day].try(:[], :id) unless params[:presence_day_id]
        params[:presence_day_id]
      end

      def resource_representer
        ::Api::V1::TimeEntriesRepresenter
      end
    end
  end
end
