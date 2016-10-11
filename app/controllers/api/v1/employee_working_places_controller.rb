module API
  module V1
    class EmployeeWorkingPlacesController < ApplicationController
      include EmployeeWorkingPlacesSchemas
      include EmployeeBalancesPresenceVerification

      def index
        authorize! :index, EmployeeWorkingPlace.new
        if params[:working_place_id]
          render_resource(working_place_resources)
        else
          response = employee_resources.map do |resource|
            resource_representer.new(resource).working_place_json
          end
          render json: response
        end
      end

      def create
        verified_dry_params(dry_validation_schema) do |attributes|
          authorize! :create, working_place
          resource, status = create_or_update_join_table(WorkingPlace, attributes)
          render_resource(resource, status: status)
        end
      end

      def update
        verified_dry_params(dry_validation_schema) do |attributes|
          authorize! :update, resource
          updated_resource, status = create_or_update_join_table(WorkingPlace, attributes, resource)
          render_resource(updated_resource, status: status)
        end
      end

      def destroy
        authorize! :destroy, resource
        transactions do
          resource.destroy!
          destroy_join_tables_with_duplicated_resources
          verify_if_there_are_no_balances!
        end
        render_no_content
      end

      private

      def resource
        @resource ||= Account.current.employee_working_places.find(params[:id])
      end

      def working_place
        @working_place ||= Account.current.working_places.find(params[:working_place_id])
      end

      def employee
        id = params[:employee_id] ? params[:employee_id] : params[:id]
        @employee ||= Account.current.employees.find(id)
      end

      def working_place_resources
        resources_with_effective_till(EmployeeWorkingPlace, nil, working_place.id)
      end

      def employee_resources
        resources_with_effective_till(EmployeeWorkingPlace, nil, nil, employee.id)
      end

      def resource_representer
        Api::V1::EmployeeWorkingPlaceRepresenter
      end
    end
  end
end
