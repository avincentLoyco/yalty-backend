module API
  module V1
    class WorkingPlacesController < ApplicationController
      authorize_resource except: :create
      include WorkingPlaceSchemas

      def index
        render_resource(resources_by_status(WorkingPlace, EmployeeWorkingPlace))
      end

      def show
        render_resource(resource)
      end

      def create
        verified_dry_params(dry_validation_schema) do |attributes|
          holiday_policy_id = attributes.delete(:holiday_policy).try(:[], :id)
          @resource = Account.current.working_places.new(attributes)
          authorize! :create, resource
          transactions do
            resource.save!
            AssignHolidayPolicy.new(resource, holiday_policy_id).call
          end
          render_resource(resource, status: :created)
        end
      end

      def update
        verified_dry_params(dry_validation_schema) do |attributes|
          holiday_policy_id = attributes.delete(:holiday_policy).try(:[], :id)
          transactions do
            resource.update(attributes)
            AssignHolidayPolicy.new(resource, holiday_policy_id).call
          end
          render_no_content
        end
      end

      def destroy
        if resource.employees.blank?
          resource.destroy!
          render_no_content
        else
          locked_error
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
