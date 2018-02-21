module API
  module V1
    class WorkingPlacesController < ApplicationController
      authorize_resource except: :create
      include WorkingPlaceSchemas

      def index
        render_resource(resources_by_status(WorkingPlace, EmployeeWorkingPlace).not_reset)
      end

      def show
        render_resource(resource)
      end

      def create
        verified_dry_params(dry_validation_schema) do |attributes|
          @resource = Account.current.working_places.new(attributes)
          authorize! :create, resource
          transactions do
            resource.save!
            AssignHolidayPolicy.new(resource).call
          end
          render_resource(resource, status: :created)
        end
      end

      def update
        verified_dry_params(dry_validation_schema) do |attributes|
          transactions do
            resource.update(attributes)
            AssignHolidayPolicy.new(resource).call
          end
          render_no_content
        end
      end

      def destroy
        if resource.employees.blank?
          resource.destroy!
          render_no_content
        else
          render_locked_error(controller_name, "employees")
        end
      end

      private

      def resource
        @resource ||= Account.current.working_places.find(params[:id])
      end

      def resource_representer
        ::Api::V1::WorkingPlaceRepresenter
      end
    end
  end
end
