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
          resources = ManageTimeEntry.new(time_entry_params(attributes), presence_day).call
          render_resource(resources, status: :created)
        end
      end

      def update
        verified_params(gate_rules) do |attributes|
          ManageTimeEntry.new(attributes, resource.presence_day).call
          render_no_content
        end
      end

      def destroy
        transactions do
          resource.destroy!
          related_entry.try(:destroy)
          update_presence_days_minutes
        end
        render_no_content
      end

      private

      def related_entry
        @related_entry ||= resource.related_entry
      end

      def resource
        @resource ||= TimeEntry.where(id: account_time_entries_ids).find(params[:id])
      end

      def resources
        @resources ||= presence_day.time_entries
      end

      def presence_day
        @presence_day ||= Account.current.presence_days.find(presence_day_params)
      end

      def presence_day_params
        return params[:presence_day].try(:[], :id) unless params[:presence_day_id]
        params[:presence_day_id]
      end

      def time_entry_params(attributes)
        attributes.tap { |attr| attr.delete(:presence_day) }
      end

      def account_time_entries_ids
        Account.current.presence_days.map do |day|
          day.time_entries.map { |time_entry| time_entry.id }.flatten
        end.flatten
      end

      def update_presence_days_minutes
        results = UpdatePresenceDayMinutes.new(
          [resource.presence_day, related_entry.try(:presence_day)]).call
        messages = results.map { |result| result.errors.messages }.reduce({}, :merge)
        fail InvalidResourcesError.new(resource, messages) unless messages.empty?
      end

      def resource_representer
        ::Api::V1::TimeEntriesRepresenter
      end
    end
  end
end
