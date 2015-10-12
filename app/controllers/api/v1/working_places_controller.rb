module API
  module V1
    class WorkingPlacesController < ApplicationController
      include WorkingPlaceRules

      def index
        render_resource(resources)
      end

      def show
        render_resource(resource)
      end

      def create
        verified_params(gate_rules) do |attributes|
          employees = employees_params(attributes)
          @resource = Account.current.working_places.new(attributes)

          if resource.save
            assign_employees(resource, employees)
            render_resource(resource, status: :created)
          else
            resource_invalid_error(resource)
          end
        end
      end

      def update
        verified_params(gate_rules) do |attributes|
          employees = employees_params(attributes)

          if resource.update(attributes)
            assign_employees(resource, employees)
            render_no_content
          else
            resource_invalid_error(resource)
          end
        end
      end

      def destroy
        resource.destroy!
        render_no_content
      end

      private

      def assign_employees(resource, employees)
        return if employees.nil?

        assign_collection(resource, employees, 'employees')
      end

      def employees_params(attributes)
        attributes.delete(:employees)
      end

      def resources
        @resources ||= Account.current.working_places
      end

      def resource
        @resource ||= resources.find(params[:id])
      end

      def resource_representer
        WorkingPlaceRepresenter
      end
    end
  end
end
