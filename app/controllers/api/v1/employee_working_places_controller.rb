module API
  module V1
    class EmployeeWorkingPlacesController < ApplicationController
      include EmployeeWorkingPlacesRules

      def index
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
          resource = create_hash(resource.id).first
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
        authorize! :index, working_place
        create_hash(nil, working_place.id)
      end

      def employee_resources
        authorize! :index, employee
        create_hash(nil, nil, employee.id)
      end

      def create_hash(resource_id, working_place_id = nil, employee_id = nil)
        resources =
          JoinTableWithEffectiveTill
          .new(EmployeeWorkingPlace, Account.current.id, working_place_id, employee_id, resource_id)
          .call
        resources.map { |ewp_hash| EmployeeWorkingPlace.new(ewp_hash) }
      end

      def resource_representer
        Api::V1::EmployeeWorkingPlaceRepresenter
      end
    end
  end
end
