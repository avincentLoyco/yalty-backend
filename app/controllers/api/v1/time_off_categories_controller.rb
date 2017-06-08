module API
  module V1
    class TimeOffCategoriesController < ApplicationController
      include TimeOffCategoriesSchemas

      def show
        authorize! :show, Account.current
        render_resource(resource)
      end

      def index
        authorize! :index, TimeOffCategory.new, params[:employee_id]
        params[:employee_id].present? ? render_resources_for_employee : render_resource(resources)
      end

      def create
        verified_dry_params(dry_validation_schema) do |attributes|
          resource = Account.current.time_off_categories.new(attributes)
          authorize! :create, resource

          resource.save!
          render_resource(resource, status: :created)
        end
      end

      def update
        authorize! :create, editable_resource
        verified_dry_params(dry_validation_schema) do |attributes|
          editable_resource.update!(attributes)
          render_no_content
        end
      end

      def destroy
        authorize! :create, editable_resource
        if editable_resource.time_offs.empty?
          editable_resource.destroy!
          render_no_content
        else
          locked_error('time_off_category', 'time-off')
        end
      end

      private

      def render_resources_for_employee
        response =
          employee.time_off_categories.uniq.map do |resource|
            resource_representer.new(
              resource, PeriodsForTimeOffCategory.new(employee, resource).call
            ).complete
          end
        render json: response
      end

      def resource
        @resource ||= resources.find(params[:id])
      end

      def editable_resource
        @editable_resource ||= resources.editable.find(params[:id])
      end

      def resources
        @resources ||= Account.current.time_off_categories
      end

      def employee
        Account.current.employees.find(params[:employee_id])
      end

      def resource_representer
        ::Api::V1::TimeOffCategoryRepresenter
      end
    end
  end
end
