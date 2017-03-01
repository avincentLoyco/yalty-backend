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

          join_table_resource = previous_join_table_resource
          attributes[:employee_id] = attributes.delete(:id)
          response = create_or_update_join_table(WorkingPlace, attributes)
          if response[:status] == 201 || join_table_resource
            find_and_update_balances(response[:result], attributes, nil, join_table_resource)
          end

          render_join_table(response[:result], response[:status])
        end
      end

      def update
        verified_dry_params(dry_validation_schema) do |attributes|
          authorize! :update, resource
          previous_date = resource.effective_at
          join_table_resource = previous_join_table_resource

          response = create_or_update_join_table(WorkingPlace, attributes, resource)
          find_and_update_balances(resource, attributes, previous_date, join_table_resource)
          render_join_table(response[:result], response[:status])
        end
      end

      def destroy
        authorize! :destroy, resource
        transactions do
          resource.destroy!
          clear_respective_reset_join_tables(resource.employee, resource.effective_at)
          destroy_join_tables_with_duplicated_resources
          find_and_update_balances(resource)
        end
        render_no_content
      end

      private

      def previous_join_table_resource
        employee
          .employee_working_places
          .find_by(effective_at: params[:effective_at])
          .try(:working_place)
      end

      def resource
        @resource ||= Account.current.employee_working_places.not_reset.find(params[:id])
      end

      def working_place
        @working_place ||= Account.current.working_places.find(params[:working_place_id])
      end

      def employee
        @employee ||=
          if request.put?
            resource.employee
          else
            id = params[:employee_id] ? params[:employee_id] : params[:id]
            Account.current.employees.find(id)
          end
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
