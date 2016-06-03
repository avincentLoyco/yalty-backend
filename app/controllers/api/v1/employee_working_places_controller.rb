module API
  module V1
    class EmployeeWorkingPlacesController < ApplicationController
      include EmployeeWorkingPlacesRules

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
        verified_params(gate_rules) do |attributes|
          authorize! :create, working_place
          resource = employee.employee_working_places.create!(attributes.except(:id))
          resource = resources_with_effective_till(EmployeeWorkingPlace, resource.id).first
          render_resource(resource, status: 201)
        end
      end

      private

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
