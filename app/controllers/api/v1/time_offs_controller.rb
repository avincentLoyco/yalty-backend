module API
  module V1
    class TimeOffsController < ApplicationController
      authorize_resource except: [:create, :index, :show]
      include TimeOffsSchemas

      def show
        authorize! :show, resource
        render_resource(resource)
      end

      def index
        authorize! :index, current_user
        render_resource(resources)
      end

      def create
        convert_times_to_utc
        verified_dry_params(dry_validation_schema) do |attributes|
          resource = TimeOff.new(time_off_attributes(attributes))
          authorize! :create, resource
          ::TimeOffs::Create.call(time_off_attributes(attributes)) do |create|
            create.add_observers(internal_dispatcher, email_dispatcher)
            create.on(:success) do |time_off|
              render_resource(time_off, status: :created)
            end
          end
        end
      end

      def update
        convert_times_to_utc
        verified_dry_params(dry_validation_schema) do |attributes|
          authorize! :update, resource
          update_scenario.call(resource, attributes) do |update|
            update.add_observers(
              internal_dispatcher, email_dispatcher, clear_notifications_observer
            )
            update.on(:success) { render_no_content }
          end
        end
      end

      def destroy
        ::TimeOffs::Destroy.call(resource) do |destroy|
          destroy.on(:success) { render_no_content }
        end
      end

      private

      def update_scenario
        can?(:approve, resource) ? ::TimeOffs::Update : ::TimeOffs::Resubmit
      end

      def time_off_category
        @time_off_category ||= Account.current.time_off_categories.find(time_off_category_id)
      end

      def time_off_category_id
        params[:time_off_category_id] || params[:time_off_category][:id]
      end

      def employee
        @employee ||= Account.current.employees.find(params[:employee][:id])
      end

      def resource
        @resource ||= Account.current.time_offs.find(params[:id])
      end

      def resources
        return time_off_category.time_offs if current_user.owner_or_administrator?
        return TimeOff.none unless current_user.employee
        time_off_category.time_offs.where(employee: current_user.employee)
      end

      def time_off_attributes(attributes)
        attributes
          .except(:employee, :time_off_category)
          .merge(employee: employee, being_processed: true, time_off_category: time_off_category)
      end

      def resource_representer
        ::Api::V1::TimeOffRepresenter
      end

      def convert_times_to_utc
        return unless params[:start_time].present? && params[:end_time].present?
        params[:start_time] = params.delete(:start_time) + "+00:00"
        params[:end_time] = params.delete(:end_time) + "+00:00"
      end

      def clear_notifications_observer
        ::ClearNotificationsObserver.new
      end
    end
  end
end
