module API
  module V1
    class TimeEntriesController < API::ApplicationController
      include TimeEntriesRules

      def show
        render_resource(resource)
      end

      def index
        render_resource(resources)
      end

      def create
        verified_params(gate_rules) do |attributes|
          resource = resources.new(time_entry_params(attributes))
          if resource.save
            render_resource(resource, status: :created)
          else
            resource_invalid_error(resource)
          end
        end
      end

      def update
        verified_params(gate_rules) do |attributes|
          if resource.update(attributes)
            render_no_content
          else
            resource_invalid_error(resource)
          end
        end
      end

      def destroy
        transactions do
          resource.destroy!
          resource.presence_day.update_minutes!
        end
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

      def time_entry_params(attributes)
        attributes.tap { |attr| attr.delete(:presence_day) }
      end

      def resource_representer
        ::Api::V1::TimeEntriesRepresenter
      end
    end
  end
end
